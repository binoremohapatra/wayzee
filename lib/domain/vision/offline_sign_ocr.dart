import 'dart:async';
import '../models/spatial_zone.dart';

enum SignCategory {
  roomNumber,
  facility,
  hazard,
  exit,
  general,
}

/// Representation of a door sign or room number identified by offline OCR.
class SignDetection {
  final String rawText;
  final String formattedTitle;
  final SignCategory category;
  final SpatialZone zone;
  final double confidence;
  final int timestamp;

  const SignDetection({
    required this.rawText,
    required this.formattedTitle,
    required this.category,
    required this.zone,
    required this.confidence,
    required this.timestamp,
  });

  /// Builds an accessible spoken utterance for blind audio guidance
  String toSpokenUtterance() {
    final direction = zone == SpatialZone.left
        ? 'on your left'
        : (zone == SpatialZone.right ? 'on your right' : 'straight ahead');

    switch (category) {
      case SignCategory.roomNumber:
        return '$formattedTitle $direction.';
      case SignCategory.facility:
        return '$formattedTitle $direction.';
      case SignCategory.exit:
        return '$formattedTitle sign $direction.';
      case SignCategory.hazard:
        return 'Caution: $formattedTitle sign $direction.';
      case SignCategory.general:
        return 'Sign reading $formattedTitle $direction.';
    }
  }
}

/// Offline OCR & sign detection engine operating entirely in RAM without network access.
/// Features regex pattern matching, facility dictionary resolution, and cooldown debouncing.
class OfflineSignOcrService {
  final Duration debounceCooldown;
  final Map<String, int> _lastAnnouncedTimestamps = {};
  final StreamController<SignDetection> _signStreamController =
      StreamController<SignDetection>.broadcast();

  OfflineSignOcrService({
    this.debounceCooldown = const Duration(seconds: 15),
  });

  Stream<SignDetection> get signStream => _signStreamController.stream;

  // Regex patterns for room numbers: "302", "Room 302", "Room 4B", "Lab 201"
  static final RegExp _roomNumberRegex = RegExp(
    r'\b(?:Room\s*|Cabin\s*|Office\s*|Lab\s*|Hall\s*)?([A-Z]?\d{1,4}[A-Z]?)\b',
    caseSensitive: false,
  );

  static final Map<String, TupleCategoryTitle> _facilityKeywords = {
    'emergency exit': const TupleCategoryTitle(SignCategory.exit, 'Emergency Exit'),
    'fire exit': const TupleCategoryTitle(SignCategory.exit, 'Fire Exit'),
    'exit': const TupleCategoryTitle(SignCategory.exit, 'Exit'),
    'restroom': const TupleCategoryTitle(SignCategory.facility, 'Restroom'),
    'washroom': const TupleCategoryTitle(SignCategory.facility, 'Washroom'),
    'toilet': const TupleCategoryTitle(SignCategory.facility, 'Restroom'),
    'cafeteria': const TupleCategoryTitle(SignCategory.facility, 'Cafeteria'),
    'canteen': const TupleCategoryTitle(SignCategory.facility, 'Cafeteria'),
    'library': const TupleCategoryTitle(SignCategory.facility, 'Library'),
    'elevator': const TupleCategoryTitle(SignCategory.facility, 'Elevator'),
    'lift': const TupleCategoryTitle(SignCategory.facility, 'Elevator'),
    'stairs': const TupleCategoryTitle(SignCategory.facility, 'Stairs'),
    'staircase': const TupleCategoryTitle(SignCategory.facility, 'Staircase'),
    'wet floor': const TupleCategoryTitle(SignCategory.hazard, 'Wet Floor'),
    'do not enter': const TupleCategoryTitle(SignCategory.hazard, 'Do Not Enter'),
    'keep clear': const TupleCategoryTitle(SignCategory.hazard, 'Keep Clear'),
    'caution': const TupleCategoryTitle(SignCategory.hazard, 'Caution'),
  };

  /// Processes text recognized in a video frame or image crop.
  /// If recognized and not currently in cooldown debouncing, returns a SignDetection and emits to stream.
  SignDetection? processText({
    required String rawOcrText,
    required SpatialZone zone,
    double confidence = 0.85,
    int? timestampMs,
  }) {
    final text = rawOcrText.trim();
    if (text.isEmpty) return null;

    final now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final lower = text.toLowerCase();

    SignCategory category = SignCategory.general;
    String formattedTitle = text;
    bool matched = false;

    // 1. Check facility keywords
    for (final entry in _facilityKeywords.entries) {
      if (lower.contains(entry.key)) {
        category = entry.value.category;
        formattedTitle = entry.value.title;
        matched = true;
        break;
      }
    }

    // 2. Check room number regex if not already matched
    if (!matched) {
      final match = _roomNumberRegex.firstMatch(text);
      if (match != null) {
        final roomNum = match.group(1);
        if (roomNum != null && roomNum.isNotEmpty) {
          category = SignCategory.roomNumber;
          formattedTitle = 'Room $roomNum';
          matched = true;
        }
      }
    }

    if (!matched) return null;

    // 3. Debounce: check if same sign was announced within cooldown window
    final cacheKey = '${category.name}_${formattedTitle.toLowerCase()}';
    if (_lastAnnouncedTimestamps.containsKey(cacheKey)) {
      final lastTime = _lastAnnouncedTimestamps[cacheKey]!;
      if (now - lastTime < debounceCooldown.inMilliseconds) {
        // In cooldown window, suppress repeated announcement
        return null;
      }
    }

    _lastAnnouncedTimestamps[cacheKey] = now;

    final detection = SignDetection(
      rawText: text,
      formattedTitle: formattedTitle,
      category: category,
      zone: zone,
      confidence: confidence,
      timestamp: now,
    );

    _signStreamController.add(detection);
    return detection;
  }

  void clearCooldownCache() {
    _lastAnnouncedTimestamps.clear();
  }

  void dispose() {
    _signStreamController.close();
  }
}

class TupleCategoryTitle {
  final SignCategory category;
  final String title;
  const TupleCategoryTitle(this.category, this.title);
}
