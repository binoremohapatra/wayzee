class VoicePhrases {
  // Language packs
  static const Map<String, Map<String, List<String>>> _phrases = {
    'English': {
      'listening': ['I\'m listening.', 'Go ahead.', 'I\'m ready.'],
      'didNotCatch1': [
        'Sorry, I didn\'t catch that. Please say it once more.',
        'I didn\'t hear that clearly. Could you repeat it?',
      ],
      'didNotCatch2': [
        'No problem. Which place? You can say library, washroom or pharmacy.',
        'Which destination? For example, library, washroom or pharmacy.',
      ],
      'switchToList': [
        'No problem. I\'ll read the places. Press the button when you hear yours.',
        'Let\'s switch to list mode. Press the button when you hear your destination.',
      ],
      'confirmGuess': [
        'Did you say the library?',
        'Was that the library?',
      ],
      'confirmHelp': [
        'Are you sure you want to send for help?',
        'Emergency help requested. Do you want to proceed?',
      ],
      'confirmYesNo': [
        'Please say yes or no.',
        'Sorry, please answer yes or no.',
      ],
      'success': [
        'Okay, let\'s go to the library.',
        'Alright, heading to the library.',
        'Great, taking you to the library.',
      ],
      'arrival': [
        'You have arrived at the library. Well done.',
        'Here you are at the library. Good job.',
        'Arrived at the library. Excellent.',
      ],
      'listeningMarathi': [
        'Voice commands work in Hindi or English; Marathi guidance is spoken.',
      ],
    },
    'Hindi': {
      'listening': ['बोलिए।', 'जाइए।', 'आपकी सुन रहा हूँ।'],
      'didNotCatch1': [
        'माफ़ कीजिए, बात साफ़ नहीं सुनाई दी। कृपया एक बार फिर बोलिए।',
        'बात स्पष्ट नहीं हुई। कृपया दोबारा बोलिए।',
      ],
      'didNotCatch2': [
        'कोई बात नहीं। किस जगह जाना है? आप लाइब्रेरी, शौचालय या फ़ार्मेसी बोल सकते हैं।',
        'किस जगह जाना चाहते हैं? जैसे लाइब्रेरी, शौचालय या फ़ार्मेसी।',
      ],
      'switchToList': [
        'कोई बात नहीं। अब जगहों के नाम सुनाए जाएँगे। अपनी जगह सुनकर बटन दबाइए।',
        'स्थानों की सूची शुरू हो रही है। अपनी जगह पर बटन दबाएँ।',
      ],
      'confirmGuess': [
        'क्या आपने लाइब्रेरी कहा?',
        'क्या आप लाइब्रेरी जाना चाहते हैं?',
      ],
      'confirmHelp': [
        'क्या आप सच में मदद भेजना चाहते हैं?',
        'आपातकालीन मदद चाहिए? हाँ या ना कहें।',
      ],
      'confirmYesNo': [
        'कृपया हाँ या ना बोलिए।',
        'कृपया हाँ या नहीं में उत्तर दें।',
      ],
      'success': [
        'ठीक है, लाइब्रेरी चलते हैं।',
        'ठीक है, लाइब्रेरी की ओर चलते हैं।',
        'अच्छा, लाइब्रेरी ले चलते हैं।',
      ],
      'arrival': [
        'आप लाइब्रेरी पहुँच गए हैं। बहुत बढ़िया।',
        'लाइब्रेरी में पहुँच गए। शाबाश।',
        'लाइब्रेरी आ गए। बहुत अच्छा।',
      ],
      'listeningMarathi': [
        'वॉयस कमांड्स हिंदी या अंग्रेजी में काम करते हैं; मराठी निर्देश बोले जाते हैं।',
      ],
    },
    'Marathi': {
      'listening': ['बोला.', 'जाइये.', 'मी ऐकत आहे.'],
      'didNotCatch1': [
        'माफ करा, नीट ऐकू आलं नाही. कृपया पुन्हा सांगा.',
        'नीट समजले नाही. कृपया पुन्हा एकदा सांगा.',
      ],
      'didNotCatch2': [
        'ठीक आहे. कुठे जायचं आहे? तुम्ही ग्रंथालय, स्वच्छतागृह किंवा फार्मसी म्हणू शकता.',
        'कोणत्या ठिकाणी जायचे आहे? उदाहरणार्थ ग्रंथालय किंवा स्वच्छतागृह.',
      ],
      'switchToList': [
        'काही हरकत नाही. जागांची नावे वाचली जातील. तुमची जागा ऐकू आल्यावर बटण दाबा.',
        'यादी मोड सुरू करत आहे. तुमची जागा आल्यावर बटण दाबा.',
      ],
      'confirmGuess': [
        'तुम्ही ग्रंथालय म्हणालात का?',
        'ग्रंथालयात जायचे आहे का?',
      ],
      'confirmHelp': [
        'तुम्हाला मदतीसाठी संदेश पाठवायचा आहे का?',
        'मदत हवी आहे का? हो किंवा नाही सांगा.',
      ],
      'confirmYesNo': [
        'कृपया हो किंवा नाही सांगा.',
        'कृपया हो किंवा नाही म्हणा.',
      ],
      'success': [
        'ठीक आहे, ग्रंथालयाकडे जाऊया.',
        'ठीक आहे, ग्रंथालयच्या दिशेने जाऊया.',
        'छान, ग्रंथालयकडे नेऊया.',
      ],
      'arrival': [
        'तुम्ही ग्रंथालयात पोहोचलात. छान!',
        'ग्रंथालयात पोहोचलात. शाबाश!',
        'ग्रंथालय आलात. खूप छान!',
      ],
      'listeningMarathi': [
        'व्हॉइस कमांड्स हिंदी किंवा इंग्रजीत काम करतात; मराठी मार्गदर्शन बोलले जाते.',
      ],
    },
  };

  // Rotation state to avoid repeating same phrase
  static final Map<String, Map<String, int>> _phraseIndex = {};

  static String getPhrase(
    String language,
    String key, {
    String? placeholder,
    String? notEqual,
  }) {
    final langPhrases = _phrases[language];
    if (langPhrases == null) {
      // Fallback to English
      return _getPhraseWithRotation('English', key, placeholder, notEqual);
    }

    final phrases = langPhrases[key];
    if (phrases == null || phrases.isEmpty) {
      // Fallback to English
      return _getPhraseWithRotation('English', key, placeholder, notEqual);
    }

    return _getPhraseWithRotation(language, key, placeholder, notEqual);
  }

  static String _getPhraseWithRotation(
    String language,
    String key,
    String? placeholder,
    String? notEqual,
  ) {
    final langPhrases = _phrases[language];
    if (langPhrases == null) {
      return '';
    }

    final phrases = langPhrases[key];
    if (phrases == null || phrases.isEmpty) {
      return '';
    }

    // Initialize index if not exists
    _phraseIndex.putIfAbsent(language, () => {});
    _phraseIndex[language]!.putIfAbsent(key, () => 0);

    // Get current phrase
    var index = _phraseIndex[language]![key]!;
    var phrase = phrases[index];

    // If matches notEqual and we have alternatives, pick next
    if (notEqual != null) {
      final rendered = placeholder != null ? phrase.replaceAll('library', placeholder) : phrase;
      if (rendered == notEqual && phrases.length > 1) {
        index = (index + 1) % phrases.length;
        phrase = phrases[index];
      }
    }

    // Advance rotation
    _phraseIndex[language]![key] = (index + 1) % phrases.length;

    // Replace placeholder if provided
    if (placeholder != null) {
      return phrase.replaceAll('library', placeholder);
    }

    return phrase;
  }

  // Reset rotation state (for testing)
  static void resetRotation() {
    _phraseIndex.clear();
  }
}
