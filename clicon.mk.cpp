#
# Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
#
# This file is part of CLIXON.
#
# CLIXON is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# CLIXON is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CLIXON; see the file LICENSE.  If not, see
# <http://www.gnu.org/licenses/>.
#

#
# Include this file in your application Makefile using eg:
# -include $(datarootdir)/clicon/clicon.mk
# then you can use the DIRS below in your install rules.
# You also get rules for the application configure file.
# NOTE: APPNAME must be defined in the local Makefile

clicon_DBSPECDIR=prefix/share/$(APPNAME)
clicon_SYSCONFDIR=sysconfdir
clicon_LOCALSTATEDIR=localstatedir/$(APPNAME)
clicon_LIBDIR=libdir/$(APPNAME)
clicon_DATADIR=datadir/clicon

# Rules for the clicon application configuration file.
# The clicon applications should be started with this fileas its -f argument.
# Typically installed in sysconfdir
# Example: APPNAME=myapp --> clicon_cli -f /usr/local/etc/myapp.conf
# The two variants are if there is a .conf.local file or not
.PHONY: $(APPNAME).conf
ifneq (,$(wildcard ${APPNAME}.conf.local)) 	
${APPNAME}.conf:  ${clicon_DATADIR}/clicon.conf.cpp ${APPNAME}.conf.local
	$(CPP) -P -x assembler-with-cpp -DAPPNAME=$(APPNAME) $< > $@
	cat ${APPNAME}.conf.local >> $@
else
${APPNAME}.conf:  ${clicon_DATADIR}/clicon.conf.cpp
	$(CPP) -P -x assembler-with-cpp -DAPPNAME=$(APPNAME) $< > $@
endif
