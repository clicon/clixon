/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * handling netconf plugins
 *****************************************************************************/
#ifndef _NETCONF_PLUGIN_H_
#define _NETCONF_PLUGIN_H_

/*
 * Types
 */

/* Database dependency description */
struct netconf_reg {
    qelem_t 	 nr_qelem;	/* List header */
    netconf_cb_t nr_callback;	/* Validation/Commit Callback */
    void	*nr_arg;	/* Application specific argument to cb */
    char        *nr_tag;	/* Xml tag when matched, callback called */
};
typedef struct netconf_reg netconf_reg_t;

/*
 * Prototypes
 */ 
int netconf_plugin_load(clicon_handle h);

int netconf_plugin_start(clicon_handle h, int argc, char **argv);

int netconf_plugin_unload(clicon_handle h);


int netconf_plugin_callbacks(clicon_handle h,
//			 dbspec_key *dbspec,
			cxobj *xn, 
			 cbuf *xf, 
			 cbuf *xf_err, 
			 cxobj *xt);

#endif  /* _NETCONF_PLUGIN_H_ */
