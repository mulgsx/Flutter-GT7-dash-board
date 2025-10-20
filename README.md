# Flutter GT7 Dashboard

A cross-platform application built with Flutter that receives telemetry data transmitted via UDP communication from the racing game *Gran Turismo 7 (GT7)* and displays it as a dashboard on iOS/Android and other platforms.

This project extracts accurate data from GT7's telemetry packets and provides drivers with essential information in real-time.

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

## 💡 Extension Ideas

* **Rich Custom Gauges**: Implement speedometer and tachometer UI with animations and visual effects.
* **Data Logging**: Save received data to a backend like Firebase or local database to enable analysis of driving history.
* **UX Improvements**: Add automatic IP address detection functionality.
