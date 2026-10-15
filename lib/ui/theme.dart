// Space look: deep night background, a blue ocean, gold accents, seven country colours.
import 'package:flutter/material.dart';

const night = Color(0xFF101631);
const nightDeep = Color(0xFF070B1C);
const gold = Color(0xFFF5C451);
const correctGreen = Color(0xFF34D399);
const wrongRed = Color(0xFFF87171);

const ocean = Color(0xFF1D3B78);
const oceanDeep = Color(0xFF0A1838);
const landGrey = Color(0xFF5B6476);
const otherLand = Color(0xFF3F4657); // land that isn't a playable country

/// Natural Earth's map colour index (1–7) gives neighbouring countries different colours.
const countryColors = [
  Color(0xFF2DD4BF), // teal
  Color(0xFFFBBF24), // amber
  Color(0xFFFB7185), // rose
  Color(0xFF60A5FA), // blue
  Color(0xFFA78BFA), // violet
  Color(0xFFA3E635), // lime
  Color(0xFFFB923C), // orange
];

Color countryColor(int index) => countryColors[(index - 1) % countryColors.length];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB), brightness: Brightness.dark).copyWith(
    primary: gold,
    onPrimary: nightDeep,
    surface: night,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: nightDeep,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.07),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}

/// Whether the system asks for reduced motion.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
