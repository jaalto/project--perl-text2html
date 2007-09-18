# $Id: vars.mk,v 1.8 2004/10/23 18:56:01 jaalto Exp $
#
#	Copyright (C)  Jari Aalto
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License as
#	published by the Free Software Foundation; either version 2 of the
#	License, or (at your option) any later version

# ########################################################### &basic ###

DESTDIR		=
prefix		= /usr/local
exec_prefix	= $(prefix)

BINDIR		= $(DESTDIR)$(exec_prefix)/bin
MANDIR		= $(DESTDIR)$(prefix)/man/man1
ETCDIR		= $(DESTDIR)/etc/$(PACKAGE)

DOCDIR		= ./doc
TMPDIR		= /tmp

INSTALL	= /bin/install
INSTALL_BIN	= -m 755
INSTALL_DATA	= -m 644

BASENAME	= basename
DIRNAME		= dirname
PERL		= perl		     # location varies
AWK		= awk
BASH		= /bin/bash
SHELL		= /bin/sh
MAKEFILE	= Makefile

TAR		= tar
TAR_OPT_NO	= --exclude='.build'	 \
		  --exclude='.sinst'	 \
		  --exclude='.inst'	 \
		  --exclude='tmp'	 \
		  --exclude='*.bak'	 \
		  --exclude='*[~\#]'	 \
		  --exclude='.\#*'	 \
		  --exclude='CVS'	 \
		  --exclude='*.tar*'	 \
		  --exclude='*.tgz'

TAR_OPT_COPY	= $(TAR_OPT_NO)
TAR_OPT_WORLD	= $(TAR_OPT_NO)


#   RELEASE must be increased if Cygwin corrections are make to same package
#   at the same day.

RELEASE	= 1
VERSION	= `date '+%Y.%m%d'`

BUILDDIR	= .build
PACKAGEVER	= $(PACKAGE)-$(VERSION)
RELEASEDIR	= $(BUILDDIR)/$(PACKAGEVER)
RELEASE_FILE	= $(PACKAGEVER).tar.gz
RELEASE_FILE_PATH = $(BUILDDIR)/$(RELEASE_FILE)

TAR_FILE_WORLD_LS  = `ls -t1 $(BUILDDIR)/*.tar.gz | sort -r | head -1`

# ########################################################### &files ###


# Rule: echo-vars - [maintenance] Echo important variables
echo-vars:
	@echo DESTDIR=$(DESTDIR) prefix=$(prefix) exec_prefix=$(exec_prefix)
	@echo BINDIR=$(BINDIR) MANDIR=$(MANDIR) DOCDIR=$(DOCDIR)


# End of file