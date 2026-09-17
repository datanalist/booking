#!/usr/bin/env python3
"""Enable passwordless email magic-link (OTP under the hood) on PocketBase `users`.

Reads POCKETBASE_URL / POCKETBASE_SU / POCKETBASE_SU_PASSWORD from env or `.env.local`.
Optional SMTP_* keys are applied only if present (never printed).
Sender display name defaults to vallome.booking.
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
    "subject": "Вход в vallome.booking",
    "body": (
        '<!doctype html><html lang="ru"><body style="margin:0;padding:0;background:#ffffff;">'
        '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#ffffff;">'
        '<tr><td align="center" style="padding:56px 24px;">'
        '<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;width:100%;">'
        '<tr><td align="center" style="font-family:Georgia,\'Times New Roman\',Times,serif;font-size:34px;font-weight:700;color:#111111;letter-spacing:0.04em;padding-bottom:56px;">vallome.booking</td></tr>'
        '<tr><td align="center" style="font-family:Arial,Helvetica,sans-serif;font-size:28px;color:#1a1a1a;padding-bottom:36px;line-height:1.3;">Уведомление о входе</td></tr>'
        '<tr><td align="left" style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#4a4a4a;padding-bottom:36px;">Нажмите кнопку ниже, чтобы продолжить.</td></tr>'
        '<tr><td align="center" style="padding-bottom:48px;">'
        '<a href="{APP_URL}/api/vallome/magic-auth?id={OTP_ID}&code={OTP}" target="_blank" rel="noopener" '
        'style="display:inline-block;background:#6B8AFF;color:#ffffff;text-decoration:none;'
        "font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.2;padding:14px 40px;border-radius:6px;\">"
        "Авторизоваться</a>"
        "</td></tr>"
        '<tr><td align="left" style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#4a4a4a;">'
        "Ссылка действительна 10 минут с момента отправки.</td></tr>"
        "</table></td></tr></table></body></html>"
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
    if collection.get("createRule") == "":
        patch["createRule"] = None
        print("createRule was public; locking to admin-only (user is created after magic-link)")

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
    sender_name = env("SMTP_SENDER_NAME", "vallome.booking")
    meta = dict(settings.get("meta") or {})
    meta_patch = dict(meta)
    meta_patch["senderName"] = sender_name

    if smtp_host and smtp_user and smtp_password:
        if env("SMTP_SENDER"):
            meta_patch["senderAddress"] = env("SMTP_SENDER")
        elif smtp_user and not meta_patch.get("senderAddress"):
            meta_patch["senderAddress"] = smtp_user
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
                "meta": meta_patch,
            },
        )
        print("smtp: updated from SMTP_* env; senderName:", sender_name)
    else:
        if meta.get("senderName") != sender_name:
            pb.request("PATCH", "/api/settings", json_body={"meta": meta_patch})
            print("meta.senderName:", sender_name)
        else:
            print("meta.senderName:", meta.get("senderName"))
        if not smtp.get("enabled"):
            print(
                "smtp: DISABLED — magic-link emails will not send until SMTP is configured",
                file=sys.stderr,
            )
            return 3
    print("deploy pb_hooks/*.pb.js next to the PocketBase executable (pb_hooks/)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
