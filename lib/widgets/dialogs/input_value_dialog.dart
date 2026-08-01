import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IPアドレスやRPM等、単一の値をキーボード入力させるための共通ダイアログ
/// Shared dialog for entering a single value (e.g. IP address, RPM) via keyboard
///
/// 通常のAlertDialogだとキーボード表示時にレイアウトが崩れやすいため、
/// 全画面（Dialog.fullscreen）にして、入力中の値を画面上部に大きく表示する
/// A plain AlertDialog tends to break its layout when the keyboard appears,
/// so this covers the full screen instead and shows the in-progress value large, near the top
class InputValueDialog extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;

  const InputValueDialog({
    super.key,
    required this.title,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.focusNode,
    this.hintText,
    this.onSubmitted,
  });

  /// ダイアログを表示するヘルパー / Helper that shows the dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    String? hintText,
    ValueChanged<String>? onSubmitted,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => InputValueDialog(
        title: title,
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        focusNode: focusNode,
        hintText: hintText,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<InputValueDialog> createState() => _InputValueDialogState();
}

class _InputValueDialogState extends State<InputValueDialog> {
  // Cancel時に戻すため、開いた時点の値を控えておく / Remembered so Cancel can restore it
  late final String _originalText;

  @override
  void initState() {
    super.initState();
    _originalText = widget.controller.text;
  }

  void _cancel() {
    // 編集内容を破棄して元の値に戻す / Discard edits and restore the original value
    widget.controller.text = _originalText;
    Navigator.of(context).pop();
  }

  void _confirm() {
    widget.onSubmitted?.call(widget.controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
          // leading はデフォルト幅56pxしかなくボタン2つだと収まらないため広げる
          // Default leading width (56px) is too narrow for two buttons, so widen it
          leadingWidth: 140,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _confirm,
                child: const Text('OK'),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: true,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  onSubmitted: (text) => _confirm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
