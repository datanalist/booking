#!/usr/bin/env python3
"""Idempotent seed for PocketBase `reviews` (kind=listing) on published listings.

Creates completed bookings when needed, writes demo reviews, then PATCHes
listings.reviews_count / listings.rating and host users.reviews_count / rating.

Usage:
  python3 scripts/seed_reviews.py
  python3 scripts/seed_reviews.py --reset   # delete seed reviews/bookings, then recreate
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from seed_listings import (  # noqa: E402
    PocketBase,
    SEED_PASSWORD,
    apply_user_profile,
    env,
    load_dotenv,
    pb_filter,
    users_field_names,
)

SEED_NOTE = "[seed_reviews]"
REVIEWS_PER_LISTING = 3
KIND_LISTING = "listing"

SEED_GUESTS = [
    {
        "key": "anton",
        "email": "anton.kirivlyanov@seed.booking.local",
        "name": "Антон Киривлянов",
        "first_name": "Антон",
        "last_name": "Киривлянов",
        "roles": ["guest"],
        "verified_host": False,
    },
    {
        "key": "irina",
        "email": "irina.kulenkova@seed.booking.local",
        "name": "Ирина Куленкова",
        "first_name": "Ирина",
        "last_name": "Куленкова",
        "roles": ["guest"],
        "verified_host": False,
    },
    {
        "key": "pavel",
        "email": "pavel.sokolov@seed.booking.local",
        "name": "Павел Соколов",
        "first_name": "Павел",
        "last_name": "Соколов",
        "roles": ["guest"],
        "verified_host": False,
    },
    {
        "key": "olga",
        "email": "olga.belova@seed.booking.local",
        "name": "Ольга Белова",
        "first_name": "Ольга",
        "last_name": "Белова",
        "roles": ["guest"],
        "verified_host": False,
    },
]

SEED_TEXTS = [
    (
        5,
        "Отличное жилье, полностью доволен проведенным здесь временем, еще вернусь!",
    ),
    (
        4,
        "В целом всё хорошо! Но были нюансы из-за которых 5 звезд ставить не хочется.",
    ),
    (
        5,
        "Чисто, удобно, хозяин всегда на связи. С удовольствием вернёмся.",
    ),
]


def list_records(
    pb: PocketBase,
    collection: str,
    flt: str = "",
    *,
    per_page: int = 200,
) -> list[dict]:
    page = 1
    items: list[dict] = []
    while True:
        query: dict[str, str] = {"page": str(page), "perPage": str(per_page)}
        if flt:
            query["filter"] = flt
        data = pb.request(
            "GET",
            f"/api/collections/{collection}/records",
            query=query,
        )
        items.extend(data.get("items") or [])
        if page >= int(data.get("totalPages") or 1):
            break
        page += 1
    return items


def pb_date(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.000Z")


def seed_review_guests(pb: PocketBase) -> list[dict]:
    field_names = users_field_names(pb)
    records: list[dict] = []
    for user in SEED_GUESTS:
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
        if "account_status" in field_names:
            body["account_status"] = "active"
        if existing:
            update = {
                "name": user["name"],
                "verified": True,
                "emailVisibility": False,
            }
            apply_user_profile(update, user, field_names)
            if "account_status" in field_names:
                update["account_status"] = "active"
            record = pb.update("users", existing["id"], update)
            print(f"review guest exists {user['email']} -> {record['id']}")
        else:
            record = pb.create("users", body)
            print(f"review guest created {user['email']} -> {record['id']}")
        records.append(record)
    extra = pb.first(
        "users",
        pb_filter("email = {:email}", {"email": "guest.demo@seed.booking.local"}),
    )
    if extra:
        records.append(extra)
        print(f"review guest reuse guest.demo@seed.booking.local -> {extra['id']}")
    return records


def has_listing_review(pb: PocketBase, booking_id: str) -> bool:
    found = pb.first(
        "reviews",
        pb_filter(
            "booking = {:booking} && kind = {:kind}",
            {"booking": booking_id, "kind": KIND_LISTING},
        ),
    )
    return found is not None


def unused_completed_bookings(
    pb: PocketBase,
    listing_id: str,
    host_id: str,
) -> list[dict]:
    rows = list_records(
        pb,
        "bookings",
        pb_filter(
            'listing = {:listing} && status = "completed"',
            {"listing": listing_id},
        ),
    )
    unused: list[dict] = []
    for row in rows:
        guest = str(row.get("guest") or "")
        if not guest or guest == host_id:
            continue
        note = str(row.get("guest_note") or "")
        if SEED_NOTE in note:
            continue
        if has_listing_review(pb, str(row.get("id") or "")):
            continue
        unused.append(row)
    return unused


def find_seed_booking(
    pb: PocketBase,
    listing_id: str,
    guest_id: str,
    seq: int,
) -> dict | None:
    note = f"{SEED_NOTE} {seq}"
    return pb.first(
        "bookings",
        pb_filter(
            "listing = {:listing} && guest = {:guest} && guest_note = {:note}",
            {"listing": listing_id, "guest": guest_id, "note": note},
        ),
    )


def create_completed_booking(
    pb: PocketBase,
    listing: dict,
    guest_id: str,
    seq: int,
    listing_index: int,
) -> dict:
    nights = 3
    price = listing.get("price_night")
    try:
        night = float(price) if price is not None else 3000.0
    except (TypeError, ValueError):
        night = 3000.0
    total = round(night * nights)
    prepay = round(total * 0.3)
    remainder = total - prepay
    commission = round(total * 0.15)
    host_amount = total - commission
    check_out = datetime(2026, 8, 20, 11, 0, tzinfo=timezone.utc) - timedelta(
        days=listing_index * 21 + seq * 6
    )
    check_in = check_out - timedelta(days=nights)
    check_in = check_in.replace(hour=15, minute=0, second=0, microsecond=0)
    body = {
        "listing": listing["id"],
        "guest": guest_id,
        "host": listing["host"],
        "check_in": pb_date(check_in),
        "check_out": pb_date(check_out),
        "adults": 2,
        "children": 0,
        "pets": 0,
        "guest_note": f"{SEED_NOTE} {seq}",
        "total": total,
        "prepay": prepay,
        "remainder": remainder,
        "commission": commission,
        "host_amount": host_amount,
        "prepaid_at": pb_date(check_in),
        "status": "completed",
    }
    record = pb.create("bookings", body)
    print(
        f"completed booking {record['id']} listing={listing['id']} "
        f"guest={guest_id} {body['check_in'][:10]}→{body['check_out'][:10]}"
    )
    return record


def upsert_listing_review(
    pb: PocketBase,
    booking: dict,
    listing: dict,
    author_id: str,
    rating: int,
    comment: str,
) -> tuple[dict, bool]:
    existing = pb.first(
        "reviews",
        pb_filter(
            "booking = {:booking} && kind = {:kind}",
            {"booking": booking["id"], "kind": KIND_LISTING},
        ),
    )
    if existing:
        return existing, False
    record = pb.create(
        "reviews",
        {
            "booking": booking["id"],
            "author": author_id,
            "listing": listing["id"],
            "subject": listing["host"],
            "kind": KIND_LISTING,
            "rating": rating,
            "comment": comment,
        },
    )
    return record, True


def avg_rating(ratings: list[float]) -> float:
    if not ratings:
        return 0.0
    return round(sum(ratings) / len(ratings), 1)


def recompute_denorms(pb: PocketBase, listing_ids: set[str], host_ids: set[str]) -> None:
    for listing_id in sorted(listing_ids):
        rows = list_records(
            pb,
            "reviews",
            pb_filter(
                'listing = {:listing} && kind = {:kind}',
                {"listing": listing_id, "kind": KIND_LISTING},
            ),
        )
        ratings = []
        for row in rows:
            try:
                ratings.append(float(row.get("rating")))
            except (TypeError, ValueError):
                continue
        count = len(ratings)
        rating = avg_rating(ratings)
        pb.update(
            "listings",
            listing_id,
            {"reviews_count": count, "rating": rating},
        )
        print(f"listing {listing_id} reviews_count={count} rating={rating}")

    for host_id in sorted(host_ids):
        owned = list_records(
            pb,
            "listings",
            pb_filter("host = {:host}", {"host": host_id}),
        )
        owned_ids = [str(item.get("id") or "") for item in owned]
        owned_ids = [item for item in owned_ids if item]
        rows = list_records(
            pb,
            "reviews",
            pb_filter(
                "subject = {:subject} && kind = {:kind}",
                {"subject": host_id, "kind": KIND_LISTING},
            ),
        )
        if not rows and owned_ids:
            rows = []
            for listing_id in owned_ids:
                rows.extend(
                    list_records(
                        pb,
                        "reviews",
                        pb_filter(
                            "listing = {:listing} && kind = {:kind}",
                            {"listing": listing_id, "kind": KIND_LISTING},
                        ),
                    )
                )
        seen: set[str] = set()
        ratings: list[float] = []
        for row in rows:
            rid = str(row.get("id") or "")
            if rid in seen:
                continue
            seen.add(rid)
            try:
                ratings.append(float(row.get("rating")))
            except (TypeError, ValueError):
                continue
        count = len(ratings)
        rating = avg_rating(ratings)
        pb.update(
            "users",
            host_id,
            {"reviews_count": count, "rating": rating},
        )
        print(f"host {host_id} reviews_count={count} rating={rating}")


def reset_seed(pb: PocketBase) -> None:
    bookings = list_records(
        pb,
        "bookings",
        pb_filter("guest_note ~ {:note}", {"note": SEED_NOTE}),
    )
    deleted_reviews = 0
    for booking in bookings:
        while True:
            found = pb.first(
                "reviews",
                pb_filter("booking = {:booking}", {"booking": booking["id"]}),
            )
            if not found:
                break
            pb.delete("reviews", found["id"])
            deleted_reviews += 1
        pb.delete("bookings", booking["id"])
        print(f"deleted seed booking {booking['id']}")

    comments = [text for _, text in SEED_TEXTS]
    leftover = 0
    for comment in comments:
        while True:
            found = pb.first(
                "reviews",
                pb_filter(
                    "comment = {:comment} && kind = {:kind}",
                    {"comment": comment, "kind": KIND_LISTING},
                ),
            )
            if not found:
                break
            pb.delete("reviews", found["id"])
            leftover += 1
    print(
        f"reset: bookings={len(bookings)} reviews={deleted_reviews} "
        f"leftover_by_comment={leftover}"
    )


def authors_for_listing(guests: list[dict], host_id: str, listing_index: int) -> list[dict]:
    pool = [user for user in guests if str(user.get("id") or "") != host_id]
    if not pool:
        raise RuntimeError("Need guest users other than the listing host")
    start = listing_index % len(pool)
    rotated = pool[start:] + pool[:start]
    out: list[dict] = []
    for i in range(REVIEWS_PER_LISTING):
        out.append(rotated[i % len(rotated)])
    return out


def seed_reviews(pb: PocketBase) -> tuple[int, int, set[str], set[str]]:
    listings = list_records(pb, "listings", 'status = "published"')
    if not listings:
        raise RuntimeError("No published listings to review")
    guests = seed_review_guests(pb)
    created = 0
    skipped = 0
    listing_ids: set[str] = set()
    host_ids: set[str] = set()

    for listing_index, listing in enumerate(listings):
        listing_id = str(listing.get("id") or "")
        host_id = str(listing.get("host") or "")
        if not listing_id or not host_id:
            continue
        listing_ids.add(listing_id)
        host_ids.add(host_id)
        existing_reviews = list_records(
            pb,
            "reviews",
            pb_filter(
                "listing = {:listing} && kind = {:kind}",
                {"listing": listing_id, "kind": KIND_LISTING},
            ),
        )
        existing_count = len(existing_reviews)
        reviewed_authors = {
            str(row.get("author") or "") for row in existing_reviews
        }
        unused = unused_completed_bookings(pb, listing_id, host_id)
        authors = authors_for_listing(guests, host_id, listing_index)
        for seq, author in enumerate(authors):
            if existing_count >= REVIEWS_PER_LISTING:
                skipped += 1
                print(
                    f"review skip {listing.get('title')} "
                    f"already has {existing_count} listing-reviews"
                )
                continue
            rating, comment = SEED_TEXTS[seq % len(SEED_TEXTS)]
            author_id = str(author.get("id") or "")
            booking = None
            if unused:
                booking = unused.pop(0)
                author_id = str(booking.get("guest") or author_id)
            if booking is None:
                booking = find_seed_booking(pb, listing_id, author_id, seq)
            if (
                booking is None
                and author_id in reviewed_authors
            ):
                skipped += 1
                print(
                    f"review skip {listing.get('title')} "
                    f"author={author.get('name') or author_id} already reviewed"
                )
                continue
            if booking is None:
                booking = create_completed_booking(
                    pb, listing, author_id, seq, listing_index
                )
            _, inserted = upsert_listing_review(
                pb, booking, listing, author_id, rating, comment
            )
            if inserted:
                created += 1
                existing_count += 1
                reviewed_authors.add(author_id)
                print(
                    f"review created {listing.get('title')} "
                    f"author={author.get('name') or author_id} rating={rating}"
                )
            else:
                skipped += 1
                reviewed_authors.add(author_id)
                print(
                    f"review exists booking={booking['id']} "
                    f"listing={listing_id} kind={KIND_LISTING}"
                )
    return created, skipped, listing_ids, host_ids


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Delete seed reviews and seed bookings, then recreate",
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

    collections = pb.request(
        "GET",
        "/api/collections",
        query={"page": "1", "perPage": "200"},
    )
    names = {item.get("name") for item in collections.get("items") or []}
    if "reviews" not in names:
        print("Need collection `reviews` — run python3 scripts/ensure_reviews.py", file=sys.stderr)
        return 2
    if "bookings" not in names:
        print("Need collection `bookings` — run python3 scripts/ensure_bookings.py", file=sys.stderr)
        return 2

    if args.reset:
        reset_seed(pb)

    created, skipped, listing_ids, host_ids = seed_reviews(pb)
    recompute_denorms(pb, listing_ids, host_ids)

    reviews = list_records(pb, "reviews")
    listing_kind = [row for row in reviews if row.get("kind") == KIND_LISTING]
    print(f"reviews total={len(reviews)} listing_kind={len(listing_kind)}")
    print(f"seed this run: created={created} skipped={skipped}")
    by_listing: dict[str, int] = {}
    for row in listing_kind:
        listing_id = str(row.get("listing") or "")
        if listing_id:
            by_listing[listing_id] = by_listing.get(listing_id, 0) + 1
    for listing_id in sorted(by_listing):
        print(f"  listing {listing_id}: {by_listing[listing_id]} listing-reviews")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
