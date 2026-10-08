#   Prolog Interface to libcurl (HTTP)
#   Copyright (C) 2026  Alexander Diemand
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

NAME = plcurl
SWI_OBJS = swi-curl.o curl_core.o
GP_OBJS = gp-curl.gpo gp-curl-c.gpo curl_core.gpo
QLF = src/curl.qlf
LIBS = -lcurl -pthread
TOP_SRC = src/top-curl.pl

include ../mk/common.mk

$(SWI_OBJ_FILES) $(OBJDIR)/gp-curl-c.gpo $(OBJDIR)/curl_core.gpo: $(SRCDIR)/curl_core.h
