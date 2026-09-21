/// <reference path="../pb_data/types.d.ts" />

// Guests can only list their own bookings, so search cannot hide occupied
// homes on the client. This route returns listing ids busy for a stay.
// Helpers live inside the handler so JSVM executor VMs can see them.
// Filter values are bound with {:placeholder} — never concatenated.
routerAdd("GET", "/api/vallome/occupied-listings", (e) => {
  const OCCUPYING = [
    "pending_host",
    "awaiting_prepayment",
    "confirmed",
    "change_requested",
    "cancel_requested",
  ]

  function str(value) {
    return value == null ? "" : String(value)
  }

  function readQuery(name) {
    try {
      const value = str(e.request.url.query().get(name)).trim()
      if (value) return value
    } catch (err) {}
    try {
      const info = e.requestInfo()
      const query = (info && info.query) || {}
      return str(query[name]).trim()
    } catch (err) {}
    return ""
  }

  function bindDate(value) {
    const raw = str(value).trim()
    const match = raw.match(/^(\d{4}-\d{2}-\d{2})/)
    if (!match) return ""
    return match[1] + " 00:00:00.000Z"
  }

  function collectionExists(name) {
    try {
      return !!e.app.findCollectionByNameOrId(name)
    } catch (err) {
      return false
    }
  }

  function collectListingIds(collection, filter, params) {
    const ids = []
    var offset = 0
    const limit = 200
    while (offset < 10000) {
      var found
      try {
        found = e.app.findRecordsByFilter(
          collection,
          filter,
          "",
          limit,
          offset,
          params,
        )
      } catch (err) {
        break
      }
      if (!found || found.length === 0) break
      for (var i = 0; i < found.length; i++) {
        const id = str(found[i].get("listing")).trim()
        if (id) ids.push(id)
      }
      if (found.length < limit) break
      offset += limit
    }
    return ids
  }

  const checkIn = bindDate(readQuery("checkIn") || readQuery("check_in"))
  const checkOut = bindDate(readQuery("checkOut") || readQuery("check_out"))
  if (!checkIn || !checkOut || checkIn >= checkOut) {
    return e.json(200, { listingIds: [] })
  }

  const params = {
    checkIn: checkIn,
    checkOut: checkOut,
  }
  const statusExpr = OCCUPYING.map(function (status, i) {
    params["status" + i] = status
    return "status = {:status" + i + "}"
  }).join(" || ")

  const unique = {}
  const fromBookings = collectListingIds(
    "bookings",
    "(" +
      statusExpr +
      ") && check_in < {:checkOut} && check_out > {:checkIn}",
    params,
  )
  for (var b = 0; b < fromBookings.length; b++) {
    unique[fromBookings[b]] = true
  }

  if (collectionExists("listing_blocks")) {
    const fromBlocks = collectListingIds(
      "listing_blocks",
      "start < {:checkOut} && end > {:checkIn}",
      { checkIn: checkIn, checkOut: checkOut },
    )
    for (var i = 0; i < fromBlocks.length; i++) {
      unique[fromBlocks[i]] = true
    }
  }

  return e.json(200, { listingIds: Object.keys(unique) })
})

// Sibling route: occupied ranges for one listing's calendar.
// Do not return guest/host PII — only start/end. Helpers stay nested.
routerAdd("GET", "/api/vallome/occupied-dates", (e) => {
  const OCCUPYING = [
    "pending_host",
    "awaiting_prepayment",
    "confirmed",
    "change_requested",
    "cancel_requested",
  ]

  function str(value) {
    return value == null ? "" : String(value)
  }

  function readQuery(name) {
    try {
      const value = str(e.request.url.query().get(name)).trim()
      if (value) return value
    } catch (err) {}
    try {
      const info = e.requestInfo()
      const query = (info && info.query) || {}
      return str(query[name]).trim()
    } catch (err) {}
    return ""
  }

  function bindId(value) {
    const raw = str(value).trim()
    if (!raw || raw.length > 32 || !/^[A-Za-z0-9]+$/.test(raw)) return ""
    return raw
  }

  function dayValue(value) {
    const raw = str(value).trim()
    const match = raw.match(/^(\d{4}-\d{2}-\d{2})/)
    return match ? match[1] : ""
  }

  function collectionExists(name) {
    try {
      return !!e.app.findCollectionByNameOrId(name)
    } catch (err) {
      return false
    }
  }

  function pushRange(ranges, startRaw, endRaw) {
    const start = dayValue(startRaw)
    const end = dayValue(endRaw)
    if (!start || !end || start >= end) return
    ranges.push({ start: start, end: end })
  }

  function collectRanges(collection, filter, params, startField, endField) {
    const ranges = []
    var offset = 0
    const limit = 200
    while (offset < 10000) {
      var found
      try {
        found = e.app.findRecordsByFilter(
          collection,
          filter,
          "",
          limit,
          offset,
          params,
        )
      } catch (err) {
        break
      }
      if (!found || found.length === 0) break
      for (var i = 0; i < found.length; i++) {
        pushRange(ranges, found[i].get(startField), found[i].get(endField))
      }
      if (found.length < limit) break
      offset += limit
    }
    return ranges
  }

  const listing = bindId(readQuery("listing"))
  if (!listing) {
    return e.json(200, { ranges: [] })
  }

  const params = { listing: listing }
  const statusExpr = OCCUPYING.map(function (status, i) {
    params["status" + i] = status
    return "status = {:status" + i + "}"
  }).join(" || ")

  var filter = "listing = {:listing} && (" + statusExpr + ")"
  const excludeId = bindId(
    readQuery("excludeBookingId") || readQuery("exclude_booking_id"),
  )
  if (excludeId) {
    params.excludeId = excludeId
    filter += " && id != {:excludeId}"
  }

  const ranges = collectRanges(
    "bookings",
    filter,
    params,
    "check_in",
    "check_out",
  )

  if (collectionExists("listing_blocks")) {
    const blocks = collectRanges(
      "listing_blocks",
      "listing = {:listing}",
      { listing: listing },
      "start",
      "end",
    )
    for (var i = 0; i < blocks.length; i++) {
      ranges.push(blocks[i])
    }
  }

  return e.json(200, { ranges: ranges })
})
