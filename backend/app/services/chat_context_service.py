"""Small, authenticated Supabase lookups used to ground chatbot answers."""

import asyncio
import logging
import re
from datetime import datetime, time, timedelta, timezone
from uuid import UUID

import httpx

from app.config import settings
from app.schemas.chatbot import ChatContext, ChatFoodRecord, ChatTurn


logger = logging.getLogger(__name__)

_STOP_WORDS = {
    "a", "about", "and", "are", "as", "at", "be", "best", "can", "calorie",
    "calories", "carb", "carbs", "carbohydrate", "carbohydrates", "contains",
    "contain", "does", "eat", "eaten", "fat", "for", "food", "from", "give",
    "good", "healthy", "help", "how", "i", "in", "is", "it", "meal", "me",
    "many", "much", "my", "nutrition", "of", "on", "or", "please", "protein",
    "should", "show", "tell", "that", "the", "this", "to", "what", "when", "with",
    "would", "yung", "ano", "ang", "ba", "daw", "dito", "ilan", "ko", "magkano",
    "mo", "na", "ng", "opo", "paano", "po", "sa", "sana", "ito", "yan", "yong",
    "gram", "grams", "kilogram", "kilograms", "kilo", "kilos", "kg", "oz", "ounce",
}


class ChatContextService:
    """Reads only the current user's permitted records using their Supabase JWT."""

    async def get_context(
        self,
        *,
        auth_user_id: str,
        access_token: str,
        message: str,
        history: list[ChatTurn] | None = None,
    ) -> ChatContext | None:
        if not settings.supabase_url or not settings.supabase_anon_key or not access_token:
            return None
        try:
            UUID(auth_user_id)
        except (TypeError, ValueError, AttributeError):
            return None

        headers = {
            "apikey": settings.supabase_anon_key,
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                user_rows, food_rows = await asyncio.gather(
                    self._get_rows(
                        client,
                        "app_user",
                        {
                            "select": "user_id",
                            "auth_user_id": f"eq.{auth_user_id}",
                            "limit": "1",
                        },
                        headers,
                    ),
                    self._get_food_rows(client, message, history, headers),
                )
                app_user_id = str(user_rows[0].get("user_id")) if user_rows else None
                if not app_user_id:
                    return self._context_or_none(food_records=food_rows)

                manila_timezone = timezone(timedelta(hours=8))
                local_day = datetime.now(manila_timezone).date()
                day_start = datetime.combine(local_day, time.min, manila_timezone)
                day_end = day_start + timedelta(days=1)
                start_utc = day_start.astimezone(timezone.utc).isoformat()
                end_utc = day_end.astimezone(timezone.utc).isoformat()

                profile, targets, snapshots, meal_logs, user_allergies, user_restrictions = (
                    await asyncio.gather(
                        self._get_rows(
                            client,
                            "user_profile",
                            {
                                "select": "fitness_goal_id,daily_budget_php",
                                "user_id": f"eq.{app_user_id}",
                                "limit": "1",
                            },
                            headers,
                        ),
                        self._get_rows(
                            client,
                            "nutrition_target",
                            {
                                "select": "fitness_goal_id,calorie_target,protein_target_g,carbs_target_g,fat_target_g",
                                "user_id": f"eq.{app_user_id}",
                                "is_active": "eq.true",
                                "order": "effective_from.desc",
                                "limit": "1",
                            },
                            headers,
                        ),
                        self._get_rows(
                            client,
                            "daily_target_snapshot",
                            {
                                "select": "calorie_target_snapshot,protein_target_g_snapshot,carbs_target_g_snapshot,fat_target_g_snapshot,daily_budget_php_snapshot",
                                "user_id": f"eq.{app_user_id}",
                                "target_date": f"eq.{local_day.isoformat()}",
                                "limit": "1",
                            },
                            headers,
                        ),
                        self._get_rows(
                            client,
                            "meal_log",
                            {
                                "select": "calories_snapshot,protein_g_snapshot,carbs_g_snapshot,fat_g_snapshot,cost_php_snapshot",
                                "user_id": f"eq.{app_user_id}",
                                "is_deleted": "eq.false",
                                "and": f"(logged_at.gte.{start_utc},logged_at.lt.{end_utc})",
                                "limit": "1000",
                            },
                            headers,
                        ),
                        self._get_rows(
                            client,
                            "user_allergy",
                            {
                                "select": "allergy_id",
                                "user_id": f"eq.{app_user_id}",
                            },
                            headers,
                        ),
                        self._get_rows(
                            client,
                            "user_dietary_restriction",
                            {
                                "select": "restriction_id",
                                "user_id": f"eq.{app_user_id}",
                            },
                            headers,
                        ),
                    )
                )

                profile_row = profile[0] if profile else {}
                target_row = snapshots[0] if snapshots else (targets[0] if targets else {})
                goal_id = profile_row.get("fitness_goal_id") or target_row.get("fitness_goal_id")

                allergy_ids = self._lookup_ids(user_allergies, "allergy_id")
                restriction_ids = self._lookup_ids(user_restrictions, "restriction_id")
                goal_rows, allergy_rows, restriction_rows = await asyncio.gather(
                    self._get_lookup_rows(client, "fitness_goal", "fitness_goal_id", goal_id, headers),
                    self._get_lookup_rows(client, "allergy", "allergy_id", allergy_ids, headers),
                    self._get_lookup_rows(
                        client,
                        "dietary_restriction",
                        "restriction_id",
                        restriction_ids,
                        headers,
                    ),
                )

                consumed = {
                    key: sum(self._as_float(row.get(column)) for row in meal_logs)
                    for key, column in {
                        "calories": "calories_snapshot",
                        "protein": "protein_g_snapshot",
                        "carbs": "carbs_g_snapshot",
                        "fat": "fat_g_snapshot",
                        "cost": "cost_php_snapshot",
                    }.items()
                }
                calorie_target = self._first_number(
                    target_row, "calorie_target_snapshot", "calorie_target"
                )
                protein_target = self._first_number(
                    target_row, "protein_target_g_snapshot", "protein_target_g"
                )
                carbs_target = self._first_number(
                    target_row, "carbs_target_g_snapshot", "carbs_target_g"
                )
                fat_target = self._first_number(
                    target_row, "fat_target_g_snapshot", "fat_target_g"
                )
                budget = self._first_number(
                    target_row,
                    "daily_budget_php_snapshot",
                )
                if budget is None:
                    budget = self._as_optional_float(profile_row.get("daily_budget_php"))

                context = ChatContext(
                    fitness_goal=(goal_rows[0].get("goal_code") if goal_rows else None),
                    calorie_target=int(calorie_target) if calorie_target is not None else None,
                    protein_target_g=protein_target,
                    carbs_target_g=carbs_target,
                    fat_target_g=fat_target,
                    calories_consumed_today=consumed["calories"],
                    protein_consumed_today_g=consumed["protein"],
                    carbs_consumed_today_g=consumed["carbs"],
                    fat_consumed_today_g=consumed["fat"],
                    remaining_budget_php=(
                        max(0.0, budget - consumed["cost"]) if budget is not None else None
                    ),
                    remaining_calories=(
                        max(0, int(round(calorie_target - consumed["calories"])))
                        if calorie_target is not None
                        else None
                    ),
                    remaining_protein_g=(
                        max(0.0, protein_target - consumed["protein"])
                        if protein_target is not None
                        else None
                    ),
                    remaining_carbs_g=(
                        max(0.0, carbs_target - consumed["carbs"])
                        if carbs_target is not None
                        else None
                    ),
                    remaining_fat_g=(
                        max(0.0, fat_target - consumed["fat"])
                        if fat_target is not None
                        else None
                    ),
                    allergies=[str(row["allergy_name"]) for row in allergy_rows if row.get("allergy_name")],
                    dietary_restrictions=[
                        str(row["restriction_name"])
                        for row in restriction_rows
                        if row.get("restriction_name")
                    ],
                    food_records=food_rows,
                )
                return self._context_or_none(context=context)
        except (httpx.RequestError, httpx.HTTPStatusError, ValueError, TypeError) as exc:
            # Chat should remain available if the optional context lookup is down.
            logger.warning("Chat context lookup unavailable (%s)", type(exc).__name__)
            return None

    async def _get_food_rows(
        self,
        client: httpx.AsyncClient,
        message: str,
        history: list[ChatTurn] | None,
        headers: dict[str, str],
    ) -> list[ChatFoodRecord]:
        terms = self._food_search_terms(message, history)
        if not terms:
            return []
        filters = ",".join(
            f"{column}.ilike.*{term}*"
            for term in terms
            for column in ("food_name", "normalized_name")
        )
        rows = await self._get_rows(
            client,
            "food_catalog",
            {
                "select": "food_name,normalized_name,serving_label,serving_grams,calories,protein_g,carbs_g,fat_g,estimated_price_php",
                "or": f"({filters})",
                "limit": "12",
            },
            headers,
        )
        ranked = sorted(
            rows,
            key=lambda row: sum(
                term in f"{row.get('food_name', '')} {row.get('normalized_name', '')}".casefold()
                for term in terms
            ),
            reverse=True,
        )
        found: list[ChatFoodRecord] = []
        seen: set[str] = set()
        for row in ranked:
            name = str(row.get("food_name") or "").strip()
            serving = str(row.get("serving_label") or "").strip()
            if not name or not serving or name.casefold() in seen:
                continue
            try:
                found.append(
                    ChatFoodRecord(
                        food_name=name,
                        serving_label=serving,
                        serving_grams=self._as_float(row.get("serving_grams")),
                        calories=self._as_float(row.get("calories")),
                        protein_g=self._as_float(row.get("protein_g")),
                        carbs_g=self._as_float(row.get("carbs_g")),
                        fat_g=self._as_float(row.get("fat_g")),
                        estimated_price_php=self._as_optional_float(
                            row.get("estimated_price_php")
                        ),
                    )
                )
                seen.add(name.casefold())
            except (TypeError, ValueError):
                continue
            if len(found) == 3:
                break
        return found

    async def _get_lookup_rows(
        self,
        client: httpx.AsyncClient,
        table: str,
        id_column: str,
        identifiers: int | str | list[int] | None,
        headers: dict[str, str],
    ) -> list[dict]:
        if identifiers is None or identifiers == []:
            return []
        filter_value = (
            f"eq.{identifiers}"
            if isinstance(identifiers, (int, str))
            else f"in.({','.join(str(value) for value in identifiers)})"
        )
        name_column = {
            "fitness_goal": "goal_code",
            "allergy": "allergy_name",
            "dietary_restriction": "restriction_name",
        }[table]
        return await self._get_rows(
            client,
            table,
            {"select": name_column, id_column: filter_value},
            headers,
        )

    async def _get_rows(
        self,
        client: httpx.AsyncClient,
        table: str,
        params: dict[str, str],
        headers: dict[str, str],
    ) -> list[dict]:
        url = f"{settings.supabase_url.rstrip('/')}/rest/v1/{table}"
        try:
            response = await client.get(url, params=params, headers=headers)
            response.raise_for_status()
            payload = response.json()
            return payload if isinstance(payload, list) else []
        except httpx.HTTPStatusError as exc:
            logger.warning(
                "Chat context query rejected table=%s status=%s",
                table,
                exc.response.status_code,
            )
        except (httpx.RequestError, ValueError) as exc:
            logger.warning(
                "Chat context query failed table=%s error=%s",
                table,
                type(exc).__name__,
            )
        return []

    @staticmethod
    def _food_search_terms(message: str, history: list[ChatTurn] | None) -> list[str]:
        sources = [message]
        sources.extend(
            turn.content
            for turn in reversed(history or [])
            if turn.role == "user"
        )
        for source in sources:
            terms = list(
                dict.fromkeys(
                    token
                    for token in re.findall(r"[a-z0-9]+", source.casefold())
                    if len(token) >= 3 and token not in _STOP_WORDS and not token.isdigit()
                )
            )
            if terms:
                return terms[:4]
        return []

    @staticmethod
    def _lookup_ids(rows: list[dict], key: str) -> list[int]:
        ids: list[int] = []
        for row in rows:
            try:
                value = int(row[key])
            except (KeyError, TypeError, ValueError):
                continue
            if value not in ids:
                ids.append(value)
        return ids

    @staticmethod
    def _as_float(value) -> float:
        return float(value or 0)

    @staticmethod
    def _as_optional_float(value) -> float | None:
        return None if value is None else float(value)

    @classmethod
    def _first_number(cls, row: dict, *keys: str) -> float | None:
        for key in keys:
            if row.get(key) is not None:
                return cls._as_optional_float(row[key])
        return None

    @staticmethod
    def _context_or_none(
        *,
        context: ChatContext | None = None,
        food_records: list[ChatFoodRecord] | None = None,
    ) -> ChatContext | None:
        if context is None:
            context = ChatContext(food_records=food_records or [])
        if context.model_dump(exclude_none=True, exclude_defaults=True):
            return context
        return None
