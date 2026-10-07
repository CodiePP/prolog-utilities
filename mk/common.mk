#   Prolog utilities -- build rules shared by the pl_* modules
#   Copyright (C) 1999-2026  Alexander Diemand
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

# A module Makefile sets the variables below and then includes this file:
#
#   NAME      library base name, e.g. plregexp
#   SWI_OBJS  object files of the SWI-Prolog foreign library (empty: none)
#   GP_OBJS   object files of the GNU Prolog library
#             (names only, e.g. swi-regexp.o, gp-regexp.gpo; built in obj-<arch>)
#   QLF       precompiled SWI-Prolog module, e.g. src/regexp.qlf
#   LIBS      extra libraries for both systems, e.g. -lcurl
#   TOP_SRC   top-level source for 'make top'; TOP_LIBS extra libraries for it
#
# Targets: all (default), top, clean, asan.
#   make asan   rebuilds the libraries with AddressSanitizer and UBSan
#               (SANITIZE=1); see the README for running the tests with them.

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

ARCH := $(shell uname -s)
include $(MK_DIR)$(ARCH).def

# SWI-Prolog locations, unless the environment provides them (make.sh,
# ci/env.sh): PLBASE (headers), PLLIBDIR and PLLIB (library to link)
ifeq ($(origin PLBASE),undefined)
PL_RUNTIME := $(shell swipl --dump-runtime-variables 2>/dev/null)
PLBASE := $(patsubst PLBASE="%";,%,$(filter PLBASE=%,$(PL_RUNTIME)))
PLLIBDIR := $(patsubst PLLIBDIR="%";,%,$(filter PLLIBDIR=%,$(PL_RUNTIME)))
PLLIB := $(patsubst PLLIB="%";,%,$(filter PLLIB=%,$(PL_RUNTIME)))
endif

ifeq ($(SANITIZE),1)
# _FORTIFY_SOURCE and the sanitizers get in each other's way
FORTIFY =
SAN = -fsanitize=address,undefined -fno-omit-frame-pointer
endif

CFLAGS_ALL = $(DEF) $(OPT) $(DEBUG) $(WARN) $(PIC) $(FORTIFY) $(HARDEN) $(SAN)
SWI_CFLAGS = $(CFLAGS_ALL) -I$(PLBASE)/include
SWI_LDFLAGS = -shared $(HARDEN_LDFLAGS) $(SAN) -L$(PLLIBDIR)
SWI_LDLIBS = $(PLLIB) $(LIBS)
GP_CFLAGS = $(CFLAGS_ALL)

SRCDIR = src
OBJDIR = obj-$(ARCH)
SWI_LIB = $(NAME)-$(ARCH)
GP_LIB = lib$(NAME)-$(ARCH).a
SWI_OBJ_FILES = $(addprefix $(OBJDIR)/,$(SWI_OBJS))
GP_OBJ_FILES = $(addprefix $(OBJDIR)/,$(GP_OBJS))

.PHONY: all top clean asan
.SUFFIXES:

all: $(if $(SWI_OBJS),$(SWI_LIB)) $(GP_LIB) $(QLF)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

$(OBJDIR)/%.o : $(SRCDIR)/%.c | $(OBJDIR)
	@echo "compiling $<"
	$(CC) -c $(SWI_CFLAGS) -o $@ $<

$(OBJDIR)/%.gpo : $(SRCDIR)/%.pl | $(OBJDIR)
	@echo "compiling $<"
	$(GPLC) -c -o $@ $<

$(OBJDIR)/%.gpo : $(SRCDIR)/%.c | $(OBJDIR)
	@echo "compiling $<"
	$(GPLC) -c -C '$(GP_CFLAGS)' -o $@ $<

# loading the module loads the foreign library (through the sbcl path)
$(SRCDIR)/%.qlf : $(SRCDIR)/%.pl $(if $(SWI_OBJS),$(SWI_LIB))
	@echo "compiling $<"
	$(SWIPL) -q -t "qcompile(\"$<\")."

$(SWI_LIB): $(SWI_OBJ_FILES)
	@echo "Building module $(SWI_LIB)"
	$(LINK) $(SWI_LDFLAGS) -o $@ $(SWI_OBJ_FILES) $(SWI_LDLIBS)

$(GP_LIB): $(GP_OBJ_FILES)
	@echo "Building library $(GP_LIB)"
	$(AR) -r -c $@ $(GP_OBJ_FILES)
	$(RANLIB) $@

# gplc -L passes its argument to the linker
top: $(TOP_SRC) $(GP_LIB)
	$(GPLC) -o $@ --new-top-level $(TOP_SRC) $(GP_LIB) $(TOP_LIBS) $(if $(LIBS),-L '$(LIBS)')

clean:
	@echo "Cleaning away everything."
	rm -rf $(OBJDIR) $(SWI_LIB) $(GP_LIB) $(QLF) top

# only the libraries: qcompile would have to load the instrumented library
# into an uninstrumented swipl. Run 'make clean all' to return to normal.
asan:
	rm -rf $(OBJDIR) $(SWI_LIB) $(GP_LIB)
	$(MAKE) SANITIZE=1 $(if $(SWI_OBJS),$(SWI_LIB)) $(GP_LIB)
