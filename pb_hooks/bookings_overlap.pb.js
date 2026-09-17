/// <reference path="../pb_data/types.d.ts" />

// Occupying statuses from docs/pocketbase-schema.md. Guests cannot list
// other people's bookings, so overlap is enforced here on create/update.
// Helpers live inside the handler so JSVM executor VMs can see them.
// Filter values are bound with {:placeholder} — never concatenated.
function rejectIfOverlap(e) {
  const OCCUPYING = [
    "pending_host",
    "awaiting_prepayment",
    "confirmed",
    "change_requested",
    "cancel_requested",
  ]

  const record = e.record
  if (!record) {
    e.next()
    return
  }

  const listing = record.get("listing")
  const checkIn = record.get("check_in")
  const checkOut = record.get("check_out")
  if (!listing || !checkIn || !checkOut) {
    e.next()
    return
  }

  const params = {
    listing: String(listing),
    checkIn: String(checkIn),
    checkOut: String(checkOut),
  }
  const statusExpr = OCCUPYING.map(function (status, i) {
    params["status" + i] = status
    return "status = {:status" + i + "}"
  }).join(" || ")

  var filter =
    "listing = {:listing} && (" +
    statusExpr +
    ") && check_in < {:checkOut} && check_out > {:checkIn}"

  const id = record.id
  if (id) {
    params.id = String(id)
    filter += " && id != {:id}"
  }

  const found = e.app.findRecordsByFilter(
    "bookings",
    filter,
    "",
    1,
    0,
    params,
  )
  if (found && found.length > 0) {
    throw new BadRequestError("На эти даты жилье уже занято")
  }
  e.next()
}

onRecordCreateRequest(rejectIfOverlap, "bookings")
onRecordUpdateRequest(rejectIfOverlap, "bookings")
