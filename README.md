# uptime

Внешняя проверка снаружи, не с самих серверов: если ляжет машина у хостинга, проверка останется жива.

- сервер игры «Подпольные бои: Лихие 90-е» (https://undergroundfightgame.com) — `/api/health` и чтение из базы
  (`/api/bots/version`); файлы `state.txt`, `OUTAGES.md`;
- сайт https://theway4you.co.uk — главная и страница консультации (слоты из базы); `state-theway.txt`,
  `OUTAGES-theway.md`;
- сайт https://tcampo.com — главная с формой; `state-tcampo.txt`, `OUTAGES-tcampo.md`;
- сайт https://idlecoin.pro — главная; `state-idlecoin.txt`, `OUTAGES-idlecoin.md`;
- сайт https://qaprovider.com — главная; `state-qaprovider.txt`, `OUTAGES-qaprovider.md`;
- сайт https://sabostack.com — главная; `state-sabostack.txt`, `OUTAGES-sabostack.md`.

The Way и TCampo живут на одном VPS (Hostinger srv452300), игра — на другом.

- **Раз в 5 минут** GitHub запускает `check.sh` (`.github/workflows/check.yml`), по каждому — три попытки подряд.
- **Лёг** — пуш на телефон через [ntfy](https://ntfy.sh) («Сервер игры не отвечает», «Сайт The Way не отвечает», …), пока лежит — напоминание раз в
  час; **поднялся** — «снова работает» и сколько лежал. Канал ntfy — в секрете репозитория `NTFY_TOPIC`.
- `state*.txt` — что известно между запусками (`up|down`, с какого времени, когда напоминали), `OUTAGES*.md` — все
  падения, `alive.txt` — раз в 20 дней, чтобы GitHub не выключил расписание (он выключает его через 60 дней без
  коммитов).
- Проверить руками: вкладка **Actions** → **check** → **Run workflow**.
