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

    test('finalizes a practice lap as LapType.practice when last_lap changes', () {
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

      // ここからは開始時刻が確定した状態で次のラップを計測する
      // From here, the next lap is tracked with a known start time
      telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, positionX: 5);
      fakeNow = fakeNow.add(const Duration(seconds: 70));
      telemetry.latestPacketNotifier.value = _packet(lapTime: 69266);

      expect(completed, hasLength(1));
      expect(completed.single.type, LapType.practice);
      expect(completed.single.lapTimeMs, 69266);
      expect(completed.single.samples, isNotEmpty);

      service.dispose();
    });

    test(
      'requestCapture(target) waits for the next lap boundary before capturing, '
      'and reports it via onReferenceLapCaptured with type target',
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
        telemetry.latestPacketNotifier.value = _packet(lapTime: -1);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000);

        // ボタンを押した時点で周回の途中 / Mid-lap when the button is pressed
        service.requestCapture(LapType.target);
        expect(service.pendingCaptureNotifier.value, LapType.target);
        // アーム前: 既存の(無関係な)ラップのデータをUIに見せてはいけない
        // Before arming: must not expose the pre-existing (unrelated) lap data to the UI
        expect(service.isArmedRecordingNotifier.value, isFalse);
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, positionX: 3);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // この境界はまだキャプチャ対象ではない(要求後の最初の境界=開始点)
        // This boundary isn't captured yet (first boundary after the request = the start point)
        fakeNow = fakeNow.add(const Duration(seconds: 71));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 71000);
        expect(referenceCaptured, isEmpty);
        expect(completed, hasLength(1));
        expect(completed.single.type, LapType.practice);
        // アームされた: ここからのサンプルはキャプチャ対象のラップのもの
        // Now armed: samples from here on belong to the lap being captured
        expect(service.isArmedRecordingNotifier.value, isTrue);

        // 境界パケット自身も新ラップの最初のサンプルとして数えられる
        // The boundary packet itself also counts as the new lap's first sample
        telemetry.latestPacketNotifier.value = _packet(lapTime: 71000, positionX: 20);
        expect(service.currentLapSamples, hasLength(2));

        // 次の境界でキャプチャ完了 / Captured at the following boundary
        fakeNow = fakeNow.add(const Duration(seconds: 69));
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69266);

        expect(referenceCaptured, hasLength(1));
        expect(referenceCaptured.single.type, LapType.target);
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
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 50000,
          speedKmh: 100,
          positionX: 10,
        );

        // 次のラップ境界(last_lapの変化)でこのラップが確定する。
        // 末尾は「実質的に走っている」速度で終わる(停止して終わる場合の破棄は別テストで検証)
        // The next lap boundary (last_lap changing) finalizes this lap. It ends at
        // a "still really driving" speed (the stop-ending discard case is covered separately)
        fakeNow = fakeNow.add(const Duration(seconds: 42));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 42000,
          speedKmh: 100,
        );

        expect(completed, hasLength(1));
        final lap = completed.single;
        // 閾値未満だった先頭・末尾のサンプルが取り除かれている
        // The below-threshold leading/trailing samples have been removed
        expect(lap.samples, hasLength(1));
        expect(lap.samples.every((s) => s.speedKmh >= 5), isTrue);
        // 残った先頭サンプルを基準に0へ振り直されている
        // Re-based to 0 at the first remaining sample
        expect(lap.samples.first.elapsedMs, 0);
        expect(lap.samples.first.distanceM, 0);
        expect(lap.startSpeedKmh, 100);
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
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 2);
        fakeNow = fakeNow.add(const Duration(seconds: 70));
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
        telemetry.latestPacketNotifier.value = _packet(lapTime: 69069, speedKmh: 135);

        expect(completed, hasLength(1));
        expect(completed.single.lapTimeMs, 69069);
        expect(completed.single.samples, isNotEmpty);

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
        telemetry.latestPacketNotifier.value = _packet(lapTime: 50000, speedKmh: 135);
        fakeNow = fakeNow.add(const Duration(seconds: 69));
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
      'arms for the requested capture via the post-lap teleport while '
      'monitoring, rather than waiting for a current_lap increase (real '
      'device logs showed current_lap can increase at unpredictable points '
      'mid-lap, which used to finalize segments far shorter than a real lap '
      'as if they were a complete one)',
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

        // 準備: 直前の周回が完了した状態にする
        // Prime it as if the previous lap just completed
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

        service.requestCapture(LapType.best);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        // ゴール後、リプレイがループしてスタート地点へ位置が瞬間移動する。
        // モニタリング中にこれが起きた時点でアームする(計測モード開始)
        // After the finish, the replay loops and position teleports back to
        // the start. Arms right here, since this happened while monitoring.
        fakeNow = fakeNow.add(const Duration(seconds: 2));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 1000,
        );
        expect(service.isArmedRecordingNotifier.value, isTrue);

        // 瞬間移動の直後から78秒間クリーンに走る
        // Drives cleanly for 78 seconds right after the teleport
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

        // 次の境界(last_lapの変化=ゴール)でこの周が確定し、要求されたベスト
        // ラップとして保存される
        // The next boundary (last_lap changing = finish) finalizes this lap
        // and saves it as the requested best-lap capture
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 1030,
        );

        expect(referenceCaptured, hasLength(1));
        expect(referenceCaptured.single.type, LapType.best);
        expect(referenceCaptured.single.lapTimeMs, 70320);
        expect(service.isArmedRecordingNotifier.value, isFalse);

        service.dispose();
      },
    );

    test(
      'discards (rather than accepts) a capture-armed segment that '
      'completes implausibly fast for its claimed lap time, instead of '
      'trusting whatever boundary happens to arrive next',
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
          speedKmh: 100,
          positionX: 0,
        );
        fakeNow = fakeNow.add(const Duration(milliseconds: 10));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 0,
        );

        service.requestCapture(LapType.target);

        // 瞬間移動でアームする / Arms via the teleport
        fakeNow = fakeNow.add(const Duration(seconds: 2));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: -1,
          speedKmh: 100,
          positionX: 1000,
        );
        expect(service.isArmedRecordingNotifier.value, isTrue);

        // アームからわずか数秒で次の境界を迎える(申告タイムと矛盾する)
        // The next boundary arrives only a few seconds after arming
        // (inconsistent with the claimed lap time)
        fakeNow = fakeNow.add(const Duration(seconds: 3));
        telemetry.latestPacketNotifier.value = _packet(
          lapTime: 70320,
          speedKmh: 100,
          positionX: 1010,
        );

        expect(referenceCaptured, isEmpty);
        // 破棄後もアーム状態は維持され、次の本物の周を捕まえようとし続ける
        // Arming survives the discard, so it keeps trying to catch the next real lap
        expect(service.isArmedRecordingNotifier.value, isTrue);

        service.dispose();
      },
    );
  });
}
