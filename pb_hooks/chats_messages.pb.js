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

  function str(value) {
    return value == null ? "" : String(value)
  }

  function messagePreview(message) {
    const text = str(message.getString("text")).trim()
    const images = message.get("images")
    const hasImages = Array.isArray(images)
      ? images.length > 0
      : !!(images && String(images).length)
    let preview = text
    if (!preview) {
      preview = hasImages ? "Фото" : "Сообщение"
    } else if (preview.length > 120) {
      preview = preview.slice(0, 117) + "…"
    }
    return preview
  }

  function personName(user) {
    if (!user) return ""
    const first = str(user.getString("first_name")).trim()
    const last = str(user.getString("last_name")).trim()
    const full = (first + " " + last).trim()
    if (full) return full
    const name = str(user.getString("name")).trim()
    if (name) return name
    const email = str(user.getString("email")).trim()
    if (email) {
      const at = email.indexOf("@")
      return at > 0 ? email.slice(0, at) : email
    }
    return ""
  }

  function recipientFor(chat, authorId) {
    const guest = str(chat.getString("guest"))
    const host = str(chat.getString("host"))
    const staff = str(chat.getString("staff"))
    if (authorId === guest) return host || staff
    if (authorId === host || authorId === staff) return guest
    // Неизвестный автор — не шумим уведомлением.
    return ""
  }

  function upsertChatNotice(chat, authorId, preview) {
    const recipientId = recipientFor(chat, authorId)
    if (!recipientId || recipientId === authorId) return

    let authorName = "пользователя"
    try {
      const author = $app.findRecordById("users", authorId)
      const resolved = personName(author)
      if (resolved) authorName = resolved
    } catch (err) {}

    const title = "Новое сообщение от " + authorName
    const listingId = str(chat.getString("listing"))
    const bookingId = str(chat.getString("booking"))

    let existing = []
    try {
      existing = $app.findRecordsByFilter(
        "notifications",
        "user = {:user} && chat = {:chat}",
        "-updated",
        1,
        0,
        { user: recipientId, chat: chatId },
      ) || []
    } catch (err) {
      // Коллекция / поле chat ещё не подняты — превью чата важнее.
      console.error("chats_messages: notifications lookup failed", err)
      return
    }

    try {
      if (existing.length > 0) {
        const notice = existing[0]
        notice.set("title", title)
        notice.set("body", preview)
        notice.set("read", false)
        if (listingId) notice.set("listing", listingId)
        if (bookingId) notice.set("booking", bookingId)
        $app.save(notice)
        return
      }

      const collection = $app.findCollectionByNameOrId("notifications")
      const notice = new Record(collection)
      notice.set("user", recipientId)
      notice.set("title", title)
      notice.set("body", preview)
      notice.set("read", false)
      notice.set("chat", chatId)
      if (listingId) notice.set("listing", listingId)
      if (bookingId) notice.set("booking", bookingId)
      $app.save(notice)
    } catch (err) {
      console.error("chats_messages: failed to upsert notification", err)
    }
  }

  try {
    const chat = $app.findRecordById("chats", chatId)
    const preview = messagePreview(record)
    chat.set("last_message", preview)
    chat.set("last_message_at", record.get("created") || new Date().toISOString())
    $app.save(chat)

    const authorId = str(record.getString("author"))
    if (authorId) upsertChatNotice(chat, authorId, preview)
  } catch (err) {
    console.error("chats_messages: failed to update chat preview", err)
  }
}, "messages")
