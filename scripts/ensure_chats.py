#!/usr/bin/env python3
"""Create or update PocketBase collection `chats`.

Fields follow docs/pocketbase-schema.md.
Unique (listing, guest) for kind=listing is enforced by pb_hooks/chats_unique.pb.js.

Usage:
  python3 scripts/ensure_chats.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

KIND_VALUES = ["listing", "support"]

PARTICIPANT = (
    "@request.auth.id != '' && "
    "(guest = @request.auth.id || host = @request.auth.id || "
    "staff = @request.auth.id)"
)
LIST_VIEW_RULE = PARTICIPANT
CREATE_RULE = (
    "@request.auth.id != '' && "
    "@request.body.guest = @request.auth.id && "
    "(@request.body.kind = 'listing' || @request.body.kind = 'support')"
)
UPDATE_RULE = (
    PARTICIPANT
    + " && "
    "(@request.body.guest:isset = false || @request.body.guest = guest) && "
    "(@request.body.host:isset = false || @request.body.host = host) && "
    "(@request.body.staff:isset = false || @request.body.staff = staff) && "
    "(@request.body.listing:isset = false || @request.body.listing = listing) && "
    "(@request.body.kind:isset = false || @request.body.kind = kind)"
)
INDEXES = [
    "CREATE INDEX `idx_chats_guest` ON `chats` (`guest`)",
    "CREATE INDEX `idx_chats_host` ON `chats` (`host`)",
    "CREATE INDEX `idx_chats_listing` ON `chats` (`listing`)",
    "CREATE INDEX `idx_chats_last_message_at` ON `chats` (`last_message_at`)",
]


def _relation(name: str, collection_id: str, required: bool = False) -> dict:
    return {
        "name": name,
        "type": "relation",
        "required": required,
        "collectionId": collection_id,
        "cascadeDelete": False,
        "maxSelect": 1,
        "minSelect": 0,
    }


def _text(name: str, required: bool = False) -> dict:
    return {"name": name, "type": "text", "required": required}


def _date(name: str, required: bool = False) -> dict:
    return {"name": name, "type": "date", "required": required}


def _select(name: str, values: list[str], required: bool = False) -> dict:
    return {
        "name": name,
        "type": "select",
        "required": required,
        "maxSelect": 1,
        "values": values,
    }


def custom_fields(
    users_id: str,
    listings_id: str,
    bookings_id: str,
) -> list[dict]:
    return [
        _select("kind", KIND_VALUES, True),
        _relation("listing", listings_id, False),
        _relation("booking", bookings_id, False),
        _relation("guest", users_id, True),
        _relation("host", users_id, False),
        _relation("staff", users_id, False),
        _text("last_message"),
        _date("last_message_at"),
        _date("guest_last_read"),
        _date("host_last_read"),
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


def upsert_chats(pb: PocketBase) -> dict:
    users = find_collection(pb, "users")
    listings = find_collection(pb, "listings")
    bookings = find_collection(pb, "bookings")
    if not users or not listings or not bookings:
        raise RuntimeError(
            "Need existing `users`, `listings` and `bookings` collections"
        )
    desired = custom_fields(users["id"], listings["id"], bookings["id"])
    payload = {
        "name": "chats",
        "type": "base",
        "listRule": LIST_VIEW_RULE,
        "viewRule": LIST_VIEW_RULE,
        "createRule": CREATE_RULE,
        "updateRule": UPDATE_RULE,
        "deleteRule": None,
        "indexes": INDEXES,
        "fields": desired,
    }
    existing = find_collection(pb, "chats")
    if existing is None:
        created = pb.request("POST", "/api/collections", json_body=payload)
        print("created collection chats", created.get("id"))
        return created
    payload["fields"] = merge_fields(existing.get("fields") or [], desired)
    updated = pb.request(
        "PATCH",
        f"/api/collections/{existing['id']}",
        json_body=payload,
    )
    print("updated collection chats", updated.get("id"))
    return updated


def write_schema_dump(collection: dict) -> None:
    dump_path = ROOT / "pb_schema.json"
    schema = json.loads(dump_path.read_text(encoding="utf-8"))
    replaced = False
    for i, item in enumerate(schema):
        if item.get("name") == "chats":
            schema[i] = collection
            replaced = True
            break
    if not replaced:
        insert_at = next(
            (i + 1 for i, item in enumerate(schema) if item.get("name") == "reviews"),
            len(schema),
        )
        schema.insert(insert_at, collection)
    dump_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote", dump_path.relative_to(ROOT), "chats id", collection.get("id"))


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
    collection = upsert_chats(pb)
    names = [field.get("name") for field in collection.get("fields") or []]
    print("fields:", ", ".join(str(name) for name in names))
    print("listRule:", collection.get("listRule"))
    print("createRule:", collection.get("createRule"))
    print("updateRule:", collection.get("updateRule"))
    print("deleteRule:", collection.get("deleteRule"))
    print("indexes:")
    for index in collection.get("indexes") or []:
        print(" ", index)
    write_schema_dump(collection)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
