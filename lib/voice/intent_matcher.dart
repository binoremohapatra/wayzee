import 'dart:math';

enum Intent {
  startNavigation,
  whereAmI,
  whatsAhead,
  repeat,
  slower,
  faster,
  louder,
  quieter,
  moreDetail,
  lessDetail,
  stopNavigation,
  nextStep,
  howFar,
  takeMeBack,
  avoidStairsOn,
  avoidStairsOff,
  readSign,
  askForHelp,
  sendHelp,
  battery,
  language,
  help,
  unknown,
}

class IntentMatch {
  final Intent intent;
  final String? place;
  final double confidence;

  IntentMatch({
    required this.intent,
    this.place,
    required this.confidence,
  });
}

class IntentMatcher {
  // Command patterns - English
  static const Map<Intent, List<String>> _englishPatterns = {
    Intent.startNavigation: [
      'take me to',
      'go to',
      'navigate to',
      'reach',
      'start navigation',
    ],
    Intent.whereAmI: [
      'where am i',
      'where am',
      'my location',
      'current location',
    ],
    Intent.whatsAhead: [
      'what is ahead',
      'what ahead',
      'what\'s ahead',
      'ahead',
    ],
    Intent.repeat: [
      'repeat',
      'say again',
      'again',
      'once more',
    ],
    Intent.slower: [
      'speak slower',
      'slower',
      'slow down',
      'slow',
    ],
    Intent.faster: [
      'speak faster',
      'faster',
      'speed up',
      'fast',
    ],
    Intent.louder: [
      'louder',
      'volume up',
      'increase volume',
      'louder please',
    ],
    Intent.quieter: [
      'quieter',
      'volume down',
      'decrease volume',
      'quieter please',
    ],
    Intent.moreDetail: [
      'speak more',
      'more detail',
      'explain more',
      'more info',
    ],
    Intent.lessDetail: [
      'speak less',
      'less detail',
      'explain less',
      'less info',
    ],
    Intent.stopNavigation: [
      'stop',
      'cancel',
      'stop navigation',
      'cancel navigation',
      'end',
    ],
    Intent.nextStep: [
      'next step',
      'what next',
      'next',
    ],
    Intent.howFar: [
      'how far',
      'how many steps',
      'distance',
      'how much more',
    ],
    Intent.takeMeBack: [
      'take me back',
      'go back',
      'return',
      'go to entrance',
    ],
    Intent.avoidStairsOn: [
      'avoid stairs',
      'no stairs',
      'no stair',
    ],
    Intent.avoidStairsOff: [
      'allow stairs',
      'stairs ok',
      'use stairs',
    ],
    Intent.readSign: [
      'read this sign',
      'read sign',
      'what does it say',
      'read text',
    ],
    Intent.askForHelp: [
      'ask for help',
      'ask someone for help',
      'get help',
    ],
    Intent.sendHelp: [
      'send help',
      'call for help',
      'sos',
      'emergency',
    ],
    Intent.battery: [
      'battery',
      'battery level',
      'how much battery',
    ],
    Intent.language: [
      'change language',
      'switch language',
      'language settings',
    ],
    Intent.help: [
      'help',
      'what can i say',
      'commands',
      'voice commands',
    ],
  };

  // Command patterns - Hindi (Devanagari and Romanized)
  static const Map<Intent, List<String>> _hindiPatterns = {
    Intent.startNavigation: [
      'मुझे',
      'ले चलो',
      'चलो',
      'नेविगेट करो',
      'le chalo',
      'chalo',
      'take me to',
    ],
    Intent.whereAmI: [
      'मैं कहाँ हूँ',
      'मेरी लोकेशन',
      'कहाँ हूँ',
    ],
    Intent.whatsAhead: [
      'आगे क्या है',
      'आगे',
      'सामने क्या है',
    ],
    Intent.repeat: [
      'दोहराओ बोलो',
      'फिर से बोलो',
      'दुबारा',
      'एक बार फिर',
    ],
    Intent.slower: [
      'धीरे बोलो',
      'धीरे',
      'धीमा गति',
    ],
    Intent.faster: [
      'तेज़ बोलो',
      'तेज़',
      'तेज़ गति',
    ],
    Intent.louder: [
      'आवाज़ बढ़ा',
      'आवाज़',
      'ध्वनि बढ़ा',
    ],
    Intent.quieter: [
      'आवाज़ कम करो',
      'आवाज़ कम',
      'ध्वनि कम करो',
    ],
    Intent.moreDetail: [
      'ज़्यादा बताओ',
      'ज़्यादा',
      'और बताओ',
    ],
    Intent.lessDetail: [
      'कम बताओ',
      'कम',
      'थोड़ा बताओ',
    ],
    Intent.stopNavigation: [
      'रुको',
      'बंद करो',
      'रुक',
      'बंद',
    ],
    Intent.nextStep: [
      'अगला कदम',
      'अगला क्या',
      'अगला',
    ],
    Intent.howFar: [
      'कितने कदम बचे',
      'कितना बाकी',
      'कितना और',
    ],
    Intent.takeMeBack: [
      'वापस ले चलो',
      'वापस',
      'वापस जाओ',
      'प्रवेश',
    ],
    Intent.avoidStairsOn: [
      'सीढ़ियाँ मत लो',
      'सीढ़ियाँ नहीं',
      'सीढ़ी नहीं',
    ],
    Intent.avoidStairsOff: [
      'सीढ़ियाँ लो',
      'सीढ़ियाँ ठीक है',
      'सीढ़ी ठीक',
    ],
    Intent.readSign: [
      'यह क्या लिखा है',
      'क्या लिखा है',
      'पढ़ लिखो',
    ],
    Intent.askForHelp: [
      'मदद माँगो',
      'किसी से मदद माँगो',
      'मदद चाहिए',
    ],
    Intent.sendHelp: [
      'मदद भेजो',
      'मदद भेजिए',
      'एसओएस',
      'मदद भेजो',
    ],
    Intent.battery: [
      'बैटरी कितनी है',
      'बैटरी',
      'बैटरी लेवल',
    ],
    Intent.language: [
      'भाषा बदलो',
      'भाषा हिन्दी करो',
      'भाषा सेटिंग्स',
    ],
    Intent.help: [
      'मदद',
      'मदद करो',
      'क्या बोल सकते है',
      'कमांड्स',
    ],
  };

  // Fuzzy matching helper
  static double _fuzzyMatch(String text, String pattern) {
    text = text.toLowerCase().trim();
    pattern = pattern.toLowerCase().trim();
    
    // Check if pattern is exact match or appears as a distinct word/phrase in text
    if (text == pattern) {
      return 1.0;
    }

    final regex = RegExp(r'(?:^|\s)' + RegExp.escape(pattern) + r'(?:$|\s)');
    if (regex.hasMatch(text)) {
      return 1.0;
    }
    
    // Levenshtein distance
    final distance = _levenshteinDistance(text, pattern);
    final maxLen = max(text.length, pattern.length);
    if (maxLen == 0) return 0.0;
    return 1.0 - (distance / maxLen);
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

  // Match intent from spoken text
  // Threshold: 0.6 chosen to balance false positives vs false negatives
  // - 0.5 was too permissive, matching too many partial matches
  // - 0.7 was too strict, missing legitimate near-matches
  // - 0.6 works well for "library" vs "laboratory" type ambiguity
  static IntentMatch matchIntent(String text, String language) {
    text = text.toLowerCase().trim();
    if (text.isEmpty) {
      return IntentMatch(intent: Intent.unknown, confidence: 0.0);
    }

    final patterns = language == 'Hindi' ? _hindiPatterns : _englishPatterns;
    Intent? bestIntent;
    double bestConfidence = 0.0;
    String? bestPlace;

    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        final confidence = _fuzzyMatch(text, pattern);
        if (confidence > bestConfidence && confidence > 0.6) {
          bestConfidence = confidence;
          bestIntent = entry.key;
        }
      }
    }

    // Extract place name for navigation intents
    if (bestIntent == Intent.startNavigation) {
      bestPlace = _extractPlaceName(text, language);
      // If no place extracted, reject the match with low confidence
      if (bestPlace == null || bestPlace.isEmpty) {
        return IntentMatch(intent: Intent.unknown, confidence: 0.0);
      }
    }

    return IntentMatch(
      intent: bestIntent ?? Intent.unknown,
      place: bestPlace,
      confidence: bestConfidence,
    );
  }

  // Extract place name from navigation command
  static String? _extractPlaceName(String text, String language) {
    if (language == 'Hindi' || text.contains('le chalo') || text.contains('chalo')) {
      // Hindi: "मुझे लाइब्रेरी जाना है" -> "लाइब्रेरी" or "Bathroom le chalo" -> "bathroom"
      final suffixes = [' जाना है', ' ले चलो', ' चलो', ' जाओ', ' जाना', ' le chalo', ' chalo'];
      for (final suffix in suffixes) {
        if (text.endsWith(suffix)) {
          var place = text.substring(0, text.length - suffix.length).trim();
          // Remove prefix "मुझे"
          if (place.startsWith('मुझे ')) {
            place = place.substring(5).trim();
          }
          if (place.isNotEmpty) {
            return place;
          }
        }
      }
    }
    
    // English: "take me to the library" -> "the library"
    final prefixes = ['take me to', 'go to', 'navigate to', 'reach'];
    for (final prefix in prefixes) {
      if (text.contains(prefix)) {
        final index = text.indexOf(prefix);
        var place = text.substring(index + prefix.length).trim();
        if (place.isNotEmpty) {
          return place;
        }
      }
    }
    
    return null;
  }

  // Instance helper method
  IntentMatch match(String text, [String language = 'Hindi']) =>
      matchIntent(text, language);

  // Check if two intents are too similar (for disambiguation)
  static bool areSimilar(String text1, String text2) {
    final dist = _levenshteinDistance(text1.toLowerCase(), text2.toLowerCase());
    final maxLen = max(text1.length, text2.length);
    return dist < 2 && maxLen > 4; // Very similar if within 2 chars and length > 4
  }
}
