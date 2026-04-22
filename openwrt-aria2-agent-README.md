# openwrt-aria2 Agent README

## Purpose

This document is a verified implementation brief for the `openwrt-aria2` project that:

- tracks `AnInsomniacy/aria2-builder` as an upstream **git submodule**,
- uses its **Linux static-build flow** as the reference sample,
- rebuilds `aria2c` for **multiple OpenWrt targets** using the `docker run` pattern with OpenWrt SDK containers (NOT the `container:` directive),
- links third-party libraries **statically**,
- uses **OpenSSL** rather than GnuTLS,
- compresses final binaries with **UPX** when safe,
- publishes OpenWrt-ready artifacts, a GitHub Release, and a feed branch.

---

## Architecture: Proven CI/CD Pattern

The CI/CD architecture is modeled after `GuNanOvO/openwrt-tailscale`, a proven working project.

### Critical Design Decision: `docker run` vs `container:`

**DO NOT use the GitHub Actions `container:` directive** with OpenWrt SDK images. This approach fails because:

1. The `container.image` field cannot use `env` context — GitHub Actions evaluates `container` before `env` is available at job level.
2. Running `apt-get` inside the SDK container via the `container:` directive is fragile and slow.
3. The `container:` approach limits available GitHub Actions contexts and causes expression evaluation issues.

**Instead, use the `docker run` command** from an `ubuntu-latest` runner for build jobs. Lightweight Git-only automation such as `sync-upstream.yml` can use `ubuntu-slim`:

```yaml
# CORRECT: docker run from host runner for build jobs
runs-on: ubuntu-latest
steps:
  - name: Build in SDK Container
    run: |
      docker run --rm --user root \
        -v "$(pwd)/repo:/work/repo:z" \
        -v "$(pwd)/output:/work/output:z" \
        -e PLATFORM=${{ matrix.platform }} \
        ghcr.io/openwrt/sdk:${{ matrix.platform }}-V${{ env.OPENWRT_IPK_SDK }} \
        bash /work/repo/build_scripts/build_in_sdk.sh "${{ matrix.platform }}"
```

This pattern is proven by `openwrt-tailscale` and avoids all context evaluation issues.

### SDK Image Tag Format

OpenWrt SDK Docker images use **uppercase `-V`** in tags:

```
ghcr.io/openwrt/sdk:<platform>-V<version>
```

Example: `ghcr.io/openwrt/sdk:x86_64-V24.10.4`

**NOT lowercase `-v`** (this was a bug in the original implementation).

### Workflow Trigger Chain

```
sync-upstream.yml (schedule/manual on ubuntu-slim)
  → detects new aria2-builder tagged release
  → pushes submodule update
  → triggers build via repository_dispatch

build-aria2.yml (manual / repository_dispatch)
  → build job: matrix build across all targets via docker run
  → deploy job: updates feed branch
  → release job: creates or updates the GitHub Release tagged with the upstream aria2 version
```

---

## Verified Facts from Upstream Sources

### A. What `aria2-builder` Actually Does

`AnInsomniacy/aria2-builder` provides cross-platform statically linked aria2 builds. For Linux, published support:

- `Linux x86_64` with `OpenSSL` and `Fully static`
- `Linux ARM64` with `OpenSSL` and `Fully static`

It does **not** claim OpenWrt target coverage. It is a useful static-build reference, but not a direct OpenWrt artifact source.

### B. Linux Build Pattern from `aria2-builder`

The build pattern is:

1. Build dependencies from source as static libraries (zlib, expat, c-ares, SQLite, OpenSSL, libssh2).
2. Build OpenSSL with `./Configure <target> no-shared no-module no-tests`.
3. Build `libssh2` with `--with-crypto=openssl --with-libssl-prefix=$PREFIX`.
4. Build `aria2` with `--without-gnutls --with-openssl`, `ARIA2_STATIC=yes`, `-static -static-libgcc -static-libstdc++`.
5. Strip the resulting binary.

### C. What `openwrt-tailscale` Proves

The `openwrt-tailscale` project validates the following reusable pattern:

1. **`docker run` from `ubuntu-latest` for build jobs** — NOT the `container:` directive.
2. **Volume mounts** to pass scripts, sources, and outputs between host and SDK container.
3. **SDK image format**: `ghcr.io/openwrt/sdk:<platform>-V<version>` (capital V).
4. **Version checking workflow**: scheduled checks for upstream updates, triggers build via `repository_dispatch`.
5. **Single consolidated workflow**: build → deploy feed → create release, all in one workflow file.
6. **UPX conditional**: disabled for `mips64*`, `riscv64*`, `loongarch64*` architectures.
7. **`--user root`** when needed for installing packages inside the container.
8. **`:z` SELinux suffix** on volume mounts for container compatibility.

---

## Corrections to Earlier Assumptions

### 1. "All OpenWrt targets will be fully static."
Not proven. Treat static linking as the goal, verify per target, fail or mark unsupported when a target cannot satisfy the requirement.

### 2. "The exact Linux workflow can be copied unchanged into OpenWrt SDK."
Not proven. Reuse the dependency set and feature choices, but adapt compiler, target triple, sysroot, and OpenSSL Configure target per OpenWrt platform.

### 3. "UPX should always run."
Not safe. Maintain a skip list for known-bad architectures (`mips64*`, `mips64el*`, `riscv64*`, `loongarch64*`).

### 4. "Use `container:` directive for SDK builds."
**Incorrect and the root cause of workflow failures.** Use `docker run` from the host runner instead.

### 5. "SDK tags use lowercase `-v`."
**Incorrect.** SDK tags use uppercase `-V` (e.g., `-V24.10.4`).

---

## Repository Layout

```text
openwrt-aria2/
├── .gitmodules
├── .github/
│   └── workflows/
│       ├── sync-upstream.yml      # Daily upstream check + trigger build
│       └── build-aria2.yml        # Build + Deploy Feed + Release (consolidated)
├── aria2-builder/                  # git submodule → AnInsomniacy/aria2-builder
├── build_scripts/
│   ├── common.sh                  # Shared helpers
│   ├── versions.sh                # Dependency version pins
│   ├── target-map.sh              # Platform → compiler triple mapping
│   ├── build_in_sdk.sh            # SDK container entrypoint (NEW)
│   ├── build_deps_static.sh       # Build all static dependencies
│   ├── build_static_aria2.sh      # Build aria2 binary
│   ├── verify_binary.sh           # Linkage + functional verification
│   ├── pack_with_upx.sh           # UPX compression
│   ├── build_ipk.sh               # .ipk package assembly
│   ├── build_apk.sh               # .apk package assembly (OpenWrt 25.12+)
│   ├── collect_artifacts.sh        # Artifact + BUILDINFO collection
│   └── gen_feed.sh                # Feed index generation
├── package/
│   └── aria2-static/
│       ├── Makefile
│       └── files/
│           ├── aria2.init
│           └── aria2.conf
├── feed_template/
│   ├── index.html
│   └── style.css
├── setup.sh
└── README.md
```

## Design Rules

1. `aria2-builder` is a **submodule and source reference**, not the direct OpenWrt binary source.
2. Final OpenWrt binaries are rebuilt inside the matching OpenWrt SDK via `docker run`.
3. Use OpenSSL only; do not implement GnuTLS fallback.
4. Third-party libraries are built as static libraries and linked into `aria2c`.
5. UPX is a post-build optimization; skipped on incompatible targets.
6. Each target is independently verified for linkage and runtime sanity.
7. The packaged `/etc/init.d/aria2` and `/etc/config/aria2` should stay compatible with OpenWrt's `net/aria2/files` UCI model; adapt from the Apache-2.0 upstream files instead of maintaining a custom one-off config format.

## Packaged Service Compatibility

- `package/aria2-static/files/aria2.init` and `package/aria2-static/files/aria2.conf` are adapted from OpenWrt `packages/net/aria2/files`.
- The upstream init script is Apache-2.0 licensed, which makes it a suitable source model for this repository.
- The static package should accept the OpenWrt-style UCI keys such as `dir`, `enable_dht`, `rpc_auth_method`, `list header`, `list bt_tracker`, `list extra_settings`, and multiple `config aria2` sections.
- Keep small migration fallbacks only where they help existing `aria2-static` installs, such as mapping legacy `download_dir` to `dir`.

---

## Workflow Details

### `sync-upstream.yml`

**Trigger:** Daily schedule (00:00 UTC) + manual dispatch.

**Runner:** `ubuntu-slim` — the job only needs Git, submodule updates, and the GitHub API, so a single-CPU runner is sufficient.

**Flow:**
1. Checkout repo with submodules.
2. Fetch `aria2-builder` tags and checkout the latest tagged release.
3. Compare old vs new SHA/tag.
4. If changed: commit + push the updated gitlink.
5. Trigger `build-aria2.yml` via `repository_dispatch` event (`build-aria2` type).

### `build-aria2.yml`

**Trigger:** `workflow_dispatch` + `repository_dispatch[build-aria2]`.

**Env vars:**
- `OPENWRT_IPK_SDK: "24.10.4"` — SDK version for most platforms (IPK builds).
- `OPENWRT_APK_SDK: "25.12.0"` — SDK version for APK builds and 25.12-only platforms.
- `ONLY_25` — Space-separated platforms that only exist in 25.12 SDK (e.g., `riscv64_generic`).
- `SKIP_25` — Space-separated platforms removed in 25.12 SDK (e.g., `mips_4kec riscv64_riscv64`).

**Jobs:**
1. **`build`** — Matrix build across 33 OpenWrt targets:
   - Checkout repo with submodules into `repo/`.
   - Determine SDK version (24.10 default, 25.12 for `ONLY_25` platforms).
   - Pull SDK Docker image: `ghcr.io/openwrt/sdk:<platform>-V<version>`.
   - `docker run --rm --user root` with volume mounts.
   - Entrypoint: `build_in_sdk.sh <platform>` — produces `.ipk` + `.apk` per target.
   - Upload artifacts per target.

2. **`deploy`** — Feed branch update (needs: build):
  - Download all artifacts.
  - Generate per-platform Packages index.
  - Generate per-architecture HTML tables from the copied artifacts.
  - Stamp release version and build date into the feed landing page template.
  - Force-push to `feed` branch.

3. **`release`** — GitHub Release (needs: build):
  - Download all artifacts.
  - Rename IPKs and APKs with platform suffix.
  - Rename raw binaries to `aria2c_<version>_<platform>` to keep release asset names unique.
  - Generate release notes markdown table (IPK + APK + binary columns).
  - Publish or refresh the GitHub Release under the upstream aria2 tag (`v<version>`) via `softprops/action-gh-release`.

### `build_in_sdk.sh` — Container Entrypoint

Runs inside the SDK container. Steps:
1. `apt-get install` build tools (autoconf, automake, libtool, curl, upx-ucl, etc.).
2. Discover SDK toolchain at `/builder/staging_dir/toolchain-*/bin/`.
3. Set `STAGING_DIR` environment variable (required by OpenWrt toolchain binaries).
4. Source `target-map.sh`, resolve target triple + OpenSSL target via wildcard patterns.
5. Auto-detect `TARGET_HOST` from SDK toolchain GCC binary (overrides mapped default if different).
6. Run `build_deps_static.sh` — build all static dependencies.
7. Run `build_static_aria2.sh` — configure + make aria2.
8. Run `verify_binary.sh` — linkage + functional checks.
9. Run `pack_with_upx.sh` — conditional UPX compression.
10. Run `collect_artifacts.sh` — BUILDINFO generation.
11. Run `build_ipk.sh` — .ipk package assembly.
12. Run `build_apk.sh` — .apk package assembly (OpenWrt 25.12+ APK v2 format).
13. Output written to `/work/output/<platform>/`.

---

## Target Matrix (33 platforms)

`target-map.sh` uses **wildcard patterns** (`aarch64_*`, `arm_*`, etc.) to map any platform variant to the correct compiler triple and OpenSSL target. An `auto_detect_target_host()` function reads the actual GCC binary from the SDK toolchain and overrides the mapped triple if it differs.

| Pattern | Compiler Triple | OpenSSL Target | UPX | Example Platforms |
|---|---|---|---|---|
| `x86_64` | `x86_64-openwrt-linux-musl` | `linux-x86_64` | Yes | `x86_64` |
| `aarch64_*` | `aarch64-openwrt-linux-musl` | `linux-aarch64` | Yes | `aarch64_generic`, `aarch64_cortex-a53`, `aarch64_cortex-a72`, `aarch64_cortex-a76` |
| `arm_*` | `arm-openwrt-linux-muslgnueabi` | `linux-armv4` | Yes | `arm_cortex-a7`, `arm_cortex-a9`, `arm_cortex-a15_neon-vfpv4`, `arm_xscale`, etc. |
| `i386_*` | `i486-openwrt-linux-musl` | `linux-elf` | Yes | `i386_pentium4`, `i386_pentium-mmx` |
| `mips_*` | `mips-openwrt-linux-musl` | `linux-mips32` | Yes | `mips_24kc`, `mips_4kec`, `mips_mips32` |
| `mipsel_*` | `mipsel-openwrt-linux-musl` | `linux-mips32` | Yes | `mipsel_24kc`, `mipsel_74kc`, `mipsel_mips32`, `mipsel_24kc_24kf` |
| `mips64_*` | `mips64-openwrt-linux-musl` | `linux64-mips64` | **Skip** | `mips64_mips64r2`, `mips64_octeonplus` |
| `mips64el_*` | `mips64el-openwrt-linux-musl` | `linux64-mips64` | **Skip** | `mips64el_mips64r2` |
| `riscv64_*` | `riscv64-openwrt-linux-musl` | `linux64-riscv64` | **Skip** | `riscv64_riscv64`, `riscv64_generic` |
| `loongarch64_*` | `loongarch64-openwrt-linux-musl` | `linux64-loongarch64` | **Skip** | `loongarch64_generic` |

**SDK version routing:**
- Most platforms use **24.10.4** SDK.
- `ONLY_25` platforms (e.g., `riscv64_generic`) use **25.12.0** SDK.
- `SKIP_25` platforms (e.g., `mips_4kec`, `riscv64_riscv64`) are only in 24.10.

---

## GitHub Actions Setup Requirements

1. **Enable Actions** in repository settings.
2. **Workflow permissions**: Settings → Actions → General → set to "Read and write permissions".
3. **GitHub Pages** (optional): Enable for the `feed` branch to serve the package feed.
4. **Update repo-specific values**: `REPO_OWNER` and `REPO_NAME` in `build-aria2.yml` env section, and URLs in `feed_template/index.html`.

---

## Dependency Versions

Managed in `build_scripts/versions.sh`:

| Library | Version |
|---|---|
| zlib | 1.3.1 |
| expat | 2.5.0 |
| SQLite | 3430100 |
| c-ares | 1.19.1 |
| libssh2 | 1.11.0 |
| OpenSSL | 3.4.4 |

---

## Static Dependency Build Details

Within each SDK container, build prefix: `/work/static-prefix`.

- **zlib**: `--static`
- **expat**: `--disable-shared --enable-static`
- **c-ares**: `--disable-shared --enable-static`
- **SQLite**: `--disable-shared --enable-static`
- **OpenSSL**: `./Configure <target> no-shared no-module no-tests --prefix=$PREFIX --libdir=lib`
- **libssh2**: `--disable-shared --enable-static --with-crypto=openssl --with-libssl-prefix=$PREFIX`

### aria2 Configure

```sh
./configure \
  --host="$TARGET_HOST" --prefix=/usr --disable-nls \
  --without-gnutls --with-openssl \
  --without-libxml2 --with-libexpat \
  --with-libcares --with-libz --with-sqlite3 --with-libssh2 \
  ARIA2_STATIC=yes \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib -static -static-libgcc -static-libstdc++" \
  LIBS="-lgcc_eh" \
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
```

---

## UPX Policy

- Maintain a skip list: `mips64*`, `mips64el*`, `riscv64*`, `loongarch64*`.
- Always: build → strip → backup → UPX compress → integrity test → verify.
- On any failure: restore uncompressed binary.

---

## Final Engineering Position

The validated approach is:

1. Use `aria2-builder` as a **submodule and Linux static-build reference**.
2. Use `openwrt-tailscale` as the **OpenWrt SDK `docker run` / packaging / release / feed reference**.
3. **Never use `container:` directive** for SDK builds — use `docker run` from `ubuntu-latest`; use `ubuntu-slim` only for lightweight sync-only automation.
4. Rebuild `aria2c` per OpenWrt target with static dependencies inside the SDK container.
5. Verify static linkage per target.
6. Apply UPX only after testing, skip on incompatible architectures.
7. Publish OpenWrt-specific artifacts via consolidated build→deploy→release workflow.
