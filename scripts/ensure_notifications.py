#!/usr/bin/env python3
"""Create or update PocketBase collection `notifications`.

Fields follow docs/pocketbase-schema.md (no type enum).
Client create is allowed for the signed-in user, same idea as bookings.

Usage:
  python3 scripts/ensure_notifications.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

OWNED = "@request.auth.id != '' && user = @request.auth.id"
CREATE_RULE = (
    "@request.auth.id != '' && "
    "@request.body.user = @request.auth.id"
)
UPDATE_RULE = (
    "user = @request.auth.id && "
    "(@request.body.user:isset = false || @request.body.user = user)"
)
INDEXES = [
    "CREATE INDEX `idx_notifications_user` ON `notifications` (`user`)",
    "CREATE INDEX `idx_notifications_user_read` ON `notifications` (`user`, `read`)",
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


def custom_fields(
    users_id: str,
    bookings_id: str | None,
    listings_id: str | None,
    chats_id: str | None,
) -> list[dict]:
    fields = [
        _relation("user", users_id, True),
        _text("title", True),
        _text("body"),
        {"name": "read", "type": "bool", "required": False},
    ]
    if bookings_id:
        fields.append(_relation("booking", bookings_id, False))
    if listings_id:
        fields.append(_relation("listing", listings_id, False))
    if chats_id:
        fields.append(_relation("chat", chats_id, False))
    fields.extend(
        [
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
    )
    return fields


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


def upsert_notifications(pb: PocketBase) -> dict:
    users = find_collection(pb, "users")
    if not users:
        raise RuntimeError("Need existing `users` collection")
    bookings = find_collection(pb, "bookings")
    listings = find_collection(pb, "listings")
    chats = find_collection(pb, "chats")
    desired = custom_fields(
        users["id"],
        bookings["id"] if bookings else None,
        listings["id"] if listings else None,
        chats["id"] if chats else None,
    )
    payload = {
        "name": "notifications",
        "type": "base",
        "listRule": OWNED,
        "viewRule": OWNED,
        "createRule": CREATE_RULE,
        "updateRule": UPDATE_RULE,
        "deleteRule": None,
        "indexes": INDEXES,
        "fields": desired,
    }
    existing = find_collection(pb, "notifications")
    if existing is None:
        created = pb.request("POST", "/api/collections", json_body=payload)
        print("created collection notifications", created.get("id"))
        return created
    payload["fields"] = merge_fields(existing.get("fields") or [], desired)
    updated = pb.request(
        "PATCH",
        f"/api/collections/{existing['id']}",
        json_body=payload,
    )
    print("updated collection notifications", updated.get("id"))
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
    collection = upsert_notifications(pb)
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
        if item.get("name") == "notifications":
            schema[i] = collection
            replaced = True
            break
    if not replaced:
        insert_at = next(
            (i + 1 for i, item in enumerate(schema) if item.get("name") == "bookings"),
            len(schema),
        )
        schema.insert(insert_at, collection)
    dump_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote", dump_path.relative_to(ROOT), "notifications id", collection.get("id"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
