#!/usr/bin/env python3
"""Builds assets/world.json and assets/flags/*.svg from the sources in data/.

Sources (all free to use):
  data/ne_50m_admin_0_countries.geojson  Natural Earth 1:50m countries, public domain
  data/capitals.json                     Wikidata (CC0), query in tool/capitals.rq
  data/population.json                   World Bank SP.POP.TOTL, CC BY 4.0
  flags                                  github.com/lipis/flag-icons, MIT (downloaded by this script)

Which countries are playable: the 193 UN member states plus the observer states Palestine and the
Holy See. Everything else on the map (e.g. Greenland, Antarctica) is drawn as neutral land.

Usage: python3 tool/build_world.py
"""
import json, math, os, urllib.request

TOLERANCE = 0.04  # degrees; Douglas–Peucker simplification
MIN_RING_AREA = 0.02  # square degrees; smaller islands are dropped unless they are the country's main shape
FLAG_URL = 'https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/{}.svg'

# Antigua and Barbuda has no capital (P36) on Wikidata; its capital is St. John's.
CAPITAL_FIXES = {'AG': (["St. John’s"], ["St. John's"])}


def iso2(p):
    return p['ISO_A2'] if p['ISO_A2'] != '-99' else p['ISO_A2_EH']


def iso3(p):
    return p['ISO_A3'] if p['ISO_A3'] != '-99' else p['ISO_A3_EH']


def simplify(points, tol):
    """Douglas–Peucker on a ring of [lon, lat]."""
    if len(points) < 4:
        return points
    def dist(p, a, b):
        if a == b:
            return math.dist(p, a)
        (x, y), (x1, y1), (x2, y2) = p, a, b
        return abs((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1) / math.dist(a, b)
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        i, j = stack.pop()
        best, idx = 0, None
        for k in range(i + 1, j):
            d = dist(points[k], points[i], points[j])
            if d > best:
                best, idx = d, k
        if idx is not None and best > tol:
            keep[idx] = True
            stack += [(i, idx), (idx, j)]
    return [p for p, k in zip(points, keep) if k]


def area(ring):
    return abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]))) / 2


def rings(geometry):
    polys = [geometry['coordinates']] if geometry['type'] == 'Polygon' else geometry['coordinates']
    return [poly[0] for poly in polys]  # outer rings only; lakes/holes are not needed at this scale


def shapes(features):
    all_rings = [r for f in features for r in rings(f['geometry'])]
    largest = max(all_rings, key=area)
    out = []
    for r in all_rings:
        if r is not largest and area(r) < MIN_RING_AREA:
            continue
        s = simplify(r, TOLERANCE)
        if len(s) < 4 and r is largest:
            s = r  # tiny countries keep their full outline
        digits = 3 if s is r else 2
        if len(s) >= 4:
            out.append([[round(x, digits), round(y, digits)] for x, y in s])
    return out


def is_tiny(features):
    """Too small to tap on the globe: shown with a marker dot as well."""
    return sum(area(r) for f in features for r in rings(f['geometry'])) < 1.0


def main():
    ne = json.load(open('data/ne_50m_admin_0_countries.geojson'))['features']
    caps = {}
    for r in json.load(open('data/capitals.json'))['results']['bindings']:
        c = caps.setdefault(r['iso']['value'], {'de': [], 'en': []})
        for lang in ('de', 'en'):
            v = r.get('cap' + lang.capitalize(), {}).get('value')
            if v and v not in c[lang]:
                c[lang].append(v)
    for code, (de, en) in CAPITAL_FIXES.items():
        if not caps[code]['en']:
            caps[code] = {'de': de, 'en': en}

    population = {x['countryiso3code']: (x['value'], x['date'])
                  for x in json.load(open('data/population.json'))[1] if x['countryiso3code'] and x['value']}

    by_iso = {}
    for f in ne:
        by_iso.setdefault(iso2(f['properties']), []).append(f)

    countries, land = [], []
    for code, features in sorted(by_iso.items(), key=lambda kv: kv[0]):
        main = max(features, key=lambda f: area(max(rings(f['geometry']), key=area)))
        p = main['properties']
        if code in caps:
            pop = population.get(iso3(p))
            countries.append({
                'iso': code,
                'name': {'de': p['NAME_DE'], 'en': p['NAME_EN'], 'ar': p['NAME_AR']},
                'capital': caps[code],
                'continent': p['CONTINENT'],
                'population': pop[0] if pop else None,
                'populationYear': int(pop[1]) if pop else None,
                'label': [round(p['LABEL_X'], 2), round(p['LABEL_Y'], 2)],
                'tiny': is_tiny(features),
                'color': p['MAPCOLOR7'],  # 1–7, chosen by Natural Earth so neighbours differ
                'shapes': shapes(features),
            })
        else:
            land.extend(shapes(features))

    missing = sorted(set(caps) - {c['iso'] for c in countries})
    if missing:
        raise SystemExit(f'no map shape for: {missing}')
    no_capital = [c['iso'] for c in countries if not c['capital']['en']]
    if no_capital:
        raise SystemExit(f'no capital for: {no_capital}')

    os.makedirs('assets/flags', exist_ok=True)
    for c in countries:
        path = f"assets/flags/{c['iso'].lower()}.svg"
        if not os.path.exists(path):
            urllib.request.urlretrieve(FLAG_URL.format(c['iso'].lower()), path)

    out = {
        'sources': {
            'map': 'Natural Earth 1:50m admin-0 countries (public domain)',
            'capitals': 'Wikidata (CC0)',
            'population': 'World Bank, SP.POP.TOTL (CC BY 4.0)',
            'flags': 'flag-icons by Panayiotis Lipiridis (MIT)',
        },
        'countries': countries,
        'land': land,
    }
    json.dump(out, open('assets/world.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    points = sum(len(r) for c in countries for r in c['shapes']) + sum(len(r) for r in land)
    print(f'{len(countries)} countries, {len(land)} other land shapes, {points} points, '
          f'{os.path.getsize("assets/world.json") // 1024} KB')


if __name__ == '__main__':
    main()
