from dataclasses import dataclass, field
import re
import unicodedata


def contains_profanity(message: str) -> bool:
    text = unicodedata.normalize('NFKC', message).casefold()
    text = ''.join(c for c in text if unicodedata.category(c) != 'Cf')
    text = text.translate(str.maketrans({'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', '$': 's'}))
    # Word boundaries avoid blocking ordinary words such as assistant or putative.
    for word in ('fuck', 'shit', 'bitch', 'putangina', 'tangina', 'puta', 'gago', 'tanga', 'ulol', 'pakyu', 'tarantado', 'burat', 'kantot'):
        pattern = r'(?<![a-z])' + r'[\W_]*'.join(re.escape(c) + '+' for c in word) + r'(?![a-z])'
        if re.search(pattern, text):
            return True
    return False


@dataclass
class SafetyCheck:
    status: str  # "safe" | "redirected" | "blocked"
    matched_topics: list[str] = field(default_factory=list)


BLOCKED_TOPICS = [
    "medical diagnosis",
    "disease treatment",
    "eating disorder",
    "extreme fasting",
    "supplement prescription",
    "dangerous calorie restriction",
]

EMERGENCY_TOPICS = [
    "chest pain",
    "difficulty breathing",
    "can't breathe",
    "cannot breathe",
    "feel faint",
    "fainted",
    "severe allergic reaction",
    "anaphylaxis",
    "suicidal",
    "suicide",
    "self harm",
]

REDIRECTED_TOPICS = [
    "weight loss pill",
    "detox cleanse",
    "magic diet",
    "crash diet",
]


def check_safety(message: str) -> SafetyCheck:
    msg_lower = message.lower()

    matched_emergency = [t for t in EMERGENCY_TOPICS if t in msg_lower]
    matched_redirected = [t for t in REDIRECTED_TOPICS if t in msg_lower]
    matched_blocked = [t for t in BLOCKED_TOPICS if t in msg_lower]

    if matched_emergency:
        return SafetyCheck(status="blocked", matched_topics=matched_emergency)

    if contains_profanity(message):
        return SafetyCheck(status="redirected", matched_topics=['profanity'])

    if matched_blocked:
        return SafetyCheck(status="blocked", matched_topics=matched_blocked)

    if matched_redirected:
        return SafetyCheck(status="redirected", matched_topics=matched_redirected)

    return SafetyCheck(status="safe")
