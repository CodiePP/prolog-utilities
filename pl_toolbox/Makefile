#   Prolog Toolbox
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

NAME = pltoolbox
SWI_OBJS = lowlevelroutines.o
GP_OBJS = gp-toolbox.gpo
QLF = src/toolbox.qlf
TOP_SRC = src/top-toolbox.pl

include ../mk/common.mk

# the Prolog sources are included by toolbox.pl / gp-toolbox.pl
PL_SRCS = $(SRCDIR)/math.pl $(SRCDIR)/stream.pl $(SRCDIR)/string.pl $(SRCDIR)/vector.pl $(SRCDIR)/json.pl
$(OBJDIR)/gp-toolbox.gpo: $(PL_SRCS)
$(QLF): $(PL_SRCS)

.PHONY: check

# JSON tests, GNU Prolog (and SWI-Prolog if installed)
check: | $(OBJDIR)
	$(GPLC) --no-top-level -o $(OBJDIR)/test_json test/test_json.pl $(SRCDIR)/json.pl
	$(OBJDIR)/test_json
	if command -v $(SWIPL) >/dev/null; then $(SWIPL) -q $(SRCDIR)/json.pl test/test_json.pl; fi
