/// <reference path="../pb_data/types.d.ts" />

// Keep chats.last_message / last_message_at in sync after a new message.
// Enforce one listing chat per (listing, guest) pair (schema note).

onRecordCreateRequest((e) => {
  const record = e.record
  if (!record || e.collection?.name !== "chats") {
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
  e.next()
}, "chats")

onRecordAfterCreateSuccess((e) => {
  const record = e.record
  if (!record || e.collection?.name !== "messages") return
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
