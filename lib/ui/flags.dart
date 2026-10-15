// Flags: ten flags per round, which country does each belong to?
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

const flagsPerRound = 10;

class FlagsScreen extends StatefulWidget {
  const FlagsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  final _rnd = Random();
  late List<Country> _round;
  int _index = 0;
  int _score = 0;
  List<String> _options = const [];
  int? _chosen;
  int _confetti = 0;
  int _shake = 0;
  bool _newBest = false;

  String get lang => widget.state.lang;
  Country get _country => _round[_index];
  bool get _done => _index >= _round.length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _round = ([...widget.state.world.countries]..shuffle(_rnd)).take(flagsPerRound).toList();
    _index = 0;
    _score = 0;
    _newBest = false;
    _prepare();
  }

  void _prepare() {
    _chosen = null;
    if (!_done) _options = optionsFor(widget.state.world, _country, (c) => c.name(lang), _rnd);
  }

  void _answer(int i) {
    final correct = _options[i] == _country.name(lang);
    setState(() {
      _chosen = i;
      if (correct) {
        _score++;
        _confetti++;
      } else {
        _shake++;
      }
    });
    correct ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
  }

  void _next() => setState(() {
        _index++;
        if (_done) _newBest = widget.state.recordFlags(_score);
        _prepare();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NightSky(
        child: Stack(children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              child: Column(children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  Expanded(
                    child: Text(
                      _done ? tr(lang, 'flags') : tr(lang, 'round', {'n': _index + 1, 'total': _round.length}),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  ),
                  const Icon(Icons.star_rounded, color: gold, size: 20),
                  const SizedBox(width: 4),
                  CountUp(_score, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(width: 12),
                ]),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(a), child: child),
                    ),
                    child: _done ? _result(context) : _question(context),
                  ),
                ),
              ]),
            ),
          ),
          Positioned.fill(child: Confetti(trigger: _confetti)),
        ]),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final answered = _chosen != null;
    final correctIndex = _options.indexOf(_country.name(lang));
    return Padding(
      key: ValueKey(_index),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        const Spacer(),
        Text(tr(lang, 'whichFlag'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        PopIn(
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 12))]),
            child: Flag(_country, width: min(MediaQuery.sizeOf(context).width * 0.7, 320)),
          ),
        ),
        const Spacer(),
        Shake(
          trigger: _shake,
          child: AnswerGrid(children: [
            for (final (i, o) in _options.indexed)
              PopIn(
                delay: Duration(milliseconds: 120 + 60 * i),
                child: AnswerButton(
                  text: o,
                  state: answerState(answered: answered, index: i, correct: correctIndex, chosen: _chosen),
                  onTap: () => _answer(i),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: answered ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: answered ? _next : null, child: Text(tr(lang, 'next'))),
          ),
        ),
      ]),
    );
  }

  Widget _result(BuildContext context) => Column(
        key: const ValueKey('result'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_rounded, color: gold, size: 64),
          const SizedBox(height: 12),
          Text(_newBest ? tr(lang, 'newBest') : tr(lang, 'score', {'n': _score, 'total': _round.length}),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (_newBest) Text(tr(lang, 'score', {'n': _score, 'total': _round.length})),
          const SizedBox(height: 8),
          Text(tr(lang, 'best', {'n': widget.state.bestFlags}), style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton.icon(
              onPressed: () => setState(_start),
              icon: const Icon(Icons.replay_rounded),
              label: Text(tr(lang, 'again')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr(lang, 'home'))),
        ],
      );
}
