"""Collect and quality-check Filipino food image candidates.

The collector is intentionally source-first and resumable. It uses the
Wikimedia Commons and Openverse APIs for discovery, keeps full provenance,
rejects disallowed or incomplete licenses, strips EXIF data from downloaded
copies, and prevents exact/near-duplicate images from being counted twice.

Example:
    python tools/dataset/collect_food_images.py \
      --registry tools/dataset/dish_registry.json \
      --work-dir C:/Users/HP/Desktop/jcg-dataset-work/filipino_food_100 \
      --target-real 40 --max-dishes 10

The raw dataset is deliberately kept outside the repository. Generated and
captured images can later be added to the same manifest with the fields used
here; they should not be silently treated as open-source images.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import io
import json
import re
import time
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import quote

import requests
from PIL import Image, ImageOps, UnidentifiedImageError


COMMONS_API = "https://commons.wikimedia.org/w/api.php"
OPENVERSE_API = "https://api.openverse.org/v1/images/"
USER_AGENT = "JCG-Fitness-Filipino-Food-Dataset/0.1 (academic prototype)"
MAX_RETRIES = 6
OPENVERSE_LICENSE_CODES = ("cc0", "by", "by-sa")


class ProviderRateLimitError(requests.RequestException):
    """Raised when a provider asks the batch to stop and resume later."""


def _plain(value: str | None) -> str:
    if not value:
        return ""
    value = html.unescape(value)
    value = re.sub(r"<[^>]+>", " ", value)
    return " ".join(value.split())


def _normalise_license(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def license_decision(license_name: str, license_url: str) -> tuple[str, str]:
    """Return (decision, reason) using a conservative production allowlist."""

    name = _normalise_license(license_name)
    url = _normalise_license(license_url)
    combined = f"{name}{url}"
    if not combined:
        return "reject", "missing_license_metadata"
    if any(token in combined for token in ("noncommercial", "bync", "ncsa", "ncnd")):
        return "reject", "noncommercial_license"
    if any(token in combined for token in ("noderivatives", "bynd", "nd")):
        return "reject", "no_derivatives_license"
    if "cc0" in combined or "publicdomain" in combined:
        return "allow", "cc0_or_public_domain"
    if "creativecommons" in combined and ("ccby" in combined or "by" in name):
        if "sharealike" in combined or "bysa" in combined:
            return "allow_with_review", "cc_by_sa_requires_attribution_review"
        return "allow", "cc_by"
    return "reject", "license_not_on_allowlist"


def _sleep_for_retry(response: requests.Response | None, attempt: int) -> None:
    retry_after = response.headers.get("Retry-After") if response is not None else None
    try:
        delay = float(retry_after) if retry_after else min(60.0, 1.5 * (2**attempt))
    except ValueError:
        delay = min(60.0, 1.5 * (2**attempt))
    time.sleep(delay)


def request_json(
    session: requests.Session,
    url: str,
    params: dict[str, Any],
    *,
    timeout: int = 60,
) -> dict[str, Any]:
    last_response: requests.Response | None = None
    for attempt in range(MAX_RETRIES):
        try:
            response = session.get(url, params=params, timeout=timeout)
            last_response = response
            if response.status_code == 429:
                if attempt >= 2:
                    raise ProviderRateLimitError(
                        f"Provider rate limit reached for {url}"
                    )
                _sleep_for_retry(response, attempt)
                continue
            if response.status_code >= 500:
                _sleep_for_retry(response, attempt)
                continue
            response.raise_for_status()
            return response.json()
        except (requests.RequestException, ValueError):
            if attempt == MAX_RETRIES - 1:
                raise
            _sleep_for_retry(last_response, attempt)
    raise RuntimeError(f"Unable to read {url}")


def request_bytes(
    session: requests.Session,
    url: str,
    *,
    timeout: int = 90,
) -> bytes:
    """Download one image while respecting provider throttling."""

    last_response: requests.Response | None = None
    for attempt in range(MAX_RETRIES):
        try:
            response = session.get(
                url,
                timeout=timeout,
                headers={"Accept": "image/*"},
            )
            last_response = response
            if response.status_code == 429 or response.status_code >= 500:
                _sleep_for_retry(response, attempt)
                continue
            response.raise_for_status()
            return response.content
        except requests.RequestException:
            if attempt == MAX_RETRIES - 1:
                raise
            _sleep_for_retry(last_response, attempt)
    raise RuntimeError(f"Unable to download {url}")


def _metadata_value(metadata: dict[str, Any], key: str) -> str:
    value = metadata.get(key, {})
    if isinstance(value, dict):
        value = value.get("value", "")
    return _plain(str(value))


def _commons_record(page: dict[str, Any]) -> dict[str, Any] | None:
    infos = page.get("imageinfo") or []
    if not infos:
        return None
    info = infos[0]
    mime = str(info.get("mime") or "")
    if not mime.startswith("image/"):
        return None
    metadata = info.get("extmetadata") or {}
    title = str(page.get("title") or "")
    source_page = info.get("descriptionurl") or (
        "https://commons.wikimedia.org/wiki/" + quote(title.replace(" ", "_"), safe="():,_-")
    )
    license_name = _metadata_value(metadata, "LicenseShortName")
    license_url = _metadata_value(metadata, "LicenseUrl")
    decision, reason = license_decision(license_name, license_url)
    author = _metadata_value(metadata, "Artist") or "Unknown / not stated"
    return {
        "source_type": "wikimedia_commons",
        "source_id": f"commons:{page.get('pageid') or title}",
        "title": title,
        "source_page": source_page,
        "image_url": info.get("thumburl") or info.get("url"),
        "mime": mime,
        "width": info.get("width"),
        "height": info.get("height"),
        "source_sha1": info.get("sha1"),
        "license": license_name,
        "license_url": license_url,
        "license_decision": decision,
        "license_reason": reason,
        "author": author,
        "credit": _metadata_value(metadata, "Credit"),
        "description": _metadata_value(metadata, "ImageDescription"),
        "retrieved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def discover_commons(
    session: requests.Session,
    query: str,
    *,
    max_results: int,
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    params: dict[str, Any] = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": str(min(50, max_results)),
        "prop": "imageinfo",
        "iiprop": "url|mime|size|sha1|timestamp|extmetadata",
        "iiurlwidth": "1280",
        "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Credit|ImageDescription",
        "format": "json",
        "formatversion": "2",
    }
    while len(records) < max_results:
        payload = request_json(session, COMMONS_API, params)
        query_payload = payload.get("query") or {}
        pages = query_payload.get("pages") or []
        if isinstance(pages, dict):
            pages = list(pages.values())
        for page in pages:
            record = _commons_record(page)
            if record is not None:
                record["query"] = query
                records.append(record)
                if len(records) >= max_results:
                    break
        continuation = payload.get("continue")
        if not continuation:
            break
        params.update(continuation)
        time.sleep(0.25)
    return records


def discover_openverse(
    session: requests.Session,
    query: str,
    *,
    max_results: int,
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for license_code in OPENVERSE_LICENSE_CODES:
        payload = request_json(
            session,
            OPENVERSE_API,
            {
                "q": query,
                "license": license_code,
                "page_size": min(100, max_results),
            },
        )
        for item in payload.get("results") or []:
            source_page = item.get("foreign_landing_url") or item.get("detail_url")
            image_url = item.get("url") or item.get("thumbnail")
            if not source_page or not image_url:
                continue
            license_name = " ".join(
                str(value)
                for value in (item.get("license"), item.get("license_version"))
                if value
            )
            license_url = item.get("license_url") or ""
            decision, reason = license_decision(license_name, license_url)
            records.append(
                {
                    "source_type": "openverse",
                    "source_id": f"openverse:{item.get('id') or image_url}",
                    "title": item.get("title") or "",
                    "source_page": source_page,
                    "image_url": image_url,
                    "mime": item.get("mimetype") or "image/jpeg",
                    "width": item.get("width"),
                    "height": item.get("height"),
                    "source_sha1": "",
                    "license": license_name,
                    "license_url": license_url,
                    "license_decision": "needs_manual_review"
                    if decision.startswith("allow")
                    else decision,
                    "license_reason": "verify_original_source_page_before_training"
                    if decision.startswith("allow")
                    else reason,
                    "author": item.get("creator") or "",
                    "credit": item.get("source") or "",
                    "description": item.get("description") or "",
                    "query": query,
                    "retrieved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
            )
            if len(records) >= max_results:
                break
        if len(records) >= max_results:
            break
        time.sleep(0.5)
    return records[:max_results]


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _average_hash(image: Image.Image) -> str:
    small = ImageOps.fit(image.convert("L"), (16, 16), method=Image.Resampling.LANCZOS)
    values = list(small.get_flattened_data())
    average = sum(values) / len(values)
    return "".join("1" if value >= average else "0" for value in values)


def _hamming(left: str, right: str) -> int:
    if len(left) != len(right):
        return 10_000
    return sum(a != b for a, b in zip(left, right))


def _safe_stem(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9_-]+", "_", value).strip("_")
    return value[:80] or "image"


def _load_jsonl(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    records: dict[str, dict[str, Any]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        key = str(record.get("candidate_key") or record.get("source_id"))
        records[key] = record
    return records


def _write_jsonl(path: Path, records: Iterable[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    lines = [json.dumps(record, ensure_ascii=False, sort_keys=True) for record in records]
    temporary.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    temporary.replace(path)


def _download_and_validate(
    session: requests.Session,
    record: dict[str, Any],
    destination: Path,
    *,
    min_short_side: int,
    known_hashes: set[str],
    known_perceptual_hashes: list[str],
) -> tuple[str, dict[str, Any]]:
    image_url = record.get("image_url")
    if not image_url:
        return "rejected_quality", {"reject_reason": "missing_image_url"}
    source_bytes = request_bytes(session, image_url)
    if len(source_bytes) > 25 * 1024 * 1024:
        return "rejected_quality", {"reject_reason": "source_file_over_25mb"}
    try:
        with Image.open(io.BytesIO(source_bytes)) as opened:
            image = ImageOps.exif_transpose(opened).convert("RGB")
            width, height = image.size
            if min(width, height) < min_short_side:
                return "rejected_quality", {
                    "reject_reason": "short_side_below_minimum",
                    "decoded_width": width,
                    "decoded_height": height,
                }
            perceptual_hash = _average_hash(image)
            source_hash = _sha256(source_bytes)
            if source_hash in known_hashes:
                return "rejected_duplicate", {"reject_reason": "exact_duplicate"}
            if any(_hamming(perceptual_hash, value) <= 4 for value in known_perceptual_hashes):
                return "rejected_duplicate", {"reject_reason": "near_duplicate"}
            image.thumbnail((1280, 1280), Image.Resampling.LANCZOS)
            destination.parent.mkdir(parents=True, exist_ok=True)
            image.save(destination, format="JPEG", quality=92, optimize=True)
            saved_bytes = destination.read_bytes()
            return "downloaded_pending_review", {
                "source_bytes": len(source_bytes),
                "decoded_width": width,
                "decoded_height": height,
                "saved_width": image.width,
                "saved_height": image.height,
                "download_sha256": source_hash,
                "saved_sha256": _sha256(saved_bytes),
                "perceptual_hash": perceptual_hash,
                "image_path": destination.as_posix(),
                "review_status": "human_pending",
            }
    except (UnidentifiedImageError, OSError) as exc:
        return "rejected_quality", {"reject_reason": f"image_decode_failed:{type(exc).__name__}"}


def _query_variants(entry: dict[str, Any], query_limit: int) -> list[str]:
    variants: list[str] = []
    for alias in entry.get("aliases") or []:
        for query in (alias, f"{alias} Philippines"):
            if query not in variants:
                variants.append(query)
            if len(variants) >= query_limit:
                return variants
    return variants


def collect(args: argparse.Namespace) -> dict[str, Any]:
    registry = json.loads(Path(args.registry).read_text(encoding="utf-8"))
    entries = registry["classes"]
    selected_ids = set(args.dish_id or [])
    if selected_ids:
        entries = [entry for entry in entries if entry["id"] in selected_ids]
    if args.max_dishes:
        entries = entries[: args.max_dishes]
    if not entries:
        raise ValueError("No dish classes selected")

    work_dir = Path(args.work_dir).resolve()
    manifest_path = work_dir / "manifests" / "candidates.jsonl"
    records = _load_jsonl(manifest_path)
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    known_hashes = {
        str(record["download_sha256"])
        for record in records.values()
        if record.get("download_sha256")
    }
    known_perceptual_hashes = [
        str(record["perceptual_hash"])
        for record in records.values()
        if record.get("perceptual_hash")
    ]
    summary: list[dict[str, Any]] = []

    for entry in entries:
        dish_id = entry["id"]
        queries = _query_variants(entry, args.query_limit)
        candidates: list[dict[str, Any]] = []
        for query in queries:
            if args.source in ("commons", "both"):
                candidates.extend(
                    discover_commons(session, query, max_results=args.search_limit)
                )
            if args.source in ("openverse", "both"):
                candidates.extend(
                    discover_openverse(session, query, max_results=args.search_limit)
                )
        unique_candidates: dict[str, dict[str, Any]] = {}
        for candidate in candidates:
            candidate_key = f"{candidate['source_type']}:{candidate['source_id']}"
            candidate["candidate_key"] = candidate_key
            candidate["dish_id"] = dish_id
            candidate["canonical_label"] = entry["display_name"]
            unique_candidates[candidate_key] = candidate
        candidates = list(unique_candidates.values())

        for candidate in candidates:
            key = candidate["candidate_key"]
            if key in records:
                existing = records[key]
                if not existing.get("author") and candidate.get("author"):
                    existing["author"] = candidate["author"]
                if not existing.get("license_url") and candidate.get("license_url"):
                    existing["license_url"] = candidate["license_url"]
                if not existing.get("license") and candidate.get("license"):
                    existing["license"] = candidate["license"]
                records[key] = existing
                continue
            if candidate["license_decision"] not in ("allow", "allow_with_review"):
                candidate["status"] = "rejected_license"
                records[key] = candidate

        existing_downloads = [
            record
            for record in records.values()
            if record.get("dish_id") == dish_id
            and record.get("status") == "downloaded_pending_review"
        ]
        remaining = max(0, args.target_real - len(existing_downloads))
        accepted_candidates = [
            candidate
            for candidate in candidates
            if candidate["candidate_key"] not in records
            and candidate["license_decision"] in ("allow", "allow_with_review")
            and candidate["source_type"] == "wikimedia_commons"
        ]
        provider_rate_limited = False
        for candidate in accepted_candidates[:remaining]:
            stem = _safe_stem(candidate["source_id"].split(":", 1)[-1])
            destination = work_dir / "raw" / "open_source" / dish_id / f"{stem}.jpg"
            try:
                status, details = _download_and_validate(
                    session,
                    candidate,
                    destination,
                    min_short_side=args.min_short_side,
                    known_hashes=known_hashes,
                    known_perceptual_hashes=known_perceptual_hashes,
                )
            except ProviderRateLimitError:
                provider_rate_limited = True
                print("Provider rate limit reached; save progress and resume later")
                break
            except requests.RequestException as exc:
                status = "deferred_download"
                details = {
                    "reject_reason": "provider_request_failed",
                    "download_error": str(exc),
                }
            candidate.update(details)
            candidate["status"] = status
            if status == "downloaded_pending_review":
                candidate["image_path"] = destination.relative_to(work_dir).as_posix()
                known_hashes.add(candidate["download_sha256"])
                known_perceptual_hashes.append(candidate["perceptual_hash"])
            records[candidate["candidate_key"]] = candidate
            time.sleep(args.download_delay)

        dish_records = [record for record in records.values() if record.get("dish_id") == dish_id]
        summary.append(
            {
                "dish_id": dish_id,
                "display_name": entry["display_name"],
                "queries": queries,
                "discovered": len(candidates),
                "accepted_downloaded_pending_review": sum(
                    record.get("status") == "downloaded_pending_review"
                    for record in dish_records
                ),
                "license_rejected": sum(
                    record.get("status") == "rejected_license" for record in dish_records
                ),
                "near_or_exact_duplicates": sum(
                    record.get("status") == "rejected_duplicate" for record in dish_records
                ),
            }
        )
        _write_jsonl(manifest_path, records.values())
        print(json.dumps(summary[-1], ensure_ascii=False))
        if provider_rate_limited:
            break

    summary_path = work_dir / "manifests" / "collection_summary.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return {"work_dir": str(work_dir), "manifest": str(manifest_path), "summary": summary}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--dish-id", action="append", help="Repeat to select specific dish IDs")
    parser.add_argument("--max-dishes", type=int)
    parser.add_argument("--source", choices=("commons", "openverse", "both"), default="commons")
    parser.add_argument("--target-real", type=int, default=40)
    parser.add_argument("--query-limit", type=int, default=4)
    parser.add_argument("--search-limit", type=int, default=50)
    parser.add_argument("--min-short-side", type=int, default=640)
    parser.add_argument("--download-delay", type=float, default=2.0)
    args = parser.parse_args()
    result = collect(args)
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
