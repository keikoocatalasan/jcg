/// Deterministic client-side safety check for Community posts and comments.
///
/// This is intentionally a fast UX guard, not the security boundary. The
/// Supabase content-safety trigger applies the same family of checks before
/// cloud writes, while admins can maintain the server-side dictionary.
class CommunityContentFilterResult {
  final bool allowed;
  final String normalizedText;
  final List<String> matchedWords;

  const CommunityContentFilterResult({
    required this.allowed,
    required this.normalizedText,
    this.matchedWords = const [],
  });
}

class CommunityContentFilter {
  const CommunityContentFilter._();

  /// Keep the terms in one versioned client list so the local composer can
  /// give immediate feedback. The database dictionary remains authoritative.
  static const blockedWords = <String>{
    // Filipino / Tagalog profanity and harassment.
    'putangina',
    'putang ina',
    'putang ina mo',
    'puta',
    'gago',
    'gaga',
    'tanga',
    'bobo',
    'ulol',
    'kupal',
    'tarantado',
    'siraulo',
    'bwisit',
    'buwisit',
    'lintik',
    'leche',
    'pakshet',
    'pakshit',
    'hinayupak',
    'hayop ka',
    'manyakis',
    'malandi',
    'bastos',
    'yawa',
    'pisti',
    // English profanity and harassment.
    'fuck',
    'fck',
    'fucking',
    'shit',
    'bullshit',
    'bitch',
    'asshole',
    'bastard',
    'damn',
    'crap',
    'dick',
    'pussy',
    'cunt',
    'slut',
    'whore',
    'jerk',
    'idiot',
    'moron',
    'stupid',
    // Sexual, hateful, threatening, and self-harm content.
    'porn',
    'nude',
    'nudes',
    'sexual',
    'rape',
    'rapist',
    'kys',
    'kill yourself',
    'go die',
    'i will kill you',
    'kill you',
    'shoot you',
    'nigger',
    'nigga',
    'faggot',
    'fag',
    'dyke',
    'tranny',
    'retard',
    'chink',
    'spic',
    'wetback',
    'kike',
  };

  static const _characterReplacements = <String, String>{
    // Common leetspeak.
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '9': 'g',
    '@': 'a',
    r'$': 's',
    '!': 'i',
    '|': 'i',
    // Frequently used Latin accents and Unicode lookalikes.
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
    // Common Cyrillic/Greek lookalikes typed into Latin text.
    'а': 'a',
    'е': 'e',
    'і': 'i',
    'о': 'o',
    'с': 'c',
    'к': 'k',
    'р': 'p',
    'х': 'x',
    'у': 'y',
    'ο': 'o',
    'ρ': 'p',
    'ι': 'i',
  };

  static CommunityContentFilterResult check(String text) {
    final normalized = _normalize(text);
    final padded = ' $normalized ';
    final obfuscatedRuns = _obfuscatedRuns(normalized);
    final matches = <String>{};

    for (final word in blockedWords) {
      final normalizedWord = _normalize(word);
      final compactWord = normalizedWord.replaceAll(' ', '');
      if (padded.contains(' $normalizedWord ') ||
          obfuscatedRuns.contains(compactWord)) {
        matches.add(word);
      }
    }

    // A few high-risk phrases are clearer as a category than as a raw term.
    if (_containsThreatOrSelfHarmPhrase(normalized)) {
      matches.add('unsafe threat or self-harm phrase');
    }

    return CommunityContentFilterResult(
      allowed: matches.isEmpty,
      normalizedText: text.trim(),
      matchedWords: matches.toList(growable: false),
    );
  }

  static String _normalize(String text) {
    var value = text.toLowerCase();
    // Remove zero-width formatting characters before collapsing separators.
    value = value.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    for (final entry in _characterReplacements.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    // Collapse repeated characters so fuuuuuck and gaaaago are equivalent to
    // their dictionary form without changing ordinary word boundaries.
    value = value.replaceAllMapped(
      RegExp(r'([a-z0-9])\1+'),
      (match) => match.group(1)!,
    );
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return value;
  }

  /// Joins short separator-delimited pieces such as `f.u.c.k` or `g 4 g 0`.
  /// Normal words remain a single token, so a safe word such as "spice" is
  /// not rejected just because it starts with a blocked short form.
  static Set<String> _obfuscatedRuns(String normalized) {
    if (normalized.isEmpty) return const <String>{};
    final tokens = normalized.split(' ');
    final runs = <String>{};
    for (var index = 0; index < tokens.length; index++) {
      if (tokens[index].length > 2) continue;
      final buffer = StringBuffer();
      var cursor = index;
      while (cursor < tokens.length && tokens[cursor].length <= 2) {
        buffer.write(tokens[cursor]);
        cursor++;
      }
      // A zero-width character can leave a short prefix beside one normal
      // token, for example `pu tangina`. Include that final token as part of
      // the same obfuscated run.
      if (buffer.isNotEmpty && cursor < tokens.length) {
        buffer.write(tokens[cursor]);
      }
      if (buffer.length >= 3) runs.add(buffer.toString());
    }
    return runs;
  }

  static bool _containsThreatOrSelfHarmPhrase(String normalized) {
    const phrases = [
      'hurt yourself',
      'harm yourself',
      'end your life',
      'take your life',
      'i want to die',
      'you should die',
      'i will hurt you',
      'i will shoot you',
    ];
    final padded = ' $normalized ';
    return phrases.any((phrase) => padded.contains(' $phrase '));
  }
}
