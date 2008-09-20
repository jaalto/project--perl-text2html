#!/usr/bin/make -f
#
#	Copyright (C) 1997-2009 Jari Aalto
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License as
#	published by the Free Software Foundation; either version 2 of the
#	License, or (at your option) any later version
#
#	This program is distributed in the hope that it will be useful, but
#	WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#	General Public License for more details at
#	<http://www.gnu.org/copyleft/gpl.html>.

ifneq (,)
This makefile requires GNU Make.
endif

MAKEDIR	= admin/mk

include $(MAKEDIR)/vars.mk
include $(MAKEDIR)/manifest.mk
include $(MAKEDIR)/clean.mk
include $(MAKEDIR)/perl.mk
include $(MAKEDIR)/release.mk
include $(MAKEDIR)/www.mk

PACKAGE			= t2html
PL			= $(PACKAGE).pl
BIN			= $(PACKAGE)
SRC			= bin/$(PL)

WWWROOT			= ..
INSTALL_OBJS		= $(BIN)
INSTALL_DOC_OBJS	= COPYING README
INSTALL_MAN1_OBJS	= bin/*.1
INSTALL_BIN_S_OBJS	= $(SRC)

# ######################################################## &suffixes ###

.SUFFIXES:
.SUFFIXES: .pl .1

#   Pod generates .x~~ extra files and rm(1) cleans them
#
#   $<	  = name of the input (full)
#   $@	  = name, but only basename part, without suffix
#   $(*D) = macro; Give only directory part
#   $(*F) = macro; Give only file part ($* would give DIR/FILE)

.pl.1:
	perl $< --Help-man  > bin/$(*F).1
	perl $< --Help-html > doc/manual/index.html
	perl $< --help	    > doc/manual/index.txt
	-rm  -f *[~#] *.tmp

bin/$(PACKAGE).1: $(SRC)

# ######################################################### &targets ###

# Rule: all - Make all before install
all: perl-shebang-fix

install: all install-script-bin install-man1 install-doc

# Rule: realclean - Clean everything
realclean: distclean

# Rule: html - Generate or update HTML documentation
doc/conversion/index.html: doc/conversion/index.txt
	perl -S t2html.pl --Auto-detect --Out --print-url $<

html: doc/conversion/index.html

# Rule: doc - Generate or update manual page documentation
doc: bin/$(BIN).1

# Rule: check - Check that program does not have compilation errors
test:
	perl -cw $(SRC)

.PHONY: install install-doc install-man install-test realclean html test

# End of file
