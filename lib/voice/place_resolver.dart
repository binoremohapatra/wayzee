import 'dart:math';

enum PlaceMatchResult {
  exactMatch,
  closeMatch,
  ambiguous,
  notFound,
}

class PlaceResolution {
  final PlaceMatchResult result;
  final String? place;
  final List<String>? alternatives;

  PlaceResolution({
    required this.result,
    this.place,
    this.alternatives,
  });
}

class PlaceResolver {
  final List<String> _knownPlaces;
  final Map<String, List<String>> _aliases;

  PlaceResolver({
    required List<String> knownPlaces,
    Map<String, List<String>>? aliases,
  })  : _knownPlaces = List<String>.from(knownPlaces),
        _aliases = aliases != null ? Map<String, List<String>>.from(aliases) : {};

  // Resolve a spoken word against known places
  PlaceResolution resolve(String spokenWord) {
    spokenWord = spokenWord.toLowerCase().trim();
    if (spokenWord.isEmpty) {
      return PlaceResolution(result: PlaceMatchResult.notFound);
    }

    // Check exact match in known places
    for (final place in _knownPlaces) {
      if (place.toLowerCase() == spokenWord) {
        return PlaceResolution(
          result: PlaceMatchResult.exactMatch,
          place: place,
        );
      }
    }

    // Check aliases
    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        if (alias.toLowerCase() == spokenWord) {
          return PlaceResolution(
            result: PlaceMatchResult.exactMatch,
            place: entry.key,
          );
        }
      }
    }

    // Check close match (fuzzy)
    final closeMatches = <String>[];
    for (final place in _knownPlaces) {
      final p = place.toLowerCase();
      final dist = _levenshteinDistance(spokenWord, p);
      final maxLen = max(spokenWord.length, p.length);
      final similarity = maxLen > 0 ? 1.0 - (dist / maxLen) : 0.0;

      // Close match: within 2 edits for words > 4 chars, or similarity >= 0.70
      if ((dist <= 2 && maxLen > 4) || similarity >= 0.70) {
        closeMatches.add(place);
      }
    }

    if (closeMatches.length == 1) {
      return PlaceResolution(
        result: PlaceMatchResult.closeMatch,
        place: closeMatches.first,
      );
    }

    if (closeMatches.length > 1) {
      return PlaceResolution(
        result: PlaceMatchResult.ambiguous,
        alternatives: closeMatches,
      );
    }

    // Not found
    return PlaceResolution(
      result: PlaceMatchResult.notFound,
    );
  }

  static int _levenshteinDistance(String a, String b) {
    final matrix = List.generate(
      b.length + 1,
      (i) => i,
    );

    for (int i = 1; i <= a.length; i++) {
      matrix[0] = i;
      int prevDiag = i - 1;

      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final newDiag = matrix[j];
        matrix[j] = min(min(matrix[j] + 1, matrix[j - 1] + 1), prevDiag + cost);
        prevDiag = newDiag;
      }
    }

    return matrix[b.length];
  }

  // Add an alias for a place
  void addAlias(String place, String alias) {
    _aliases.putIfAbsent(place, () => []);
    if (!_aliases[place]!.contains(alias)) {
      _aliases[place]!.add(alias);
    }
  }

  List<String> get knownPlaces => List.unmodifiable(_knownPlaces);
}
