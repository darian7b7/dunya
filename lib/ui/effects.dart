// Animated pieces: twinkling night sky, confetti, shake, staggered pop-in, count-up.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Background: a deep gradient with softly twinkling stars.
class NightSky extends StatefulWidget {
  const NightSky({super.key, required this.child});

  final Widget child;

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  final _stars = List.generate(70, (i) {
    final r = Random(i * 7919);
    return (Offset(r.nextDouble(), r.nextDouble()), r.nextDouble() * 1.6 + 0.4, r.nextDouble() * 2 * pi);
  });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) _controller.stop();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [night, nightDeep]),
      ),
      child: Stack(fit: StackFit.expand, children: [
        RepaintBoundary(child: CustomPaint(painter: _StarPainter(_stars, _controller))),
        widget.child,
      ]),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.time) : super(repaint: time);

  final List<(Offset, double, double)> stars;
  final Animation<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final (pos, radius, phase) in stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time.value * 2 * pi + phase));
      paint.color = Colors.white.withValues(alpha: 0.55 * twinkle);
      canvas.drawCircle(Offset(pos.dx * size.width, pos.dy * size.height * 0.75), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

/// A burst of confetti each time [trigger] changes.
class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.trigger, this.colors = const [gold, ...countryColors]});

  final int trigger;
  final List<Color> colors;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  List<_Piece> _pieces = const [];

  @override
  void didUpdateWidget(Confetti old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0 && !reduceMotion(context)) {
      final r = Random();
      _pieces = List.generate(70, (_) {
        final angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 0.9;
        final speed = 0.9 + r.nextDouble() * 0.9;
        return _Piece(Offset(cos(angle) * speed, sin(angle) * speed), widget.colors[r.nextInt(widget.colors.length)],
            r.nextDouble() * pi, (r.nextDouble() - 0.5) * 12);
      });
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _ConfettiPainter(_pieces, _controller), size: Size.infinite)));
}

class _Piece {
  const _Piece(this.velocity, this.color, this.rotation, this.spin);

  final Offset velocity;
  final Color color;
  final double rotation;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress) : super(repaint: progress);

  final List<_Piece> pieces;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0 || t == 1) return;
    final origin = Offset(size.width / 2, size.height * 0.55);
    final scale = size.height * 0.75;
    final paint = Paint();
    for (final p in pieces) {
      final pos = origin + p.velocity * scale * t + Offset(0, 0.9 * scale * t * t); // gravity
      paint.color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotation + p.spin * t);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2.5, 8, 5), const Radius.circular(1.5)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.pieces != pieces;
}

/// Shakes its child sideways once each time [trigger] changes.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !reduceMotion(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.translate(offset: Offset(sin(_controller.value * pi * 6) * 10 * (1 - _controller.value), 0), child: child),
        child: widget.child,
      );
}

/// Fades and slides its child in after [delay], for staggered entrances.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero, this.offset = const Offset(0, 0.25)});

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, _controller.forward);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: widget.offset, end: Offset.zero).animate(_curve),
          child: widget.child,
        ),
      );
}

/// A number that counts up to [value].
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text('$v', style: style),
      );
}
