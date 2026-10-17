#!/usr/bin/env bash
# The game server watched from outside (Underground Fight: Wild 90s, undergroundfightgame.com): GitHub runs this every
# 5 minutes (.github/workflows/check.yml). Down — three tries in a row failed (the API itself and a read from the
# database) — a push to the phone through ntfy (secret NTFY_TOPIC); still down — a reminder every hour; back — «снова
# работает» and how long it was down. state.txt keeps what is known between the runs, OUTAGES.md — every outage.
set -u

SITE="https://undergroundfightgame.com"
STATE="state.txt"
LOG="OUTAGES.md"
REMIND=3600                          # s between the reminders while it is down

now=$(date -u +%s)
stamp() { date -u -d "@$1" +"%Y-%m-%d %H:%M UTC"; }

# One look: the API answers and reads the database.
look() {
  curl -fsS --max-time 20 "$SITE/api/health" | grep -q '"ok":true' &&
    curl -fsS --max-time 20 "$SITE/api/bots/version" | grep -q '"version"'
}

up=0
for i in 1 2 3; do
  if look; then up=1; break; fi
  [ "$i" -lt 3 ] && sleep 15
done

push() {                             # title, message, priority (1–5), tag
  [ -z "${NTFY_TOPIC:-}" ] && { echo "no NTFY_TOPIC"; return; }
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, os, sys, urllib.request
title, msg, prio, tag = sys.argv[1:5]
body = json.dumps({"topic": os.environ["NTFY_TOPIC"], "title": title, "message": msg, "priority": int(prio),
                   "tags": [tag], "click": "https://undergroundfightgame.com/api/health"}).encode()
urllib.request.urlopen(urllib.request.Request("https://ntfy.sh/", data=body,
                       headers={"Content-Type": "application/json"}), timeout=20)
PY
}

status=up; since=0; told=0
[ -f "$STATE" ] && read -r status since told < "$STATE"
mins() { echo $(( ($1 + 59) / 60 )); }

if [ "$up" = 1 ]; then
  if [ "$status" = down ]; then
    took=$(mins $(( now - since )))
    push "Сервер игры снова работает" "undergroundfightgame.com отвечает. Лежал около $took мин (с $(stamp "$since"))." 3 white_check_mark
    [ -f "$LOG" ] || printf '# Падения сервера игры\n\n| Начало | Конец | Минут |\n|---|---|---|\n' > "$LOG"
    echo "| $(stamp "$since") | $(stamp "$now") | $took |" >> "$LOG"
    echo "up $now 0" > "$STATE"
  fi
else
  if [ "$status" != down ]; then
    push "Сервер игры не отвечает" "undergroundfightgame.com не отвечает (3 попытки подряд). Проверь VPS в панели Hostinger." 5 rotating_light
    echo "down $now $now" > "$STATE"
  elif [ $(( now - told )) -ge "$REMIND" ]; then
    push "Сервер игры всё ещё лежит" "Уже около $(mins $(( now - since ))) мин (с $(stamp "$since"))." 4 warning
    echo "down $since $now" > "$STATE"
  fi
fi
echo "status: $( [ "$up" = 1 ] && echo up || echo down )"
