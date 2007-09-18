# $Id: net.mk,v 1.4 2004/08/19 11:21:15 jaalto Exp $
#
#	Copyright (C)  Jari Aalto
#	Keywords:      Makefile, sourceforge
#
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License as
#	published by the Free Software Foundation; either version 2 of the
#	License, or (at your option) any later version
#
#	Make targets to update files to a remote location.

SOURCEFORGE_UPLOAD_HOST	= upload.sourceforge.net
SOURCEFORGE_UPLOAD_DIR	= /incoming

SOURCEFORGE_DIR		= /home/groups/p/pe/perl-text2html
SOURCEFORGE_SHELL	= shell.sourceforge.net
SOURCEFORGE_USER	= $(USER)
SOURCEFORGE_SSH_DIR	= \
  $(SOURCEFORGE_USER)@$(SOURCEFORGE_SHELL):$(SOURCEFORGE_DIR)

CYGETC_DIR		= etc/cygwin
CYGETC_UPLOAD_DIR	= $(SOURCEFORGE_SSH_DIR)

# ######################################################### &targets ###

sf-uload-no-root:
	@if [ $(SOURCEFORGE_USER) = "root" ]; then		    \
	    echo "'root' cannot upload files. ";		    \
	    echo "Please call with 'make USER=<sfuser> <target>";   \
	    return 1;						    \
	fi

# Rule: sf-upload-doc - [Maintenence] Sourceforge; Upload documentation
sf-upload-doc: doc sf-uload-no-root
	scp index.html $(SOURCEFORGE_SSH_DIR)/htdocs
	scp doc/*.html $(SOURCEFORGE_SSH_DIR)/htdocs/doc

# Rule: sf-upload-cyg-setup-ini - [Maintenence] Sourceforge; Upload setup.ini
sf-upload-cyg-setup-ini: sf-uload-no-root
	scp $(CYGETC_DIR)/setup.ini $(CYGETC_UPLOAD_DIR)

sf-upload-release-check:
	@if [ -f $(CYGWIN_RELEASE_FILE_PATH).tar.gz ]; then		\
	    echo "$(CYGWIN_RELEASE_FILE_PATH) Release path not found";	\
	    false;							\
	fi

# Rule: sf-upload-release - [Maintenence] Sourceforge; Upload documentation
sf-upload-release: sf-upload-release-check
	@echo "-- run command --"
	@echo $(FTP)			    \
		$(SOURCEFORGE_UPLOAD_HOST)  \
		$(SOURCEFORGE_UPLOAD_DIR)   \
		$(TAR_FILE_WORLD_LS)

# End of file
