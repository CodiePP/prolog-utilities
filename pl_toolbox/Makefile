#   Prolog Toolbox
#   Copyright (C) 1999-2023  Alexander Diemand
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


# load platform dependent settings (compiler, flags, libs...)
ARCH = $(shell uname -s)
ifeq ($(ARCH), IRIX64)
ARCH=IRIX
endif
include $(ARCH).def

SWI_CFLAGS = $(DEF) $(OPT) $(SWI_ARCH_INC) $(DEBUG) $(WARN) $(PIC)
SWI_LDFLAGS = $(SWI_ARCH_LDFLAGS)
SWI_LDLIBS = $(SWI_ARCH_LIBS)
GP_CFLAGS = $(DEF) $(OPT) $(GP_ARCH_INC) $(DEBUG) $(WARN) $(PIC)
GP_LDFLAGS = $(GP_ARCH_LDFLAGS)
GP_LDLIBS = $(GP_ARCH_LIBS)

# module name
MODULE = pltoolbox-$(ARCH)

SRCDIR = src
OBJDIR = obj-$(ARCH)

PL_SRCS = $(SRCDIR)/math.pl $(SRCDIR)/stream.pl $(SRCDIR)/string.pl $(SRCDIR)/vector.pl $(SRCDIR)/json.pl $(SRCDIR)/gp-toolbox.pl
GP_OBJS = $(OBJDIR)/gp-toolbox.gpo

# object files
SWI_OBJS = $(OBJDIR)/lowlevelroutines.o

.SUFFIXES: .c

# other implicit rules
$(OBJDIR)/%.o : $(SRCDIR)/%.c
	@echo "compiling $<"
	$(CC) -c $(SWI_CFLAGS) -o $@ $<

$(OBJDIR)/%.gpo : $(SRCDIR)/%.pl
	@echo "compiling $<"
	$(GPLC) -c -o $@ $<

$(SRCDIR)/%.qlf : $(SRCDIR)/toolbox.pl
	@echo "compiling $<"
	$(SWIPL) -q -t "qcompile(\"$<\")."

# rule to make it all
all: $(MODULE) lib$(MODULE).a $(SRCDIR)/toolbox.qlf

$(GP_OBJS): $(PL_SRCS)

$(SRCDIR)/toolbox.pl: $(PL_SRCS)

# builds the executable
$(MODULE): $(OBJDIR) $(SWI_OBJS)
	@echo "Building module $(MODULE)"
	eval $(swipl --dump-runtime-variables)
	@$(LINK) $(SWI_LDFLAGS) -o $(MODULE) $(SWI_OBJS) $(SWI_LDLIBS)
lib$(MODULE).a: $(OBJDIR) $(GP_OBJS)
	@echo "Building library $(MODULE)"
	$(AR) -r -c $@ $(GP_OBJS)
	$(RANLIB) $@
top: $(SRCDIR)/top-toolbox.pl lib$(MODULE).a
	gplc -o $@ --new-top-level $(SRCDIR)/top-toolbox.pl lib$(MODULE).a

clean:
	@echo "Cleaning away everything."
	@test -d $(OBJDIR) && rm -r $(OBJDIR); true
	@test -f $(MODULE) && rm $(MODULE); true
	@test -f lib$(MODULE).a && rm lib$(MODULE).a; true

$(OBJDIR):
	@mkdir $(OBJDIR)

