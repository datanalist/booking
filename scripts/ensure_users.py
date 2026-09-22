#!/usr/bin/env python3
"""Align PocketBase auth collection `users` with docs/pocketbase-schema.md.

Only ADD/PATCH fields and backfill empty values. Does not delete fields,
records, avatar files, or the default `name` field.

Reads POCKETBASE_URL / POCKETBASE_SU / POCKETBASE_SU_PASSWORD from env or `.env.local`.

Usage:
  python3 scripts/ensure_users.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

ROLE_VALUES = ["guest", "host", "staff"]
ACCOUNT_STATUS_VALUES = ["active", "pending", "blocked", "rejected"]
PROTECTED_ACCOUNT_STATUSES = {"blocked", "rejected"}
PHONE_INDEX = (
    "CREATE UNIQUE INDEX `idx_users_phone` ON `users` (`phone`) "
    "WHERE `phone` != ''"
)
SEED_HOST_YEARS = {
    "анна иваненко": 4,
    "раиль сафин": 2,
    "марина орлова": 1,
}
SEED_HOST_YEARS_BY_EMAIL = {
    "anna.ivanenko@seed.booking.local": 4,
    "rail.safin@seed.booking.local": 2,
    "marina.orlova@seed.booking.local": 1,
}


def _text(name: str, required: bool = False) -> dict:
    return {"name": name, "type": "text", "required": required}


def _bool(name: str) -> dict:
    return {"name": name, "type": "bool", "required": False}


def _number(name: str) -> dict:
    return {
        "name": name,
        "type": "number",
        "required": False,
        "onlyInt": False,
    }


def _date(name: str) -> dict:
    return {"name": name, "type": "date", "required": False}


def _select(
    name: str,
    values: list[str],
    *,
    required: bool = False,
    max_select: int = 1,
) -> dict:
    return {
        "name": name,
        "type": "select",
        "required": required,
        "maxSelect": max_select,
        "values": values,
    }


def desired_fields(*, account_status_required: bool) -> list[dict]:
    return [
        _text("phone"),
        _text("first_name"),
        _text("last_name"),
        _date("birthdate"),
        _bool("limited_browse"),
        _text("bio"),
        _select("roles", ROLE_VALUES, max_select=len(ROLE_VALUES)),
        _select(
            "account_status",
            ACCOUNT_STATUS_VALUES,
            required=account_status_required,
        ),
        _text("staff_tasks"),
        _bool("verified_host"),
        _number("years_hosting"),
        _number("rating"),
        _number("reviews_count"),
        _number("balance"),
        _text("fcm_token"),
    ]


def merge_fields(existing: list[dict], desired: list[dict]) -> list[dict]:
    desired_by_name = {field["name"]: field for field in desired}
    seen: set[str] = set()
    out: list[dict] = []
    for field in existing:
        name = str(field.get("name") or "")
        seen.add(name)
        if name in desired_by_name:
            merged = dict(field)
            merged.update(desired_by_name[name])
            if field.get("id"):
                merged["id"] = field["id"]
            out.append(merged)
        else:
            out.append(dict(field))
    for spec in desired:
        if spec["name"] not in seen:
            out.append(dict(spec))
    return out


def merge_indexes(existing: list[str], extra: list[str]) -> list[str]:
    out = [str(item) for item in existing]
    have = {item.replace("`", "") for item in out}
    for item in extra:
        if item.replace("`", "") not in have:
            out.append(item)
    return out


def find_collection(pb: PocketBase, name: str) -> dict | None:
    data = pb.request(
        "GET",
        "/api/collections",
        query={"page": "1", "perPage": "200"},
    )
    for item in data.get("items") or []:
        if item.get("name") == name:
            return item
    return None


def list_records(pb: PocketBase, collection: str) -> list[dict]:
    page = 1
    items: list[dict] = []
    while True:
        data = pb.request(
            "GET",
            f"/api/collections/{collection}/records",
            query={"page": str(page), "perPage": "200"},
        )
        items.extend(data.get("items") or [])
        if page >= int(data.get("totalPages") or 1):
            break
        page += 1
    return items


def patch_collection(pb: PocketBase, existing: dict, fields: list[dict]) -> dict:
    payload = {
        "fields": fields,
        "indexes": merge_indexes(existing.get("indexes") or [], [PHONE_INDEX]),
    }
    updated = pb.request(
        "PATCH",
        f"/api/collections/{existing['id']}",
        json_body=payload,
    )
    print("updated collection users", updated.get("id"))
    return updated


def try_relax_email_required(pb: PocketBase, collection: dict) -> dict:
    """Schema: email is not required for OTP. Keep the field; only drop required."""
    fields = [dict(field) for field in collection.get("fields") or []]
    email = next((field for field in fields if field.get("name") == "email"), None)
    if email is None or email.get("required") is False:
        return collection
    email["required"] = False
    try:
        updated = pb.request(
            "PATCH",
            f"/api/collections/{collection['id']}",
            json_body={"fields": fields},
        )
        print("email.required: false (OTP guests may skip the profile form)")
        return updated
    except RuntimeError as exc:
        print(
            "email.required left as-is (auth field; PocketBase rejected the change):",
            exc,
        )
        return collection


def _blank(value: object) -> bool:
    if value is None:
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    if isinstance(value, (list, tuple, dict)) and len(value) == 0:
        return True
    return False


def _num_empty(value: object) -> bool:
    if _blank(value):
        return True
    try:
        return float(value) == 0
    except (TypeError, ValueError):
        return True


def split_name(name: str) -> tuple[str, str]:
    parts = name.strip().split(None, 1)
    if not parts:
        return "", ""
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[1]


def display_name(user: dict) -> str:
    first = str(user.get("first_name") or "").strip()
    last = str(user.get("last_name") or "").strip()
    joined = f"{first} {last}".strip()
    if joined:
        return joined
    return str(user.get("name") or "").strip()


def normalize_name(value: str) -> str:
    return " ".join(value.casefold().split())


def seed_years_for(user: dict) -> int | None:
    email = str(user.get("email") or "").strip().casefold()
    if email in SEED_HOST_YEARS_BY_EMAIL:
        return SEED_HOST_YEARS_BY_EMAIL[email]
    return SEED_HOST_YEARS.get(normalize_name(display_name(user)))


def listing_stats_by_host(listings: list[dict]) -> dict[str, dict[str, float]]:
    best: dict[str, dict[str, float]] = {}
    for item in listings:
        host_id = str(item.get("host") or "")
        if not host_id:
            continue
        rating = item.get("rating")
        reviews = item.get("reviews_count")
        try:
            rating_n = float(rating) if not _blank(rating) else None
        except (TypeError, ValueError):
            rating_n = None
        try:
            reviews_n = float(reviews) if not _blank(reviews) else None
        except (TypeError, ValueError):
            reviews_n = None
        if rating_n is None and reviews_n is None:
            continue
        score = reviews_n or 0
        prev = best.get(host_id)
        if prev is None or score > prev["_score"]:
            best[host_id] = {
                "rating": rating_n if rating_n is not None else 0,
                "reviews_count": reviews_n if reviews_n is not None else 0,
                "_score": score,
            }
    return best


def backfill_users(pb: PocketBase) -> dict[str, int]:
    users = list_records(pb, "users")
    listings = list_records(pb, "listings")
    host_ids = {str(item.get("host") or "") for item in listings}
    host_ids.discard("")
    stats = listing_stats_by_host(listings)
    counts = {
        "verified_host": 0,
        "names": 0,
        "years": 0,
        "roles": 0,
        "rating": 0,
        "account_status": 0,
        "users_patched": 0,
    }
    for user in users:
        patch: dict = {}
        user_id = str(user.get("id") or "")
        roles = list(user.get("roles") or []) if isinstance(user.get("roles"), list) else []
        is_host = user_id in host_ids or "host" in roles

        if _blank(user.get("first_name")) and _blank(user.get("last_name")):
            first, last = split_name(str(user.get("name") or ""))
            if first or last:
                if first:
                    patch["first_name"] = first
                if last:
                    patch["last_name"] = last
                counts["names"] += 1

        if is_host and not user.get("verified_host"):
            patch["verified_host"] = True
            counts["verified_host"] += 1

        if is_host and _num_empty(user.get("years_hosting")):
            years = seed_years_for(user)
            if years:
                patch["years_hosting"] = years
                counts["years"] += 1

        if user_id in host_ids:
            was_empty = len(roles) == 0
            changed = False
            if "host" not in roles:
                roles.append("host")
                changed = True
            if was_empty and "guest" not in roles:
                roles.insert(0, "guest")
                changed = True
            if changed:
                patch["roles"] = roles
                counts["roles"] += 1

        if is_host:
            listing = stats.get(user_id)
            if listing:
                if _num_empty(user.get("rating")) and listing.get("rating"):
                    patch["rating"] = listing["rating"]
                    counts["rating"] += 1
                if _num_empty(user.get("reviews_count")) and listing.get(
                    "reviews_count"
                ):
                    patch["reviews_count"] = listing["reviews_count"]

        status = user.get("account_status")
        if _blank(status) and status not in PROTECTED_ACCOUNT_STATUSES:
            patch["account_status"] = "active"
            counts["account_status"] += 1

        if not patch:
            continue
        pb.update("users", user_id, patch)
        counts["users_patched"] += 1
        print(f"backfill {user.get('email') or user_id}: {sorted(patch)}")
    return counts


def write_schema(pb: PocketBase, dump_path: Path) -> str:
    data = pb.request(
        "GET",
        "/api/collections",
        query={"page": "1", "perPage": "200"},
    )
    live_users = next(
        (item for item in data.get("items") or [] if item.get("name") == "users"),
        None,
    )
    if live_users is None:
        raise RuntimeError("GET /api/collections did not return users")
    schema = json.loads(dump_path.read_text(encoding="utf-8"))
    replaced = False
    for i, item in enumerate(schema):
        if item.get("name") == "users":
            schema[i] = live_users
            replaced = True
            break
    if not replaced:
        schema.insert(0, live_users)
    dump_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return str(live_users.get("id"))


def main() -> int:
    load_dotenv(ROOT / ".env.local")
    load_dotenv(Path("/home/mk/Projects/Booking/.env.local"))
    base = env("POCKETBASE_URL", "https://pb.booking.vallome.ru")
    identity = env("POCKETBASE_SU")
    password = env("POCKETBASE_SU_PASSWORD")
    if not identity or not password:
        print(
            "Need POCKETBASE_SU and POCKETBASE_SU_PASSWORD (env or .env.local)",
            file=sys.stderr,
        )
        return 2

    pb = PocketBase(base)
    print(f"auth {base} as superuser")
    pb.auth_superuser(identity, password)

    existing = find_collection(pb, "users")
    if existing is None:
        raise RuntimeError("Need existing `users` collection")

    before_names = [field.get("name") for field in existing.get("fields") or []]
    print("fields before:", ", ".join(str(name) for name in before_names))

    # Add domain fields first with account_status optional so existing rows validate.
    collection = patch_collection(
        pb,
        existing,
        merge_fields(existing.get("fields") or [], desired_fields(account_status_required=False)),
    )
    added = [
        name
        for name in (
            field.get("name")
            for field in collection.get("fields") or []
        )
        if name not in before_names
    ]
    print("added fields:", ", ".join(str(name) for name in added) or "(none)")

    counts = backfill_users(pb)

    after_backfill = find_collection(pb, "users")
    if after_backfill is None:
        raise RuntimeError("users collection disappeared")
    collection = patch_collection(
        pb,
        after_backfill,
        merge_fields(
            after_backfill.get("fields") or [],
            desired_fields(account_status_required=True),
        ),
    )
    collection = try_relax_email_required(pb, collection)

    names = [field.get("name") for field in collection.get("fields") or []]
    print("fields after:", ", ".join(str(name) for name in names))
    print("indexes:")
    for index in collection.get("indexes") or []:
        print(" ", index)
    print(
        "backfill:",
        f"verified_host={counts['verified_host']}",
        f"names={counts['names']}",
        f"years={counts['years']}",
        f"roles={counts['roles']}",
        f"rating={counts['rating']}",
        f"account_status={counts['account_status']}",
        f"users_patched={counts['users_patched']}",
    )

    dump_path = ROOT / "pb_schema.json"
    collection_id = write_schema(pb, dump_path)
    print("wrote", dump_path.relative_to(ROOT), "users id", collection_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
