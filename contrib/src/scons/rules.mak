SCONS_VERSION := 4.11.1
SCONS_URL := $(GITHUB)/SCons/scons/archive/refs/tags/$(SCONS_VERSION).tar.gz

ifeq ($(call need_pkg,"scons"),)
PKGS_FOUND += scons
endif

# no need to make this available to meson/cmake
# PKGS.tools += scons
# PKGS.tools.scons.config-tool = scons
# PKGS.tools.scons.path = $(PYTHON_VENV)/bin/scons

$(TARBALLS)/scons-$(SCONS_VERSION).tar.gz:
	$(call download_pkg,$(SCONS_URL),scons)

.sum-scons: scons-$(SCONS_VERSION).tar.gz

scons: scons-$(SCONS_VERSION).tar.gz .sum-scons
	$(UNPACK)
	$(MOVE)

.scons: scons .python-venv
	$(PYTHON_INSTALL)
	touch $@
