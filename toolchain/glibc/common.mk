#
# Copyright (C) 2006-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=glibc
PKG_VERSION:=2.26

# FIXME: I overwrite this.
PKG_SOURCE_URL:=https://api.github.com/repos/riscv/riscv-glibc/tarball/2f626de717a86be3a1fe39e779f0b179e13ccfbb?
PKG_SOURCE:=riscv-riscv-glibc-2f626de.tar.gz
PKG_HASH:=f85cb29d63aa9cf011982acd425d4d0b6e0e9a85a019c998bbae1d4245671599

# FIXME: I overwrite this.
PKG_SOURCE_SUBDIR:=riscv-riscv-glibc-2f626de
HOST_BUILD_DIR:=$(BUILD_DIR_TOOLCHAIN)/$(PKG_SOURCE_SUBDIR)
CUR_BUILD_DIR:=$(HOST_BUILD_DIR)-$(VARIANT)

include $(INCLUDE_DIR)/toolchain-build.mk

HOST_STAMP_PREPARED:=$(HOST_BUILD_DIR)/.prepared
HOST_STAMP_CONFIGURED:=$(CUR_BUILD_DIR)/.configured
HOST_STAMP_BUILT:=$(CUR_BUILD_DIR)/.built
HOST_STAMP_INSTALLED:=$(TOOLCHAIN_DIR)/stamp/.glibc_$(VARIANT)_installed

ifeq ($(ARCH),mips64)
  ifdef CONFIG_MIPS64_ABI_N64
    TARGET_CFLAGS += -mabi=64
  endif
  ifdef CONFIG_MIPS64_ABI_N32
    TARGET_CFLAGS += -mabi=n32
  endif
  ifdef CONFIG_MIPS64_ABI_O32
    TARGET_CFLAGS += -mabi=32
  endif
endif


# -Os miscompiles w. 2.24 gcc5/gcc6
# only -O2 tested by upstream changeset
# "Optimize i386 syscall inlining for GCC 5"

#FIXME: I overwrite here:
#       WHY REAL_CNU_TARGET_NAME can't be riscv64-openwrt-linux-gnu?
# ifeq ($(ARCH),riscv64)
#   REAL_GNU_TARGET_NAME=riscv-linux-gnu
# endif

GLIBC_CONFIGURE:= \
	BUILD_CC="$(HOSTCC)" \
	$(TARGET_CONFIGURE_OPTS) \
	CFLAGS="-O2 $(filter-out -Os,$(call qstrip,$(TARGET_CFLAGS)))" \
	libc_cv_slibdir="/lib" \
	use_ldconfig=no \
	$(HOST_BUILD_DIR)/$(GLIBC_PATH)configure \
		--prefix= \
		--build=$(GNU_HOST_NAME) \
		--host=$(REAL_GNU_TARGET_NAME) \
		--with-headers=$(TOOLCHAIN_DIR)/include \
		--disable-profile \
		--disable-werror \
		--without-gd \
		--without-cvs \
		--enable-add-ons \
		--$(if $(CONFIG_SOFT_FLOAT),without,with)-fp
		#\
		libc_cv_forced_unwind=yes \
		libc_cv_c_cleanup=yes \
		--enable-shared \
		--enable-__thread \
		--enable-kernel=2.6.32 \
		\

export libc_cv_ssp=no
export libc_cv_ssp_strong=no
export ac_cv_header_cpuid_h=yes
export HOST_CFLAGS := $(HOST_CFLAGS) -idirafter $(CURDIR)/$(PATH_PREFIX)/include

define Host/SetToolchainInfo
	$(SED) 's,^\(LIBC_TYPE\)=.*,\1=$(PKG_NAME),' $(TOOLCHAIN_DIR)/info.mk
	$(SED) 's,^\(LIBC_URL\)=.*,\1=http://www.gnu.org/software/libc/,' $(TOOLCHAIN_DIR)/info.mk
	$(SED) 's,^\(LIBC_VERSION\)=.*,\1=$(PKG_VERSION),' $(TOOLCHAIN_DIR)/info.mk
	$(SED) 's,^\(LIBC_SO_VERSION\)=.*,\1=$(PKG_VERSION),' $(TOOLCHAIN_DIR)/info.mk
endef

define Host/Configure
	[ -f $(HOST_BUILD_DIR)/.autoconf ] || { \
		cd $(HOST_BUILD_DIR)/; \
		autoconf --force && \
		touch $(HOST_BUILD_DIR)/.autoconf; \
	}
	mkdir -p $(CUR_BUILD_DIR)
	( cd $(CUR_BUILD_DIR); rm -f config.cache; \
		$(GLIBC_CONFIGURE) \
	);
endef

define Host/Prepare
	$(call Host/Prepare/Default)
	ln -snf $(PKG_SOURCE_SUBDIR) $(BUILD_DIR_TOOLCHAIN)/$(PKG_NAME)
endef

define Host/Clean
	rm -rf $(CUR_BUILD_DIR)* \
		$(BUILD_DIR_TOOLCHAIN)/$(LIBC)-dev \
		$(BUILD_DIR_TOOLCHAIN)/$(PKG_NAME)
endef
