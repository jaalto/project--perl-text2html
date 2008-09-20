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
#	General Public License for more details.
#
#	Visit <http://www.gnu.org/copyleft/gpl.html>

ifneq (,)
This makefile requires GNU Make.
endif

include common.mk

PACKAGE		= t2html
PL		= $(PACKAGE).pl
BIN		= $(PACKAGE)
SRC		= bin/$(PL)

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

EXDIR		     = $(SHAREDIR)/examples

BIN		     = $(PACKAGE)
INSTALL_OBJS	     = $(BIN)
INSTALL_EXAMPLE_OBJS = doc/examples/*
INSTALL_DOC_OBJS     = COPYING README

EXDIR	= $(SHAREDIR)/examples

# Rule: all - Make all before install
all: perl-fix

install-doc:
	# Rule install-doc - install documentation
	$(INSTALL_BIN) -d $(DOCDIR)
	$(INSTALL_DATA) $(INSTALL_DOC_OBJS) $(DOCDIR)
	(cd doc && $(TAR) $(TAR_OPT_NO) --create --file=- . ) | \
	(cd $(DOCDIR) && $(TAR) --extract --file=- )

install-man:
	# Rule install-man - install manual page
	$(INSTALL_BIN) -D bin/$(BIN).1 $(MANDIR1)/$(BIN).1

install-bin:
	# Rule install-bin - install program
	$(INSTALL_BIN) -D $(SRC) $(BINDIR)/$(BIN)

install: all install-bin install-man install-doc

install-test:
	# Rule install-test - for Maintainer only
	rm -rf tmp
	make DESTDIR=`pwd`/tmp prefix=/. install

# Rule: distclean - Clean everything
realclean: distclean

# Rule: html - Generate or update HTML documentation
doc/conversion/index.html: doc/conversion/index.txt
	perl -S t2html.pl --Auto-detect --Out --print-url $<

html: doc/conversion/index.html

# Rule: doc - Generate or update manual page documentation
doc: bin/$(BIN).1

# Rule: release-check - Check that program does not have compilation errors
test:
	perl -cw $(SRC)

.PHONY: install install-doc install-man install-test realclean html test

# End of file
