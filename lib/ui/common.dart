// Shared pieces: answer buttons, flags, number formatting, globe colours.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/learning.dart';
import '../core/world.dart';
import '../state.dart';
import 'theme.dart';

enum AnswerState { idle, correct, wrong, dimmed }

AnswerState answerState({required bool answered, required int index, required int correct, required int? chosen}) {
  if (!answered) return AnswerState.idle;
  if (index == correct) return AnswerState.correct;
  if (index == chosen) return AnswerState.wrong;
  return AnswerState.dimmed;
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({super.key, required this.text, required this.state, required this.onTap});

  final String text;
  final AnswerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (state) {
      AnswerState.idle => (Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.14), Colors.white),
      AnswerState.correct => (correctGreen.withValues(alpha: 0.25), correctGreen, Colors.white),
      AnswerState.wrong => (wrongRed.withValues(alpha: 0.25), wrongRed, Colors.white),
      AnswerState.dimmed => (Colors.white.withValues(alpha: 0.03), Colors.transparent, Colors.white.withValues(alpha: 0.4)),
    };
    return AnimatedScale(
      scale: state == AnswerState.correct ? 1.04 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 1.5)),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: state == AnswerState.idle ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              alignment: Alignment.center,
              child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two columns of answer buttons.
class AnswerGrid extends StatelessWidget {
  const AnswerGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final c in children) SizedBox(width: w, child: c)]);
        },
      );
}

class Flag extends StatelessWidget {
  const Flag(this.country, {super.key, this.width = 64});

  final Country country;
  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(width / 12),
        child: SizedBox(
          width: width,
          height: width * 3 / 4,
          child: SvgPicture.asset(country.flagAsset, fit: BoxFit.cover),
        ),
      );
}

/// "83.491.249" (German) or "83,491,249".
String groupDigits(int n, String lang) {
  final s = n.toString();
  final sep = lang == 'de' ? '.' : ',';
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(sep);
    out.write(s[i]);
  }
  return out.toString();
}

/// Grey until named, light colour with the country, full colour with the capital.
Color Function(Country) progressColors(AppState state) => (c) => switch (state.progressOf(c.iso)) {
      Progress.none => landGrey,
      Progress.country => Color.lerp(landGrey, countryColor(c.color), 0.5)!,
      Progress.complete => countryColor(c.color),
    };
