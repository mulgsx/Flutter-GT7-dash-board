import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../extensions/build_context_extensions.dart';
import '../services/gt7_telemetry_service.dart';
import '../theme/app_colors.dart';
import 'dialogs/input_value_dialog.dart';

class TelemetryDrawer extends StatefulWidget {
  // Drawer が必要な状態をすべて service から自分で取得する
  // The drawer owns its own state watching by holding the service directly
  final GT7TelemetryService service;

  const TelemetryDrawer({super.key, required this.service});

  @override
  State<TelemetryDrawer> createState() => _TelemetryDrawerState();
}

class _TelemetryDrawerState extends State<TelemetryDrawer>
    with SingleTickerProviderStateMixin {
  // パルスアニメーション用コントローラ / Controller for the pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // 1.0（明るい）→ 0.0（暗い）へフェードアウトする / Fades from bright to dim
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    // パケットが届くたびにアニメーションをリセットして再生する
    // Restart animation each time a new packet arrives
    widget.service.packetCountNotifier.addListener(_onPacket);
  }

  void _onPacket() {
    _pulseController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.service.packetCountNotifier.removeListener(_onPacket);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      // 受信中かどうかを監視する / Watches whether the service is listening
      valueListenable: widget.service.isListeningNotifier,
      builder: (context, isListening, _) {
        return ValueListenableBuilder<String>(
          // 接続ステータスのテキストを監視する / Watches the connection status text
          valueListenable: widget.service.statusNotifier,
          builder: (context, status, _) {
            return ValueListenableBuilder<StatusType>(
              // 接続ステータスの種別を監視する / Watches the connection status type
              valueListenable: widget.service.statusTypeNotifier,
              builder: (context, statusType, _) {
                return _buildDrawer(context, isListening, status, statusType);
              },
            );
          },
        );
      },
    );
  }

  Color _colorForStatusType(StatusType statusType) {
    switch (statusType) {
      case StatusType.receiving:
        return AppColors.statusReceiving;
      case StatusType.error:
        return AppColors.statusError;
      case StatusType.connecting:
        return AppColors.statusConnecting;
      case StatusType.idle:
        return AppColors.statusIdle;
    }
  }

  Widget _buildDrawer(
    BuildContext context,
    bool isListening,
    String status,
    StatusType statusType,
  ) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Drawer(
        // 横向き画面の40%を占める幅に設定する / Set width to 40% of the landscape screen
        width: MediaQuery.of(context).size.width * 0.4,
        child: SingleChildScrollView(
          // キーボード表示時に入力欄が隠れないよう下に余白を追加する
          // Add bottom padding so input fields stay visible above the keyboard
          padding: context.keyboardPadding,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                // Drawer 内の全 Widget を幅いっぱいに伸ばす / Stretches all children to full drawer width
                // Widget 側に個別指定せず Column で一括制御する / Controlled here on the Column rather than per widget
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drawer 上部のタイトル表示 / Title at the top of the drawer
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  TextField(
                    // 入力値は service 側で管理し、startListening() で参照する
                    // The value is managed by the service and read when startListening() is called
                    controller: widget.service.ipController,
                    // タップ時はダイアログで入力させ、この場ではキーボードを出さない
                    // Tapping opens the input dialog instead of showing the keyboard here
                    readOnly: true,
                    showCursor: false,
                    onTap: () => InputValueDialog.show(
                      context,
                      title: 'PS5 IP Address',
                      controller: widget.service.ipController,
                      // 数字キーボードを表示する
                      // decimal: true  → .（ドット）キーを表示する（IPアドレスに必要）
                      // signed: false  → −（マイナス）キーを非表示にする（IPに不要）
                      // Shows a numeric keyboard
                      // decimal: true  → show the . key (needed for IP addresses)
                      // signed: false  → hide the − key (not needed for IP)
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      // キーボードをすり抜けた入力を制限する
                      // 数字（0〜9）とドット（.）以外は入力できない
                      // Filters out any input that passes through the keyboard
                      // Only digits (0–9) and dots (.) are allowed
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                      ],
                      hintText: 'ex: 192.168.0.50',
                    ),
                    decoration: InputDecoration(
                      // フォーカス時に上に浮き上がるラベル / Label that floats above the field when focused
                      labelText: 'PS5 IP Address',
                      // 未入力時にグレーで表示されるヒント / Placeholder shown in grey when empty
                      hintText: 'ex: 192.168.0.50',
                      // 枠線を四角形で表示する / Displays a rectangular border around the field
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ValueListenableBuilder<bool>(
                    // GT7未接続の間（car_id 未確定）は入力欄を非活性にする
                    // Disabled while not connected to GT7 (car_id not yet known)
                    valueListenable: widget.service.revWarningEditableNotifier,
                    builder: (context, editable, _) {
                      return TextField(
                        // 値は service 側で管理する（IP フィールドと同じパターン）
                        // Value is managed by the service, same pattern as the IP field
                        controller: widget.service.revWarningController,
                        enabled: editable,
                        // タップ時はダイアログで入力させ、この場ではキーボードを出さない
                        // Tapping opens the input dialog instead of showing the keyboard here
                        readOnly: true,
                        showCursor: false,
                        onTap: () => InputValueDialog.show(
                          context,
                          title: 'Rev Warning RPM',
                          controller: widget.service.revWarningController,
                          focusNode: widget.service.revWarningFocusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          hintText: 'ex: 6800',
                          // Enter で確定した場合もフォーカスを外さず保存できるようにする
                          // Also commit on Enter, so it saves without requiring the user to tap away
                          onSubmitted: widget.service.commitRevWarningOverride,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Rev Warning RPM',
                          hintText: editable ? 'ex: 6800' : 'Connect to GT7 first',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // 受信中: statusError（stop） / 停止中: statusReceiving（start）
                      // Listening: statusError (stop) / Stopped: statusReceiving (start)
                      backgroundColor: isListening
                          ? AppColors.statusError
                          : AppColors.statusReceiving,
                      // 赤・緑どちらでも視認できるよう文字色は白固定
                      // White text ensures readability on both colors
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 開始ボタン押下時にIPアドレスを渡してリスニングを開始し、成功時のみDrawerを閉じる
                    // Starts listening with the entered IP address; closes the drawer only on success
                    // 停止ボタン押下時にリスニングを停止する（Drawerは閉じない）
                    // Stops listening when the stop button is tapped (does not close the drawer)
                    onPressed: isListening
                        ? widget.service.stopListening
                        : () async {
                            final success = await widget.service
                                .startListening(
                                  widget.service.ipController.text,
                                );
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: Text(
                      isListening ? 'Stop Receiving' : 'Start Receiving',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PacketRateIndicator(
                    service: widget.service,
                    pulseAnimation: _pulseAnimation,
                  ),
                  const Divider(),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      fontSize: 14,
                      color: _colorForStatusType(statusType),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// パルスドット + Hz 表示をまとめたプライベート Widget
// Private widget combining the pulse dot and Hz display
class _PacketRateIndicator extends StatelessWidget {
  final GT7TelemetryService service;
  final Animation<double> pulseAnimation;

  const _PacketRateIndicator({
    required this.service,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      // 受信レート（Hz）を監視する / Watches the reception rate in Hz
      valueListenable: service.packetRateNotifier,
      builder: (context, rate, _) {
        return Row(
          children: [
            // パケット受信のたびに光るパルスドット / Pulse dot that lights up on each packet
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, _) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      Colors.green.shade900,
                      Colors.greenAccent,
                      pulseAnimation.value,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${rate.toStringAsFixed(1)} Hz',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        );
      },
    );
  }
}
