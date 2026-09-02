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

  static const blockedWords = <String>{
    'putangina',
    'putang ina',
    'puta',
    'gago',
    'tanga',
    'bobo',
    'ulol',
    'fuck',
    'fck',
    'fucking',
    'shit',
    'bitch',
    'asshole',
    'kill yourself',
  };

  static CommunityContentFilterResult check(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final padded = ' $normalized ';
    final exactMatches = blockedWords
        .where((word) => padded.contains(' ${word.toLowerCase()} '))
        .toSet();
    final compact = normalized.replaceAll(' ', '');
    final obfuscatedMatches = blockedWords
        .where((word) =>
            !word.contains(' ') && compact.contains(word.toLowerCase()))
        .toSet();
    final matches =
        {...exactMatches, ...obfuscatedMatches}.toList(growable: false);
    return CommunityContentFilterResult(
      allowed: matches.isEmpty,
      normalizedText: text.trim(),
      matchedWords: matches,
    );
  }
}
