import 'dart:async';
import 'package:flutter/material.dart';

// ─── 定数 ────────────────────────────────────────────────────────────────────

const _bg    = Color(0xFF0A0A14);
const _panel = Color(0xFF0F0F1E);
const _rim   = Color(0xFF1E1E32);

const List<Color> _ledColors = [
  Color(0xFF4CAF50), Color(0xFF4CAF50), Color(0xFF4CAF50), Color(0xFF4CAF50),
  Color(0xFFFFD740), Color(0xFFFFD740), Color(0xFFFFD740), Color(0xFFFFD740),
  Color(0xFFFF1744), Color(0xFFFF1744), Color(0xFFFF1744), Color(0xFFFF1744),
];

// ─── ヘルパー ─────────────────────────────────────────────────────────────────

String _fmtLap(int ms) {
  if (ms < 0) return '--:--.---';
  final m   = ms ~/ 60000;
  final s   = (ms % 60000) ~/ 1000;
  final mil = ms % 1000;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${mil.toString().padLeft(3, '0')}';
}

String _fmtDelta(int ms) {
  final sign = ms >= 0 ? '+' : '-';
  final abs  = ms.abs();
  return '$sign${abs ~/ 1000}.${(abs % 1000).toString().padLeft(3, '0')}';
}

String _fmtRpm(double rpm) {
  final v = rpm.toInt();
  if (v >= 1000) return '${v ~/ 1000},${(v % 1000).toString().padLeft(3, '0')}';
  return '$v';
}

Color _tempColor(double t) {
  if (t <= 0)  return Colors.white12;
  if (t < 60)  return const Color(0xFF4FC3F7);
  if (t < 80)  return Color.lerp(const Color(0xFF4FC3F7), const Color(0xFF4CAF50), (t - 60) / 20)!;
  if (t < 100) return const Color(0xFF4CAF50);
  if (t < 120) return Color.lerp(const Color(0xFF4CAF50), const Color(0xFFFFD740), (t - 100) / 20)!;
  if (t < 140) return Color.lerp(const Color(0xFFFFD740), const Color(0xFFFF1744), (t - 120) / 20)!;
  return const Color(0xFFFF1744);
}

Color _wearColor(double w) {
  if (w > 0.6) return const Color(0xFF4CAF50);
  if (w > 0.3) return const Color(0xFFFFD740);
  return const Color(0xFFFF1744);
}

TextStyle _labelStyle(double h) =>
    TextStyle(color: Colors.white30, fontSize: (h * 0.020).clamp(10, 16), letterSpacing: 1.5);

// ─── メインウィジェット ───────────────────────────────────────────────────────

class RaceDashboard extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int>    rpmWarningNotifier;
  final ValueNotifier<int>    rpmLimiterNotifier;
  final ValueNotifier<double> speedNotifier;
  final ValueNotifier<int>    lapCountNotifier;
  final ValueNotifier<int>    lapsInRaceNotifier;
  final ValueNotifier<int>    bestLapNotifier;
  final ValueNotifier<int>    lastLapNotifier;
  final ValueNotifier<int>    currentLapMsNotifier;
  final ValueNotifier<double> fuelLevelNotifier;
  final ValueNotifier<double> fuelCapacityNotifier;
  final ValueNotifier<double> lapsRemainingNotifier;
  final ValueNotifier<double> fuelPerLapNotifier;
  final ValueNotifier<double> tyreTempFLNotifier;
  final ValueNotifier<double> tyreTempFRNotifier;
  final ValueNotifier<double> tyreTempRLNotifier;
  final ValueNotifier<double> tyreTempRRNotifier;
  final ValueNotifier<double> tyreWearFLNotifier;
  final ValueNotifier<double> tyreWearFRNotifier;
  final ValueNotifier<double> tyreWearRLNotifier;
  final ValueNotifier<double> tyreWearRRNotifier;

  const RaceDashboard({
    super.key,
    required this.rpmNotifier,
    required this.rpmWarningNotifier,
    required this.rpmLimiterNotifier,
    required this.speedNotifier,
    required this.lapCountNotifier,
    required this.lapsInRaceNotifier,
    required this.bestLapNotifier,
    required this.lastLapNotifier,
    required this.currentLapMsNotifier,
    required this.fuelLevelNotifier,
    required this.fuelCapacityNotifier,
    required this.lapsRemainingNotifier,
    required this.fuelPerLapNotifier,
    required this.tyreTempFLNotifier,
    required this.tyreTempFRNotifier,
    required this.tyreTempRLNotifier,
    required this.tyreTempRRNotifier,
    required this.tyreWearFLNotifier,
    required this.tyreWearFRNotifier,
    required this.tyreWearRLNotifier,
    required this.tyreWearRRNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final shiftH = (h * 0.052).clamp(24.0, 40.0);
        final fuelH  = (h * 0.095).clamp(48.0, 80.0);
        final gap    = (w * 0.007).clamp(4.0, 10.0);
        final pad    = (w * 0.007).clamp(4.0, 10.0);
        final leftW  = (w * 0.175).clamp(120.0, 200.0);
        final rightW = (w * 0.260).clamp(160.0, 280.0);

        return ColoredBox(
          color: _bg,
          child: Column(
            children: [
              SizedBox(
                height: shiftH,
                child: _ShiftLightBar(
                  rpmNotifier:        rpmNotifier,
                  rpmWarningNotifier: rpmWarningNotifier,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, gap * 0.5, pad, gap * 0.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: leftW,
                        child: _SpeedRpmPanel(
                          speedNotifier: speedNotifier,
                          rpmNotifier:   rpmNotifier,
                          h: h,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _LapPanel(
                          lapCountNotifier:     lapCountNotifier,
                          lapsInRaceNotifier:   lapsInRaceNotifier,
                          bestLapNotifier:      bestLapNotifier,
                          lastLapNotifier:      lastLapNotifier,
                          currentLapMsNotifier: currentLapMsNotifier,
                          h: h,
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                        width: rightW,
                        child: _TyrePanel(
                          tempFL: tyreTempFLNotifier,
                          tempFR: tyreTempFRNotifier,
                          tempRL: tyreTempRLNotifier,
                          tempRR: tyreTempRRNotifier,
                          wearFL: tyreWearFLNotifier,
                          wearFR: tyreWearFRNotifier,
                          wearRL: tyreWearRLNotifier,
                          wearRR: tyreWearRRNotifier,
                          h: h,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: fuelH,
                child: _FuelBar(
                  fuelLevelNotifier:     fuelLevelNotifier,
                  fuelCapacityNotifier:  fuelCapacityNotifier,
                  lapsRemainingNotifier: lapsRemainingNotifier,
                  fuelPerLapNotifier:    fuelPerLapNotifier,
                  lapCountNotifier:      lapCountNotifier,
                  lapsInRaceNotifier:    lapsInRaceNotifier,
                  h: h,
                  w: w,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── ① シフトライトバー ────────────────────────────────────────────────────────

class _ShiftLightBar extends StatefulWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int>    rpmWarningNotifier;
  const _ShiftLightBar({required this.rpmNotifier, required this.rpmWarningNotifier});

  @override
  State<_ShiftLightBar> createState() => _ShiftLightBarState();
}

class _ShiftLightBarState extends State<_ShiftLightBar> {
  Timer? _timer;
  bool _flash = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) setState(() => _flash = !_flash);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.rpmNotifier, widget.rpmWarningNotifier]),
      builder: (_, __) {
        final rpm     = widget.rpmNotifier.value;
        final warnRpm = widget.rpmWarningNotifier.value.toDouble();
        if (warnRpm <= 0) return _buildLEDs(0, false);
        final start      = warnRpm * 0.80;
        final isFlashing = rpm >= warnRpm;
        final lit        = isFlashing
            ? 12
            : ((rpm - start) / (warnRpm - start) * 12).clamp(0.0, 12.0).round();
        return _buildLEDs(lit, isFlashing);
      },
    );
  }

  Widget _buildLEDs(int lit, bool flashing) {
    final show = !flashing || _flash;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: List.generate(12, (i) {
          final on    = i < lit && show;
          final color = _ledColors[i];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                decoration: BoxDecoration(
                  color: on ? color : color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: on
                      ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)]
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── ② 左: スピード・RPM ──────────────────────────────────────────────────────

class _SpeedRpmPanel extends StatelessWidget {
  final ValueNotifier<double> speedNotifier;
  final ValueNotifier<double> rpmNotifier;
  final double h;

  const _SpeedRpmPanel({
    required this.speedNotifier,
    required this.rpmNotifier,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rim, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: ListenableBuilder(
        listenable: Listenable.merge([speedNotifier, rpmNotifier]),
        builder: (_, __) {
          final speed = speedNotifier.value;
          final rpm   = rpmNotifier.value;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('SPEED', style: _labelStyle(h)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    speed.toStringAsFixed(0),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: h * 0.110,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              Text('km/h', style: TextStyle(color: Colors.white38, fontSize: (h * 0.020).clamp(10, 16), letterSpacing: 2)),
              SizedBox(height: (h * 0.015).clamp(6, 18)),
              Divider(color: _rim, indent: 8, endIndent: 8, thickness: 1),
              SizedBox(height: (h * 0.010).clamp(4, 12)),
              Text('RPM', style: _labelStyle(h)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _fmtRpm(rpm),
                    style: TextStyle(
                      color: const Color(0xFF4FC3F7),
                      fontSize: h * 0.062,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── ③ 中央: ラップ情報 ───────────────────────────────────────────────────────

class _LapPanel extends StatelessWidget {
  final ValueNotifier<int> lapCountNotifier;
  final ValueNotifier<int> lapsInRaceNotifier;
  final ValueNotifier<int> bestLapNotifier;
  final ValueNotifier<int> lastLapNotifier;
  final ValueNotifier<int> currentLapMsNotifier;
  final double h;

  const _LapPanel({
    required this.lapCountNotifier,
    required this.lapsInRaceNotifier,
    required this.bestLapNotifier,
    required this.lastLapNotifier,
    required this.currentLapMsNotifier,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rim, width: 1.5),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: (h * 0.025).clamp(10, 24),
        vertical:   (h * 0.014).clamp(6, 16),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          lapCountNotifier, lapsInRaceNotifier,
          bestLapNotifier, lastLapNotifier, currentLapMsNotifier,
        ]),
        builder: (_, __) {
          final lap     = lapCountNotifier.value;
          final total   = lapsInRaceNotifier.value;
          final best    = bestLapNotifier.value;
          final last    = lastLapNotifier.value;
          final current = currentLapMsNotifier.value;
          final delta   = best > 0 ? current - best : 0;
          final dColor  = delta > 0 ? const Color(0xFFFF5252) : const Color(0xFF69F0AE);
          final lColor  = (last >= 0 && best >= 0 && last <= best)
              ? const Color(0xFF69F0AE) : Colors.white;

          return Column(
            children: [
              // ラップカウント
              Expanded(
                flex: 20,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('LAP  ', style: _labelStyle(h)),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            total > 0 ? '$lap / $total' : '$lap',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: h * 0.065,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: _rim, thickness: 1, height: 8),
              // 現在ラップ
              Expanded(
                flex: 35,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT LAP', style: _labelStyle(h)),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _fmtLap(current),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: h * 0.065,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    if (best > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _fmtDelta(delta),
                          style: TextStyle(
                            color: dColor,
                            fontSize: h * 0.048,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(color: _rim, thickness: 1, height: 8),
              // ベスト / ラスト
              Expanded(
                flex: 22,
                child: Row(
                  children: [
                    Expanded(child: _lapRow('BEST', best, Colors.white70, h)),
                    SizedBox(width: (h * 0.015).clamp(6, 16)),
                    Expanded(child: _lapRow('LAST', last, lColor, h)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _lapRow(String label, int ms, Color color, double h) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(h)),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _fmtLap(ms),
              style: TextStyle(
                color: color,
                fontSize: h * 0.036,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── ④ 右: タイヤ ─────────────────────────────────────────────────────────────

class _TyrePanel extends StatelessWidget {
  final ValueNotifier<double> tempFL, tempFR, tempRL, tempRR;
  final ValueNotifier<double> wearFL, wearFR, wearRL, wearRR;
  final double h;

  const _TyrePanel({
    required this.tempFL, required this.tempFR,
    required this.tempRL, required this.tempRR,
    required this.wearFL, required this.wearFR,
    required this.wearRL, required this.wearRR,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rim, width: 1.5),
      ),
      padding: EdgeInsets.all((h * 0.014).clamp(6, 14)),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          tempFL, tempFR, tempRL, tempRR,
          wearFL, wearFR, wearRL, wearRR,
        ]),
        builder: (_, __) {
          final gap = (h * 0.008).clamp(4.0, 10.0);
          return Column(
            children: [
              Text('TYRES', style: _labelStyle(h)),
              SizedBox(height: gap),
              Expanded(child: Row(children: [
                Expanded(child: _TyreCell('FL', tempFL.value, wearFL.value, h)),
                SizedBox(width: gap),
                Expanded(child: _TyreCell('FR', tempFR.value, wearFR.value, h)),
              ])),
              SizedBox(height: gap),
              Expanded(child: Row(children: [
                Expanded(child: _TyreCell('RL', tempRL.value, wearRL.value, h)),
                SizedBox(width: gap),
                Expanded(child: _TyreCell('RR', tempRR.value, wearRR.value, h)),
              ])),
            ],
          );
        },
      ),
    );
  }
}

class _TyreCell extends StatelessWidget {
  final String label;
  final double temp;
  final double wear;
  final double h;
  const _TyreCell(this.label, this.temp, this.wear, this.h);

  @override
  Widget build(BuildContext context) {
    final tc = _tempColor(temp);
    final wc = _wearColor(wear.clamp(0.0, 1.0));
    final dotSize = (h * 0.016).clamp(8.0, 14.0);

    return Container(
      padding: EdgeInsets.all((h * 0.010).clamp(5, 10)),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tc.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ラベル
          Text(label, style: TextStyle(
            color: Colors.white38,
            fontSize: (h * 0.018).clamp(9, 15),
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          )),
          // 温度 (FittedBox で縮小保護)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: dotSize, height: dotSize,
                  decoration: BoxDecoration(
                    color: tc, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: tc.withValues(alpha: 0.6), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      temp > 0 ? '${temp.toStringAsFixed(0)}°' : '---',
                      style: TextStyle(color: tc, fontSize: h * 0.046, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 摩耗バー
          SizedBox(
            height: (h * 0.016).clamp(6, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: wear.clamp(0.0, 1.0),
                backgroundColor: wc.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(wc),
              ),
            ),
          ),
          SizedBox(height: 2),
          Text(
            '${(wear.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: wc.withValues(alpha: 0.8), fontSize: (h * 0.016).clamp(8, 13)),
          ),
        ],
      ),
    );
  }
}

// ─── ⑤ 下部: 燃料バー ─────────────────────────────────────────────────────────

class _FuelBar extends StatelessWidget {
  final ValueNotifier<double> fuelLevelNotifier;
  final ValueNotifier<double> fuelCapacityNotifier;
  final ValueNotifier<double> lapsRemainingNotifier;
  final ValueNotifier<double> fuelPerLapNotifier;
  final ValueNotifier<int>    lapCountNotifier;
  final ValueNotifier<int>    lapsInRaceNotifier;
  final double h;
  final double w;

  const _FuelBar({
    required this.fuelLevelNotifier,
    required this.fuelCapacityNotifier,
    required this.lapsRemainingNotifier,
    required this.fuelPerLapNotifier,
    required this.lapCountNotifier,
    required this.lapsInRaceNotifier,
    required this.h,
    required this.w,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        fuelLevelNotifier, fuelCapacityNotifier,
        lapsRemainingNotifier, fuelPerLapNotifier,
        lapCountNotifier, lapsInRaceNotifier,
      ]),
      builder: (_, __) {
        final level     = fuelLevelNotifier.value;
        final capacity  = fuelCapacityNotifier.value;
        final ratio     = capacity > 0 ? (level / capacity).clamp(0.0, 1.0) : 0.0;
        final perLap    = fuelPerLapNotifier.value;
        final fuelLaps  = lapsRemainingNotifier.value;
        final raceLap   = lapCountNotifier.value;
        final raceTotal = lapsInRaceNotifier.value;
        final raceLeft  = raceTotal > 0 ? raceTotal - raceLap : 0;
        final fuelShort = fuelLaps > 0 && raceLeft > 0 && fuelLaps < raceLeft;

        final fc = ratio > 0.40
            ? const Color(0xFF4CAF50)
            : ratio > 0.20 ? const Color(0xFFFFD740) : const Color(0xFFFF1744);

        final lblSz = (h * 0.018).clamp(9.0, 14.0);
        final valSz = (h * 0.030).clamp(13.0, 22.0);
        final hPad  = (w * 0.010).clamp(8.0, 16.0);

        return Container(
          color: const Color(0xFF0C0C18),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
          child: Row(
            children: [
              Text('FUEL', style: TextStyle(color: Colors.white30, fontSize: lblSz, letterSpacing: 2)),
              SizedBox(width: hPad),
              // バー（Flexible で幅を柔軟に）
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: (h * 0.038).clamp(14, 30),
                    backgroundColor: fc.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(fc),
                  ),
                ),
              ),
              SizedBox(width: hPad),
              // 残量 %
              Text(
                '${(ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: fc, fontSize: valSz * 1.05, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: hPad),
              // /LAP
              Flexible(child: _stat('/LAP', perLap > 0 ? '${perLap.toStringAsFixed(2)}L' : '---', Colors.white60, lblSz, valSz)),
              SizedBox(width: hPad),
              // 燃料残りラップ
              Flexible(
                child: _stat(
                  'FUEL LAPS',
                  fuelLaps > 0 ? '~${fuelLaps.toStringAsFixed(1)}' : '---',
                  fuelShort ? const Color(0xFFFF5252) : Colors.white60,
                  lblSz, valSz,
                ),
              ),
              if (raceLeft > 0) ...[
                SizedBox(width: hPad),
                Flexible(child: _stat('REMAIN', '$raceLeft laps', Colors.white60, lblSz, valSz)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value, Color color, double lblSz, double valSz) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white30, fontSize: lblSz, letterSpacing: 1)),
        Text(value, style: TextStyle(color: color, fontSize: valSz, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
