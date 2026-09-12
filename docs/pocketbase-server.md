# PocketBase + Caddy на VPS

Дата: 2026-09-13. Хост: `root@159.194.252.80` (Beget KVM, Ubuntu 26.04, hostname `uohpdtmfxu`).

Домен: **vallome.ru** (зарегистрирован 2026-09-12, Beget; WHOIS `REGISTERED, DELEGATED, UNVERIFIED`). PocketBase только на `https://pb.booking.vallome.ru`. С IP больше не отдаётся.

Сертификаты Let's Encrypt (~90 дней) сняты 2026-09-12 21:22–21:23 UTC на `pb.booking.vallome.ru`, `booking.vallome.ru`, `vallome.ru`, `www.vallome.ru`. Issuer `Let's Encrypt` (CN YE1/YE2).

## Хосты

| Имя | Роль |
| --- | --- |
| `https://pb.booking.vallome.ru` | PocketBase (API + админка `/_/`) |
| `https://booking.vallome.ru` | Заглушка под веб-клиент (Flutter web ещё не выкладывали) |
| `https://vallome.ru`, `https://www.vallome.ru` | 301 → `https://booking.vallome.ru` |
| `http(s)://159.194.252.80` | 301 → `https://pb.booking.vallome.ru{uri}` |

Админка: `https://pb.booking.vallome.ru/_/`  
Health: `https://pb.booking.vallome.ru/api/health`

Клиент — Flutter-приложение, бэкенд в коде ещё не подключён. URL для будущего клиента: `POCKETBASE_URL=https://pb.booking.vallome.ru` в `.env.local` (файл в git не коммитить).

## DNS в Beget (зона `vallome.ru`)

A-записи в панели Beget на месте. Публичные резолверы (8.8.8.8, 1.1.1.1) отдают `159.194.252.80`. NS: `ns1/ns2.beget.com` (+ `.ru` / `.pro`).

До делегирования в зоне `.ru` Let's Encrypt видел NXDOMAIN — Caddy не мог снять cert и рвал TLS (`PR_END_OF_FILE_ERROR` / `tlsv1 alert internal error`). После публикации зоны reload Caddy снял сертификаты (HTTP-01 сначала падал по NXDOMAIN, затем прошёл tls-alpn-01).

Панель Beget → DNS / «DNS-записи» домена `vallome.ru`. Поле **хост** — относительно зоны. Если видите парковочные A/CNAME Beget на чужой IP — удалите их. **AAAA не добавлять**: на eth0 только `159.194.252.80/32`, публичного IPv6 нет. Дубль A у `www` безвреден.

| Тип | Хост (Beget) | FQDN | Значение | TTL |
| --- | --- | --- | --- | --- |
| A | `@` | `vallome.ru` | `159.194.252.80` | 300 |
| A | `booking` | `booking.vallome.ru` | `159.194.252.80` | 300 |
| A | `pb.booking` | `pb.booking.vallome.ru` | `159.194.252.80` | 300 |
| A | `www` | `www.vallome.ru` | `159.194.252.80` | 300 |

`www` необязателен; в Caddy он уже ведёт на `booking.vallome.ru`. Почту Beget не трогать: MX/TXT для mail оставить. WHOIS ещё `UNVERIFIED` — подтвердить домен в кабинете Beget, иначе позже возможны ограничения реестра.

Проверка с своей машины:

```
dig +short A vallome.ru booking.vallome.ru pb.booking.vallome.ru www.vallome.ru
# все четыре → 159.194.252.80
```

## Пути и порты

| Что | Где |
| --- | --- |
| Бинарник PB | `/opt/pocketbase/pocketbase` **0.40.4** |
| Данные PB | `/opt/pocketbase/pb_data` |
| Лог PB | `/var/log/pocketbase/std.log` |
| Юнит PB | `/etc/systemd/system/pocketbase.service` |
| Caddy | `/usr/bin/caddy` **2.11.4** |
| Caddyfile | `/etc/caddy/Caddyfile` |
| Access log Caddy | `/var/log/caddy/access.log` |
| fail2ban | `/etc/fail2ban/jail.local` |
| Бэкап Caddyfile (IP-сайт) | `/etc/caddy/Caddyfile.bak-20260912T193727Z` |
| Заглушка сайта | `/var/www/booking/index.html` |
| Сертификаты | `/var/lib/caddy/.local/share/caddy/certificates/` |
| Юнит Caddy | `/etc/systemd/system/caddy.service` |

Слушают:

- `127.0.0.1:8090` — PocketBase (снаружи не открыт)
- `:80` / `:443` — Caddy
- `127.0.0.1:2019` — админка Caddy
- `:22` — sshd

## PocketBase

```
ExecStart=/opt/pocketbase/pocketbase serve --http=127.0.0.1:8090 --dir=/opt/pocketbase/pb_data
```

Superuser задан через CLI (`mikefro62@gmail.com`). Пароли в репозиторий не копировать.

## Caddyfile

Блок `tls { profile shortlived }` только у IP (старый LE на адрес, ~6 суток). Имена домена — обычный ACME ~90 дней.

JSON access log: `/var/log/caddy/access.log` (ротация Caddy: 20mb × 7). Нужен fail2ban.

```
{
	email mikefro62@gmail.com
}

(accesslog) {
	log {
		output file /var/log/caddy/access.log {
			roll_size 20mb
			roll_keep 7
			roll_keep_for 168h
		}
		format json
	}
}

pb.booking.vallome.ru {
	import accesslog
	encode gzip
	request_body {
		max_size 32MB
	}
	reverse_proxy 127.0.0.1:8090 {
		header_up X-Real-IP {remote_host}
		header_up X-Forwarded-For {remote_host}
		header_up X-Forwarded-Proto {scheme}
		transport http {
			read_timeout 360s
		}
	}
}

booking.vallome.ru {
	import accesslog
	encode gzip
	root * /var/www/booking
	file_server
}

vallome.ru, www.vallome.ru {
	import accesslog
	redir https://booking.vallome.ru{uri} permanent
}

https://159.194.252.80 {
	import accesslog
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			email mikefro62@gmail.com
			profile shortlived
			disable_tlsalpn_challenge
		}
	}
	redir https://pb.booking.vallome.ru{uri} permanent
}

http://159.194.252.80 {
	import accesslog
	redir https://pb.booking.vallome.ru{uri} permanent
}
```

Применить:

```
sudo -u caddy caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

## Проверка

```
ssh root@159.194.252.80
systemctl is-active pocketbase caddy fail2ban
curl -sS http://127.0.0.1:8090/api/health
curl -sS https://pb.booking.vallome.ru/api/health
curl -sSI https://pb.booking.vallome.ru/_/
curl -sSI https://booking.vallome.ru/
curl -sSI https://vallome.ru/              # 301 → https://booking.vallome.ru/
curl -sSI https://159.194.252.80/          # 301 → https://pb.booking.vallome.ru/
curl -sSI https://159.194.252.80/_/        # 301, не тело PB
echo | openssl s_client -connect pb.booking.vallome.ru:443 -servername pb.booking.vallome.ru \
  | openssl x509 -noout -issuer -dates -ext subjectAltName
```

Ожидание: health JSON 200, `/_/` 200, issuer Let's Encrypt, SAN `DNS:pb.booking.vallome.ru`. IP не отдаёт тело PB.

На VPS в `/etc/hosts` прописаны имена зоны → `159.194.252.80` (публичный резолвер Beget зону может не видеть).

## Обновить PocketBase

```
ssh root@159.194.252.80
systemctl stop pocketbase
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p /opt/pocketbase-backups/$STAMP
cp -a /opt/pocketbase/pocketbase /opt/pocketbase-backups/$STAMP/
cp -a /opt/pocketbase/pb_data /opt/pocketbase-backups/$STAMP/
sudo -u pocketbase /opt/pocketbase/pocketbase update
systemctl start pocketbase
/opt/pocketbase/pocketbase --version
```

Либо zip нужной версии в `/tmp`, `sha256sum -c`, `install`, `chown pocketbase:pocketbase`, `systemctl start`.

## Откат Caddy на IP-сайт

```
cp -a /etc/caddy/Caddyfile.bak-20260912T193727Z /etc/caddy/Caddyfile
sudo -u caddy caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

`pb_data` не трогать.

## fail2ban

Был пакет Beget: только `sshd`, бан 10 мин, `ignoreip` пустой. Стало 1.1.0, 4 jail.

| Jail | Триггер | maxretry / окно | Бан |
| --- | --- | --- | --- |
| `sshd` | systemd-журнал `sshd`+`sshd-session`, `mode=extra` | 4 / 10м | 1ч, растёт до 1 нед |
| `caddy-auth` | `400/401/403` на `/api/collections/*/auth-with-password` | 5 / 10м | 1ч |
| `caddy-scan` | `.env`, `.git`, `wp-login`, phpMyAdmin и т.п. + 401/403 на `/api/collections/_superusers` | 6 / 10м | 12ч |
| `recidive` | 3 бана за сутки (по `/var/log/fail2ban.log`) | 3 / 1д | 1 нед, все порты |

`ignoreip`: `127.0.0.0/8`, `::1`, `178.213.115.161` (fox-pc). ACME (`/.well-known/`) фильтр сканера не матчит.

Файлы:

- `/etc/fail2ban/jail.local`
- `/etc/fail2ban/filter.d/caddy-auth.conf`
- `/etc/fail2ban/filter.d/caddy-scan.conf`
- бэкап стока: `/root/fail2ban-backups/20260912T212357Z/`
- банaction как у Beget: `iptables-ipset-proto6` (не nftables из `jail.d/defaults-debian.conf`)

```
fail2ban-client status
fail2ban-client status sshd
fail2ban-client set sshd unbanip A.B.C.D
fail2ban-client set recidive unbanip A.B.C.D
```

Добавить свой IP в whitelist: строка `ignoreip` в `/etc/fail2ban/jail.local`, затем `fail2ban-client reload`.

## Риски

- Диска 8.6G. Бэкапы `pb_data` и логи смотреть.
- UFW выключен: 80/443 открыты, 8090 нет. fail2ban банит точечно, это не firewall.
- Superuser без IP-whitelist и без MFA. SMTP не настроен.
- SSH паролем на root ещё возможен. Секреты в git не коммитить.
- Если IP fox-pc сменится — править `ignoreip`, иначе можно забанить себя с другого адреса (sshd 4 ошибки / 10 мин).
