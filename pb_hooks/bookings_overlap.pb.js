/// <reference path="../pb_data/types.d.ts" />

// Occupying statuses from docs/pocketbase-schema.md. Guests cannot list
// other people's bookings, so overlap is enforced here on create/update.
// Helpers live inside the handler so JSVM executor VMs can see them.
function rejectIfOverlap(e) {
  const OCCUPYING = [
    "pending_host",
    "awaiting_prepayment",
    "confirmed",
    "change_requested",
    "cancel_requested",
  ]

  function quote(value) {
    return String(value == null ? "" : value).replace(/"/g, "")
  }

  function overlapFilter(record) {
    const listing = quote(record.get("listing"))
    const checkIn = quote(record.get("check_in"))
    const checkOut = quote(record.get("check_out"))
    if (!listing || !checkIn || !checkOut) return ""
    const statuses = OCCUPYING.map((status) => `status = "${status}"`).join(" || ")
    const id = quote(record.id)
    const exclude = id ? ` && id != "${id}"` : ""
    return (
      `listing = "${listing}" && (${statuses}) && ` +
      `check_in < "${checkOut}" && check_out > "${checkIn}"` +
      exclude
    )
  }

  const record = e.record
  if (!record) {
    e.next()
    return
  }
  const filter = overlapFilter(record)
  if (!filter) {
    e.next()
    return
  }
  const found = e.app.findRecordsByFilter("bookings", filter, "", 1, 0)
  if (found && found.length > 0) {
    throw new BadRequestError("На эти даты жилье уже занято")
  }
  e.next()
}

onRecordCreateRequest(rejectIfOverlap, "bookings")
onRecordUpdateRequest(rejectIfOverlap, "bookings")
