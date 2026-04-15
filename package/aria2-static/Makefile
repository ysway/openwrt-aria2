include $(TOPDIR)/rules.mk

PKG_NAME:=aria2-static
PKG_RELEASE:=1

# Version is determined at build time from the aria2-builder submodule
PKG_VERSION:=$(shell grep '^AC_INIT' $(CURDIR)/../../aria2-builder/configure.ac 2>/dev/null | sed -n 's/.*\[\([0-9][0-9.]*\)\].*/\1/p')
ifeq ($(PKG_VERSION),)
  PKG_VERSION:=0.0.0
endif

PKG_MAINTAINER:=openwrt-aria2
PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=COPYING

include $(INCLUDE_DIR)/package.mk

define Package/aria2-static
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=File Transfer
  TITLE:=aria2 download utility (static build)
  URL:=https://aria2.github.io/
  DEPENDS:=
  CONFLICTS:=aria2
endef

define Package/aria2-static/description
  aria2 is a lightweight multi-protocol & multi-source, cross-platform
  download utility operated via command line. It supports HTTP/HTTPS,
  FTP, SFTP, BitTorrent, and Metalink.

  This package ships a statically linked binary with OpenSSL, libssh2,
  c-ares, expat, sqlite3, and zlib embedded. No external library
  dependencies are required at runtime.
endef

define Package/aria2-static/conffiles
/etc/config/aria2
endef

# The actual binary is pre-built by the CI pipeline; this Makefile
# is used for packaging reference only.

define Build/Compile
	@echo "aria2-static: binary is pre-built"
endef

define Package/aria2-static/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/aria2c $(1)/usr/bin/aria2c

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/aria2.init $(1)/etc/init.d/aria2

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/aria2.conf $(1)/etc/config/aria2
endef

$(eval $(call BuildPackage,aria2-static))
