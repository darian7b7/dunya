# Dunya · دنيا

Learn the world on a 3D globe: turn it, tap a country, name it, then name its capital, and watch the world fill with colour. It's offline, in German and English.

## Run

```bash
cd ~/dunya
CHROME_EXECUTABLE=/usr/bin/chromium flutter run -d chrome   # in the browser
flutter test                                                  # tests
```

## Modes

- **Explore the world:**
  - Swipe to turn the globe (it keeps spinning a little), pinch to zoom, tap a country.
  - Grey means not named yet. **Light colour** means you named the country. **Full colour** means you also named the capital.
  - Wrong answers show the right one; you can try again later.
  - The dice button picks a random country you haven't completed.
- **Flags:** 10 flags per round. Wrong options come from the same continent.
- **Higher or lower?** Which of two countries has more people? Keep your streak going.

## Data (all free to use)

| What | Source | Licence |
|---|---|---|
| Borders, names (de/en/ar), continent, map colours | [Natural Earth](https://www.naturalearthdata.com) 1:50m | Public domain |
| Capitals (de/en) | Wikidata, query in `tool/capitals.rq` | CC0 |
| Population | World Bank `SP.POP.TOTL`, latest year | CC BY 4.0 |
| Flags | [flag-icons](https://github.com/lipis/flag-icons) | MIT |

**Which countries:** the 193 UN member states plus the observer states Palestine and the Holy See. This is a clear, neutral rule. Everything else (e.g. Greenland, Antarctica) is shown as grey land without a question.

**Capitals:** where a country has several (e.g. South Africa, Bolivia), all of them are shown.

**Fixes made in the build script:**
- Denmark is added explicitly, because its Wikidata membership entry is incomplete.
- Antigua and Barbuda's capital, St. John's, is added, because it's missing on Wikidata.

## Updating the data

```bash
python3 tool/build_world.py   # data/* → assets/world.json + assets/flags/*.svg
```

To refresh population or capitals, download `data/population.json` (World Bank API) and `data/capitals.json` (Wikidata, `tool/capitals.rq`) again.

## Structure

| File | Purpose |
|---|---|
| `lib/core/globe.dart` | Orthographic projection, turning, tapping countries (pure Dart, tested) |
| `lib/core/learning.dart` | Progress, answer options, population pairs |
| `lib/ui/globe_view.dart` | The 3D globe: drawing, gestures, momentum, fly-to |
| `lib/ui/explore.dart` · `flags.dart` · `higher_lower.dart` | The three modes |
| `lib/ui/effects.dart` | Night sky, confetti, shake, pop-in (shared with Majlis) |

## Next

- **Party mode** for several players (from Majlis)
- **Daily challenge**
- **Capitals as points on the globe**, from Wikidata coordinates
- **Explore by continent**

## License

The code is under the [MIT License](LICENSE). The data keeps its own licence (see the sources above).
