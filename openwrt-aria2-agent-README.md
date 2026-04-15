# openwrt-aria2 Agent README

## Purpose

This document is a verified implementation brief for building an `openwrt-aria2` project that:

- tracks `AnInsomniacy/aria2-builder` as an upstream **git submodule**,
- uses its **Linux static-build flow** as the reference sample,
- rebuilds `aria2c` for **multiple OpenWrt targets** inside OpenWrt SDK containers,
- links third-party libraries **statically**,
- uses **OpenSSL** rather than GnuTLS,
- compresses final binaries with **UPX** when safe,
- publishes OpenWrt-ready artifacts and a feed.

This README intentionally distinguishes between:

1. things verified directly from upstream GitHub code / docs,
2. engineering decisions derived from those sources,
3. places where the implementation must be conservative because the sources do **not** prove a stronger claim.

---

## Verified facts from upstream sources

### A. What `aria2-builder` actually does

`AnInsomniacy/aria2-builder` states in its README that it provides cross-platform statically linked aria2 builds. For Linux, the published support table is only:

- `Linux x86_64` with `OpenSSL` and `Fully static`
- `Linux ARM64` with `OpenSSL` and `Fully static`

It does **not** claim OpenWrt target coverage. Its README also states that the full feature set includes Async DNS, BitTorrent, Metalink, XML-RPC, HTTPS, SFTP via libssh2, GZip, message digest, and Firefox3 cookie support. Build details list zlib, expat, c-ares, SQLite, libssh2, and OpenSSL for Linux. This means it is a useful static-build reference, but not a direct OpenWrt artifact source.

### B. What the Linux workflow in `aria2-builder` actually shows

The GitHub Actions workflow `release.yml` for `aria2-builder` verifies the following Linux build pattern:

1. Build dependencies from source as static libraries.
2. Build OpenSSL with:
   - `./Configure linux-x86_64 no-shared no-module no-tests ...` for Linux x86_64
   - `./Configure linux-aarch64 no-shared no-module no-tests ...` for Linux ARM64
3. Build `libssh2` with `--with-crypto=openssl --with-libssl-prefix=$PREFIX`.
4. Build `aria2` with:
   - `--without-gnutls --with-openssl`
   - `--without-libxml2 --with-libexpat`
   - `--with-libcares --with-libz --with-sqlite3 --with-libssh2`
   - `ARIA2_STATIC=yes`
   - `LDFLAGS="-L$PREFIX/lib -static-libgcc -static-libstdc++"`
5. Strip the resulting `src/aria2c`.
6. Run `ldd src/aria2c || true` as a linkage check.

Important: the workflow proves that `aria2-builder` is doing a static-oriented build, but it does **not** prove that every OpenWrt target can be built the same way unchanged.

### C. What `openwrt-tailscale` actually does

`GuNanOvO/openwrt-tailscale` verifies a reusable OpenWrt automation pattern:

1. Its build workflow uses a large OpenWrt target matrix including `aarch64_generic`, `arm_cortex-a7`, `arm_cortex-a9`, `i386_pentium4`, `loongarch64_generic`, `mips_24kc`, `mipsel_24kc`, `riscv64_generic`, and `x86_64`.
2. It runs builds inside OpenWrt SDK Docker images such as:
   - `ghcr.io/openwrt/sdk:${{ matrix.platform }}-V${{ env.OPENWRT_IPK_SDK }}`
3. It mounts helper directories into the SDK container, including an `upx` directory.
4. It downloads artifacts later in the release stage and pushes a `feed` branch.
5. Its package Makefile uses UPX conditionally, and explicitly disables UPX for `mips64*`, `riscv64*`, and `loongarch64*` architectures.

This proves the right OpenWrt-side pattern is “rebuild per target in SDK”, not “take a generic Linux binary and just rename it”.

### D. What the OpenWrt official `aria2` package actually does

The official `openwrt/packages` `net/aria2/Makefile` currently shows:

- `PKG_VERSION:=1.37.0`
- source pulled from official aria2 release tarballs
- dynamic-style package dependencies such as `+zlib`, `+libstdcpp`, `+libopenssl`, `+libssh2`, `+libcares`, `+libsqlite3`, etc.

That package design is **not** the design needed here. It is useful as a packaging reference, but it is not a static self-contained binary recipe.

### E. What Git and GitHub officially support for submodules

Git documents that:

- `.gitmodules` can specify `submodule.<name>.branch` for upstream tracking,
- `git submodule update --remote` updates to the submodule's remote-tracking branch,
- `update --remote` fetches before calculating the target SHA unless `--no-fetch` is given.

`actions/checkout` documents a `submodules` input where:

- `true` checks out submodules,
- `recursive` recursively checks out submodules.

Therefore the project can safely support both:

- reproducible builds from a pinned submodule gitlink,
- a separate scheduled workflow that updates the submodule pointer to newer upstream commits.

### F. What is actually supported by UPX

UPX documents itself as a portable executable packer for multiple executable formats. This supports using UPX as a post-build optimization step. However, the `openwrt-tailscale` project is a useful cautionary example because it disables UPX for some architectures. Therefore UPX should be treated as:

- desired,
- tested,
- but skippable on incompatible targets.

### G. OpenSSL and TLS 1.3

OpenSSL's own TLS 1.3 article states that OpenSSL 1.1.1 would include TLS 1.3 support, and that TLS 1.3 is enabled by default in development versions discussed there unless explicitly disabled. This validates the high-level requirement that choosing OpenSSL is the right path when TLS 1.3 support is required.

---

## Corrections to earlier assumptions

The following statements are **too strong** and should not be implemented as written:

### 1. “All OpenWrt targets will be fully static.”
Not proven.

What is proven:
- `aria2-builder` achieves fully static Linux x86_64 / ARM64 outputs.
- OpenWrt SDK builds can be matrix-driven per target.

What is **not** proven:
- that every OpenWrt SDK / libc / toolchain combination will permit a fully static `aria2c` with no target-specific fixes.

Implementation rule:
- treat static linking as the goal,
- verify it per target,
- fail or mark unsupported when a target cannot satisfy the static requirement.

### 2. “The exact Linux workflow can be copied unchanged into OpenWrt SDK.”
Not proven.

What is proven:
- the dependency set and configure flags are a good Linux sample,
- OpenWrt SDK is the right place to cross-build per target.

Implementation rule:
- reuse the dependency set and feature choices,
- but adapt compiler, target triple, sysroot, and OpenSSL Configure target per OpenWrt platform.

### 3. “UPX should always run.”
Not safe.

What is proven:
- UPX is generally valid,
- `openwrt-tailscale` disables it on some architectures.

Implementation rule:
- run UPX only after the binary is built,
- test the packed file,
- fall back to the uncompressed binary on failure,
- optionally keep a per-target skip list.

### 4. “Use `aria2-builder` release binaries as upstream OpenWrt inputs.”
Incorrect.

The verified upstream only provides generic Linux x86_64 and ARM64 static outputs, not OpenWrt target artifacts. The correct use of the project is:

- submodule reference,
- source tree reference,
- Linux build recipe reference,
- not direct OpenWrt binary redistribution.

---

## Required project architecture

## 1. Repository layout

Recommended repository layout:

```text
openwrt-aria2/
├── .gitmodules
├── .github/
│   └── workflows/
│       ├── sync-upstream.yml
│       ├── build-aria2.yml
│       └── release-feed.yml
├── aria2-builder/                  # git submodule
├── build_scripts/
│   ├── common.sh
│   ├── versions.sh
│   ├── target-map.sh
│   ├── build_deps_static.sh
│   ├── build_static_aria2.sh
│   ├── verify_binary.sh
│   ├── pack_with_upx.sh
│   ├── build_ipk.sh
│   ├── build_apk.sh
│   ├── collect_artifacts.sh
│   └── gen_feed.sh
├── package/
│   └── aria2-static/
│       ├── Makefile
│       └── files/
│           ├── aria2.init
│           └── aria2.conf
├── feed_template/
│   └── index.html
├── install.sh
└── README.md
```

## 2. Design rules

1. `aria2-builder` is a **submodule and source reference**, not the direct OpenWrt binary source.
2. Final OpenWrt binaries must be rebuilt inside the matching OpenWrt SDK.
3. Use OpenSSL only; do not implement GnuTLS fallback.
4. Third-party libraries must be built as static libraries and linked into `aria2c`.
5. UPX is a post-build optimization and must not be a hard requirement on unsupported targets.
6. Each target must be independently verified for linkage and runtime sanity.

---

## Submodule policy

## 1. Add the submodule

Use `aria2-builder` as a standard git submodule.

Suggested `.gitmodules` entry:

```ini
[submodule "aria2-builder"]
	path = aria2-builder
	url = https://github.com/AnInsomniacy/aria2-builder.git
	branch = master
```

## 2. Build policy

Normal builds must use the committed submodule SHA pinned in the superproject.

This gives reproducible outputs.

## 3. Upstream sync policy

A separate scheduled workflow should:

1. checkout repo with submodules,
2. run `git submodule update --remote -- aria2-builder`,
3. detect whether the gitlink changed,
4. commit the updated gitlink if changed,
5. trigger the real build pipeline.

This matches Git's documented submodule update model.

---

## Build model

## 1. Build per OpenWrt target in SDK containers

Use the `openwrt-tailscale` pattern:

- matrix over OpenWrt targets,
- run SDK Docker image for each target,
- mount scripts and sources into the container,
- build target-specific packages and release artifacts.

Suggested first-wave targets:

- `x86_64`
- `aarch64_generic`
- `arm_cortex-a7`
- `arm_cortex-a9`
- `i386_pentium4`
- `mips_24kc`
- `mipsel_24kc`
- `riscv64_generic`
- `loongarch64_generic`

Do not assume every target succeeds on day one.

## 2. Dependency set

Use the Linux sample's dependency set as the required baseline:

- zlib
- expat
- c-ares
- SQLite
- OpenSSL
- libssh2

Reasons:
- they are explicitly present in `aria2-builder` build details,
- they line up with the feature set claimed by that project,
- they correspond to the relevant feature toggles in the OpenWrt package.

## 3. Why not reuse OpenWrt's dynamic package recipe as-is

Because the official OpenWrt `aria2` package is dependency-driven and dynamic-library oriented.

This project's value proposition is the opposite:

- keep runtime dependencies minimal,
- reduce reliance on old firmware package sets,
- package a mostly self-contained `aria2c`.

---

## Static dependency build requirements

Within each SDK container, implement a build prefix such as:

```text
/work/static-prefix
```

Install all static third-party outputs there.

### Build rules for dependencies

#### zlib

Build static only.

#### expat

Build with:

```sh
--disable-shared --enable-static
```

#### c-ares

Build with:

```sh
--disable-shared --enable-static
```

#### SQLite

Build with static output enabled and shared output disabled when possible.

#### OpenSSL

Use the Linux sample as the reference:

```sh
./Configure <openssl-target> no-shared no-module no-tests \
  --prefix="$PREFIX" --libdir=lib
```

Do **not** rely on the OpenWrt system OpenSSL package.

#### libssh2

Must be built against the static OpenSSL just built:

```sh
./configure --disable-shared --enable-static --prefix="$PREFIX" \
  --with-crypto=openssl --with-libssl-prefix="$PREFIX"
```

---

## aria2 configure requirements

Use the Linux sample flags as baseline, adapted for cross-compilation.

Required feature choices:

```sh
./configure \
  --host="$TARGET_HOST" \
  --prefix=/usr \
  --disable-nls \
  --without-gnutls --with-openssl \
  --without-libxml2 --with-libexpat \
  --with-libcares --with-libz --with-sqlite3 --with-libssh2 \
  ARIA2_STATIC=yes \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib -static -static-libgcc -static-libstdc++" \
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
```

Notes:

1. `--without-gnutls --with-openssl` is required.
2. `--with-libssh2`, `--with-libcares`, `--with-sqlite3`, `--with-libexpat`, and `--with-libz` are required.
3. Explicit `-static` is recommended here even though the upstream Linux sample only clearly shows `-static-libgcc -static-libstdc++`; the project goal is stronger than the upstream example and must be verified per target.
4. `autoreconf -i` must run before configure, matching the Linux sample.

---

## Target mapping requirements

A target mapping layer is required.

OpenSSL Configure target names are not the same thing as OpenWrt matrix names. Implement a table in `target-map.sh` that maps OpenWrt platform IDs to:

- compiler triple,
- target CPU flags,
- OpenSSL Configure target.

Initial examples:

```text
x86_64              -> openssl target linux-x86_64
 aarch64_generic     -> openssl target linux-aarch64
 i386_pentium4       -> openssl target linux-elf
 arm_cortex-a7       -> openssl target linux-armv4   + target-specific CFLAGS
 arm_cortex-a9       -> openssl target linux-armv4   + target-specific CFLAGS
 mips_24kc           -> openssl target linux-mips32
 mipsel_24kc         -> openssl target linux-mips32
 riscv64_generic     -> openssl target linux64-riscv64
 loongarch64_generic -> openssl target linux64-loongarch64
```

This mapping must be testable and overrideable per target.

---

## Packaging requirements

## 1. Package name

Use a distinct package name such as:

- `aria2-static`

The binary installed should remain:

- `/usr/bin/aria2c`

## 2. Package contents

Recommended package contents:

```text
/usr/bin/aria2c
/etc/init.d/aria2
/etc/config/aria2
/usr/share/doc/aria2-static/BUILDINFO
```

## 3. BUILDINFO requirements

Generate a `BUILDINFO` text file per target containing at least:

- project build version
- OpenWrt target name
- SDK version
- submodule commit
- aria2 version
- OpenSSL version
- zlib version
- expat version
- c-ares version
- SQLite version
- libssh2 version
- whether UPX was applied
- whether the binary verified as fully static

## 4. Runtime dependencies

Do not intentionally depend on OpenWrt's `libopenssl`, `libssh2`, `libcares`, or `libsqlite3`.

Keep dependencies as small as reality allows after verification.

---

## UPX policy

UPX is required as a preferred optimization, but not as an unconditional packaging rule.

## Required flow

1. build `aria2c`
2. strip it
3. save a backup copy
4. run UPX
5. run UPX integrity test
6. run `aria2c --version`
7. if packed binary fails, restore original binary

Recommended policy:

- maintain a skip list for known-bad architectures,
- seed the initial skip list from the `openwrt-tailscale` example:
  - `mips64*`
  - `riscv64*`
  - `loongarch64*`
- extend the skip list only based on observed failures.

UPX should never silently replace a working binary with an unverified packed one.

---

## Verification requirements

Every build must perform all of the following.

## 1. Linkage verification

Run checks such as:

```sh
file src/aria2c
readelf -d src/aria2c || true
objdump -p src/aria2c | grep NEEDED || true
ldd src/aria2c || true
```

Acceptance rule:

- ideal result: no dynamic `NEEDED` entries,
- minimum acceptable result: no dependency on the third-party libraries intended to be embedded statically.

If the target does not meet the static requirement, mark the target unsupported or fail that matrix job.

## 2. Functional verification

Run at least:

```sh
./src/aria2c --version
./src/aria2c --help >/dev/null
```

Preserve the `--version` output in logs and optionally in `BUILDINFO`.

## 3. UPX verification

Run:

```sh
upx -t ./src/aria2c
./src/aria2c --version
```

If either fails, restore the uncompressed binary.

---

## Workflow requirements

## 1. `sync-upstream.yml`

Purpose:
- update the `aria2-builder` submodule pointer on a schedule or manual run.

Required behavior:
- checkout with submodules,
- run `git submodule update --remote -- aria2-builder`,
- commit changed gitlink,
- trigger build workflow.

## 2. `build-aria2.yml`

Purpose:
- matrix-build per OpenWrt target in SDK containers.

Required behavior:
- checkout repository and submodule,
- use OpenWrt SDK Docker images per target,
- build static dependencies,
- build `aria2c`,
- verify,
- UPX if safe,
- build `.ipk`,
- optionally build `.apk`,
- upload artifacts per target.

## 3. `release-feed.yml`

Purpose:
- aggregate artifacts,
- publish GitHub release,
- update feed branch and index.

Required behavior:
- download all artifacts,
- compute hashes,
- build release markdown,
- publish release,
- update feed branch.

---

## Implementation priorities

### Phase 1

Targets:
- `x86_64`
- `aarch64_generic`
- `arm_cortex-a7`
- `mipsel_24kc`

Deliverables:
- static `aria2c`
- `.ipk`
- BUILDINFO
- UPX policy
- release artifact upload

### Phase 2

Add:
- `arm_cortex-a9`
- `i386_pentium4`
- `mips_24kc`
- `riscv64_generic`

### Phase 3

Add:
- `loongarch64_generic`
- `apk`
- feed branch automation
- install script

---

## Non-goals for v1

Do not implement these in v1 unless needed later:

- direct reuse of `aria2-builder` Linux binaries as OpenWrt deliverables,
- GnuTLS support,
- libxml2 support,
- broad assumptions that every architecture can be UPX-packed or fully static,
- packaging every possible LuCI integration before the binary pipeline is stable.

---

## Final engineering position

The validated approach is:

1. use `aria2-builder` as a **submodule and Linux static-build reference**,
2. use `openwrt-tailscale` as the **OpenWrt SDK matrix / packaging / release / feed reference**,
3. rebuild `aria2c` per OpenWrt target with static dependencies,
4. verify static linkage per target,
5. apply UPX only after testing,
6. publish OpenWrt-specific artifacts.

This is the strongest implementation path supported by the checked sources, without assuming capabilities those sources do not actually prove.
