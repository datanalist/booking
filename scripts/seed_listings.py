#!/usr/bin/env python3
"""Idempotent seed for PocketBase `users` then `listings`.

Reads credentials from the environment or `.env.local`:
  POCKETBASE_URL
  POCKETBASE_SU
  POCKETBASE_SU_PASSWORD

Usage:
  python3 scripts/seed_listings.py
  python3 scripts/seed_listings.py --reset   # delete seed listings, then recreate

Seed users (password SeedPass123!):
  example@mail.com                 # Email-tab stub (scripts/seed_auth_stub.py)
  anna.ivanenko@seed.booking.local
  rail.safin@seed.booking.local
  marina.orlova@seed.booking.local
  guest.demo@seed.booking.local

Listings reference those user IDs via `host`. Published catalog is public;
draft listing is only visible to its host.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Collection names are literals. Never take them from env/CLI without this check.
_PB_COLLECTIONS = frozenset(
    {"users", "listings", "bookings", "notifications", "reviews", "_superusers"}
)
_PB_PLACEHOLDER = re.compile(r"\{:([A-Za-z_][A-Za-z0-9_]*)\}")
_PB_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def require_collection(name: str) -> str:
    """Allow only known collection names in seed-script API paths."""
    if name not in _PB_COLLECTIONS:
        raise ValueError(f"unknown PocketBase collection: {name!r}")
    return name


def pb_filter(expr: str, params: dict[str, object] | None = None) -> str:
    """Bind {:name} placeholders. Field names stay as literals in expr.

    Same idea as lib/data/pocketbase_filter.dart — do not concatenate user
    (or record) text into a PocketBase filter string.
    """
    if not params:
        return expr
    for key in params:
        if not _PB_IDENT.fullmatch(key):
            raise ValueError(f"filter param names must be identifiers: {key!r}")

    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in params:
            return match.group(0)
        return _pb_literal(params[key])

    return _PB_PLACEHOLDER.sub(repl, expr)


def _pb_literal(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    text = str(value).replace("\\", "\\\\").replace("'", "\\'")
    return f"'{text}'"


SEED_PASSWORD = "SeedPass123!"
SEED_DOMAIN = "@seed.booking.local"

# Email-tab stub (scripts/seed_auth_stub.py). Phone is for a later agent.
AUTH_STUB_USER = {
    "key": "auth_stub",
    "email": "example@mail.com",
    "name": "Example Mail",
    "first_name": "Example",
    "last_name": "Mail",
    "phone": "+79999999999",
    "roles": ["guest"],
    "verified_host": False,
}

USERS = [
    AUTH_STUB_USER,
    {
        "key": "anna",
        "email": f"anna.ivanenko{SEED_DOMAIN}",
        "name": "Анна Иваненко",
        "first_name": "Анна",
        "last_name": "Иваненко",
        "roles": ["guest", "host"],
        "verified_host": True,
        "years_hosting": 4,
    },
    {
        "key": "rail",
        "email": f"rail.safin{SEED_DOMAIN}",
        "name": "Раиль Сафин",
        "first_name": "Раиль",
        "last_name": "Сафин",
        "roles": ["guest", "host"],
        "verified_host": True,
        "years_hosting": 2,
    },
    {
        "key": "marina",
        "email": f"marina.orlova{SEED_DOMAIN}",
        "name": "Марина Орлова",
        "first_name": "Марина",
        "last_name": "Орлова",
        "roles": ["guest", "host"],
        "verified_host": True,
        "years_hosting": 1,
    },
    {
        "key": "guest",
        "email": f"guest.demo{SEED_DOMAIN}",
        "name": "Демо Гость",
        "first_name": "Демо",
        "last_name": "Гость",
        "roles": ["guest"],
        "verified_host": False,
    },
]

LISTINGS = [
    {
        "host": "anna",
        "title": "Уютная студия в центре Москвы",
        "city": "Москва",
        "address": "Москва, ул. Невская 48",
        "geo": {"lon": 37.6018, "lat": 55.7584},
        "housing_type": "Квартира",
        "placement_type": "Студия",
        "photos": [
            "images/search/studio-moscow.png",
            "images/chat/studio-moscow.jpg",
            "images/onbordins.v1/01-find-housing.png",
        ],
        "description": (
            "<p>Современное и комфортное жилье в шаговой доступности от главных "
            "достопримечательностей города. В студии есть двуспальная кровать, "
            "зона отдыха с диваном, кухня с необходимой техникой и ванная комната.</p>"
        ),
        "amenities": ["Wifi", "Телевизор", "Кондиционер", "Фен", "Утюг", "Кухня", "Стиральная машина", "Посуда"],
        "extras": ["Самостоятельное заселение"],
        "max_guests": 3,
        "pets_allowed": True,
        "cancellation_allowed": True,
        "access_info": "Код домофона 48#, ключ в сейфе.",
        "house_rules": "Не курить в квартире. Тишина после 23:00.",
        "extra_info": "Рядом метро Тверская.",
        "check_in_time": "15:00",
        "check_out_time": "11:00",
        "price_night": 3034,
        "price_14": 2800,
        "price_28": 2500,
        "status": "published",
        "rating": 4.5,
        "reviews_count": 13,
    },
    {
        "host": "anna",
        "title": "Квартира в старом городе",
        "city": "Москва",
        "address": "Москва, ул. Пятницкая 12",
        "geo": {"lon": 37.6232, "lat": 55.7536},
        "housing_type": "Квартира",
        "placement_type": "Квартира целиком",
        "photos": [
            "images/search/old-town.png",
            "images/search/studio-moscow.png",
            "images/onbordins.v1/02-book-confidently.png",
        ],
        "description": (
            "<p>Квартира в историческом центре: высокие потолки, тихий двор и всё "
            "нужное для короткой поездки. Рядом кафе, метро и прогулочные улицы.</p>"
        ),
        "amenities": ["Wifi", "Телевизор", "Кухня", "Стиральная машина", "Посуда"],
        "extras": ["Парковка"],
        "max_guests": 4,
        "pets_allowed": True,
        "cancellation_allowed": True,
        "access_info": "Встреча у подъезда.",
        "house_rules": "Можно с животными по согласованию.",
        "extra_info": "",
        "check_in_time": "14:00",
        "check_out_time": "12:00",
        "price_night": 3034,
        "price_14": 2750,
        "price_28": 2400,
        "status": "published",
        "rating": 4.7,
        "reviews_count": 29,
    },
    {
        "host": "anna",
        "title": "Частный дом в 10 км от Москвы",
        "city": "Москва",
        "address": "Москва, деревня Дубровки 5",
        "geo": {"lon": 37.6114, "lat": 55.7468},
        "housing_type": "Дом",
        "placement_type": "Дом целиком",
        "photos": [
            "images/search/country-house.png",
            "images/onbordins.v1/03-travel-without-borders.png",
            "images/search/studio-moscow.png",
        ],
        "description": (
            "<p>Частный дом за городом: сад, мангал и тишина. Подходит для семьи "
            "или компании, которая хочет отдохнуть рядом с Москвой.</p>"
        ),
        "amenities": ["Wifi", "Кухня", "Обогреватель"],
        "extras": ["Камин", "Парковка", "Бассейн", "Сауна"],
        "max_guests": 8,
        "pets_allowed": True,
        "cancellation_allowed": True,
        "access_info": "Калитка по коду из сообщения.",
        "house_rules": "Мангал только на площадке.",
        "extra_info": "Дрова для камина в сарае.",
        "check_in_time": "16:00",
        "check_out_time": "12:00",
        "price_night": 3294,
        "price_14": 3000,
        "price_28": 2700,
        "status": "published",
        "rating": 4.5,
        "reviews_count": 13,
    },
    {
        "host": "rail",
        "title": "Лофт у Казанского кремля",
        "city": "Казань",
        "address": "Казань, ул. Баумана 15",
        "geo": {"lon": 49.1089, "lat": 55.7963},
        "housing_type": "Квартира",
        "placement_type": "Лофт",
        "photos": [
            "images/search/kazan-loft.png",
            "images/chat/minsk-loft.jpg",
            "images/onbordins.v1/01-find-housing.png",
        ],
        "description": (
            "<p>Светлый лофт в пешей доступности от кремля. Высокие окна, рабочее "
            "место и кухня, если захотите готовить сами.</p>"
        ),
        "amenities": ["Wifi", "Телевизор", "Кондиционер", "Кухня"],
        "extras": ["Завтраки", "Спортзал"],
        "max_guests": 2,
        "pets_allowed": True,
        "cancellation_allowed": True,
        "access_info": "Самостоятельное заселение, ключ в боксе.",
        "house_rules": "Не шуметь после 22:00.",
        "extra_info": "",
        "check_in_time": "15:00",
        "check_out_time": "11:00",
        "price_night": 3100,
        "price_14": 2900,
        "price_28": 2600,
        "status": "published",
        "rating": 4.8,
        "reviews_count": 21,
    },
    {
        "host": "marina",
        "title": "Комната у Невского проспекта",
        "city": "Санкт-Петербург",
        "address": "Санкт-Петербург, Невский проспект 28",
        "geo": {"lon": 30.3351, "lat": 59.9343},
        "housing_type": "Комната",
        "placement_type": "Отдельная комната",
        "photos": [
            "images/search/spb-room.png",
            "images/chat/minsk-flat.jpg",
            "images/onbordins.v1/02-book-confidently.png",
        ],
        "description": (
            "<p>Отдельная комната в квартире у Невского. Рядом метро, магазины и "
            "основные маршруты по центру.</p>"
        ),
        "amenities": ["Wifi", "Фен", "Утюг"],
        "extras": [],
        "max_guests": 2,
        "pets_allowed": True,
        "cancellation_allowed": True,
        "access_info": "Хозяева встретят в подъезде.",
        "house_rules": "Общая кухня и ванная.",
        "extra_info": "",
        "check_in_time": "13:00",
        "check_out_time": "11:00",
        "price_night": 2300,
        "price_14": 2100,
        "price_28": 1900,
        "status": "published",
        "rating": 4.3,
        "reviews_count": 8,
    },
    {
        "host": "anna",
        "title": "Черновик: апартаменты на модерации",
        "city": "Москва",
        "address": "Москва, ул. Арбат 10",
        "geo": {"lon": 37.591, "lat": 55.749},
        "housing_type": "Квартира",
        "placement_type": "Апартаменты",
        "photos": ["images/search/old-town.png"],
        "description": "<p>Черновик для проверки фильтра status=published.</p>",
        "amenities": ["Wifi"],
        "extras": [],
        "max_guests": 2,
        "pets_allowed": True,
        "cancellation_allowed": True,
        "access_info": "",
        "house_rules": "",
        "extra_info": "",
        "check_in_time": "15:00",
        "check_out_time": "11:00",
        "price_night": 5000,
        "price_14": 4500,
        "price_28": 4000,
        "status": "draft",
        "rating": 0,
        "reviews_count": 0,
    },
]


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


class PocketBase:
    def __init__(self, base: str, token: str = "") -> None:
        self.base = base.rstrip("/")
        self.token = token

    def _headers(self, extra: dict[str, str] | None = None) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.token:
            headers["Authorization"] = self.token
        if extra:
            headers.update(extra)
        return headers

    def request(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, str] | None = None,
        json_body: dict | None = None,
        data: bytes | None = None,
        content_type: str | None = None,
    ) -> dict:
        url = f"{self.base}{path}"
        if query:
            url = f"{url}?{urllib.parse.urlencode(query)}"
        headers = self._headers()
        body = data
        if json_body is not None:
            body = json.dumps(json_body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        elif content_type:
            headers["Content-Type"] = content_type
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {path} -> {exc.code}: {detail}") from exc
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def auth_superuser(self, identity: str, password: str) -> None:
        candidates = [identity]
        if identity.endswith("."):
            candidates.append(identity[:-1])
        last_error = None
        for item in candidates:
            try:
                data = self.request(
                    "POST",
                    "/api/collections/_superusers/auth-with-password",
                    json_body={"identity": item, "password": password},
                )
                self.token = data["token"]
                return
            except RuntimeError as exc:
                last_error = exc
        raise RuntimeError(f"superuser auth failed: {last_error}")

    def _records_path(self, collection: str, record_id: str | None = None) -> str:
        name = urllib.parse.quote(require_collection(collection), safe="")
        path = f"/api/collections/{name}/records"
        if record_id:
            path = f"{path}/{urllib.parse.quote(record_id, safe='')}"
        return path

    def first(self, collection: str, flt: str) -> dict | None:
        data = self.request(
            "GET",
            self._records_path(collection),
            query={"page": "1", "perPage": "1", "filter": flt},
        )
        items = data.get("items") or []
        return items[0] if items else None

    def delete(self, collection: str, record_id: str) -> None:
        self.request("DELETE", self._records_path(collection, record_id))

    def create(self, collection: str, body: dict) -> dict:
        return self.request(
            "POST",
            self._records_path(collection),
            json_body=body,
        )

    def update(self, collection: str, record_id: str, body: dict) -> dict:
        return self.request(
            "PATCH",
            self._records_path(collection, record_id),
            json_body=body,
        )

    def upsert_multipart(
        self,
        collection: str,
        record_id: str | None,
        fields: dict[str, str],
        files: list[tuple[str, Path]],
    ) -> dict:
        boundary = "----BookingSeedBoundary"
        chunks: list[bytes] = []

        def add_field(name: str, value: str) -> None:
            chunks.append(f"--{boundary}\r\n".encode())
            chunks.append(
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
            )
            chunks.append(value.encode("utf-8"))
            chunks.append(b"\r\n")

        for key, value in fields.items():
            add_field(key, value)
        for field, path in files:
            mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
            chunks.append(f"--{boundary}\r\n".encode())
            chunks.append(
                (
                    f'Content-Disposition: form-data; name="{field}"; '
                    f'filename="{path.name}"\r\n'
                ).encode()
            )
            chunks.append(f"Content-Type: {mime}\r\n\r\n".encode())
            chunks.append(path.read_bytes())
            chunks.append(b"\r\n")
        chunks.append(f"--{boundary}--\r\n".encode())
        body = b"".join(chunks)
        method = "PATCH" if record_id else "POST"
        path = self._records_path(collection, record_id)
        return self.request(
            method,
            path,
            data=body,
            content_type=f"multipart/form-data; boundary={boundary}",
        )


def listing_fields(item: dict, host_id: str) -> dict[str, str]:
    return {
        "host": host_id,
        "title": item["title"],
        "city": item["city"],
        "address": item["address"],
        "geo": json.dumps(item["geo"], ensure_ascii=False),
        "housing_type": item["housing_type"],
        "placement_type": item["placement_type"],
        "description": item["description"],
        "amenities": json.dumps(item["amenities"], ensure_ascii=False),
        "extras": json.dumps(item["extras"], ensure_ascii=False),
        "max_guests": str(item["max_guests"]),
        "pets_allowed": "true" if item["pets_allowed"] else "false",
        "cancellation_allowed": "true" if item["cancellation_allowed"] else "false",
        "access_info": item["access_info"],
        "house_rules": item["house_rules"],
        "extra_info": item["extra_info"],
        "check_in_time": item["check_in_time"],
        "check_out_time": item["check_out_time"],
        "price_night": str(item["price_night"]),
        "price_14": str(item["price_14"]),
        "price_28": str(item["price_28"]),
        "status": item["status"],
    }


def ensure_user_view_rule(pb: PocketBase) -> None:
    """Host cards on listings need public view of a single user (list stays private)."""
    collection = pb.request("GET", "/api/collections/users")
    if collection.get("viewRule") == "":
        return
    pb.request(
        "PATCH",
        "/api/collections/users",
        json_body={"viewRule": ""},
    )
    print("updated users.viewRule so listing.host expand works for guests")


def users_field_names(pb: PocketBase) -> set[str]:
    collection = pb.request("GET", "/api/collections/users")
    return {str(field.get("name")) for field in collection.get("fields") or []}


def users_has_phone(pb: PocketBase) -> bool:
    return "phone" in users_field_names(pb)


def apply_user_profile(body: dict, user: dict, field_names: set[str]) -> dict:
    """Write domain host/profile fields when the collection already has them.

    `verified` (email OTP) stays a separate caller concern from `verified_host`.
    """
    first = user.get("first_name")
    last = user.get("last_name")
    if not first and not last and user.get("name"):
        parts = str(user["name"]).strip().split(None, 1)
        first = parts[0] if parts else ""
        last = parts[1] if len(parts) > 1 else ""
    mapping = {
        "first_name": first,
        "last_name": last,
        "roles": user.get("roles"),
        "verified_host": user.get("verified_host"),
        "years_hosting": user.get("years_hosting"),
    }
    for key, value in mapping.items():
        if value is None or key not in field_names:
            continue
        body[key] = value
    return body


def seed_auth_stub_user(pb: PocketBase) -> dict:
    """Create or refresh example@mail.com used by the Email auth tab."""
    field_names = users_field_names(pb)
    existing = pb.first(
        "users",
        pb_filter("email = {:email}", {"email": AUTH_STUB_USER["email"]}),
    )
    body = {
        "email": AUTH_STUB_USER["email"],
        "emailVisibility": True,
        "name": AUTH_STUB_USER["name"],
        "password": SEED_PASSWORD,
        "passwordConfirm": SEED_PASSWORD,
        "verified": True,
    }
    apply_user_profile(body, AUTH_STUB_USER, field_names)
    if "phone" in field_names:
        body["phone"] = AUTH_STUB_USER["phone"]
    if existing:
        update = {
            "name": AUTH_STUB_USER["name"],
            "verified": True,
            "emailVisibility": True,
            "password": SEED_PASSWORD,
            "passwordConfirm": SEED_PASSWORD,
        }
        apply_user_profile(update, AUTH_STUB_USER, field_names)
        if "phone" in field_names:
            update["phone"] = AUTH_STUB_USER["phone"]
        record = pb.update("users", existing["id"], update)
        print(f"auth stub exists {AUTH_STUB_USER['email']} -> {record['id']}")
        return record
    record = pb.create("users", body)
    print(f"auth stub created {AUTH_STUB_USER['email']} -> {record['id']}")
    return record


def seed_users(pb: PocketBase) -> dict[str, str]:
    ids: dict[str, str] = {}
    field_names = users_field_names(pb)
    for user in USERS:
        existing = pb.first(
            "users",
            pb_filter("email = {:email}", {"email": user["email"]}),
        )
        body = {
            "email": user["email"],
            "emailVisibility": False,
            "name": user["name"],
            "password": SEED_PASSWORD,
            "passwordConfirm": SEED_PASSWORD,
            "verified": True,
        }
        apply_user_profile(body, user, field_names)
        if "phone" in field_names and user.get("phone"):
            body["phone"] = user["phone"]
            body["emailVisibility"] = True
        if existing:
            update = {
                "name": user["name"],
                "verified": True,
                "emailVisibility": body["emailVisibility"],
                "password": SEED_PASSWORD,
                "passwordConfirm": SEED_PASSWORD,
            }
            apply_user_profile(update, user, field_names)
            if "phone" in field_names and user.get("phone"):
                update["phone"] = user["phone"]
            record = pb.update("users", existing["id"], update)
            print(f"user exists {user['email']} -> {record['id']}")
        else:
            record = pb.create("users", body)
            print(f"user created {user['email']} -> {record['id']}")
        ids[user["key"]] = record["id"]
    return ids


def seed_listings(pb: PocketBase, user_ids: dict[str, str], reset: bool) -> None:
    titles = [item["title"] for item in LISTINGS]
    if reset:
        for title in titles:
            while True:
                found = pb.first(
                    "listings",
                    pb_filter("title = {:title}", {"title": title}),
                )
                if not found:
                    break
                pb.delete("listings", found["id"])
                print(f"deleted listing {title} ({found['id']})")

    for item in LISTINGS:
        host_id = user_ids[item["host"]]
        existing = pb.first(
            "listings",
            pb_filter(
                "title = {:title} && host = {:host}",
                {"title": item["title"], "host": host_id},
            ),
        )
        fields = listing_fields(item, host_id)
        files = [("photos", ROOT / rel) for rel in item["photos"]]
        missing = [str(path) for _, path in files if not path.exists()]
        if missing:
            raise FileNotFoundError("missing photo files:\n" + "\n".join(missing))
        upload = not existing or reset or not existing.get("photos")
        if existing and not upload:
            record = pb.update("listings", existing["id"], {k: item[k] if k in item else v for k, v in {
                "host": host_id,
                "title": item["title"],
                "city": item["city"],
                "address": item["address"],
                "geo": item["geo"],
                "housing_type": item["housing_type"],
                "placement_type": item["placement_type"],
                "description": item["description"],
                "amenities": item["amenities"],
                "extras": item["extras"],
                "max_guests": item["max_guests"],
                "pets_allowed": item["pets_allowed"],
                "cancellation_allowed": item["cancellation_allowed"],
                "access_info": item["access_info"],
                "house_rules": item["house_rules"],
                "extra_info": item["extra_info"],
                "check_in_time": item["check_in_time"],
                "check_out_time": item["check_out_time"],
                "price_night": item["price_night"],
                "price_14": item["price_14"],
                "price_28": item["price_28"],
                "status": item["status"],
            }.items()})
            print(f"listing updated {item['title']} -> {record['id']}")
            continue
        record = pb.upsert_multipart(
            "listings",
            existing["id"] if existing else None,
            fields,
            files,
        )
        action = "updated" if existing else "created"
        print(f"listing {action} {item['title']} -> {record['id']} host={host_id}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Delete seed listings by title, then recreate with photos",
    )
    args = parser.parse_args()

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
    ensure_user_view_rule(pb)
    user_ids = seed_users(pb)
    seed_listings(pb, user_ids, reset=args.reset)
    published = pb.request(
        "GET",
        "/api/collections/listings/records",
        query={"filter": 'status = "published"', "expand": "host", "perPage": "50"},
    )
    print(f"published listings: {published.get('totalItems', len(published.get('items') or []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
