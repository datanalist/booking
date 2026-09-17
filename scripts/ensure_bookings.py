#!/usr/bin/env python3
"""Create or update PocketBase collection `bookings`.

Fields, statuses and money names follow docs/pocketbase-schema.md.
Reads POCKETBASE_URL / POCKETBASE_SU / POCKETBASE_SU_PASSWORD from env or `.env.local`.

Usage:
  python3 scripts/ensure_bookings.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

STATUS_VALUES = [
    "pending_host",
    "awaiting_prepayment",
    "confirmed",
    "completed",
    "cancel_requested",
    "change_requested",
    "cancelled",
]
CANCEL_REASON_VALUES = [
    "guest",
    "host",
    "host_timeout",
    "prepay_timeout",
]

LIST_VIEW_RULE = (
    "@request.auth.id != '' && "
    "(guest = @request.auth.id || host = @request.auth.id)"
)
CREATE_RULE = (
    "@request.auth.id != '' && "
    "@request.body.guest = @request.auth.id && "
    "@request.body.status = 'pending_host'"
)
UPDATE_RULE = (
    "(guest = @request.auth.id || host = @request.auth.id) && "
    "(@request.body.guest:isset = false || @request.body.guest = guest) && "
    "(@request.body.host:isset = false || @request.body.host = host) && "
    "(@request.body.listing:isset = false || @request.body.listing = listing)"
)
INDEXES = [
    "CREATE INDEX `idx_bookings_listing` ON `bookings` (`listing`)",
    "CREATE INDEX `idx_bookings_guest` ON `bookings` (`guest`)",
    "CREATE INDEX `idx_bookings_host` ON `bookings` (`host`)",
    "CREATE INDEX `idx_bookings_status` ON `bookings` (`status`)",
    "CREATE INDEX `idx_bookings_listing_check_in` ON `bookings` (`listing`, `check_in`)",
]


def _relation(name: str, collection_id: str, required: bool = True) -> dict:
    return {
        "name": name,
        "type": "relation",
        "required": required,
        "collectionId": collection_id,
        "cascadeDelete": False,
        "maxSelect": 1,
        "minSelect": 0,
    }


def _date(name: str, required: bool = False) -> dict:
    return {"name": name, "type": "date", "required": required}


def _number(name: str, required: bool = False) -> dict:
    return {
        "name": name,
        "type": "number",
        "required": required,
        "onlyInt": False,
    }


def _text(name: str, required: bool = False) -> dict:
    return {"name": name, "type": "text", "required": required}


def _select(name: str, values: list[str], required: bool = False) -> dict:
    return {
        "name": name,
        "type": "select",
        "required": required,
        "maxSelect": 1,
        "values": values,
    }


def custom_fields(listings_id: str, users_id: str) -> list[dict]:
    return [
        _relation("listing", listings_id, True),
        _relation("guest", users_id, True),
        _relation("host", users_id, True),
        _date("check_in", True),
        _date("check_out", True),
        _number("adults"),
        _number("children"),
        _number("pets"),
        _text("guest_note"),
        _number("total"),
        _number("prepay"),
        _number("remainder"),
        _number("commission"),
        _number("host_amount"),
        _date("prepaid_at"),
        _select("status", STATUS_VALUES, True),
        _select("cancel_reason", CANCEL_REASON_VALUES),
        _date("host_respond_until"),
        _date("prepay_until"),
        _date("requested_check_in"),
        _date("requested_check_out"),
        {
            "name": "created",
            "type": "autodate",
            "onCreate": True,
            "onUpdate": False,
        },
        {
            "name": "updated",
            "type": "autodate",
            "onCreate": True,
            "onUpdate": True,
        },
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


def upsert_bookings(pb: PocketBase) -> dict:
    listings = find_collection(pb, "listings")
    users = find_collection(pb, "users")
    if not listings or not users:
        raise RuntimeError("Need existing `listings` and `users` collections")
    desired = custom_fields(listings["id"], users["id"])
    payload = {
        "name": "bookings",
        "type": "base",
        "listRule": LIST_VIEW_RULE,
        "viewRule": LIST_VIEW_RULE,
        "createRule": CREATE_RULE,
        "updateRule": UPDATE_RULE,
        "deleteRule": None,
        "indexes": INDEXES,
        "fields": desired,
    }
    existing = find_collection(pb, "bookings")
    if existing is None:
        created = pb.request("POST", "/api/collections", json_body=payload)
        print("created collection bookings", created.get("id"))
        return created
    payload["fields"] = merge_fields(existing.get("fields") or [], desired)
    updated = pb.request(
        "PATCH",
        f"/api/collections/{existing['id']}",
        json_body=payload,
    )
    print("updated collection bookings", updated.get("id"))
    return updated


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
    collection = upsert_bookings(pb)
    names = [field.get("name") for field in collection.get("fields") or []]
    print("fields:", ", ".join(str(name) for name in names))
    print("listRule:", collection.get("listRule"))
    print("createRule:", collection.get("createRule"))
    print("updateRule:", collection.get("updateRule"))
    print("deleteRule:", collection.get("deleteRule"))
    print("indexes:")
    for index in collection.get("indexes") or []:
        print(" ", index)
    dump_path = ROOT / "pb_schema.json"
    schema = json.loads(dump_path.read_text(encoding="utf-8"))
    replaced = False
    for i, item in enumerate(schema):
        if item.get("name") == "bookings":
            schema[i] = collection
            replaced = True
            break
    if not replaced:
        insert_at = next(
            (i + 1 for i, item in enumerate(schema) if item.get("name") == "listings"),
            len(schema),
        )
        schema.insert(insert_at, collection)
    dump_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote", dump_path.relative_to(ROOT), "bookings id", collection.get("id"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
