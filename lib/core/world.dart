// Countries and land shapes from assets/world.json. Pure Dart.

class Country {
  const Country({
    required this.iso,
    required this.names,
    required this.capitals,
    required this.continent,
    required this.population,
    required this.populationYear,
    required this.label,
    required this.tiny,
    required this.color,
    required this.shapes,
  });

  final String iso; // "DE"
  final Map<String, String> names; // de, en, ar
  final Map<String, List<String>> capitals; // de, en; several where a country has more than one
  final String continent;
  final int? population; // World Bank, latest year; null if not available
  final int? populationYear;
  final (double, double) label; // (lon, lat) where the name/marker sits
  final bool tiny; // too small to tap: also drawn as a marker
  final int color; // 1–7: neighbours have different colours
  final List<List<(double, double)>> shapes; // rings of (lon, lat)

  String name(String lang) => names[lang] ?? names['en']!;
  List<String> capitalsIn(String lang) => (capitals[lang]?.isNotEmpty ?? false) ? capitals[lang]! : capitals['en']!;
  String capital(String lang) => capitalsIn(lang).join(' / ');
  String get flagAsset => 'assets/flags/${iso.toLowerCase()}.svg';

  factory Country.fromJson(Map<String, dynamic> j) => Country(
        iso: j['iso'] as String,
        names: Map<String, String>.from(j['name'] as Map),
        capitals: {
          for (final e in (j['capital'] as Map).entries) e.key as String: [for (final c in e.value as List) c as String],
        },
        continent: j['continent'] as String,
        population: j['population'] as int?,
        populationYear: j['populationYear'] as int?,
        label: _point(j['label'] as List),
        tiny: j['tiny'] as bool,
        color: j['color'] as int,
        shapes: [for (final r in j['shapes'] as List) _ring(r as List)],
      );
}

(double, double) _point(List p) => ((p[0] as num).toDouble(), (p[1] as num).toDouble());
List<(double, double)> _ring(List r) => [for (final p in r) _point(p as List)];

class World {
  World(this.countries, this.land) : _byIso = {for (final c in countries) c.iso: c};

  final List<Country> countries;
  final List<List<(double, double)>> land; // other land (e.g. Greenland, Antarctica): drawn, not playable
  final Map<String, Country> _byIso;

  Country? byIso(String iso) => _byIso[iso];

  factory World.fromJson(Map<String, dynamic> j) => World(
        [for (final c in j['countries'] as List) Country.fromJson(c as Map<String, dynamic>)],
        [for (final r in j['land'] as List) _ring(r as List)],
      );
}
