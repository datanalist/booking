/// <reference path="../pb_data/types.d.ts" />

// Keep chats.last_message / last_message_at in sync after a new message.
// Enforce one listing chat per (listing, guest) pair (schema note).
// Listing chats may be created only when the guest has a booking for that listing.

onRecordCreateRequest((e) => {
  // Коллекция уже задана вторым аргументом ("chats"); e.collection?.name
  // в JSVM может быть undefined — тогда раньше хук молча пропускал create.
  const record = e.record
  if (!record) {
    e.next()
    return
  }
  const kind = record.getString("kind")
  const listing = record.getString("listing")
  const guest = record.getString("guest")
  if (kind !== "listing" || !listing || !guest) {
    e.next()
    return
  }

  const existing = $app.findRecordsByFilter(
    "chats",
    'kind = "listing" && listing = {:listing} && guest = {:guest}',
    "-created",
    1,
    0,
    { listing: listing, guest: guest },
  )
  if (existing && existing.length > 0) {
    throw new BadRequestError("Чат по этому жилью уже есть")
  }

  const bookingId = record.getString("booking")
  if (!bookingId) {
    throw new BadRequestError(
      "Чат с владельцем откроется после бронирования этого жилья",
    )
  }

  let booking
  try {
    booking = $app.findRecordById("bookings", bookingId)
  } catch (err) {
    throw new BadRequestError(
      "Чат с владельцем откроется после бронирования этого жилья",
    )
  }

  const bookingGuest = booking.getString("guest")
  const bookingListing = booking.getString("listing")
  if (bookingGuest !== guest || bookingListing !== listing) {
    throw new BadRequestError(
      "Чат с владельцем откроется после бронирования этого жилья",
    )
  }

  const auth = e.auth
  if (!auth || auth.id !== guest) {
    throw new BadRequestError("Войдите, чтобы написать владельцу")
  }

  e.next()
}, "chats")

onRecordAfterCreateSuccess((e) => {
  // Хук уже ограничен коллекцией "messages" вторым аргументом.
  // Не проверять e.collection?.name: в PB JSVM оно часто undefined,
  // и тогда превью чата молча не обновлялось → собеседник не видел
  // сообщение, пока тред открыт (create realtime тоже не доходит).
  const record = e.record
  if (!record) return
  const chatId = record.getString("chat")
  if (!chatId) return
  try {
    const chat = $app.findRecordById("chats", chatId)
    const text = (record.getString("text") || "").trim()
    const images = record.get("images")
    const hasImages = Array.isArray(images)
      ? images.length > 0
      : !!(images && String(images).length)
    let preview = text
    if (!preview) {
      preview = hasImages ? "Фото" : "Сообщение"
    } else if (preview.length > 120) {
      preview = preview.slice(0, 117) + "…"
    }
    chat.set("last_message", preview)
    chat.set("last_message_at", record.get("created") || new Date().toISOString())
    $app.save(chat)
  } catch (err) {
    console.error("chats_messages: failed to update chat preview", err)
  }
}, "messages")
