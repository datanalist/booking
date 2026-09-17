/// <reference path="../pb_data/types.d.ts" />

// Do not create a `users` row on requestOTP. A typed email is not consent
// to register: the record is created only after the magic-link is confirmed
// (`POST /api/vallome/magic-request` + consume in magic_link.pb.js).
onRecordRequestOTPRequest((e) => {
  e.next()
}, "users")
