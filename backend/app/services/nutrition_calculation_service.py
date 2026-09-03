"""Deterministic portion-aware nutrition calculations.

The input values must come from the reviewed food catalog. Vision or LLM output
is only responsible for identifying a candidate and never supplies final
nutrition totals.
"""

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class NutritionReference:
    reference_grams: float
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    cost_php: float = 0.0


@dataclass(frozen=True)
class NutritionComponentInput:
    food_name: str
    grams: float
    reference: NutritionReference
    quantity: float = 1.0


@dataclass(frozen=True)
class NutritionTotals:
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    cost_php: float


def scale_component(
    component: NutritionComponentInput,
) -> NutritionTotals:
    if component.grams <= 0:
        raise ValueError("Component grams must be greater than zero")
    if component.quantity <= 0:
        raise ValueError("Component quantity must be greater than zero")
    if component.reference.reference_grams <= 0:
        raise ValueError("Reference grams must be greater than zero")

    multiplier = component.grams / component.reference.reference_grams
    multiplier *= component.quantity
    reference = component.reference
    return NutritionTotals(
        calories=round(reference.calories * multiplier, 2),
        protein_g=round(reference.protein_g * multiplier, 2),
        carbs_g=round(reference.carbs_g * multiplier, 2),
        fat_g=round(reference.fat_g * multiplier, 2),
        cost_php=round(reference.cost_php * multiplier, 2),
    )


def calculate_totals(
    components: Iterable[NutritionComponentInput],
) -> NutritionTotals:
    totals = NutritionTotals(0.0, 0.0, 0.0, 0.0, 0.0)
    seen = False
    for component in components:
        seen = True
        current = scale_component(component)
        totals = NutritionTotals(
            calories=round(totals.calories + current.calories, 2),
            protein_g=round(totals.protein_g + current.protein_g, 2),
            carbs_g=round(totals.carbs_g + current.carbs_g, 2),
            fat_g=round(totals.fat_g + current.fat_g, 2),
            cost_php=round(totals.cost_php + current.cost_php, 2),
        )
    if not seen:
        raise ValueError("At least one nutrition component is required")
    return totals
