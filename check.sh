#!/usr/bin/env bash
# Sites watched from outside: GitHub runs this every 5 minutes (.github/workflows/check.yml).
#   game   — Underground Fight: Wild 90s, undergroundfightgame.com: the API itself and a read from the database;
#   theway — theway4you.co.uk: the home page and the consultation page (its slots come from the database);
#   tcampo — tcampo.com: the home page with the contact form.
# theway and tcampo live on one VPS (Hostinger srv452300), the game on another.
# Down — three tries in a row failed — a push to the phone through ntfy (secret NTFY_TOPIC); still down — a reminder
# every hour; back — «снова работает» and how long it was down. state*.txt keeps what is known between the runs,
# OUTAGES*.md — every outage. The game keeps its old files (state.txt, OUTAGES.md).
set -u

REMIND=3600                          # s between the reminders while it is down
now=$(date -u +%s)
stamp() { date -u -d "@$1" +"%Y-%m-%d %H:%M UTC"; }
mins() { echo $(( ($1 + 59) / 60 )); }

# page URL, text that must be on it (a broken PHP/DB gives a 500 or an empty page)
page() { curl -fsSL --max-time 20 -A "uptime-check" "$1" | grep -q "$2"; }

look_game() {
  curl -fsS --max-time 20 "https://undergroundfightgame.com/api/health" | grep -q '"ok":true' &&
    curl -fsS --max-time 20 "https://undergroundfightgame.com/api/bots/version" | grep -q '"version"'
}
look_theway() {
  page "https://theway4you.co.uk/" "theway4you" &&
    page "https://theway4you.co.uk/pervichnaja-konsultatsija-psihologa-v-londone" "chooseConsTypeTab"
}
look_tcampo() { page "https://tcampo.com/" "contactForm"; }

push() {                             # title, message, priority (1–5), tag, click URL
  [ -z "${NTFY_TOPIC:-}" ] && { echo "no NTFY_TOPIC"; return; }
  python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import json, os, sys, urllib.request
title, msg, prio, tag, click = sys.argv[1:6]
body = json.dumps({"topic": os.environ["NTFY_TOPIC"], "title": title, "message": msg, "priority": int(prio),
                   "tags": [tag], "click": click}).encode()
urllib.request.urlopen(urllib.request.Request("https://ntfy.sh/", data=body,
                       headers={"Content-Type": "application/json"}), timeout=20)
PY
}

# key, name in the pushes, host, click URL, what to check in the panel, state file, outages file
watch() {
  local key=$1 name=$2 host=$3 click=$4 hint=$5 state=$6 log=$7
  local up=0 i status=up since=0 told=0 took
  for i in 1 2 3; do
    if "look_$key"; then up=1; break; fi
    [ "$i" -lt 3 ] && sleep 15
  done
  [ -f "$state" ] && read -r status since told < "$state"
  if [ "$up" = 1 ]; then
    if [ "$status" = down ]; then
      took=$(mins $(( now - since )))
      push "$name снова работает" "$host отвечает. Лежал около $took мин (с $(stamp "$since"))." 3 white_check_mark "$click"
      [ -f "$log" ] || printf '# Падения: %s\n\n| Начало | Конец | Минут |\n|---|---|---|\n' "$host" > "$log"
      echo "| $(stamp "$since") | $(stamp "$now") | $took |" >> "$log"
      echo "up $now 0" > "$state"
    fi
  else
    if [ "$status" != down ]; then
      push "$name не отвечает" "$host не отвечает (3 попытки подряд). $hint" 5 rotating_light "$click"
      echo "down $now $now" > "$state"
    elif [ $(( now - told )) -ge "$REMIND" ]; then
      push "$name всё ещё лежит" "Уже около $(mins $(( now - since ))) мин (с $(stamp "$since"))." 4 warning "$click"
      echo "down $since $now" > "$state"
    fi
  fi
  echo "$key: $( [ "$up" = 1 ] && echo up || echo down )"
}

# the three run side by side, so one slow site does not hold up the others
watch game "Сервер игры" undergroundfightgame.com "https://undergroundfightgame.com/api/health" \
  "Проверь VPS в панели Hostinger." state.txt OUTAGES.md &
watch theway "Сайт The Way" theway4you.co.uk "https://theway4you.co.uk/" \
  "Проверь VPS srv452300 в панели Hostinger." state-theway.txt OUTAGES-theway.md &
watch tcampo "Сайт TCampo" tcampo.com "https://tcampo.com/" \
  "Проверь VPS srv452300 в панели Hostinger." state-tcampo.txt OUTAGES-tcampo.md &
wait
