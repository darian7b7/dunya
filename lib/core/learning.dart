// What the player has learned, and the multiple-choice options for each step. Pure Dart.
import 'dart:math';

import 'world.dart';

/// grey → country named (light colour) → capital named too (full colour).
enum Progress { none, country, complete }

/// Four options: the right answer plus three wrong ones, preferably from the same continent
/// (harder and more useful to learn), all real values from other countries.
List<String> optionsFor(World world, Country country, String Function(Country) value, Random rnd) {
  final correct = value(country);
  final pool = [for (final c in world.countries) if (c.iso != country.iso && value(c) != correct) c];
  final same = pool.where((c) => c.continent == country.continent).toList()..shuffle(rnd);
  final other = pool.where((c) => c.continent != country.continent).toList()..shuffle(rnd);
  final wrong = <String>{};
  for (final c in [...same, ...other]) {
    if (wrong.length == 3) break;
    wrong.add(value(c));
  }
  return [correct, ...wrong]..shuffle(rnd);
}

/// Higher or lower: two countries with population data and clearly different numbers.
(Country, Country) populationPair(World world, Random rnd) {
  final known = [for (final c in world.countries) if (c.population != null) c];
  while (true) {
    final a = known[rnd.nextInt(known.length)], b = known[rnd.nextInt(known.length)];
    if (a.iso == b.iso) continue;
    final ratio = max(a.population!, b.population!) / min(a.population!, b.population!);
    if (ratio >= 1.15) return (a, b); // within 15 % it's a coin toss, not knowledge
  }
}
