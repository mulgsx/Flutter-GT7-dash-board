import 'package:flutter_test/flutter_test.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/lap_capture.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/lap_capture_service.dart';
import 'package:gt7_trj_log/models/gt7_models.dart';
import 'package:gt7_trj_log/services/gt7_telemetry_service.dart';

GT7Packet _packet({
  int currentLap = 1,
  int lapTime = -1,
  double positionX = 0,
  double positionZ = 0,
  double speedKmh = 100,
  double gas = 1.0,
  double brake = 0.0,
}) {
  return GT7Packet(
    positionX: positionX,
    positionY: 0,
    positionZ: positionZ,
    speedKmh: speedKmh,
    engineRPM: 5000,
    gear: 3,
    gas: gas,
    brake: brake,
    lapTime: lapTime,
    revWarningRpm: -1,
    revLimiterRpm: -1,
    carId: 1,
    currentFuel: 50,
    fuelCapacity: 100,
    tyreTempFL: 80,
    tyreTempFR: 80,
    tyreTempRL: 80,
    tyreTempRR: 80,
    currentLap: currentLap,
    totalLaps: -1,
    bestLapMs: -1,
    tcsActive: false,
  );
}

void main() {
  group('LapCaptureService', () {
    test('buffers samples during a lap and reports distance via currentSampleNotifier', () {
      final telemetry = GT7TelemetryService();
      final service = LapCaptureService(
        telemetryService: telemetry,
        onLapCompleted: (_) {},
        onReferenceLapCaptured: (_) {},
      );

      telemetry.latestPacketNotifier.value = _packet(positionX: 0);
      expect(service.currentSampleNotifier.value?.distanceM, 0);

      telemetry.latestPacketNotifier.value = _packet(positionX: 10);
      expect(service.currentSampleNotifier.value?.distanceM, closeTo(10, 0.001));

      service.dispose();
    });

    test(
      'finalizes a practice lap as LapType.practice when last_lap changes, '
      'with LAP_TIME_MS taken from the claimed last_lap value',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        // 最初に見えたラップ(=いつ始まったか不明)は境界を跨いだ時点で破棄される
        // The first lap ever observed (unknown start) is discarded at the next boundary
        telemetry.latestPacketNotifier.value = _packet(lapTime: -1);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000);
        expect(completed, isEmpty);

        // ここからは開始時刻が確定した状態で次のラップを計測する。実測1000ms
        // 地点と70000ms地点の2サンプルを置き、測定される経過時間を意味あるもの
        // にする
        // From here, the next lap is tracked with a known start time. Two
        // samples at the 1000ms and 70000ms marks give a meaningful measured
        // elapsed duration.
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, positionX: 5);
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, positionX: 8);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69266);

        expect(completed, hasLength(1));
        expect(completed.single.type, LapType.practice);
        // GT7自身の申告値(last_lap)がそのまま採用される
        // GT7's own claimed value (last_lap) is used as-is
        expect(completed.single.lapTimeMs, 69266);
        expect(completed.single.samples, hasLength(3));

        service.dispose();
      },
    );

    test(
      'requestCapture(target) waits for the next current_lap increase while '
      'monitoring before capturing (a lap already in progress when the '
      'button is pressed finishes as a plain practice lap, unaffected by '
      'the pending request), and reports it via onReferenceLapCaptured with '
      'type target',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final referenceCaptured = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: referenceCaptured.add,
          now: () => fakeNow,
        );

        // 開始時刻を確定させるための準備 / Prime a known lap-start time
        telemetry.latestPacketNotifier.value = _packet(lapTime: -1, currentLap: 1);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, currentLap: 1);

        // ボタンを押した時点で周回の途中 / Mid-lap when the button is pressed
        service.requestCapture(LapType.target);
        expect(service.pendingCaptureNotifier.value, LapType.target);
        // アーム前: 既存の(無関係な)ラップのデータをUIに見せてはいけない
        // Before arming: must not expose the pre-existing (unrelated) lap data to the UI
        expect(service.isArmedRecordingNotifier.value, isFalse);
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          currentLap: 1,
          positionX: 3,
        );
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // この境界はまだキャプチャ対象ではない(要求後もまだcurrent_lapの
        // 増加=スタートライン通過が起きていないため、通常のプラクティス
        // ラップとして終わる)
        // This boundary isn't captured yet (no current_lap increase has
        // happened since the request, so it finishes as a plain practice lap)
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          currentLap: 1,
          positionX: 6,
        );
        telemetry.latestPacketNotifier.value = _packet(lapTime: 71000, currentLap: 1);
        expect(referenceCaptured, isEmpty);
        expect(completed, hasLength(1));
        expect(completed.single.type, LapType.practice);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // 瞬間移動(リプレイのループ再生地点)は常にモニタリングへ戻すだけ
        // (currentLapの減少はアーム合図として扱わない)
        // The teleport (replay loop-restart) always just falls back to
        // monitoring (a currentLap decrease is never treated as the arm signal)
        fakeNow = fakeNow.add(const Duration(seconds: 2));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 71000,
          currentLap: 0,
          positionX: 1000,
        );
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // 数サンプル後、current_lapが増加する。これがスタートライン通過の
        // 合図としてアームする。UIも即座に赤くなる
        // A few samples later, current_lap increases. This is the "crossed
        // the start line" signal that arms here. The UI turns red immediately.
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 71000,
          currentLap: 1,
          positionX: 1010,
        );
        expect(service.isArmedRecordingNotifier.value, isTrue);

        // 境界パケット自身も新ラップの最初のサンプルとして数えられる
        // The boundary packet itself also counts as the new lap's first sample
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 71000,
          currentLap: 1,
          positionX: 1015,
        );
        expect(service.currentLapSamples, hasLength(2));

        // 次の境界でキャプチャ完了 / Captured at the following boundary
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 71000,
          currentLap: 1,
          positionX: 1020,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 69266,
          currentLap: 2,
          positionX: 1030,
        );

        expect(referenceCaptured, hasLength(1));
        expect(referenceCaptured.single.type, LapType.target);
        // GT7自身の申告値(last_lap)がそのまま採用される
        // GT7's own claimed value (last_lap) is used as-is
        expect(referenceCaptured.single.lapTimeMs, 69266);
        expect(completed, hasLength(2));
        expect(service.pendingCaptureNotifier.value, isNull);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        service.dispose();
      },
    );

    test(
      'trims idle (near-stationary) samples from both ends of a finalized lap, '
      're-basing elapsed time and distance to the first real driving sample',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        // 最初に見えたラップ(基準がまだ無いので、次の境界で破棄される)
        // The first lap ever observed (discarded at the next boundary, no baseline yet)
        telemetry.latestPacketNotifier.value = _packet(lapTime: -1, speedKmh: 100);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 0);

        // スタート地点に停止したまま少し待機(アイドル)
        // Sits idle at the start, still stopped
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 0,
          positionX: 0,
        );
        // ゆっくり動き出す(まだ閾値未満) / Starts crawling (still below the driving threshold)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 3,
          positionX: 1,
        );
        // ここから「実際に走っている」とみなされる範囲 / From here on, considered "actually driving"
        fakeNow = fakeNow.add(const Duration(seconds: 1));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 100,
          positionX: 10,
        );

        // 次のラップ境界(last_lapの変化)でこのラップが確定する。
        // 末尾は「実質的に走っている」速度で終わる(停止して終わる場合の破棄は別テストで検証)
        // The next lap boundary (last_lap changing) finalizes this lap. It ends at
        // a "still really driving" speed (the stop-ending discard case is covered separately)
        fakeNow = fakeNow.add(const Duration(seconds: 41));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 100,
          positionX: 40,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 42000,
          speedKmh: 100,
          positionX: 40,
        );

        expect(completed, hasLength(1));
        final lap = completed.single;
        // 閾値未満だった先頭・末尾のサンプルが取り除かれている
        // The below-threshold leading/trailing samples have been removed
        expect(lap.samples, hasLength(2));
        expect(lap.samples.every((s) => s.speedKmh >= 5), isTrue);
        // 残った先頭サンプルを基準に0へ振り直されている
        // Re-based to 0 at the first remaining sample
        expect(lap.samples.first.elapsedMs, 0);
        expect(lap.samples.first.distanceM, 0);
        expect(lap.startSpeedKmh, 100);
        // GT7自身の申告値(last_lap)がそのまま採用される
        // GT7's own claimed value (last_lap) is used as-is
        expect(lap.lapTimeMs, 42000);

        service.dispose();
      },
    );

    test(
      'discards a segment that ends coasted to a stop (a misdetected finish), '
      'but still captures the very next lap normally instead of also '
      'discarding it',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        // 開始時刻を確定させるための準備 / Prime a known lap-start time
        telemetry.latestPacketNotifier.value = _packet(lapTime: -1, speedKmh: 100);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 100);

        // ゴール後に停止して終わる(=誤検知)区間 / A segment that ends coasted to a stop (misdetected)
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 130);
        fakeNow = fakeNow.add(const Duration(seconds: 70));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 2);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69945, speedKmh: 1);
        expect(completed, isEmpty); // 破棄される / Discarded

        // 破棄の直後でも、次のラップがきれいなら巻き込まれずに確定される
        // (かつては次の区間も無条件で破棄していたが、それだと正常なラップまで
        // 巻き込んで捨ててしまい、いつまでも確定しなくなる不具合があった)
        // Even right after a discard, the very next lap is still captured
        // normally if it's clean (previously the next segment was also
        // unconditionally discarded, which ended up throwing away perfectly
        // good laps and meant nothing could ever be confirmed)
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69945, speedKmh: 130);
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69945, speedKmh: 132);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69069, speedKmh: 135);

        expect(completed, hasLength(1));
        // GT7自身の申告値(last_lap)がそのまま採用される
        // GT7's own claimed value (last_lap) is used as-is
        expect(completed.single.lapTimeMs, 69069);
        expect(completed.single.samples, hasLength(2));

        service.dispose();
      },
    );

    test(
      'discards a segment that stops somewhere in the middle, even when it '
      'ends back at high speed (the stop + replay-loop-restart landed inside '
      'a single detected segment, not at its tail)',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        // 開始時刻を確定させるための準備 / Prime a known lap-start time
        telemetry.latestPacketNotifier.value = _packet(lapTime: -1, speedKmh: 100);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 100);

        // 区間の途中で停止(ループ再生の巻き戻り)を挟み、また高速に戻ってから
        // 次の境界を迎える。末尾だけ見ると「普通に走っている」ように見えてしまう
        // A stop (replay loop-restart) buried mid-segment, then back to high
        // speed before the next boundary. Looking only at the tail would make
        // this look like a perfectly normal segment.
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 130);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 2);
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 135);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69000, speedKmh: 140);

        expect(completed, isEmpty);

        service.dispose();
      },
    );

    test(
      'discards a segment whose position teleports mid-lap, even when speed '
      'stays high the whole time (the replay loop-restart does not always '
      'coast to a stop first — sometimes it just jumps position)',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 0,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 100,
          positionX: 0,
        );

        // 速度は高いままだが、位置だけが瞬間移動している(=リプレイのループ再生)
        // Speed stays high throughout, but the position itself teleports (a
        // replay loop restart)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 110,
          positionX: 10,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 115,
          positionX: 500,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 120,
          positionX: 510,
        );
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 69000,
          speedKmh: 125,
          positionX: 520,
        );

        expect(completed, isEmpty);

        service.dispose();
      },
    );

    test(
      'accepts a segment that started right after a teleport once the next '
      'genuine last_lap boundary is detected, even when that boundary '
      'reports the exact same value as before (e.g. watching a fixed, '
      'looped replay of your own best lap, where last_lap never "changes")',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        // 最初のループ: 開始時刻が未確定なので次の境界で破棄される
        // First loop: discarded at the next boundary (no known start yet)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 0,
        );
        fakeNow = fakeNow.add(const Duration(milliseconds: 10));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 0,
        );
        expect(completed, isEmpty);

        // ゴール後、少し走ってから位置が瞬間移動する(リプレイがループする)
        // A bit after the finish, the position teleports (the replay loops)
        fakeNow = fakeNow.add(const Duration(seconds: 2));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 1000,
        );

        // 瞬間移動の直後から78秒間クリーンに走る。last_lap はしばらく-1のまま
        // (固定のベストラップの1周がまだ完了していないため)
        // Drives cleanly for 78 seconds right after the teleport. last_lap
        // stays at -1 for a while (this fixed best-lap loop hasn't completed yet)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 1010,
        );
        fakeNow = fakeNow.add(const Duration(seconds: 78));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 1020,
        );

        // ここでラップが完了し、last_lap が(前回とまったく同じ)70320になる
        // The lap completes here, and last_lap becomes 70320 again (identical
        // to before)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 1030,
        );

        expect(completed, hasLength(1));
        // GT7自身の申告値(last_lap)がそのまま採用される
        // GT7's own claimed value (last_lap) is used as-is
        expect(completed.single.lapTimeMs, 70320);

        service.dispose();
      },
    );

    test(
      'discards a segment that started right after a teleport and completed '
      'far too quickly for the claimed lap time (a random opponent-replay '
      'snippet), rather than accepting it just because a boundary was seen',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: (_) {},
          now: () => fakeNow,
        );

        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 0,
        );
        fakeNow = fakeNow.add(const Duration(milliseconds: 10));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 0,
        );

        // 瞬間移動(リプレイのループ) / A teleport (the replay loops)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 1000,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 1010,
        );

        // わずか数秒で(=対戦相手のランダムな断片)次の境界を迎える
        // The next boundary arrives after only a few seconds (a random snippet)
        fakeNow = fakeNow.add(const Duration(seconds: 5));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 1020,
        );

        expect(completed, isEmpty);

        service.dispose();
      },
    );

    test(
      'arms at the current_lap increase while monitoring (turning the UI '
      'red immediately) — a teleport always falls back to monitoring first, '
      'and finalizes as the requested capture at the following genuine '
      'last_lap boundary',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final referenceCaptured = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: (_) {},
          onReferenceLapCaptured: referenceCaptured.add,
          now: () => fakeNow,
        );

        // 開始時刻を確定させるための準備 / Prime a known lap-start time
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 2,
          speedKmh: 100,
          positionX: 0,
        );
        fakeNow = fakeNow.add(const Duration(milliseconds: 10));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          currentLap: 2,
          speedKmh: 100,
          positionX: 0,
        );

        service.requestCapture(LapType.best);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // 瞬間移動(スタート地点へのリセット)は常にモニタリングへ戻すだけ
        // (currentLapの減少はアーム合図として扱わない)。last_lapはリセット
        // 直後は-1のまま(実機ログで確認済み)
        // The teleport (position reset to the start) always just falls back
        // to monitoring (a currentLap decrease is never the arm signal).
        // last_lap stays -1 right after the reset (confirmed via real device logs)
        fakeNow = fakeNow.add(const Duration(seconds: 2));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 0,
          speedKmh: 100,
          positionX: 1000,
        );
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // 数サンプル後、current_lapが増加してアームする。UIも即座に赤くなる
        // A few samples later, current_lap increases and arms here. The UI
        // turns red immediately.
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 1,
          speedKmh: 100,
          positionX: 1010,
        );
        expect(service.isArmedRecordingNotifier.value, isTrue);

        // 瞬間移動の直後から70秒間クリーンに走る。last_lap はしばらく-1のまま
        // (固定のベストラップの1周がまだ完了していないため)
        // Drives cleanly for 70 seconds right after the teleport. last_lap
        // stays at -1 for a while (this fixed best-lap loop hasn't completed yet)
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 1,
          speedKmh: 100,
          positionX: 1015,
        );
        fakeNow = fakeNow.add(const Duration(seconds: 70));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 1,
          speedKmh: 100,
          positionX: 1020,
        );

        // 次の境界(last_lapの変化=ゴール)でこの周が確定し、要求されたベスト
        // ラップとして保存される。これはcurrent_lapの次の増加より前に起きる
        // (実機ログで確認済み: last_lapの更新→数秒後に瞬間移動→さらに数
        // サンプル後にcurrent_lap増加、の順)ため、次の増加を待たずにここで
        // 正しく判定できる
        // The next boundary (last_lap changing = finish) finalizes this lap
        // and saves it as the requested best-lap capture. This happens
        // before the next current_lap increase (confirmed via real device
        // logs: last_lap updates, then a few seconds later the teleport,
        // then a few samples after that current_lap increases), so this is
        // correctly judged without waiting for the next crossing.
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          currentLap: 2,
          speedKmh: 100,
          positionX: 1030,
        );

        expect(referenceCaptured, hasLength(1));
        expect(referenceCaptured.single.type, LapType.best);
        // GT7自身の申告値(last_lap)がそのまま採用される
        // GT7's own claimed value (last_lap) is used as-is
        expect(referenceCaptured.single.lapTimeMs, 70320);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        service.dispose();
      },
    );

    test(
      'discards (rather than accepts) a capture-armed segment that '
      'completes implausibly fast for its claimed lap time, and falls back '
      'to monitoring so the next current_lap increase arms it fresh again',
      () {
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final telemetry = GT7TelemetryService();
        final completed = <LapCapture>[];
        final referenceCaptured = <LapCapture>[];
        final service = LapCaptureService(
          telemetryService: telemetry,
          onLapCompleted: completed.add,
          onReferenceLapCaptured: referenceCaptured.add,
          now: () => fakeNow,
        );

        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 2,
          speedKmh: 100,
          positionX: 0,
        );
        fakeNow = fakeNow.add(const Duration(milliseconds: 10));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          currentLap: 2,
          speedKmh: 100,
          positionX: 0,
        );

        service.requestCapture(LapType.target);

        // 瞬間移動は常にモニタリングへ戻すだけ(last_lapは-1のまま)
        // The teleport always just falls back to monitoring (last_lap stays -1)
        fakeNow = fakeNow.add(const Duration(seconds: 2));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 0,
          speedKmh: 100,
          positionX: 1000,
        );
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // current_lapが増加してアームする / current_lap increases and arms
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 1,
          speedKmh: 100,
          positionX: 1005,
        );
        expect(service.isArmedRecordingNotifier.value, isTrue);

        // アームからわずか数秒で次の境界を迎える(申告タイムと矛盾する)
        // The next boundary arrives only a few seconds after arming
        // (inconsistent with the claimed lap time)
        fakeNow = fakeNow.add(const Duration(seconds: 3));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 1,
          speedKmh: 100,
          positionX: 1010,
        );
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          currentLap: 1,
          speedKmh: 100,
          positionX: 1020,
        );

        expect(referenceCaptured, isEmpty);
        // 破棄後はモニタリングモードに戻る(要求自体は残っている)
        // Falls back to monitoring after the discard (the request itself remains pending)
        expect(service.isArmedRecordingNotifier.value, isFalse);
        expect(service.pendingCaptureNotifier.value, LapType.target);

        // 次に瞬間移動→current_lap増加が起きると、改めてアームされる
        // The next teleport-then-current_lap-increase cycle arms it again
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 0,
          speedKmh: 100,
          positionX: 2000,
        );
        expect(service.isArmedRecordingNotifier.value, isFalse);
        fakeNow = fakeNow.add(const Duration(seconds: 5));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          currentLap: 1,
          speedKmh: 100,
          positionX: 2005,
        );
        expect(service.isArmedRecordingNotifier.value, isTrue);

        service.dispose();
      },
    );
  });
}
