/// <reference path="../pb_data/types.d.ts" />

// PocketBase does not create a users record on requestOTP. Without one it
// still returns 200 + a dummy otpId and never sends the email.
onRecordRequestOTPRequest((e) => {
  if (e.record) {
    e.next()
    return
  }

  const info = e.requestInfo()
  const email = String(((info && info.body) || {}).email || "").trim()
  if (!email) {
    e.next()
    return
  }

  const record = new Record(e.collection)
  record.setEmail(email)
  record.setRandomPassword()
  try {
    e.app.save(record)
    e.record = record
  } catch (err) {
    try {
      e.record = e.app.findAuthRecordByEmail(e.collection.name, email)
    } catch (_) {
      throw err
    }
  }

  e.next()
}, "users")
