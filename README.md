# Flutter GT7 Dashboard

A cross-platform application built with Flutter that receives telemetry data transmitted via UDP communication from the racing game *Gran Turismo 7 (GT7)* and displays it as a dashboard on iOS/Android and other platforms.

This project extracts accurate data from GT7's telemetry packets and provides drivers with essential information in real-time.

By adding a packet specification document, you can now build custom dashboards using vibe coding.

<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
  <img src="assets/photo/git1.jpg" alt="現在のアプリ画面" width="335" style="flex: 1 1 auto; max-width: 300px;">
  <img src="assets/photo/git2.jpg" alt="ダッシュボード拡張例" width="300" style="flex: 1 1 auto; max-width: 300px;">
</div>


## Extension Examples
<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
  <img src="assets/photo/git3.jpg" alt="ダッシュボード拡張例" width="150" style="flex: 1 1 auto; max-width: 100px;">
  <img src="assets/photo/git4.jpg" alt="ダッシュボード拡張例" width="400" style="flex: 1 1 auto; max-width: 500px;">
</div>



## 🚀 Features

* **Cross-platform Support**: Built with Flutter, it runs on various platforms including iOS and Android.
* **IP Address Configuration**: Set and save the PlayStation's IP address and UDP port (typically 33740) within the app.
* **Communication Control**: Start/stop data reception with a single button.
* **Packet Parsing**: Decrypts GT7's proprietary encrypted (Salsa20) packets and performs accurate data extraction.
* **Real-time Data Display**:
   * RPM (Engine Speed)
   * Car Speed
   * Current Gear
   * Pedal Inputs (Throttle, Brake)

## 🔧 Technical Stack

| Element | Details |
|---------|---------|
| Framework | Flutter (Dart) |
| Communication | UDP Socket |
| Encryption | Salsa20 (Custom implementation or library) |
| Supported Platforms | Android, iOS |

## 📐 Data Offsets Reference

Key telemetry data offsets used in the decoding process. (Offsets may change with GT7 version updates)

| Data Name | Offset (Dec) | Data Type |
|-----------|--------------|-----------|
| RPM | 60 | Float |
| Speed | 76 | Float |
| Current Gear | 144 | Unsigned Byte |
| Throttle Input | 145 | Unsigned Byte |
| Brake Input | 146 | Unsigned Byte |

## Built with Vibe Coding

<div style="display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;">
  <img src="assets/photo/git5.jpg" alt="Vibe coding example 1" width="300" style="flex: 1 1 auto; max-width: 300px;">
  <img src="assets/photo/git6.jpg" alt="Vibe coding example 2" width="300" style="flex: 1 1 auto; max-width: 300px;">
  <img src="assets/photo/git7.jpg" alt="Vibe coding example 3" width="300" style="flex: 1 1 auto; max-width: 300px;">
</div>
