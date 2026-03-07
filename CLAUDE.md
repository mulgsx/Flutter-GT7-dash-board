# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Flutter app that receives GT7 (Gran Turismo 7) telemetry data over UDP and displays it as a real-time dashboard. GT7 sends encrypted UDP packets (Salsa20) from the PlayStation to port 33740; the app decrypts them and renders telemetry values.

## Commands

```bash
# Run the app
flutter run

# Run on a specific device
flutter run -d <device-id>

# Build
flutter build apk        # Android
flutter build ios        # iOS (requires macOS + Xcode)

# Analyze (lint)
flutter analyze

# Test
flutter test

# Install dependencies
flutter pub get
```

## Architecture

All app logic lives in `lib/` (3 files):

- **[lib/main.dart](lib/main.dart)** — Entry point and UI. `GT7RpmAppState` manages the UDP lifecycle (bind, listen, stop), heartbeat timer, and state via `ValueNotifier`. The app is locked to landscape orientation with immersive mode. IP address is persisted via `shared_preferences`.
- **[lib/gt7_decoder.dart](lib/gt7_decoder.dart)** — Packet decryption. `decodeSalsa20()` reconstructs the 8-byte IV from bytes 64–67 of the encrypted packet (XOR with `0xDEADBEAF`), decrypts with Salsa20 using the hardcoded 32-byte key, and validates the magic number `0x47375330`. Helper `getFloat()` reads little-endian float32 from a decoded packet at a given offset.
- **[lib/gt7_drawer.dart](lib/gt7_drawer.dart)** — Side drawer widget (`GT7Drawer`) for IP input, start/stop button, packet count, and connection status.

## GT7 UDP Protocol

- GT7 sends packets to port **33740** at ~60Hz when the app sends a heartbeat (`"A"`) to port **33739** every 100ms.
- Packets are Salsa20-encrypted. Key: first 32 bytes of `"Simulator Interface Packet GT7 ver 0.0"`.
- IV construction: take bytes [64:68] as `iv1` (little-endian uint32), compute `iv2 = iv1 ^ 0xDEADBEAF`, then IV = `[iv2_LE, iv1_LE]` (8 bytes).
- Magic number at offset 0x00 of decrypted data: `0x47375330` (`GT70`).
- Full telemetry offset reference is in [packet_structure.md](packet_structure.md). Key offsets: RPM=`0x3C`, Speed=`0x4C`, Gear=`0x90`, Throttle=`0x91`, Brake=`0x92`.

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `udp` | UDP socket binding and listening |
| `pointycastle` | Salsa20 decryption |
| `cryptography` | (available, not actively used) |
| `shared_preferences` | Persisting PS5 IP address |
