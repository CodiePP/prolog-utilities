#   Prolog Toolbox
#   Copyright (C) 1999-2020  Alexander Diemand
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
MODULE = plcgi-$(ARCH)

SRCDIR = src
OBJDIR = obj-$(ARCH)

# source files
SWI_SRCS = $(SRCDIR)/cgi.pl

GP_SRCS = $(SRCDIR)/gp-cgi.pl $(SRCDIR)/common.pl
GP_OBJ = $(OBJDIR)/gp-cgi.gpo

# object files
OBJS =

.SUFFIXES: .c

# other implicit rules
$(OBJDIR)/%.o : $(SRCDIR)/%.c
	@echo "compiling $<"
	@$(CC) -c $(SWI_CFLAGS) -o $@ $<

$(OBJDIR)/%.gpo : $(SRCDIR)/%.pl
	@echo "compiling $<"
	@$(GPLC) -c -o $@ $<

%.qlf : $(SRCDIR)/%.pl
	@echo "compiling $<"
	$(SWIPL) -t "qcompile(\"$<\")."

# rule to make it all
all: $(MODULE) lib$(MODULE).a $(SRCDIR)/cgi.qlf

$(GP_OBJ) : $(GP_SRCS)

# builds the SWI-Prolog loadable module
$(MODULE): $(OBJDIR) $(OBJS)
	@echo "Building module $(MODULE)"
	@$(LINK) $(SWI_LDFLAGS) -o $(MODULE) $(OBJS) $(SWI_SRCS) $(SWI_LDLIBS)

# builds the GNU Prolog library
lib$(MODULE).a: $(OBJDIR) $(GP_OBJ)
	@echo "Building library $(MODULE)"
	$(AR) -r -c $@ $(GP_OBJ)
	$(RANLIB) $@

clean:
	@echo "Cleaning away everything."
	@test -d $(OBJDIR) && rm -r $(OBJDIR); true
	@test -f $(MODULE) && rm $(MODULE); true
	@test -f lib$(MODULE).a && rm lib$(MODULE).a; true

$(OBJDIR):
	@mkdir $(OBJDIR)
