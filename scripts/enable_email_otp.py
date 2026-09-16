#!/usr/bin/env python3
"""Enable 5-digit email OTP on PocketBase `users` and report SMTP status.

Reads POCKETBASE_URL / POCKETBASE_SU / POCKETBASE_SU_PASSWORD from env or `.env.local`.
Optional SMTP_* keys are applied only if present (never printed).
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import PocketBase, env, load_dotenv  # noqa: E402

OTP_LENGTH = 5
OTP_DURATION = 600
OTP_TEMPLATE = {
    "subject": "Код подтверждения GlobalStay",
    "body": (
        "<p>Ваш код подтверждения: <strong>{OTP}</strong></p>"
        "<p>Код действует несколько минут. Если вы не запрашивали вход, "
        "просто проигнорируйте это письмо.</p>"
    ),
}


def _ensure_otp(collection: dict) -> dict:
    otp = dict(collection.get("otp") or {})
    otp["enabled"] = True
    otp["duration"] = OTP_DURATION
    otp["length"] = OTP_LENGTH
    template = dict(otp.get("emailTemplate") or {})
    template.update(OTP_TEMPLATE)
    otp["emailTemplate"] = template
    return otp


def _relax_required_for_otp(fields: list[dict]) -> list[dict]:
    """OTP auto-create only sets email; extra required fields reject new users."""
    out = []
    names = {field.get("name") for field in fields}
    extras = []
    if "first_name" not in names:
        extras.append({"name": "first_name", "type": "text", "required": False})
    if "last_name" not in names:
        extras.append({"name": "last_name", "type": "text", "required": False})
    if "birthdate" not in names:
        extras.append({"name": "birthdate", "type": "date", "required": False})
    if "phone" not in names:
        extras.append({"name": "phone", "type": "text", "required": False})
    if "limited_browse" not in names:
        extras.append(
            {"name": "limited_browse", "type": "bool", "required": False},
        )
    for field in fields:
        item = dict(field)
        if item.get("name") in {"roles", "name", "first_name", "last_name"}:
            item["required"] = False
        out.append(item)
    out.extend(extras)
    if extras:
        print("adding fields:", ", ".join(str(item["name"]) for item in extras))
    return out


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
    pb.auth_superuser(identity, password)
    collection = pb.request("GET", "/api/collections/users")
    fields = collection.get("fields") or []
    names = [field.get("name") for field in fields]
    print("users fields:", ", ".join(str(name) for name in names))
    print("createRule:", repr(collection.get("createRule")))
    print("otp.enabled before:", (collection.get("otp") or {}).get("enabled"))

    patch: dict = {
        "otp": _ensure_otp(collection),
        "fields": _relax_required_for_otp(fields),
    }
    if collection.get("createRule") is None:
        patch["createRule"] = ""
        print("createRule was admin-only; opening it for OTP signup")

    pb.request("PATCH", "/api/collections/users", json_body=patch)
    after = pb.request("GET", "/api/collections/users")
    otp = after.get("otp") or {}
    print(
        "otp.enabled:",
        otp.get("enabled"),
        "length:",
        otp.get("length"),
        "duration:",
        otp.get("duration"),
    )
    print("createRule after:", repr(after.get("createRule")))

    settings = pb.request("GET", "/api/settings")
    smtp = settings.get("smtp") or {}
    print("smtp.enabled:", bool(smtp.get("enabled")), "host_set:", bool(smtp.get("host")))

    smtp_host = env("SMTP_HOST")
    smtp_user = env("SMTP_USERNAME")
    smtp_password = env("SMTP_PASSWORD")
    smtp_port = env("SMTP_PORT")
    if smtp_host and smtp_user and smtp_password:
        pb.request(
            "PATCH",
            "/api/settings",
            json_body={
                "smtp": {
                    "enabled": True,
                    "host": smtp_host,
                    "port": int(smtp_port or "587"),
                    "username": smtp_user,
                    "password": smtp_password,
                    "tls": env("SMTP_TLS", "true").lower() != "false",
                    "authMethod": env("SMTP_AUTH_METHOD", "PLAIN"),
                },
                "meta": {
                    "senderName": env("SMTP_SENDER_NAME", "GlobalStay"),
                    "senderAddress": env("SMTP_SENDER", smtp_user),
                },
            },
        )
        print("smtp: updated from SMTP_* env")
    elif not smtp.get("enabled"):
        print(
            "smtp: DISABLED — email codes will not send until SMTP is configured",
            file=sys.stderr,
        )
        return 3
    print("deploy pb_hooks/otp_signup.pb.js next to pb_data so new emails get a users row")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
