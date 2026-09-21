#!/usr/bin/env python3
"""Create or update PocketBase collection `messages`.

Fields follow docs/pocketbase-schema.md. Access is limited to chat participants
via relation filters on `chat.guest` / `chat.host` / `chat.staff`.

Usage:
  python3 scripts/ensure_messages.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

PARTICIPANT = (
    "@request.auth.id != '' && "
    "(chat.guest = @request.auth.id || chat.host = @request.auth.id || "
    "chat.staff = @request.auth.id)"
)
LIST_VIEW_RULE = PARTICIPANT
CREATE_RULE = (
    "@request.auth.id != '' && "
    "@request.body.author = @request.auth.id && "
    "(@request.body.chat.guest = @request.auth.id || "
    "@request.body.chat.host = @request.auth.id || "
    "@request.body.chat.staff = @request.auth.id)"
)
UPDATE_RULE = (
    "author = @request.auth.id && "
    "(@request.body.author:isset = false || @request.body.author = author) && "
    "(@request.body.chat:isset = false || @request.body.chat = chat)"
)
INDEXES = [
    "CREATE INDEX `idx_messages_chat` ON `messages` (`chat`)",
    "CREATE INDEX `idx_messages_author` ON `messages` (`author`)",
    "CREATE INDEX `idx_messages_chat_created` ON `messages` (`chat`, `created`)",
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


def _file(name: str, max_select: int = 99) -> dict:
    return {
        "name": name,
        "type": "file",
        "required": False,
        "maxSelect": max_select,
        "maxSize": 0,
        "mimeTypes": [],
        "thumbs": [],
        "protected": False,
    }


def custom_fields(chats_id: str, users_id: str) -> list[dict]:
    return [
        _relation("chat", chats_id, True),
        _relation("author", users_id, True),
        _text("text"),
        _file("images"),
        _file("files"),
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


def upsert_messages(pb: PocketBase) -> dict:
    chats = find_collection(pb, "chats")
    users = find_collection(pb, "users")
    if not chats or not users:
        raise RuntimeError("Need existing `chats` and `users` collections")
    desired = custom_fields(chats["id"], users["id"])
    payload = {
        "name": "messages",
        "type": "base",
        "listRule": LIST_VIEW_RULE,
        "viewRule": LIST_VIEW_RULE,
        "createRule": CREATE_RULE,
        "updateRule": UPDATE_RULE,
        "deleteRule": None,
        "indexes": INDEXES,
        "fields": desired,
    }
    existing = find_collection(pb, "messages")
    if existing is None:
        created = pb.request("POST", "/api/collections", json_body=payload)
        print("created collection messages", created.get("id"))
        return created
    payload["fields"] = merge_fields(existing.get("fields") or [], desired)
    updated = pb.request(
        "PATCH",
        f"/api/collections/{existing['id']}",
        json_body=payload,
    )
    print("updated collection messages", updated.get("id"))
    return updated


def write_schema_dump(collection: dict) -> None:
    dump_path = ROOT / "pb_schema.json"
    schema = json.loads(dump_path.read_text(encoding="utf-8"))
    replaced = False
    for i, item in enumerate(schema):
        if item.get("name") == "messages":
            schema[i] = collection
            replaced = True
            break
    if not replaced:
        insert_at = next(
            (i + 1 for i, item in enumerate(schema) if item.get("name") == "chats"),
            len(schema),
        )
        schema.insert(insert_at, collection)
    dump_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        "wrote",
        dump_path.relative_to(ROOT),
        "messages id",
        collection.get("id"),
    )


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
    collection = upsert_messages(pb)
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
