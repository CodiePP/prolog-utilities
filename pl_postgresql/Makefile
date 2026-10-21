#   Prolog Interface to Postgres
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

# build rules and flags: ../mk/common.mk, ../mk/<uname -s>.def
#
# libpq is keg-only on Homebrew (macOS), so its include/library paths are
# not on the default compiler search path there; pkg-config finds them on
# every platform.

LIBPQ_CFLAGS := $(shell pkg-config --cflags libpq)
LIBPQ_LIBS := $(shell pkg-config --libs libpq)

NAME = plpgsql
SWI_OBJS = swi-pgsql.o pgsql_core.o
GP_OBJS = gp-pgsql.gpo gp-pgsql-c.gpo pgsql_core.gpo
QLF = src/pgsql.qlf
LIBS = $(LIBPQ_LIBS)
TOP_SRC = src/top-pgsql.pl

include ../mk/common.mk

CFLAGS_ALL += $(LIBPQ_CFLAGS)
GP_CFLAGS += $(LIBPQ_CFLAGS)

$(SWI_OBJ_FILES) $(OBJDIR)/gp-pgsql-c.gpo $(OBJDIR)/pgsql_core.gpo: $(SRCDIR)/pgsql_core.h | libpq-check

# clear message instead of a "libpq-fe.h: file not found" compile error
libpq-check:
	@pkg-config --atleast-version=9.0 libpq || { \
	  echo "error: libpq >= 9.0 not found (pkg-config libpq)." >&2; \
	  echo "  Install libpq's development package (libpq-dev on Debian/Ubuntu," >&2; \
	  echo "  postgresql on Homebrew) and put pkg-config on PATH." >&2; \
	  exit 1; }
