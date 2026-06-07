# Ubuntu 24.04 host baseline for 6x TF2 + Docker FastDL + host nginx/PHP/MariaDB

This baseline is tuned for:

- Ubuntu 24.04 LTS
- 6 Team Fortress 2 game servers in Docker
- 1 FastDL container in Docker
- nginx + PHP-FPM + MariaDB on the host
- NVMe storage
- 4 vCPU / 16 GB RAM as the reference profile

This host can run 6 TF2 containers, but not 6 heavily loaded public servers with ideal `var`.
For this hardware, the practical target is:

- 2-3 public servers with meaningful player load
- 3-4 low-load private, mix, test, event or reserve servers

If all 6 servers are busy at the same time, CPU contention will be the bottleneck regardless of sysctl tuning.

## CPU layout

For the lowest `var` and more predictable scheduling:

- Reserve CPU `0` for the host, nginx, PHP-FPM, MariaDB and FastDL.
- Pin TF2 containers only to `1`, `2`, `3`.
- Pair two TF2 containers per core.
- Do not use Docker `cpu_quota` / `--cpus` for TF2 unless you must hard-cap abusive tenants.
- Prefer `cpuset-cpus` plus memory limits.

Suggested Pterodactyl CPU layout:

- TF2-1 -> `1`
- TF2-2 -> `2`
- TF2-3 -> `3`
- TF2-4 -> `1`
- TF2-5 -> `2`
- TF2-6 -> `3`

Priority order:

- Put your main public servers on TF2-1, TF2-2, TF2-3.
- Put test, private or event servers on TF2-4, TF2-5, TF2-6.

## Memory layout

Recommended starting points:

- MariaDB `innodb_buffer_pool_size=2G`
- PHP-FPM `pm.max_children=12`
- FastDL container memory: `256M-384M`

Suggested TF2 memory plan:

- 3 primary public servers: `1536M`
- 3 secondary servers: `1024M`

This gives:

- TF2 total: `7680M`
- MariaDB: `2048M`
- FastDL: `256M-384M`
- PHP-FPM + nginx + OS page cache + Docker overhead: enough remaining headroom for a 16 GB host

If all 6 servers are public and busy, lower expectations or move to at least `8 vCPU`.

For TF2 containers, set:

- memory swap = 0 in the panel, or
- Docker memory-swap equal to memory, or
- Docker memory-swappiness = 0.

Host swap recommendation:

- create `2G-4G` swap on SSD
- keep `vm.swappiness=10`
- do not rely on swap as operational memory for TF2

## File placement

Suggested install paths:

- `sysctl-99-tf2-mixed.conf` -> `/etc/sysctl.d/99-tf2-mixed.conf`
- `tf2-qos-backup.sh` -> `/usr/local/sbin/tf2-qos-backup.sh`
- `tf2-qos-setup.sh` -> `/usr/local/sbin/tf2-qos-setup.sh`
- `docker-daemon.json` -> `/etc/docker/daemon.json`
- `systemd/*.override.conf` -> corresponding `systemctl edit <service>`
- `systemd/tf2-qos.service` -> `/etc/systemd/system/tf2-qos.service`
- `nginx-main.conf` -> merge into `/etc/nginx/nginx.conf`
- `nginx-fastdl-proxy.conf` -> `/etc/nginx/sites-available/fastdl.conf`
- `php-fpm-www.conf` -> `/etc/php/8.3/fpm/pool.d/www.conf`
- `z-tf2-mariadb.cnf` -> `/etc/mysql/mariadb.conf.d/z-tf2-mariadb.cnf`
- `fastdl-nginx.conf` -> mount into the FastDL nginx container
- `fastdl-compose.yml` -> optional FastDL container baseline
- `pterodactyl-layout-4vcpu-16gb.md` -> exact TF2 panel allocation plan

## Apply order

1. Copy the sysctl file and run `sudo sysctl --system`.
2. Run the QoS backup script before changing traffic shaping.
3. Install the QoS setup script and systemd unit, then enable it.
4. Install the Docker daemon config and restart Docker.
5. Add the systemd overrides and restart the affected services.
6. Install nginx, PHP-FPM and MariaDB configs.
7. Reload nginx and PHP-FPM, then restart MariaDB.
8. Pin TF2 containers to dedicated CPUs.

## TF2-specific notes

- Keep FastDL files precompressed as `.bz2`; do not re-compress them on the fly.
- Keep SourceMod/Metamod architecture aligned with the actual TF2 binary being launched.
- Avoid CPU overcommit if you care about `var`; scheduler stability matters more than aggressive throughput tuning.
- Traffic priority for TF2 is handled by `tc + iptables` in `tf2-qos-setup.sh`, not by sysctl.
