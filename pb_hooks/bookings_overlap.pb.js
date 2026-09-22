/// <reference path="../pb_data/types.d.ts" />

// Occupying statuses from docs/pocketbase-schema.md. Guests cannot list
// other people's bookings, so overlap is enforced here on create/update.
// Compare calendar days in JS: a PocketBase date filter misses overlaps when
// one side is "YYYY-MM-DD HH:MM:SS.sssZ" and the other is ISO "T".
// Helpers live inside the handler so JSVM executor VMs can see them.
// Filter values are bound with {:placeholder} — never concatenated.
function rejectIfOverlap(e) {
  // Same keys as BookingStatus.upcomingApiKeys (Брони → Предстоящие).
  const OCCUPYING = [
    "pending_host",
    "awaiting_prepayment",
    "confirmed",
    "change_requested",
  ]

  function str(value) {
    return value == null ? "" : String(value)
  }

  function dayKey(value) {
    const raw = str(value).trim()
    const match = raw.match(/(\d{4}-\d{2}-\d{2})/)
    return match ? match[1] : ""
  }

  function rangesOverlap(startA, endA, startB, endB) {
    if (!startA || !endA || !startB || !endB) return false
    if (startA >= endA || startB >= endB) return false
    return startA < endB && endA > startB
  }

  function listingIdOf(record) {
    var raw = ""
    try {
      raw = record.get("listing")
    } catch (err) {}
    if (raw && typeof raw === "object") {
      try {
        if (raw.id) return str(raw.id).trim()
      } catch (err) {}
    }
    const id = str(raw).trim()
    if (id && id !== "null" && id !== "undefined" && id !== "[object Object]") {
      return id
    }
    try {
      return str(record.getString("listing")).trim()
    } catch (err) {}
    return ""
  }

  const record = e.record
  if (!record) {
    e.next()
    return
  }

  const listing = listingIdOf(record)
  const checkInDay = dayKey(record.get("check_in"))
  const checkOutDay = dayKey(record.get("check_out"))
  var reqIn = ""
  var reqOut = ""
  try {
    reqIn = dayKey(record.get("requested_check_in"))
  } catch (err) {}
  try {
    reqOut = dayKey(record.get("requested_check_out"))
  } catch (err) {}
  if (!listing || !checkInDay || !checkOutDay || checkInDay >= checkOutDay) {
    e.next()
    return
  }

  const params = { listing: listing }
  const statusExpr = OCCUPYING.map(function (status, i) {
    params["status" + i] = status
    return "status = {:status" + i + "}"
  }).join(" || ")

  var filter = "listing = {:listing} && (" + statusExpr + ")"
  const id = str(record.id).trim()
  if (id) {
    params.id = id
    filter += " && id != {:id}"
  }

  const found = e.app.findRecordsByFilter(
    "bookings",
    filter,
    "",
    200,
    0,
    params,
  )
  if (found) {
    for (var i = 0; i < found.length; i++) {
      var otherIn = ""
      var otherOut = ""
      var otherReqIn = ""
      var otherReqOut = ""
      try {
        otherIn = dayKey(found[i].get("check_in"))
      } catch (err) {}
      try {
        otherOut = dayKey(found[i].get("check_out"))
      } catch (err) {}
      try {
        otherReqIn = dayKey(found[i].get("requested_check_in"))
      } catch (err) {}
      try {
        otherReqOut = dayKey(found[i].get("requested_check_out"))
      } catch (err) {}
      var hit =
        rangesOverlap(otherIn, otherOut, checkInDay, checkOutDay) ||
        rangesOverlap(otherReqIn, otherReqOut, checkInDay, checkOutDay)
      if (reqIn && reqOut) {
        hit =
          hit ||
          rangesOverlap(otherIn, otherOut, reqIn, reqOut) ||
          rangesOverlap(otherReqIn, otherReqOut, reqIn, reqOut)
      }
      if (hit) {
        throw new BadRequestError("На эти даты жилье уже занято")
      }
    }
  }
  e.next()
}

onRecordCreateRequest(rejectIfOverlap, "bookings")
onRecordUpdateRequest(rejectIfOverlap, "bookings")
