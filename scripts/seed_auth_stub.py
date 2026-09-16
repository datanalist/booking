#!/usr/bin/env python3
"""Idempotent seed for the Email-tab stub user in PocketBase `users`.

Email: example@mail.com
Password: SeedPass123!  (same as other seed users; not a production secret)
Phone: +79999999999     (written only if collection `users` has `phone`)

Reads credentials from the environment or `.env.local`:
  POCKETBASE_URL
  POCKETBASE_SU
  POCKETBASE_SU_PASSWORD

Usage:
  python3 scripts/seed_auth_stub.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import (  # noqa: E402
    AUTH_STUB_USER,
    PocketBase,
    env,
    load_dotenv,
    seed_auth_stub_user,
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
    record = seed_auth_stub_user(pb)
    print(
        "auth stub ready "
        f"{AUTH_STUB_USER['email']} id={record['id']} "
        f"phone={record.get('phone') or '(no phone field)'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
