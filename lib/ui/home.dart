import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../state.dart';
import 'common.dart';
import 'effects.dart';
import 'explore.dart';
import 'flags.dart';
import 'globe_view.dart';
import 'higher_lower.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));

  @override
  Widget build(BuildContext context) {
    final lang = state.lang;
    final total = state.world.countries.length;
    return Scaffold(
      body: NightSky(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text('$appNameArabic · ${tr(lang, 'tagline')}', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                  ]),
                ),
                IconButton(tooltip: tr(lang, 'settings'), icon: const Icon(Icons.tune), onPressed: () => _settings(context)),
              ]),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _open(context, ExploreScreen(state: state)),
                child: GlobeView(world: state.world, colorOf: progressColors(state), autoRotate: true, interactive: false),
              ),
            ),
            PopIn(
              child: Column(children: [
                Text(tr(lang, 'progress', {'done': state.countriesKnown, 'total': total}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: state.countriesComplete / total),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: gold, backgroundColor: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(tr(lang, 'complete', {'n': state.countriesComplete}), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(children: [
                PopIn(
                  delay: const Duration(milliseconds: 100),
                  child: _ModeButton(
                    icon: Icons.public_rounded,
                    title: tr(lang, 'explore'),
                    subtitle: tr(lang, 'explore.hint'),
                    primary: true,
                    onTap: () => _open(context, ExploreScreen(state: state)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: PopIn(
                      delay: const Duration(milliseconds: 180),
                      child: _ModeButton(
                        icon: Icons.flag_rounded,
                        title: tr(lang, 'flags'),
                        subtitle: state.bestFlags > 0 ? tr(lang, 'best', {'n': state.bestFlags}) : tr(lang, 'flags.hint'),
                        onTap: () => _open(context, FlagsScreen(state: state)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PopIn(
                      delay: const Duration(milliseconds: 240),
                      child: _ModeButton(
                        icon: Icons.groups_rounded,
                        title: tr(lang, 'higherLower'),
                        subtitle: state.bestStreak > 0 ? tr(lang, 'best', {'n': state.bestStreak}) : tr(lang, 'higherLower.hint'),
                        onTap: () => _open(context, HigherLowerScreen(state: state)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _settings(BuildContext context) {
    final year = state.world.countries.map((c) => c.populationYear ?? 0).reduce((a, b) => a > b ? a : b);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: night,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final lang = state.lang;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(lang, 'language'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [for (final e in languages.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                selected: {lang},
                onSelectionChanged: (s) => state.setLang(s.first),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(tr(lang, 'resetProgress')),
              ),
              const SizedBox(height: 20),
              Text(tr(lang, 'sources'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(tr(lang, 'sources.text', {'year': year}), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.45)),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final lang = state.lang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(lang, 'resetProgress')),
        content: Text(tr(lang, 'resetProgress.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr(lang, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr(lang, 'reset'))),
        ],
      ),
    );
    if (ok == true) state.resetProgress();
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.title, required this.subtitle, required this.onTap, this.primary = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? nightDeep : Colors.white;
    return Material(
      color: primary ? gold : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: fg, size: primary ? 30 : 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: fg, fontSize: primary ? 18 : 15, fontWeight: FontWeight.w800)),
                Text(subtitle, maxLines: 2, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
