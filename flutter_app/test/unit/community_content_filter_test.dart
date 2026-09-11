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

  test('blocks Filipino and English terms when separated or repeated', () {
    expect(
      CommunityContentFilter.check('p.u.t.a.n.g.i.n.a').allowed,
      isFalse,
    );
    expect(
      CommunityContentFilter.check('h i n a y u p a k').allowed,
      isFalse,
    );
    expect(
      CommunityContentFilter.check('fuuuuuck this').allowed,
      isFalse,
    );
  });

  test('blocks zero-width and Unicode-lookalike construction', () {
    expect(
      CommunityContentFilter.check('pu\u200B tangina').allowed,
      isFalse,
    );
    // The a and o below are Cyrillic lookalikes, not Latin characters.
    expect(
      CommunityContentFilter.check('gаgо').allowed,
      isFalse,
    );
  });

  test('blocks indirect threat and self-harm language', () {
    expect(
      CommunityContentFilter.check('You should end your life').allowed,
      isFalse,
    );
    expect(
      CommunityContentFilter.check('I will shoot you').allowed,
      isFalse,
    );
  });

  test('allows safe near-misses', () {
    final result = CommunityContentFilter.check(
      'Classic chicken adobo with a little spice is my lunch today.',
    );
    expect(result.allowed, isTrue);
    expect(result.matchedWords, isEmpty);
  });
}
