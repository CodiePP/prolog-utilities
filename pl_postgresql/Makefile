#   SWI-Prolog Interface to Postgresql
#   Copyright (C) 1999-2019  Alexander Diemand
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
#


# load platform dependent settings (compiler, flags, libs...)
ARCH = $(shell uname -s)
ifeq ($(ARCH), IRIX64)
ARCH=IRIX
endif
include $(ARCH).def

INC = $(ARCH_INC)
CFLAGS = $(DEF) $(OPT) $(INC) $(DEBUG) $(WARN) $(PIC)

LDFLAGS = $(ARCH_LDFLAGS)
LDLIBS = $(ARCH_LIBS)

# module name
MODULE = plpgsql-$(ARCH)

# quick compiled pl
QPL = $(SRCDIR)/pgsql.qlf

SRCDIR = src
OBJDIR = obj-$(ARCH)

# object files
OBJS = $(OBJDIR)/pgsql.o

.SUFFIXES: .c

# other implicit rules
$(OBJDIR)/%.o : $(SRCDIR)/%.c
	@echo "compiling $<"
	@$(CC) -c $(CFLAGS) -o $@ $<

$(SRCDIR)/%.qlf : $(SRCDIR)/%.pl
	@echo "compiling $<"
	swipl -t "qcompile(\"$<\")."

# default rule
default: all

# rule to make it all
all: $(MODULE) $(QPL)

# builds the executable
$(MODULE): $(OBJDIR) $(OBJS)
	@echo "Building module $(MODULE)"
	@$(LINK) $(LDFLAGS) -o $(MODULE) $(OBJS) $(LDLIBS)

clean:
	@echo "Cleaning away everything."
	@test -d $(OBJDIR) && rm -r $(OBJDIR); true
	@test -f $(MODULE) && rm $(MODULE); true

$(OBJDIR):
	@mkdir $(OBJDIR)

