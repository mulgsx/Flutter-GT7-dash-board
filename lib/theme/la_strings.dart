/// Lap Analyzer画面群(ホーム/キャプチャ/オフライン比較/リアルタイム比較)で
/// 使う文言をここに集約する。文言修正のたびに複数ファイルを探し回らずに済む
/// Centralizes the user-facing text for the Lap Analyzer screens (home /
/// capture / offline compare / realtime compare), so wording changes don't
/// require hunting across multiple files.
class LAStrings {
  LAStrings._();

  // ---- 共通 / Common ----
  static const String cancel = 'キャンセル';
  static const String ok = 'OK';
  static const String back = '戻る';
  static const String target = 'ターゲット';
  static const String best = 'ベストラップ';

  // ---- ホーム画面 / Home screen ----
  static const String homeTitle = 'Home';
  static const String ipSettings = 'IP設定';
  static const String dashboardScreen = 'ダッシュボード画面';
  static const String targetNotLoaded = 'ターゲット: 未読み込み';
  static String targetLoaded(String time) => 'ターゲット: $time';
  static const String bestNotLoaded = 'ベスト: 未読み込み';
  static String bestLoaded(String time) => 'ベスト: $time';
  static const String loadTarget = 'ターゲット読み込み';
  static const String loadBest = '自分のベストラップ読み込み';
  static const String realtimeCompareSectionLabel = 'リアルタイム差分比較(比較相手を選択)';
  static const String compareWithTarget = 'ターゲットと比較';
  static const String compareWithBest = 'ベストラップと比較';
  static const String offlineCompareButton = 'オフライン比較(未作成)';

  static const String notReceivingTitle = 'テレメトリを受信できていません';
  static const String notReceivingMessage =
      'PS5からのUDPテレメトリが届いていません。IPアドレスや受信開始の状態を確認してください。\n'
      'このまま進んでも、接続が確立するまでラップは記録されません。';
  static const String proceedAnyway = 'このまま進む';

  static String deleteConfirmTitle(String label) => '$labelを削除しますか?';
  static String deleteConfirmMessage(String label) =>
      '既存の$labelを削除して、新しく記録し直します。';

  static String notLoadedTitle(String label) => '$labelが未読み込みです';
  static String notLoadedMessage(String label) => '先に$labelを読み込んでください。';

  // ---- キャプチャ画面 / Capture screen ----
  static String captureTitle(String label) => '$label読み込み';
  static const String discardRecordingTitle = '記録を中断しますか?';
  static const String discardRecordingMessage =
      'ラップを記録中です。今戻ると、この周回の記録は破棄されます。';
  static const String continueRecording = '続ける';
  static String recordingArmedInstruction(String label) =>
      '1周走ってください\n完了すると自動的に$labelとして保存されます';
  static const String waitingForLapStart = '次のラップ開始(スタート/ゴールライン通過)を待っています…';
  static String recordedResult(String label, String time) =>
      '記録できました($label: $time)';
  static const String recordingLabel = '記録中';
  static const String monitoringLabel = 'モニタリング中(未確定)';
  static String recordingProgress(
    String label,
    int count,
    String distanceM,
    String elapsedSec,
  ) => '$label: $count サンプル / $distanceM m / $elapsedSec 秒';
  static String recordingComplete(int count, String distanceM) =>
      '記録完了: $count サンプル / $distanceM m';
  static const String retryCapture = 'もう一度記録する';
  static const String returnHome = 'ホームに戻る';

  // ---- オフライン比較画面 / Offline compare screen ----
  static const String offlineCompareTitle = 'オフライン比較';
  static const String targetThrottle = 'ターゲット throttle';
  static const String bestThrottle = 'ベスト throttle';
  static const String targetBrake = 'ターゲット brake';
  static const String bestBrake = 'ベスト brake';

  // ---- リアルタイム比較画面 / Realtime compare screen ----
  static String realtimeCompareTitle(String opponentLabel) =>
      'リアルタイム差分比較($opponentLabel)';
  static const String startSpeed = 'スタート速度';
  static String ownValue(String value) => '自分 $value';
  static String targetValueKmh(String value) => '/ 対象 $value km/h';
  static const String deltaVsTargetLabel = 'ターゲット比(秒)';
  static const String waitingForStartLine = 'スタートラインを通過すると表示されます';
  static const String speed = '速度';
  static const String brakingPointDelta = 'ブレーキング地点差';
  static const String throttle = 'アクセル';
  static const String brake = 'ブレーキ';
  static const String linePosition = 'ライン位置(対ターゲット)';
}
