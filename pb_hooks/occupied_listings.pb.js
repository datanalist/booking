/// <reference path="../pb_data/types.d.ts" />

// Guests can only list their own bookings, so search cannot hide occupied
// homes on the client. This route returns listing ids busy for a stay.
// Helpers live inside the handler so JSVM executor VMs can see them.
// Filter values are bound with {:placeholder} — never concatenated.
routerAdd("GET", "/api/vallome/occupied-listings", (e) => {
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

  function dayKey(value) {
    const raw = str(value).trim()
    const match = raw.match(/(\d{4}-\d{2}-\d{2})/)
    return match ? match[1] : ""
  }

  function listingIdOf(record) {
    var raw = ""
    try {
      raw = record.get("listing")
    } catch (err) {}
    if (raw && typeof raw === "object") {
      try {
        if (raw.length) return str(raw[0]).trim()
      } catch (err) {}
      try {
        if (raw.id) return str(raw.id).trim()
      } catch (err) {}
    }
    const id = str(raw).trim()
    if (id && id !== "null" && id !== "undefined") return id
    try {
      return str(record.getString("listing")).trim()
    } catch (err) {}
    return ""
  }

  // Half-open nights [check_in, check_out): compare calendar days only.
  // PocketBase may store "YYYY-MM-DD HH:MM:SS.sssZ" or an ISO "T" form;
  // a full-timestamp filter then misses a same-day overlap.
  function stayOverlaps(startRaw, endRaw, checkInDay, checkOutDay) {
    const start = dayKey(startRaw)
    const end = dayKey(endRaw)
    if (!start || !end || start >= end) return false
    return start < checkOutDay && end > checkInDay
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
        try {
          console.log("occupied-listings: " + collection + " " + err)
        } catch (logErr) {}
        break
      }
      if (!found || found.length === 0) break
      for (var i = 0; i < found.length; i++) {
        if (collection === "bookings") {
          var status = ""
          try {
            status = str(found[i].get("status")).trim()
          } catch (err) {}
          var occupies = false
          for (var s = 0; s < OCCUPYING.length; s++) {
            if (status === OCCUPYING[s]) occupies = true
          }
          if (!occupies) continue
        }
        const id = listingIdOf(found[i])
        if (!id) continue
        const startField = collection === "listing_blocks" ? "start" : "check_in"
        const endField = collection === "listing_blocks" ? "end" : "check_out"
        if (
          !stayOverlaps(
            found[i].get(startField),
            found[i].get(endField),
            checkInDay,
            checkOutDay,
          )
        ) {
          continue
        }
        ids.push(id)
      }
      if (found.length < limit) break
      offset += limit
    }
    return ids
  }

  const checkInDay = dayKey(readQuery("checkIn") || readQuery("check_in"))
  const checkOutDay = dayKey(readQuery("checkOut") || readQuery("check_out"))
  if (!checkInDay || !checkOutDay || checkInDay >= checkOutDay) {
    return e.json(200, { listingIds: [] })
  }

  const unique = {}
  const fromBookings = collectListingIds("bookings", "id != ''", {})
  for (var b = 0; b < fromBookings.length; b++) {
    unique[fromBookings[b]] = true
  }

  if (collectionExists("listing_blocks")) {
    const fromBlocks = collectListingIds("listing_blocks", "id != ''", {})
    for (var i = 0; i < fromBlocks.length; i++) {
      unique[fromBlocks[i]] = true
    }
  }

  return e.json(200, { listingIds: Object.keys(unique) })
})

// Sibling route: occupied ranges for one listing's calendar.
// Do not return guest/host PII — only start/end. Helpers stay nested.
routerAdd("GET", "/api/vallome/occupied-dates", (e) => {
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
