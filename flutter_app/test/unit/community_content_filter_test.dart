import 'package:flutter_test/flutter_test.dart';

import 'package:jcg_fitness/features/community/community_content_filter.dart';

void main() {
  test('allows ordinary community content', () {
    final result = CommunityContentFilter.check(
      'I cooked chicken adobo for my family today.',
    );
    expect(result.allowed, isTrue);
    expect(result.matchedWords, isEmpty);
  });

  test('blocks exact unsafe words and phrases', () {
    expect(
        CommunityContentFilter.check('That is gago behavior').allowed, isFalse);
    expect(
      CommunityContentFilter.check('Please kill yourself').allowed,
      isFalse,
    );
  });

  test('blocks simple leetspeak obfuscation', () {
    expect(CommunityContentFilter.check('g4g0').allowed, isFalse);
    expect(CommunityContentFilter.check('f*ck').allowed, isFalse);
  });
}
