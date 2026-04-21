# openwrt-aria2

[![Build aria2](https://github.com/ysway/openwrt-aria2/actions/workflows/build-aria2.yml/badge.svg)](https://github.com/ysway/openwrt-aria2/actions/workflows/build-aria2.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Statically linked [aria2](https://aria2.github.io/) builds for [OpenWrt](https://openwrt.org/), compiled with OpenSSL and full feature support across 33 target architectures. Releases publish versioned `.ipk`, `.apk`, and raw `aria2c` assets, while the `feed` branch serves a GitHub Pages landing page plus per-architecture OPKG metadata.

## Features

- **Fully static binaries** — zero runtime library dependencies on the target device
- **OpenSSL 3.4** with TLS 1.3 support
- **Full protocol support** — HTTP(S), FTP, SFTP (libssh2), BitTorrent, Metalink, XML-RPC
- **Async DNS** via c-ares
- **33 OpenWrt target architectures** — built inside official OpenWrt SDK containers
- **UPX compressed** where safe (auto-skipped on mips64, riscv64, loongarch64)
- **Dual package format** — `.ipk` (OpenWrt ≤24.10) and `.apk` (OpenWrt ≥25.12)
- **Automated upstream tracking** — daily checks for new `aria2-builder` tagged releases via git submodule

## Supported Architectures

<details>
<summary>All 33 target platforms (click to expand)</summary>

| Architecture | Platforms | UPX | SDK |
|:---|:---|:---:|:---:|
| **AArch64** | `aarch64_cortex-a53`, `aarch64_cortex-a72`, `aarch64_cortex-a76`, `aarch64_generic` | ✅ | 24.10 |
| **ARM** | `arm_arm1176jzf-s_vfp`, `arm_arm926ej-s`, `arm_cortex-a15_neon-vfpv4`, `arm_cortex-a5_vfpv4`, `arm_cortex-a7`, `arm_cortex-a7_neon-vfpv4`, `arm_cortex-a7_vfpv4`, `arm_cortex-a8_vfpv3`, `arm_cortex-a9`, `arm_cortex-a9_neon`, `arm_cortex-a9_vfpv3-d16`, `arm_fa526`, `arm_xscale` | ✅ | 24.10 |
| **x86** | `i386_pentium-mmx`, `i386_pentium4` | ✅ | 24.10 |
| **x86_64** | `x86_64` | ✅ | 24.10 |
| **MIPS** | `mips_24kc`, `mips_4kec`, `mips_mips32` | ✅ | 24.10 |
| **MIPS-EL** | `mipsel_24kc`, `mipsel_24kc_24kf`, `mipsel_74kc`, `mipsel_mips32` | ✅ | 24.10 |
| **MIPS64** | `mips64_mips64r2`, `mips64_octeonplus` | ❌ | 24.10 |
| **MIPS64-EL** | `mips64el_mips64r2` | ❌ | 24.10 |
| **RISC-V 64** | `riscv64_riscv64` | ❌ | 24.10 |
| **RISC-V 64** | `riscv64_generic` | ❌ | 25.12 |
| **LoongArch64** | `loongarch64_generic` | ❌ | 24.10 |

</details>

### Check your architecture

```bash
# OpenWrt 24.10 or earlier
opkg print-architecture | awk 'NF==3 && $3~/^[0-9]+$/ {print $2}' | tail -1

# OpenWrt 25.12 or later
cat /etc/apk/arch
```

## Installation

### Published artifact names

- `aria2-static_<version>_<arch>.ipk` — release IPK package for OpenWrt 24.10 and older
- `aria2-static_<version>_<arch>.apk` — release APK package for OpenWrt 25.12 and newer
- `aria2c_<version>_<arch>` — raw binary for manual deployment

The `feed` branch keeps per-architecture directories with `Packages`, `Packages.gz`, `BUILDINFO`, the raw `aria2c` binary, and any matching package files.
GitHub Releases in this repository are tagged as `v<aria2-version>`, matching the upstream aria2 release tag.

### Option 1: Download the matching `.ipk` from Releases (recommended for OpenWrt ≤24.10)

```bash
VERSION="<version>"
ARCH="$(opkg print-architecture | awk 'NF==3 && $3~/^[0-9]+$/ {print $2}' | tail -1)"

wget "https://github.com/ysway/openwrt-aria2/releases/download/v${VERSION}/aria2-static_${VERSION}_${ARCH}.ipk"
opkg install "aria2-static_${VERSION}_${ARCH}.ipk"
```

### Option 2: Download the matching `.apk` from Releases (OpenWrt ≥25.12)

```bash
VERSION="<version>"
ARCH="$(cat /etc/apk/arch)"

wget "https://github.com/ysway/openwrt-aria2/releases/download/v${VERSION}/aria2-static_${VERSION}_${ARCH}.apk"
apk add --allow-untrusted "aria2-static_${VERSION}_${ARCH}.apk"
```

### Option 3: Use the package feed (OpenWrt ≤24.10 / opkg)

The repository publishes a GitHub Pages feed from the `feed` branch.
Each target has its own platform-specific feed directory containing the `.ipk`,
`Packages`, `Packages.gz`, and `BUILDINFO` files.

Use your exact OpenWrt architecture as the last path segment:

```bash
# Example: x86_64
echo 'src/gz aria2-static https://ysway.github.io/openwrt-aria2/x86_64' >> /etc/opkg/customfeeds.conf

# Example: aarch64_cortex-a53
echo 'src/gz aria2-static https://ysway.github.io/openwrt-aria2/aarch64_cortex-a53' >> /etc/opkg/customfeeds.conf

opkg update
opkg install aria2-static
```

The site root at [`https://ysway.github.io/openwrt-aria2/`](https://ysway.github.io/openwrt-aria2/) is a landing page with per-architecture file tables and checksums, not an `opkg` feed URL by itself.

### Option 4: Setup helper script

```bash
wget -O- https://raw.githubusercontent.com/ysway/openwrt-aria2/master/setup.sh | sh
```

The helper resolves the latest release tag, detects whether the device uses `opkg` or `apk`, and installs the matching package. If neither package manager is available, it falls back to the raw `aria2c` binary.

### Option 5: Direct binary

```bash
VERSION="<version>"
ARCH="x86_64"

wget -O /usr/bin/aria2c "https://github.com/ysway/openwrt-aria2/releases/download/v${VERSION}/aria2c_${VERSION}_${ARCH}"
chmod +x /usr/bin/aria2c
```

Use the raw binary path only if you do not want the OpenWrt package metadata, init script, or default UCI config.

## Configuration

After installation, configure via UCI:

```bash
uci set aria2.main.enabled=1
uci set aria2.main.rpc_secret='your-secret-here'
uci set aria2.main.download_dir='/mnt/data/downloads'
uci commit aria2
/etc/init.d/aria2 enable
/etc/init.d/aria2 start
```

Default configuration is in `/etc/config/aria2`. The init script starts aria2 with JSON-RPC enabled on port 6800.

## Feed Notes

- The GitHub Pages root publishes a landing page generated from `feed_template/` and filled during CI with per-architecture tables.
- OPKG feed metadata is generated per platform, so `.ipk` packages can be installed directly from `https://ysway.github.io/openwrt-aria2/<arch>`.
- `.apk` packages are mirrored in the feed directories and attached to GitHub Releases, but there is not yet a signed APK repository index for `apk add` by URL.
- If you fork this repository and want the feed to work, enable GitHub Pages for the `feed` branch in repository settings.

## How It Works

### Build Pipeline

```
sync-upstream.yml (daily cron / manual on ubuntu-slim)
  └─ Detects new aria2-builder tagged release
  └─ Pins the submodule to that release tag
  └─ Triggers build via repository_dispatch
       │
       ▼
build-aria2.yml (manual / repository_dispatch)
  └─ docker run inside official OpenWrt SDK container
  └─ Build static deps → Build aria2 → Verify → UPX → Package
  └─ Upload artifacts per target
       │
       ├─► deploy job: push to feed branch (GitHub Pages)
       └─► release job: create or update GitHub Release tagged v<aria2-version>
```

### Static Dependencies

All libraries are built from source as static archives inside each SDK container:

| Library | Version | Purpose |
|:---|:---|:---|
| zlib | 1.3.1 | Compression |
| expat | 2.5.0 | XML parsing (XML-RPC) |
| c-ares | 1.19.1 | Async DNS resolution |
| SQLite | 3.43.1 (3430100) | Download session persistence |
| OpenSSL | 3.4.4 | TLS 1.3, HTTPS, crypto |
| libssh2 | 1.11.0 | SFTP support |

## Local Development

### Prerequisites

- Docker
- Git with submodule support

### Build a single target locally

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/ysway/openwrt-aria2.git
cd openwrt-aria2

# Build for aarch64_cortex-a53 (or any supported platform)
PLATFORM="aarch64_cortex-a53"
SDK_VERSION="24.10.4"

mkdir -p output

docker run --rm --user root \
  -v "$(pwd):/work/repo:z" \
  -v "$(pwd)/output:/work/output:z" \
  -e PLATFORM="$PLATFORM" \
  -e OPENWRT_SDK_VERSION="$SDK_VERSION" \
  -e BUILD_VERSION="local" \
  -e TERM=xterm \
  "ghcr.io/openwrt/sdk:${PLATFORM}-V${SDK_VERSION}" \
  bash /work/repo/build_scripts/build_in_sdk.sh "$PLATFORM"
```

Output will be in `output/<platform>/`:
- `aria2c` — statically linked binary (UPX compressed if supported)
- `aria2-static_<ver>-1_<platform>.ipk` — local OpenWrt IPK package
- `aria2-static-<ver>-r1.apk` — OpenWrt APK package
- `BUILDINFO` — build metadata

The release job renames the published assets to `aria2-static_<version>_<platform>.ipk`, `aria2-static_<version>_<platform>.apk`, and `aria2c_<version>_<platform>`.

### Build for the 25.12 SDK

For platforms only available in the 25.12 SDK (e.g., `riscv64_generic`):

```bash
PLATFORM="riscv64_generic"
SDK_VERSION="25.12.0"

docker run --rm --user root \
  -v "$(pwd):/work/repo:z" \
  -v "$(pwd)/output:/work/output:z" \
  -e PLATFORM="$PLATFORM" \
  -e OPENWRT_SDK_VERSION="$SDK_VERSION" \
  -e BUILD_VERSION="local" \
  -e TERM=xterm \
  "ghcr.io/openwrt/sdk:${PLATFORM}-V${SDK_VERSION}" \
  bash /work/repo/build_scripts/build_in_sdk.sh "$PLATFORM"
```

### Build scripts overview

| Script | Purpose |
|:---|:---|
| `build_in_sdk.sh` | Container entrypoint — orchestrates the full pipeline |
| `common.sh` | Shared variables and helper functions |
| `versions.sh` | Dependency version pins |
| `target-map.sh` | Platform → compiler triple + OpenSSL target mapping |
| `build_deps_static.sh` | Build all static libraries |
| `build_static_aria2.sh` | Configure and compile aria2 |
| `verify_binary.sh` | Linkage and functional verification |
| `pack_with_upx.sh` | UPX compression with safety checks |
| `collect_artifacts.sh` | BUILDINFO generation |
| `build_ipk.sh` | IPK package assembly |
| `build_apk.sh` | APK v2 package assembly |
| `gen_feed.sh` | Feed index generation |

## Repository Structure

```
openwrt-aria2/
├── .github/workflows/
│   ├── sync-upstream.yml       # Daily upstream submodule check
│   └── build-aria2.yml         # Build + Deploy + Release (consolidated)
├── aria2-builder/               # Git submodule → AnInsomniacy/aria2-builder
├── build_scripts/               # All build, verify, and packaging scripts
├── package/aria2-static/        # OpenWrt package definition (Makefile, init script, UCI config)
├── feed_template/
│   ├── index.html              # GitHub Pages landing page template
│   └── style.css               # GitHub Pages landing page styles
├── setup.sh                     # Quick installer for OpenWrt devices
├── LICENSE                      # MIT (build scripts); GPL-2.0 (aria2 binaries)
└── README.md
```

## Design Decisions

- **Static over dynamic**: The official OpenWrt `aria2` package uses dynamic linking. This project produces self-contained binaries to eliminate firmware dependency issues.
- **OpenSSL only**: No GnuTLS fallback. OpenSSL provides TLS 1.3 and is the upstream reference choice.
- **UPX with safety net**: Compression is attempted with integrity testing. Known-incompatible architectures (mips64, riscv64, loongarch64) are automatically skipped. Failed packing restores the original binary.
- **Verification per target**: Every build checks linkage via `readelf`/`ldd` and runs functional tests where possible.
- **`docker run` pattern**: Build jobs use `docker run` from `ubuntu-latest` runners, not the GitHub Actions `container:` directive (which has context evaluation limitations with OpenWrt SDK images).
- **Lightweight sync runner**: `sync-upstream.yml` uses `ubuntu-slim` because it only needs Git, submodule updates, and the repository dispatch API.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally using the [Docker build instructions](#build-a-single-target-locally) above
4. Submit a pull request

### Key things to know

- `aria2-builder/` is a **git submodule** — do not edit files inside it directly
- Build scripts are in `build_scripts/` — the entrypoint is `build_in_sdk.sh`
- Target mapping uses wildcard patterns in `target-map.sh` with auto-detection from SDK toolchain
- The file `setup.sh` is intentionally **not** named `install.sh` — autotools' `AC_CONFIG_AUX_DIR` macro searches parent directories for `install.sh`, which would break the aria2 build system

## Acknowledgements

- **[aria2](https://github.com/aria2/aria2)** — The excellent multi-protocol download utility by Tatsuhiro Tsujikawa and contributors. Licensed under GPL-2.0-or-later.
- **[AnInsomniacy/aria2-builder](https://github.com/AnInsomniacy/aria2-builder)** — Static build recipes and cross-platform CI configuration for aria2. Used as a git submodule and build reference for this project.
- **[GuNanOvO/openwrt-tailscale](https://github.com/GuNanOvO/openwrt-tailscale)** — Proven CI/CD pattern for building software inside OpenWrt SDK Docker containers. The `docker run` workflow architecture, target matrix, and release/feed strategy in this project are modeled after openwrt-tailscale.
- **[OpenWrt](https://openwrt.org/)** — The official OpenWrt SDK Docker images (`ghcr.io/openwrt/sdk`) make cross-compilation for 33+ target architectures possible.

## License

The build scripts, CI/CD configuration, and packaging infrastructure in this repository are licensed under the [MIT License](LICENSE).

The aria2 binaries produced by this project are licensed under [GPL-2.0-or-later](https://github.com/aria2/aria2/blob/master/COPYING), following the upstream aria2 license.
