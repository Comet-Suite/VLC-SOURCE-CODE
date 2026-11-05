NSIS_VERSION_MAJOR := 3
NSIS_VERSION_MINOR := 13
MAKENSIS_VERSION := $(NSIS_VERSION_MAJOR).$(NSIS_VERSION_MINOR)
MAKENSIS_URL := https://prdownloads.sourceforge.net/nsis/nsis-$(MAKENSIS_VERSION)-src.tar.bz2?download

ifdef HAVE_WIN32
PKGS_TOOLS += makensis
PKGS += nsis

PKGS.tools += makensis
PKGS.tools.makensis.config-tool = makensis
PKGS.tools.makensis.path = $(BUILDPREFIX)/bin/makensis
endif

ifeq ($(ARCH),i386)
# the system makensis is usually targeting i686
ifeq ($(shell command -v makensis >/dev/null 2>&1 || echo FAIL),)
PKGS_TOOLS += makensis
# assume the architecture we want is supported
PKGS_FOUND += nsis
endif
endif
PKGS_ALL += makensis

DEPS_makensis = scons $(DEPS_scons)
DEPS_nsis = scons $(DEPS_scons) makensis $(DEPS_makensis)

.sum-nsis: nsis-$(MAKENSIS_VERSION)-src.tar.bz2

.sum-makensis: .sum-nsis
	touch $@

$(TARBALLS)/nsis-$(MAKENSIS_VERSION)-src.tar.bz2:
	$(call download_pkg,$(MAKENSIS_URL),nsis)

nsis: nsis-$(MAKENSIS_VERSION)-src.tar.bz2 .sum-nsis
	$(UNPACK)
ifdef HAVE_CLANG
	# remove invalid link flag with LLVM
	sed -i.orig "s@ -Wl,--exclude-libs,msvcrt.a@@" $(UNPACK_DIR)/SCons/Config/gnu
	# remove unsupported+unnecessary assembler calls
	sed -i.orig "s@\.func@#.func@" $(UNPACK_DIR)/Contrib/System/Source/Call.S
	sed -i.orig "s@\.func@#.func@" $(UNPACK_DIR)/Contrib/System/Source/Call-amd64.S
	sed -i.orig "s@\.endfunc@#.endfunc@" $(UNPACK_DIR)/Contrib/System/Source/Call.S
	sed -i.orig "s@\.endfunc@#.endfunc@" $(UNPACK_DIR)/Contrib/System/Source/Call-amd64.S
endif
	cp $(UNPACK_DIR)/SCons/Config/memset.c $(UNPACK_DIR)/Source/exehead/
	cp $(UNPACK_DIR)/SCons/Config/memset.c $(UNPACK_DIR)/Contrib/nsDialogs/
	$(APPLY) $(SRC)/nsis/nsis-memset.patch
	# fix arm64 detection with GNU compatible compilers
	sed -i.orig "s@defined(_M_ARM64)@defined(_M_ARM64) || defined(__aarch64__)@" $(UNPACK_DIR)/Contrib/System/Source/System.h
	# fix arm64 build which implements a custom CallProc only handling a few calls
	touch $(UNPACK_DIR)/Contrib/System/Source/Call-arm64CPP.S
	$(MOVE)

ifeq ($(ARCH),x86_64)
NSIS_ARCH := amd64
else ifeq ($(ARCH),i386)
NSIS_ARCH := x86
else ifeq ($(ARCH),aarch64)
NSIS_ARCH := arm64
else
$(error Unsupported NSIS architecture)
endif

# TODO: --experimental=ninja
# TODO: decide on using $(PYTHON_VENV)/bin/scons or system scons

# similar to HOSTTOOLS but STRIP is different
NSIS_COMMON_CONF := CC="$(BUILDCC)" CXX="$(BUILDCXX)" APPEND_CCFLAGS="-O2" \
	VERSION="$(MAKENSIS_VERSION)" VER_MAJOR="$(NSIS_VERSION_MAJOR)" VER_MINOR="$(NSIS_VERSION_MINOR)" \
	CHMDOCS=0 STRIP_CP=no UNICODE=yes \
	SKIPUTILS='VPatch/Source/GenPat,Makensisw,NSIS Menu,SubStart,zip2exe' \
	SKIPPLUGINS='AdvSplash,Banner,BgImage,Dialer,InstallOptions,Math,NSISdl,Splash,StartMenu,Library/TypeLib,UserInfo,VPatch/Source/Plugin' \
	DOCTYPES= SKIPTESTS=all

# ifneq ($(V),1)
# NSIS_COMMON_CONF += -s
# endif

MAKENSIS_CONF := $(NSIS_COMMON_CONF) PREFIX=$(BUILDPREFIX) SKIPSTUBS=all \
	TARGET_ARCH=$(NSIS_ARCH) # sets the default architecture as we do not build another one

NSIS_CONF := $(NSIS_COMMON_CONF) PREFIX=$(BUILDPREFIX) \
	TARGET_ARCH=$(NSIS_ARCH) XGCC_W32_PREFIX="$(HOST)-" \
	PREFIX_PLUGINAPI_INC=$(PREFIX)/include PREFIX_PLUGINAPI_LIB=$(PREFIX)/lib \
	SKIPSTUBS="bzip2"  # VLC uses lzma,zlib compression

.makensis: nsis
	rm -f $</config.log $</.sconsign.dblite $</Source/exehead/sconf.h $</Source/version.h $</Source/defines.h
	rm -rf $</build
	rm -rf $</.sconf-temp
	+$(PYTHON_VENV)/bin/scons -C $< $(MAKENSIS_CONF) -j 12 makensis
	+$(PYTHON_VENV)/bin/scons -C $< $(MAKENSIS_CONF) -j 12 install-compiler install-conf
	touch $@

.nsis: nsis
	rm -f $</config.log $</.sconsign.dblite $</Source/exehead/sconf.h $</Source/version.h $</Source/defines.h
	rm -rf $</build
	rm -rf $</.sconf-temp
	+$(PYTHON_VENV)/bin/scons -C $< $(NSIS_CONF) stubs plugins utils
	+$(PYTHON_VENV)/bin/scons -C $< $(NSIS_CONF) install-stubs install-plugins install-utils install-data
	+$(PYTHON_VENV)/bin/scons -C $< $(NSIS_CONF) install-pluginapi
	touch $@
