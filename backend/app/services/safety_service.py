from dataclasses import dataclass, field


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

    if matched_blocked:
        return SafetyCheck(status="blocked", matched_topics=matched_blocked)

    if matched_redirected:
        return SafetyCheck(status="redirected", matched_topics=matched_redirected)

    return SafetyCheck(status="safe")
