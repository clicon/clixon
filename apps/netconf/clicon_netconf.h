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
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * The exported interface to plugins. External apps (eg frontend netconf plugins)
 * should only include this file (not the netconf_*.h)
 */

#ifndef _CLICON_NETCONF_H_
#define _CLICON_NETCONF_H_

/*
 * Types
 */
typedef int (*netconf_cb_t)(
    clicon_handle h, 
    cxobj *xorig, /* Original request. */
    cxobj *xn,    /* Sub-tree (under xorig) at child: <rpc><xn></rpc> */
    cbuf  *cb,		    /* Output xml stream. For reply */
    cbuf  *cb_err,	    /* Error xml stream. For error reply */
    void  *arg               /* Argument given at netconf_register_callback() */
    );  

/*
 * Prototypes
 * (Duplicated. Also in netconf_*.h)
 */
int netconf_output(int s, cbuf *xf, char *msg);

int netconf_create_rpc_reply(cbuf *cb,            /* msg buffer */
			 cxobj *xr, /* orig request */
			 char *body,
			 int ok);

int netconf_register_callback(clicon_handle h,
			      netconf_cb_t cb,   /* Callback called */
			      void *arg,       /* Arg to send to callback */
			      char *tag);      /* Xml tag when callback is made */
int netconf_create_rpc_error(cbuf *xf,            /* msg buffer */
			     cxobj *xr, /* orig request */
			     char *tag, 
			     char *type,
			     char *severity, 
			     char *message, 
			     char *info);

void netconf_ok_set(int ok);
int netconf_ok_get(void);

int netconf_xpath(cxobj *xsearch,
		  cxobj *xfilter, 
		   cbuf *xf, cbuf *xf_err, 
		  cxobj *xt);


#endif /* _CLICON_NETCONF_H_ */
