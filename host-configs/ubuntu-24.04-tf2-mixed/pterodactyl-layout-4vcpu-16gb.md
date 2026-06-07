# Pterodactyl layout for 4 vCPU / 16 GB RAM

This layout is designed for one VPS that runs:

- 6 TF2 containers
- 1 FastDL container
- host nginx
- host PHP-FPM
- host MariaDB

## CPU pinning

Reserve CPU `0` for:

- kernel work
- nginx
- PHP-FPM
- MariaDB
- FastDL container
- Docker housekeeping

Pin TF2 servers like this:

| Server | CPU | RAM |
| --- | --- | --- |
| TF2-1 main public | `1` | `1536M` |
| TF2-2 main public | `2` | `1536M` |
| TF2-3 main public | `3` | `1536M` |
| TF2-4 secondary | `1` | `1024M` |
| TF2-5 secondary | `2` | `1024M` |
| TF2-6 secondary | `3` | `1024M` |

## Operational guidance

- Do not schedule all 6 servers as high-pop public servers.
- Use TF2-4, TF2-5 and TF2-6 for private lobbies, jump, event, mix or low-pop modes.
- If `var` spikes during peak time, move the noisiest secondary server off the machine before touching sysctl again.
- If your site is busy, consider moving MariaDB to a separate VPS before adding more TF2 capacity.

## Panel memory policy

Recommended:

- primary public servers: `1536M`
- secondary servers: `1024M`
- swap for TF2 containers: disabled

Do not set all 6 TF2 servers to `2G` each on this host. That will squeeze page cache and increase latency under mixed load.
