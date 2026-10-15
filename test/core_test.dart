import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dunya/core/globe.dart';
import 'package:dunya/core/learning.dart';
import 'package:dunya/core/world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = World.fromJson(jsonDecode(File('assets/world.json').readAsStringSync()) as Map<String, dynamic>);
  const r = 200.0;

  test('195 playable countries, each with a name, capital, shape and flag', () {
    expect(world.countries.length, 195);
    for (final c in world.countries) {
      expect(c.name('de'), isNotEmpty, reason: c.iso);
      expect(c.capitalsIn('de'), isNotEmpty, reason: c.iso);
      expect(c.shapes, isNotEmpty, reason: c.iso);
      expect(File(c.flagAsset).existsSync(), isTrue, reason: c.flagAsset);
    }
    expect(world.byIso('DE')!.capital('de'), 'Berlin');
    expect(world.byIso('ZA')!.capitalsIn('en'), containsAll(['Pretoria', 'Cape Town', 'Bloemfontein']));
  });

  group('projection', () {
    test('the centre of the view is in the middle of the globe', () {
      final p = project(10, 50, const Camera(10, 50), r);
      expect([p.x, p.y, p.visible], [closeTo(0, 1e-9), closeTo(0, 1e-9), true]);
    });

    test('north is up and east is right on screen', () {
      expect(project(0, 10, const Camera(0, 0), r).y, lessThan(0));
      expect(project(10, 0, const Camera(0, 0), r).x, greaterThan(0));
    });

    test('the far side is hidden', () {
      expect(project(180, 0, const Camera(0, 0), r).visible, isFalse);
      expect(project(89, 0, const Camera(0, 0), r).visible, isTrue);
    });

    test('screen → globe → screen gives the same point', () {
      final rnd = Random(1);
      for (var i = 0; i < 500; i++) {
        final v = Camera(rnd.nextDouble() * 360 - 180, rnd.nextDouble() * 140 - 70);
        final x = (rnd.nextDouble() * 2 - 1) * r * 0.7, y = (rnd.nextDouble() * 2 - 1) * r * 0.7;
        final ll = unproject(x, y, v, r)!;
        final p = project(ll.$1, ll.$2, v, r);
        expect([p.x, p.y], [closeTo(x, 1e-6), closeTo(y, 1e-6)]);
        expect(p.visible, isTrue);
      }
    });

    test('a tap outside the globe hits nothing', () {
      expect(unproject(r + 1, 0, const Camera(0, 0), r), isNull);
    });

    test('dragging turns the globe; latitude stops before the poles', () {
      expect(const Camera(0, 0).dragged(-100, 0, r).lon, greaterThan(0), reason: 'dragging left brings the east into view');
      expect(const Camera(0, 70).dragged(0, 10000, r).lat, 75);
    });

    test('the globe always turns the short way round', () {
      expect(lonDelta(170, -170), 20);
      expect(lonDelta(-170, 170), -20);
      expect(wrapLon(190), -170);
    });
  });

  group('tapping countries', () {
    test('turning to a country and tapping the centre selects it', () {
      for (final iso in ['DE', 'BR', 'IN', 'EG', 'AU', 'CA', 'RU', 'ID', 'PS', 'SA', 'US', 'CN']) {
        final c = world.byIso(iso)!;
        expect(countryAt(world, 0, 0, Camera(c.label.$1, c.label.$2), r)?.iso, iso);
      }
    });

    test('tiny countries can be tapped on their marker', () {
      final sg = world.byIso('SG')!;
      final v = Camera(sg.label.$1 + 3, sg.label.$2);
      final p = project(sg.label.$1, sg.label.$2, v, r);
      expect(countryAt(world, p.x + 4, p.y - 4, v, r)?.iso, 'SG');
    });

    test('the open ocean selects nothing', () {
      expect(countryAt(world, 0, 0, const Camera(-150, -30), r), isNull); // South Pacific
    });
  });

  group('learning', () {
    test('four distinct options including the right one', () {
      final rnd = Random(2);
      for (final c in world.countries) {
        final opts = optionsFor(world, c, (x) => x.name('de'), rnd);
        expect(opts.toSet().length, 4, reason: c.iso);
        expect(opts, contains(c.name('de')));
      }
    });

    test('wrong options come from the same continent when possible', () {
      final opts = optionsFor(world, world.byIso('DE')!, (x) => x.name('en'), Random(3));
      for (final o in opts) {
        expect(world.countries.firstWhere((x) => x.name('en') == o).continent, 'Europe');
      }
    });

    test('capital options contain the right capital exactly once', () {
      final rnd = Random(4);
      for (final c in world.countries) {
        final opts = optionsFor(world, c, (x) => x.capital('de'), rnd);
        expect(opts.where((o) => o == c.capital('de')).length, 1, reason: c.iso);
      }
    });

    test('higher or lower: real numbers, never too close to call', () {
      final rnd = Random(5);
      for (var i = 0; i < 200; i++) {
        final (a, b) = populationPair(world, rnd);
        expect(a.iso, isNot(b.iso));
        expect(max(a.population!, b.population!) / min(a.population!, b.population!), greaterThanOrEqualTo(1.15));
      }
    });
  });
}
