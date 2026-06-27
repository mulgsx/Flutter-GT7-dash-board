import 'package:flutter/material.dart';

// BuildContext に便利なプロパティを追加する拡張メソッド集
// Extension methods that add utility properties to BuildContext
extension BuildContextX on BuildContext {
  // キーボードが表示されている高さ分だけ下に余白を作る
  // 入力欄がキーボードに隠れないよう、SingleChildScrollView の padding に使う
  // Creates bottom padding equal to the keyboard height,
  // so input fields stay visible above the keyboard inside a SingleChildScrollView
  EdgeInsets get keyboardPadding => EdgeInsets.only(
    bottom: MediaQuery.of(this).viewInsets.bottom,
  );
}
