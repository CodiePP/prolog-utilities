#   Prolog CGI Interface
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

NAME = plcgi
SWI_OBJS =
GP_OBJS = gp-cgi.gpo common.gpo
QLF = src/cgi.qlf
TOP_SRC = src/top-cgi.pl
TOP_LIBS = ../pl_regexp/libplregexp-$(ARCH).a ../pl_toolbox/libpltoolbox-$(ARCH).a

include ../mk/common.mk

# cgi.pl includes common.pl
$(QLF): $(SRCDIR)/common.pl
