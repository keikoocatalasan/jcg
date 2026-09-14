from app.services.scanner_service import ScannerService


def test_compact_vision_contract_parses_rice_and_side_items() -> None:
    food_name, rice_present, extras, confidence = ScannerService._parse_nvidia_scan_text(
        "dish=Chicken Adobo; confidence=0.86; rice=yes; extras=atchara, boiled egg"
    )

    assert food_name == "Chicken Adobo"
    assert rice_present is True
    assert extras == ["atchara", "boiled egg"]
    assert confidence == 0.86


def test_plain_legacy_vision_response_still_parses_as_unknown_composition() -> None:
    food_name, rice_present, extras, confidence = ScannerService._parse_nvidia_scan_text(
        "Chicken Adobo"
    )

    assert food_name == "Chicken Adobo"
    assert rice_present is None
    assert extras == []
    assert confidence is None


def test_confidence_parser_accepts_percentages_and_rejects_invalid_values() -> None:
    assert ScannerService._parse_confidence("59%") == 0.59
    assert ScannerService._parse_confidence("0.86") == 0.86
    assert ScannerService._parse_confidence("certain") is None
    assert ScannerService._parse_confidence("101%") is None
