#!/usr/bin/env python3
"""Create or update PocketBase collection `favorites`.

Fields follow docs/pocketbase-schema.md:
  user → users, listing → listings, unique (user, listing).

A guest lists, creates and deletes only their own rows.

Usage:
  python3 scripts/ensure_favorites.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

OWNED = "user = @request.auth.id"
CREATE_RULE = (
    "@request.auth.id != '' && @request.body.user = @request.auth.id"
)
INDEXES = [
    "CREATE UNIQUE INDEX `idx_favorites_user_listing` "
    "ON `favorites` (`user`, `listing`)",
]


def _relation(name: str, collection_id: str) -> dict:
    return {
        "name": name,
        "type": "relation",
        "required": True,
        "collectionId": collection_id,
        "cascadeDelete": False,
        "maxSelect": 1,
        "minSelect": 0,
    }


def custom_fields(users_id: str, listings_id: str) -> list[dict]:
    return [
        _relation("user", users_id),
        _relation("listing", listings_id),
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


def upsert_favorites(pb: PocketBase) -> dict:
    users = find_collection(pb, "users")
    listings = find_collection(pb, "listings")
    if not users or not listings:
        raise RuntimeError("Need existing `users` and `listings` collections")
    desired = custom_fields(users["id"], listings["id"])
    payload = {
        "name": "favorites",
        "type": "base",
        "listRule": OWNED,
        "viewRule": OWNED,
        "createRule": CREATE_RULE,
        "updateRule": None,
        "deleteRule": OWNED,
        "indexes": INDEXES,
        "fields": desired,
    }
    existing = find_collection(pb, "favorites")
    if existing is None:
        created = pb.request("POST", "/api/collections", json_body=payload)
        print("created collection favorites", created.get("id"))
        return created
    payload["fields"] = merge_fields(existing.get("fields") or [], desired)
    updated = pb.request(
        "PATCH",
        f"/api/collections/{existing['id']}",
        json_body=payload,
    )
    print("updated collection favorites", updated.get("id"))
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
    collection = upsert_favorites(pb)
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
        if item.get("name") == "favorites":
            schema[i] = collection
            replaced = True
            break
    if not replaced:
        insert_at = next(
            (
                i + 1
                for i, item in enumerate(schema)
                if item.get("name") == "listings"
            ),
            len(schema),
        )
        schema.insert(insert_at, collection)
    dump_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote", dump_path.relative_to(ROOT), "favorites id", collection.get("id"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
