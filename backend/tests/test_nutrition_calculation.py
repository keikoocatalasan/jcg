import pytest

from app.services.nutrition_calculation_service import (
    NutritionComponentInput,
    NutritionReference,
    calculate_totals,
    scale_component,
)


def reference() -> NutritionReference:
    return NutritionReference(
        reference_grams=100,
        calories=200,
        protein_g=20,
        carbs_g=10,
        fat_g=8,
        cost_php=25,
    )


def test_scale_component_uses_grams_not_an_image_guess() -> None:
    result = scale_component(
        NutritionComponentInput("Ulam", grams=150, reference=reference())
    )

    assert result.calories == 300
    assert result.protein_g == 30
    assert result.carbs_g == 15
    assert result.fat_g == 12
    assert result.cost_php == 37.5


def test_totals_add_ulam_and_rice_without_double_counting() -> None:
    rice = NutritionReference(150, 195, 4, 42, 0.5, 15)
    totals = calculate_totals(
        [
            NutritionComponentInput("Ulam", 180, reference()),
            NutritionComponentInput("Rice", 150, rice),
        ]
    )

    assert totals.calories == 555
    assert totals.protein_g == 40
    assert totals.carbs_g == 60
    assert totals.fat_g == 14.9
    assert totals.cost_php == 60


@pytest.mark.parametrize("grams", [0, -1])
def test_invalid_grams_are_rejected(grams: float) -> None:
    with pytest.raises(ValueError):
        scale_component(NutritionComponentInput("Ulam", grams, reference()))
