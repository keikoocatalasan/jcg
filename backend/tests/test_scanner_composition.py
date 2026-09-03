from app.services.scanner_service import ScannerService


def test_compact_vision_contract_parses_rice_and_side_items() -> None:
    food_name, rice_present, extras = ScannerService._parse_nvidia_scan_text(
        "dish=Chicken Adobo; rice=yes; extras=atchara, boiled egg"
    )

    assert food_name == "Chicken Adobo"
    assert rice_present is True
    assert extras == ["atchara", "boiled egg"]


def test_plain_legacy_vision_response_still_parses_as_unknown_composition() -> None:
    food_name, rice_present, extras = ScannerService._parse_nvidia_scan_text(
        "Chicken Adobo"
    )

    assert food_name == "Chicken Adobo"
    assert rice_present is None
    assert extras == []
