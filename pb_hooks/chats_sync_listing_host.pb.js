/// <reference path="../pb_data/types.d.ts" />

// When listings.host changes, keep chats.host (and bookings.host) in sync.
// Otherwise the listing card shows the new owner while chat headers keep the old one.

onRecordAfterUpdateSuccess((e) => {
  const record = e.record
  if (!record || e.collection?.name !== "listings") return

  const listingId = record.id
  const newHost = record.getString("host")
  if (!listingId || !newHost) return

  try {
    const chats = $app.findRecordsByFilter(
      "chats",
      'kind = "listing" && listing = {:listing} && host != {:host}',
      "-created",
      200,
      0,
      { listing: listingId, host: newHost },
    )
    for (const chat of chats || []) {
      chat.set("host", newHost)
      $app.save(chat)
    }
  } catch (err) {
    console.error("chats_sync_listing_host: chats", err)
  }

  try {
    const bookings = $app.findRecordsByFilter(
      "bookings",
      "listing = {:listing} && host != {:host}",
      "-created",
      500,
      0,
      { listing: listingId, host: newHost },
    )
    for (const booking of bookings || []) {
      booking.set("host", newHost)
      $app.save(booking)
    }
  } catch (err) {
    console.error("chats_sync_listing_host: bookings", err)
  }
}, "listings")
