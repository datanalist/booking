/// <reference path="../pb_data/types.d.ts" />

// PocketBase JSVM serializes hook/route handlers into a pooled executor VM.
// Nested functions travel with the handler source; outer-scope helpers do not.

onMailerRecordOTPSend((e) => {
  function str(value) {
    return value == null ? "" : String(value)
  }

  function htmlEscape(value) {
    return str(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  function queryEscape(value) {
    var s = str(value)
    try {
      if (typeof encodeURIComponent === "function") return encodeURIComponent(s)
    } catch (err) {}
    return s.replace(/[^A-Za-z0-9\-_.~]/g, function (ch) {
      var hex = ch.charCodeAt(0).toString(16).toUpperCase()
      if (hex.length < 2) hex = "0" + hex
      return "%" + hex
    })
  }

  function appUrl() {
    try {
      const meta = $app.settings().meta || {}
      const url = str(meta.appURL || meta.appUrl).replace(/\/$/, "")
      if (url) return url
    } catch (err) {}
    return "https://pb.booking.vallome.ru"
  }

  function magicLink(otpId, password) {
    return (
      appUrl() +
      "/api/vallome/magic-auth?id=" +
      queryEscape(otpId) +
      "&code=" +
      queryEscape(password)
    )
  }

  function emailHtml(href) {
    return (
      '<!doctype html><html lang="ru"><body style="margin:0;padding:0;background:#ffffff;">' +
      '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#ffffff;">' +
      '<tr><td align="center" style="padding:56px 24px;">' +
      '<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;width:100%;">' +
      '<tr><td align="center" style="font-family:Georgia,\'Times New Roman\',Times,serif;font-size:34px;font-weight:700;color:#111111;letter-spacing:0.04em;padding-bottom:56px;">vallome.booking</td></tr>' +
      '<tr><td align="center" style="font-family:Arial,Helvetica,sans-serif;font-size:28px;color:#1a1a1a;padding-bottom:36px;line-height:1.3;">Уведомление о входе</td></tr>' +
      '<tr><td align="left" style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#4a4a4a;padding-bottom:36px;">Нажмите кнопку ниже, чтобы продолжить.</td></tr>' +
      '<tr><td align="center" style="padding-bottom:48px;">' +
      '<a href="' +
      href +
      '" target="_blank" rel="noopener" style="display:inline-block;background:#6B8AFF;color:#ffffff;text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.2;padding:14px 40px;border-radius:6px;">Авторизоваться</a>' +
      "</td></tr>" +
      '<tr><td align="left" style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#4a4a4a;">Ссылка действительна 10 минут с момента отправки.</td></tr>' +
      "</table></td></tr></table></body></html>"
    )
  }

  try {
    const meta = e.meta || {}
    const otpId = str(meta.otpId || meta.otp_id || "")
    const password = str(meta.password || meta.otp || "")
    if (otpId && password) {
      const link = magicLink(otpId, password)
      e.message.subject = "Вход в vallome.booking"
      e.message.html = emailHtml(htmlEscape(link))
      e.message.text =
        "vallome.booking\n\nУведомление о входе\n\n" +
        "Нажмите кнопку «Авторизоваться» или откройте ссылку: " +
        link +
        "\n\nСсылка действительна 10 минут с момента отправки."
    }
  } catch (err) {
    console.log("magic-link mailer: " + err)
    try {
      $app.logger().error("magic-link mailer failed", "error", String(err))
    } catch (logErr) {}
  }
  e.next()
}, "users")

function magicAuthHandler(e) {
  const MAGIC_PATH = "/api/vallome/magic-auth"
  const APP_SCHEME = "vallome-booking"
  const APP_PACKAGE = "com.booking.booking"
  const INVALID_MSG = "Ссылка недействительна или устарела."
  const EXPIRED_MSG =
    "Ссылка недействительна или устарела. Запросите новое письмо в приложении."
  const OCCUPIED_MSG = "Этот email уже занят."

  function str(value) {
    return value == null ? "" : String(value)
  }

  function htmlEscape(value) {
    return str(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  function queryEscape(value) {
    var s = str(value)
    try {
      if (typeof encodeURIComponent === "function") return encodeURIComponent(s)
    } catch (err) {}
    return s.replace(/[^A-Za-z0-9\-_.~]/g, function (ch) {
      var hex = ch.charCodeAt(0).toString(16).toUpperCase()
      if (hex.length < 2) hex = "0" + hex
      return "%" + hex
    })
  }

  function pageWrap(title, inner) {
    return (
      "<!doctype html><html lang=\"ru\"><head><meta charset=\"utf-8\">" +
      '<meta name="viewport" content="width=device-width, initial-scale=1">' +
      "<title>" +
      htmlEscape(title) +
      "</title><style>" +
      "body{font-family:system-ui,sans-serif;background:#F7F7F6;color:#1A1A1A;" +
      "display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;}" +
      ".card{background:#fff;border-radius:16px;padding:32px 24px;max-width:420px;" +
      "width:calc(100% - 32px);text-align:center;box-shadow:0 8px 24px #00000014;}" +
      "h1{font-size:22px;margin:0 0 12px;}p{margin:0 0 16px;line-height:1.45;color:#1A1B1C;}" +
      "button,.btn{display:inline-block;background:#F88A2A;color:#fff;border:0;border-radius:16px;" +
      "padding:14px 22px;font-size:16px;text-decoration:none;cursor:pointer;}" +
      "</style></head><body><div class=\"card\">" +
      inner +
      "</div></body></html>"
    )
  }

  function confirmPage(otpId, password) {
    const action = htmlEscape(MAGIC_PATH)
    const id = htmlEscape(otpId)
    const code = htmlEscape(password)
    return pageWrap(
      "Вход",
      "<h1>Вход в vallome.booking</h1>" +
        "<p>Нажмите кнопку, чтобы авторизоваться и вернуться в приложение.</p>" +
        '<form id="auth" method="post" action="' +
        action +
        '">' +
        '<input type="hidden" name="id" value="' +
        id +
        '">' +
        '<input type="hidden" name="code" value="' +
        code +
        '">' +
        '<button type="submit">Авторизоваться</button>' +
        "</form>" +
        "<script>document.getElementById('auth').submit()</script>",
    )
  }

  function successPage(token) {
    const intentHref =
      "intent://auth-callback?token=" +
      queryEscape(token) +
      "#Intent;scheme=" +
      APP_SCHEME +
      ";package=" +
      APP_PACKAGE +
      ";action=android.intent.action.VIEW;" +
      "category=android.intent.category.BROWSABLE;end"
    return pageWrap(
      "Вы авторизованы",
      "<h1>Вы авторизованы</h1>" +
        "<p>Вернитесь в приложение — вход уже выполнен. Это окно можно закрыть.</p>" +
        '<p id="open-wrap" style="display:none;margin-top:8px;">' +
        '<a class="btn" id="open-app" href="#">Открыть приложение</a></p>' +
        "<script>(function(){" +
        "if(!/Android/i.test(navigator.userAgent||''))return;" +
        "var wrap=document.getElementById('open-wrap');" +
        "if(wrap)wrap.style.display='block';" +
        "var btn=document.getElementById('open-app');" +
        "if(btn)btn.setAttribute('href'," +
        JSON.stringify(intentHref) +
        ");" +
        "})();</script>",
    )
  }

  function rememberToken(otpId, token) {
    try {
      $app.store().set("magicWait:" + otpId, token)
    } catch (err) {
      logErr(err)
    }
  }

  function errorPage(message) {
    return pageWrap(
      "Ошибка входа",
      "<h1>Не удалось войти</h1><p>" + htmlEscape(message) + "</p>",
    )
  }

  function sendHtml(status, body) {
    try {
      return e.html(status, body)
    } catch (err) {
      try {
        return e.blob(status, "text/html; charset=utf-8", body)
      } catch (err2) {
        return e.string(status, body)
      }
    }
  }

  function logErr(err) {
    console.log("magic-auth: " + err)
    try {
      $app.logger().error("magic-auth failed", "error", String(err))
    } catch (logErr2) {}
  }

  function readName(name) {
    var fromQuery = ""
    try {
      fromQuery = str(e.request.url.query().get(name))
    } catch (err) {}
    var fromForm = ""
    try {
      fromForm = str(e.request.formValue(name))
    } catch (err) {}
    var fromInfo = ""
    try {
      const info = e.requestInfo()
      const query = (info && info.query) || {}
      const body = (info && info.body) || {}
      fromInfo = str(query[name] || body[name] || "")
    } catch (err) {}
    return (fromQuery || fromForm || fromInfo).trim()
  }

  function otpField(otp, method, field) {
    try {
      if (typeof otp[method] === "function") return str(otp[method]())
    } catch (err) {}
    try {
      if (typeof otp.get === "function") return str(otp.get(field) || "")
    } catch (err) {}
    return str(otp[field] || "")
  }

  function consumePending(otpId, password) {
    var raw = ""
    try {
      raw = str($app.store().get("magicPending:" + otpId))
    } catch (err) {}
    if (!raw || raw === "null" || raw === "undefined") {
      return ""
    }
    var pending
    try {
      pending = JSON.parse(raw)
    } catch (err) {
      throw new Error("invalid")
    }
    if (!pending || str(pending.code) !== str(password)) {
      throw new Error("invalid")
    }
    if (Number(pending.expires || 0) < Date.now()) {
      try {
        $app.store().remove("magicPending:" + otpId)
      } catch (err) {}
      throw new Error("expired")
    }
    const email = str(pending.email).trim().toLowerCase()
    const changeUserId = str(pending.userId).trim()
    if (!email) {
      throw new Error("invalid")
    }

    function findUserByEmail(identity) {
      try {
        const found = e.app.findAuthRecordByEmail("users", identity)
        if (found) return found
      } catch (err) {}
      try {
        const found = e.app.findFirstRecordByFilter(
          "users",
          "email = {:email}",
          { email: identity },
        )
        if (found) return found
      } catch (err) {}
      return null
    }

    function clearEmailChange(userId, identity) {
      try {
        if (identity) $app.store().remove("emailChange:" + identity)
        if (userId) $app.store().remove("emailChangeUser:" + userId)
      } catch (err) {}
    }

    function ensureAccountStatus(user) {
      var status = ""
      try {
        status = str(user.get("account_status"))
      } catch (err) {}
      if (!status || status === "null" || status === "undefined") {
        user.set("account_status", "active")
      }
    }

    var record = null
    if (changeUserId) {
      try {
        record = e.app.findRecordById("users", changeUserId)
      } catch (err) {}
      if (!record) {
        throw new Error("invalid")
      }
      const occupier = findUserByEmail(email)
      if (occupier && occupier.id !== record.id) {
        clearEmailChange(record.id, email)
        throw new Error("occupied")
      }
      record.setEmail(email)
      if (typeof record.setVerified === "function") {
        record.setVerified(true)
      }
      ensureAccountStatus(record)
      try {
        e.app.save(record)
      } catch (err) {
        const text = str(err).toLowerCase()
        if (text.indexOf("unique") >= 0 || text.indexOf("email") >= 0) {
          clearEmailChange(record.id, email)
          throw new Error("occupied")
        }
        throw err
      }
      clearEmailChange(record.id, email)
    } else {
      record = findUserByEmail(email)
      if (!record) {
        const collection = e.app.findCollectionByNameOrId("users")
        record = new Record(collection)
        record.setEmail(email)
        record.setRandomPassword()
        if (typeof record.setVerified === "function") {
          record.setVerified(true)
        }
        ensureAccountStatus(record)
        try {
          e.app.save(record)
        } catch (err) {
          const text = str(err).toLowerCase()
          if (text.indexOf("unique") >= 0 || text.indexOf("email") >= 0) {
            throw new Error("occupied")
          }
          throw err
        }
      } else {
        const isVerified =
          typeof record.verified === "function"
            ? record.verified()
            : !!record.get("verified")
        if (!isVerified && typeof record.setVerified === "function") {
          record.setVerified(true)
          ensureAccountStatus(record)
          e.app.save(record)
        }
        try {
          const stored = str($app.store().get("emailChangeUser:" + record.id))
          if (stored && stored !== "null" && stored !== "undefined") {
            const prev = JSON.parse(stored)
            const oldEmail = str(prev && prev.email).trim().toLowerCase()
            if (oldEmail) $app.store().remove("emailChange:" + oldEmail)
            $app.store().remove("emailChangeUser:" + record.id)
          }
        } catch (err) {}
      }
    }
    try {
      $app.store().remove("magicPending:" + otpId)
    } catch (err) {}
    return record.newAuthToken()
  }

  function consumeOtp(otpId, password) {
    var otp = null
    try {
      otp = e.app.findOTPById(otpId)
    } catch (err) {
      throw new Error("not found")
    }
    if (!otp) {
      throw new Error("not found")
    }
    const valid =
      typeof otp.validatePassword === "function"
        ? otp.validatePassword(password)
        : false
    if (!valid) {
      throw new Error("invalid")
    }
    const collectionRef = otpField(otp, "collectionRef", "collectionRef")
    const recordRef = otpField(otp, "recordRef", "recordRef")
    const record = e.app.findRecordById(collectionRef, recordRef)
    const isVerified =
      typeof record.verified === "function"
        ? record.verified()
        : !!record.get("verified")
    if (!isVerified && typeof record.setVerified === "function") {
      record.setVerified(true)
      e.app.save(record)
    }
    const token = record.newAuthToken()
    try {
      e.app.delete(otp)
    } catch (err) {
      try {
        e.app.deleteAllOTPsByRecord(record)
      } catch (err2) {}
    }
    return token
  }

  try {
    const id = readName("id") || readName("otpId")
    const code = readName("code") || readName("password")
    var method = ""
    try {
      method = str(e.request.method).toUpperCase()
    } catch (err) {}

    if (method !== "POST") {
      if (!id || !code) {
        return sendHtml(400, errorPage(INVALID_MSG))
      }
      return sendHtml(200, confirmPage(id, code))
    }

    if (!id || !code) {
      return sendHtml(400, errorPage(INVALID_MSG))
    }
    try {
      var token = consumePending(id, code)
      if (!token) {
        token = consumeOtp(id, code)
      }
      rememberToken(id, token)
      return sendHtml(200, successPage(token))
    } catch (err) {
      logErr(err)
      const text = str(err)
      if (text.indexOf("occupied") >= 0) {
        return sendHtml(400, errorPage(OCCUPIED_MSG))
      }
      if (
        text.indexOf("expired") >= 0 ||
        text.indexOf("invalid") >= 0 ||
        text.indexOf("not found") >= 0
      ) {
        return sendHtml(400, errorPage(EXPIRED_MSG))
      }
      return sendHtml(
        400,
        errorPage("Не удалось завершить вход. Запросите новое письмо в приложении."),
      )
    }
  } catch (err) {
    logErr(err)
    return sendHtml(400, errorPage(INVALID_MSG))
  }
}

function magicRequestHandler(e) {
  const TTL_MS = 10 * 60 * 1000

  function str(value) {
    return value == null ? "" : String(value)
  }

  function htmlEscape(value) {
    return str(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  function queryEscape(value) {
    var s = str(value)
    try {
      if (typeof encodeURIComponent === "function") return encodeURIComponent(s)
    } catch (err) {}
    return s.replace(/[^A-Za-z0-9\-_.~]/g, function (ch) {
      var hex = ch.charCodeAt(0).toString(16).toUpperCase()
      if (hex.length < 2) hex = "0" + hex
      return "%" + hex
    })
  }

  function looksLikeEmail(value) {
    return value.indexOf("@") > 0 && value.indexOf(".") > value.indexOf("@")
  }

  function randomId() {
    try {
      return $security.randomStringWithAlphabet(
        15,
        "abcdefghijklmnopqrstuvwxyz0123456789",
      )
    } catch (err) {}
    var alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    var out = ""
    for (var i = 0; i < 15; i++) {
      out += alphabet.charAt(Math.floor(Math.random() * alphabet.length))
    }
    return out
  }

  function randomCode() {
    try {
      return $security.randomStringWithAlphabet(5, "0123456789")
    } catch (err) {}
    return String(10000 + Math.floor(Math.random() * 90000))
  }

  function appUrl() {
    try {
      const meta = $app.settings().meta || {}
      const url = str(meta.appURL || meta.appUrl).replace(/\/$/, "")
      if (url) return url
    } catch (err) {}
    return "https://pb.booking.vallome.ru"
  }

  function magicLink(otpId, password) {
    return (
      appUrl() +
      "/api/vallome/magic-auth?id=" +
      queryEscape(otpId) +
      "&code=" +
      queryEscape(password)
    )
  }

  function emailHtml(href) {
    return (
      '<!doctype html><html lang="ru"><body style="margin:0;padding:0;background:#ffffff;">' +
      '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#ffffff;">' +
      '<tr><td align="center" style="padding:56px 24px;">' +
      '<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;width:100%;">' +
      '<tr><td align="center" style="font-family:Georgia,\'Times New Roman\',Times,serif;font-size:34px;font-weight:700;color:#111111;letter-spacing:0.04em;padding-bottom:56px;">vallome.booking</td></tr>' +
      '<tr><td align="center" style="font-family:Arial,Helvetica,sans-serif;font-size:28px;color:#1a1a1a;padding-bottom:36px;line-height:1.3;">Уведомление о входе</td></tr>' +
      '<tr><td align="left" style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#4a4a4a;padding-bottom:36px;">Нажмите кнопку ниже, чтобы продолжить.</td></tr>' +
      '<tr><td align="center" style="padding-bottom:48px;">' +
      '<a href="' +
      href +
      '" target="_blank" rel="noopener" style="display:inline-block;background:#6B8AFF;color:#ffffff;text-decoration:none;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.2;padding:14px 40px;border-radius:6px;">Авторизоваться</a>' +
      "</td></tr>" +
      '<tr><td align="left" style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#4a4a4a;">Ссылка действительна 10 минут с момента отправки.</td></tr>' +
      "</table></td></tr></table></body></html>"
    )
  }

  function readEmail() {
    var fromInfo = ""
    try {
      const info = e.requestInfo()
      const body = (info && info.body) || {}
      fromInfo = str(body.email || body.identity || "")
    } catch (err) {}
    var fromForm = ""
    try {
      fromForm = str(e.request.formValue("email"))
    } catch (err) {}
    return (fromInfo || fromForm).trim().toLowerCase()
  }

  function sendMail(email, otpId, password) {
    const link = magicLink(otpId, password)
    const meta = $app.settings().meta || {}
    const message = new MailerMessage({
      from: {
        address: str(meta.senderAddress),
        name: str(meta.senderName || "vallome.booking"),
      },
      to: [{ address: email }],
      subject: "Вход в vallome.booking",
      html: emailHtml(htmlEscape(link)),
      text:
        "vallome.booking\n\nУведомление о входе\n\n" +
        "Нажмите кнопку «Авторизоваться» или откройте ссылку: " +
        link +
        "\n\nСсылка действительна 10 минут с момента отправки.",
    })
    $app.newMailClient().send(message)
  }

  function fail(status, text) {
    return e.json(status, { message: text })
  }

  try {
    const email = readEmail()
    if (!looksLikeEmail(email)) {
      return fail(400, "Введите корректный email")
    }
    const otpId = randomId()
    const code = randomCode()
    var changeUserId = ""
    try {
      const raw = str($app.store().get("emailChange:" + email))
      if (raw && raw !== "null" && raw !== "undefined") {
        const change = JSON.parse(raw)
        if (
          change &&
          str(change.userId) &&
          Number(change.expires || 0) >= Date.now()
        ) {
          var occupier = null
          try {
            occupier = e.app.findAuthRecordByEmail("users", email)
          } catch (err) {}
          try {
            if (!occupier) {
              occupier = e.app.findFirstRecordByFilter(
                "users",
                "email = {:email}",
                { email: email },
              )
            }
          } catch (err) {}
          if (!occupier || occupier.id === str(change.userId)) {
            changeUserId = str(change.userId)
          }
        }
      }
    } catch (err) {}
    $app.store().set(
      "magicPending:" + otpId,
      JSON.stringify({
        email: email,
        code: code,
        expires: Date.now() + TTL_MS,
        userId: changeUserId,
      }),
    )
    sendMail(email, otpId, code)
    return e.json(200, { otpId: otpId })
  } catch (err) {
    console.log("magic-request: " + err)
    try {
      $app.logger().error("magic-request failed", "error", String(err))
    } catch (logErr) {}
    return fail(500, "Не удалось отправить письмо на эту почту")
  }
}

routerAdd("POST", "/api/vallome/magic-request", magicRequestHandler)
routerAdd("GET", "/api/vallome/magic-auth", magicAuthHandler)
routerAdd("POST", "/api/vallome/magic-auth", magicAuthHandler)

routerAdd("GET", "/api/vallome/magic-wait", (e) => {
  function str(value) {
    return value == null ? "" : String(value)
  }

  function readId() {
    try {
      return str(e.request.url.query().get("id")).trim()
    } catch (err) {
      return ""
    }
  }

  try {
    const id = readId()
    if (!id) {
      return e.json(200, { token: "" })
    }
    var token = ""
    try {
      token = str($app.store().get("magicWait:" + id))
    } catch (err) {}
    if (!token || token === "null" || token === "undefined") {
      return e.json(200, { token: "" })
    }
    try {
      $app.store().remove("magicWait:" + id)
    } catch (err) {}
    return e.json(200, { token: token })
  } catch (err) {
    try {
      console.log("magic-wait: " + err)
    } catch (logErr) {}
    return e.json(200, { token: "" })
  }
})
