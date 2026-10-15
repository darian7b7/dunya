// Explore: tap a grey country, name it (light colour), then name its capital (full colour).
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/learning.dart';
import '../core/strings.dart';
import '../core/world.dart';
import '../state.dart';
import 'common.dart';
import 'effects.dart';
import 'globe_view.dart';
import 'theme.dart';

enum _Step { askCountry, askCapital, info }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _globe = GlobeController();
  final _rnd = Random();
  Country? _country;
  _Step _step = _Step.askCountry;
  List<String> _options = const [];
  int? _chosen; // chosen option for the current step
  int _confetti = 0;
  int _shake = 0;
  Timer? _toCapital;

  AppState get state => widget.state;
  String get lang => state.lang;

  @override
  void dispose() {
    _toCapital?.cancel();
    super.dispose();
  }

  void _select(Country? c) {
    _toCapital?.cancel();
    if (c == null) return setState(() => _country = null);
    _globe.flyToCountry(c);
    final p = state.progressOf(c.iso);
    setState(() {
      _country = c;
      _chosen = null;
      _step = switch (p) { Progress.none => _Step.askCountry, Progress.country => _Step.askCapital, Progress.complete => _Step.info };
      _options = _optionsFor(c, _step);
    });
  }

  List<String> _optionsFor(Country c, _Step step) => switch (step) {
        _Step.askCountry => optionsFor(state.world, c, (x) => x.name(lang), _rnd),
        _Step.askCapital => optionsFor(state.world, c, (x) => x.capital(lang), _rnd),
        _Step.info => const [],
      };

  void _randomCountry() {
    final open = [for (final c in state.world.countries) if (state.progressOf(c.iso) != Progress.complete && c.iso != _country?.iso) c];
    if (open.isNotEmpty) _select(open[_rnd.nextInt(open.length)]);
  }

  void _answer(int i) {
    final c = _country!;
    final correctText = _step == _Step.askCountry ? c.name(lang) : c.capital(lang);
    final correct = _options[i] == correctText;
    setState(() {
      _chosen = i;
      if (!correct) _shake++;
    });
    if (!correct) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    if (_step == _Step.askCountry) {
      state.advance(c.iso, Progress.country);
      // A short moment to enjoy the colour, then on to the capital.
      _toCapital = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted || _country?.iso != c.iso) return;
        setState(() {
          _step = _Step.askCapital;
          _chosen = null;
          _options = _optionsFor(c, _step);
        });
      });
    } else {
      state.advance(c.iso, Progress.complete);
      setState(() => _confetti++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        body: NightSky(
          child: Stack(children: [
            Positioned.fill(
              child: GlobeView(
                world: state.world,
                colorOf: progressColors(state),
                selected: _country?.iso,
                controller: _globe,
                onTap: _select,
                lift: _country == null ? 0 : MediaQuery.sizeOf(context).height * 0.17,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  Expanded(
                    child: Text(
                      tr(lang, 'progress', {'done': state.countriesKnown, 'total': state.world.countries.length}),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(tooltip: tr(lang, 'random'), onPressed: _randomCountry, icon: const Icon(Icons.casino_rounded)),
                ]),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, a) => SlideTransition(
                    position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: _country == null ? _hint() : _panel(_country!),
                ),
              ),
            ),
            Positioned.fill(child: Confetti(trigger: _confetti)),
          ]),
        ),
      ),
    );
  }

  Widget _hint() => Container(
        key: const ValueKey('hint'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(color: night.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.touch_app_rounded, color: gold),
          const SizedBox(width: 10),
          Expanded(child: Text(tr(lang, 'tapCountry'))),
        ]),
      );

  Widget _panel(Country c) {
    final answered = _chosen != null;
    final correctText = _step == _Step.askCountry ? c.name(lang) : c.capital(lang);
    final correctIndex = _options.indexOf(correctText);
    final wasRight = answered && _chosen == correctIndex;

    return Container(
      key: ValueKey('${c.iso}-$_step'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: night.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              switch (_step) {
                _Step.askCountry => tr(lang, 'whichCountry'),
                _Step.askCapital => tr(lang, 'whichCapital', {'country': c.name(lang)}),
                _Step.info => c.name(lang),
              },
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(tooltip: tr(lang, 'close'), onPressed: () => _select(null), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 8),
        if (_step == _Step.info) _info(c) else ...[
          Shake(
            trigger: _shake,
            child: AnswerGrid(children: [
              for (final (i, o) in _options.indexed)
                AnswerButton(
                  text: o,
                  state: answerState(answered: answered, index: i, correct: correctIndex, chosen: _chosen),
                  onTap: () => _answer(i),
                ),
            ]),
          ),
          if (answered) ...[
            const SizedBox(height: 12),
            PopIn(child: _feedback(c, wasRight)),
          ],
        ],
      ]),
    );
  }

  Widget _feedback(Country c, bool right) {
    final String text;
    if (_step == _Step.askCountry) {
      text = right ? tr(lang, 'countryDone') : '${tr(lang, 'thisIs', {'country': c.name(lang)})} ${tr(lang, 'tryLater')}';
    } else {
      final key = c.capitalsIn(lang).length > 1 ? 'capitalsAre' : 'capitalIs';
      text = right ? tr(lang, 'completed') : '${tr(lang, key, {'capital': c.capital(lang)})} ${tr(lang, 'tryLater')}';
    }
    return Row(children: [
      Icon(right ? Icons.check_circle_rounded : Icons.info_rounded, color: right ? correctGreen : wrongRed),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: right ? correctGreen : Colors.white, fontWeight: FontWeight.w600))),
      if (right && _step == _Step.askCapital)
        TextButton(onPressed: () => setState(() => _step = _Step.info), child: Text(tr(lang, 'next'))),
    ]);
  }

  /// What you've learned about a completed country.
  Widget _info(Country c) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6)))),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Flag(c, width: 84),
      const SizedBox(width: 16),
      Expanded(
        child: Column(children: [
          row(tr(lang, 'capital'), c.capital(lang)),
          row(tr(lang, 'continent'), tr(lang, 'continent.${c.continent}')),
          if (c.population != null) row(tr(lang, 'population'), groupDigits(c.population!, lang)),
          if (c.names['ar'] != null) row('العربية', c.names['ar']!),
        ]),
      ),
    ]);
  }
}
