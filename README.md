# pterodactyl-srcds-ubuntu2404

**Pterodactyl Docker image для Source Engine серверов на базе Ubuntu 24.04 Noble**

Оптимизирован для: TF2, CS:S, Garry's Mod, L4D2, Insurgency и других SRCDS-игр.

---

## Образ

```
ghcr.io/<ваш_username>/steamcmd:ubuntu_24.04_srcds
```

---

## Что внутри

| Компонент | Версия / описание |
|---|---|
| **Base OS** | Ubuntu 24.04 LTS (Noble Numbat) |
| **32-bit libs** | `lib32gcc-s1`, `lib32stdc++6`, `libc6-i386`, `libcurl4:i386`, `libsdl2:i386`, `libopenal1:i386`, `libncurses6:i386`, `libfontconfig1:i386`, `libfreetype6:i386` |
| **64-bit libs** | Полный набор для 64-bit расширений и нативных плагинов |
| **SteamCMD** | Скачивается при первом старте (или в install-скрипте egg) |
| **tini** | PID 1, корректная обработка сигналов |
| **rcon-cli** | `v0.10.3` — удалённое управление сервером |
| **Python 3** | Для скриптов игровых серверов |
| **Сетевые инструменты** | `curl`, `wget`, `iproute2`, `net-tools`, `dnsutils`, `iputils-ping` |

---

## Переменные среды (Pterodactyl Egg)

| Переменная | По умолчанию | Описание |
|---|---|---|
| `SRCDS_APPID` | — | Steam AppID сервера (232250 = TF2, 232330 = CSS, 4020 = GMod) |
| `AUTO_UPDATE` | `1` | Обновлять сервер через SteamCMD при старте |
| `VALIDATE` | `0` | `1` = проверка файлов (медленнее, надёжнее) |
| `STEAM_USER` | — | Логин Steam (оставить пустым для анонима) |
| `STEAM_PASS` | — | Пароль Steam |
| `SRCDS_BETAID` | — | Название beta-ветки |
| `SRCDS_BETAPASS` | — | Пароль beta-ветки |
| `HLDS_GAME` | — | Мод для GoldSrc серверов (например, `cstrike`) |
| `SOURCEMOD` | `0` | `1` = авто-установка SourceMod + MetaMod |
| `SM_GAME` | — | Папка игры для SM (`tf`, `cstrike`, `garrysmod`, `left4dead2`) |
| `SM_VERSION` | `1.12` | Версия SourceMod |
| `MM_VERSION` | `1.12` | Версия MetaMod:Source |
| `STARTUP` | — | Команда запуска (Pterodactyl подставляет автоматически) |

---

## Пример STARTUP команды для TF2

```
./srcds_run -game tf -console -port {{SERVER_PORT}} +map {{SRCDS_MAP}} +ip 0.0.0.0 -strictportbind -norestart +sv_setsteamaccount {{STEAM_ACC}} +maxplayers {{MAXPLAYERS}}
```

---

## Настройка сети (хост)

Образ включает файл `sysctl-gameserver.conf` с оптимизациями сети.  
Применить на хосте (Docker node):

```bash
sudo cp sysctl-gameserver.conf /etc/sysctl.d/99-gameserver.conf
sudo sysctl --system
```

Ключевые оптимизации:
- UDP буферы увеличены до **25–64 МБ** (критично для SRCDS)
- TCP congestion control: **BBR** (меньше задержки)
- `tcp_nodelay = 1` — отключает алгоритм Nagle (нужен для игровых пакетов)
- Расширен диапазон портов: `1024–65535`
- `nf_conntrack_max = 131072` — поддержка большого числа игроков

---

## Сборка локально

```bash
docker build -t srcds-ubuntu2404 .
```

---

## AppID справочник

| Игра | AppID |
|---|---|
| Team Fortress 2 | 232250 |
| Counter-Strike: Source | 232330 |
| Garry's Mod | 4020 |
| Left 4 Dead 2 | 222860 |
| Insurgency (2014) | 237410 |
| Day of Defeat: Source | 232290 |
| Half-Life 2: Deathmatch | 232370 |

---

## Структура репозитория

```
.
├── Dockerfile                  # Основной образ
├── entrypoint.sh               # Pterodactyl-совместимый entrypoint
├── sysctl-gameserver.conf      # Сетевые оптимизации (применять на хосте)
├── limits-gameserver.conf      # ulimit для пользователя container
├── .github/
│   └── workflows/
│       └── build.yml           # GitHub Actions CI/CD
└── README.md
```
