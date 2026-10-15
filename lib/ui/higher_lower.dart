// Higher or lower: which of two countries has more people? Keep the streak going.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/learning.dart';
import '../core/strings.dart';
import '../core/world.dart';
import '../state.dart';
import 'common.dart';
import 'effects.dart';
import 'theme.dart';

class HigherLowerScreen extends StatefulWidget {
  const HigherLowerScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HigherLowerScreen> createState() => _HigherLowerScreenState();
}

class _HigherLowerScreenState extends State<HigherLowerScreen> {
  final _rnd = Random();
  late (Country, Country) _pair = populationPair(widget.state.world, _rnd);
  int? _chosen; // 0 or 1
  int _streak = 0;
  bool _over = false;
  bool _newBest = false;
  int _confetti = 0;
  int _shake = 0;

  String get lang => widget.state.lang;

  int get _bigger => _pair.$1.population! > _pair.$2.population! ? 0 : 1;

  void _pick(int i) {
    if (_chosen != null) return;
    final right = i == _bigger;
    setState(() {
      _chosen = i;
      if (right) {
        _streak++;
        _confetti++;
      } else {
        _shake++;
        _over = true;
        _newBest = widget.state.recordStreak(_streak);
      }
    });
    right ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
  }

  void _next() => setState(() {
        if (_over) {
          _streak = 0;
          _over = false;
          _newBest = false;
        }
        _pair = populationPair(widget.state.world, _rnd);
        _chosen = null;
      });

  @override
  Widget build(BuildContext context) {
    final year = _pair.$1.populationYear ?? _pair.$2.populationYear;
    return Scaffold(
      body: NightSky(
        child: Stack(children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              child: Column(children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  Expanded(child: Text(tr(lang, 'best', {'n': widget.state.bestStreak}), style: TextStyle(color: Colors.white.withValues(alpha: 0.6)))),
                  const Icon(Icons.local_fire_department_rounded, color: gold),
                  const SizedBox(width: 4),
                  CountUp(_streak, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(width: 12),
                ]),
                const SizedBox(height: 12),
                Text(tr(lang, 'whoHasMore'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Expanded(
                  child: Shake(
                    trigger: _shake,
                    child: Column(children: [
                      Expanded(child: _card(0, _pair.$1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('VS', style: TextStyle(color: gold.withValues(alpha: 0.8), fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ),
                      Expanded(child: _card(1, _pair.$2)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                if (_chosen != null) ...[
                  if (_over)
                    PopIn(
                      child: Text(
                        _newBest ? tr(lang, 'newBest') : '${tr(lang, 'gameOver')} ${tr(lang, 'streak', {'n': _streak})}',
                        style: TextStyle(color: _newBest ? gold : wrongRed, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _next, child: Text(tr(lang, _over ? 'again' : 'next'))),
                  ),
                ],
                if (year != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(tr(lang, 'popSource', {'year': year}), style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                  ),
              ]),
            ),
          ),
          Positioned.fill(child: Confetti(trigger: _confetti)),
        ]),
      ),
    );
  }

  Widget _card(int i, Country c) {
    final revealed = _chosen != null;
    final border = !revealed
        ? Colors.white.withValues(alpha: 0.12)
        : i == _bigger
            ? correctGreen
            : (i == _chosen ? wrongRed : Colors.transparent);
    return AnimatedContainer(
      key: ValueKey('${c.iso}$i'),
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: revealed ? null : () => _pick(i),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PopIn(delay: Duration(milliseconds: 80 * i), child: Flag(c, width: 120)),
              const SizedBox(height: 12),
              Text(c.name(lang), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: revealed
                    ? TweenAnimationBuilder<double>(
                        key: const ValueKey('n'),
                        tween: Tween(begin: 0, end: c.population!.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Text(
                          '${groupDigits(v.round(), lang)} ${tr(lang, 'population')}',
                          style: TextStyle(color: i == _bigger ? correctGreen : Colors.white70, fontWeight: FontWeight.w700),
                        ),
                      )
                    : Text('?', key: const ValueKey('q'), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 20)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
