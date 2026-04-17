# openwrt-aria2

Statically linked [aria2](https://aria2.github.io/) builds for OpenWrt, with OpenSSL and full feature support.

## Features

- **Statically linked** — minimal runtime dependencies on the target device
- **OpenSSL** with TLS 1.3 support (not GnuTLS)
- **Full feature set** — Async DNS (c-ares), BitTorrent, Metalink, SFTP (libssh2), HTTPS, XML-RPC (expat), SQLite
- **Multiple OpenWrt targets** — built per-architecture inside official OpenWrt SDK containers
- **UPX compressed** where safe (auto-skipped on incompatible architectures)
- **Automated upstream tracking** via git submodule + scheduled sync

## Supported Targets

| Phase | Target | OpenSSL Target | UPX |
|-------|--------|---------------|-----|
| 1 | `x86_64` | linux-x86_64 | Yes |
| 1 | `aarch64_generic` | linux-aarch64 | Yes |
| 1 | `arm_cortex-a7` | linux-armv4 | Yes |
| 1 | `mipsel_24kc` | linux-mips32 | Yes |
| 2 | `arm_cortex-a9` | linux-armv4 | Yes |
| 2 | `i386_pentium4` | linux-elf | Yes |
| 2 | `mips_24kc` | linux-mips32 | Yes |
| 2 | `riscv64_generic` | linux64-riscv64 | Skip |
| 3 | `loongarch64_generic` | linux64-loongarch64 | Skip |

## Installation

### From .ipk (recommended)

Download the `.ipk` for your architecture from [Releases](../../releases) and install:

```sh
opkg install aria2-static_*_<arch>.ipk
```

### From feed

Add to `/etc/opkg/customfeeds.conf`:

```
src/gz aria2-static https://<ysway>.github.io/openwrt-aria2
```

Then:

```sh
opkg update
opkg install aria2-static
```

### Direct binary

```sh
wget -O /usr/bin/aria2c https://github.com/<ysway>/openwrt-aria2/releases/latest/download/aria2c-<arch>
chmod +x /usr/bin/aria2c
```

## Configuration

After installation, configure via UCI:

```sh
uci set aria2.main.enabled=1
uci set aria2.main.rpc_secret='your-secret-here'
uci set aria2.main.download_dir='/mnt/data/downloads'
uci commit aria2
/etc/init.d/aria2 enable
/etc/init.d/aria2 start
```

## Architecture

This project uses [AnInsomniacy/aria2-builder](https://github.com/AnInsomniacy/aria2-builder) as a **git submodule and build recipe reference**. It does not use upstream release binaries directly — all binaries are rebuilt inside OpenWrt SDK containers for each target architecture.

### Build Pipeline

```
sync-upstream.yml → build-aria2.yml → release-feed.yml
     (weekly)        (per target)      (publish)
```

1. **sync-upstream.yml** — Updates the submodule pointer on a schedule
2. **build-aria2.yml** — Matrix build across all targets in SDK containers
3. **release-feed.yml** — Aggregates artifacts, publishes release, updates feed branch

### Static Dependencies

Built from source inside each SDK container:

| Library | Version |
|---------|---------|
| zlib | 1.3.1 |
| expat | 2.5.0 |
| c-ares | 1.19.1 |
| SQLite | 3.43.1 |
| OpenSSL | 3.4.4 |
| libssh2 | 1.11.0 |

### Repository Layout

```
openwrt-aria2/
├── .github/workflows/     # CI/CD pipelines
├── aria2-builder/          # git submodule (upstream reference)
├── build_scripts/          # Build, verify, package scripts
├── package/aria2-static/   # OpenWrt package definition
├── feed_template/          # Feed index template
├── setup.sh                # Quick installer (named setup.sh to avoid autotools conflict)
└── README.md
```

## Design Decisions

- **Static over dynamic**: The official OpenWrt `aria2` package uses dynamic linking. This project intentionally produces self-contained binaries to minimize firmware dependency issues.
- **OpenSSL only**: No GnuTLS fallback. OpenSSL provides TLS 1.3 and is the upstream reference choice.
- **UPX with safety net**: Compression is attempted but never blindly applied. Known-bad architectures (mips64, riscv64, loongarch64) are skipped. Failed packing restores the original binary.
- **Verification per target**: Every build checks linkage (readelf/ldd) and runs functional tests where possible.

## License

aria2 is licensed under GPL-2.0-or-later. This packaging project follows the same license.
