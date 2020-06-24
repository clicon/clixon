/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

  This file is part of CLIXON.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Alternatively, the contents of this file may be used under the terms of
  the GNU General Public License Version 3 or later (the "GPL"),
  in which case the provisions of the GPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of the GPL, and not to allow others to
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 * 
 * Secondary backend for testing more than one backend plugin, with the following 
 * features:
 * - nacm
 * - transaction test
 * The transaction test is test/test_transaction.sh where a user-error is triggered
 * by this plugin if started with -- -t <xpath>. _transaction_xpath is then set
 * and triggers a validation error if it matches. The error also toggles between
 * validation and commit errors.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/syslog.h>

/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h> 

/*! Variable to control transaction logging (for debug)
 * If set, call syslog for every transaction callback
 * Start backend with -- -t
 */
static int _transaction_log = 0;

/*! Variable for failing validate and commit, if set, fail on validate vs commit
 */
static char * _transaction_xpath = NULL;
static int  _transaction_error_toggle = 0; /* fail at validate vs commit */

int
nacm_begin(clicon_handle    h, 
	   transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}
/*! This is called on validate (and commit). Check validity of candidate
 */
int
nacm_validate(clicon_handle    h, 
	      transaction_data td)
{
    if (_transaction_log){
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
	if (_transaction_error_toggle==0 &&
	    xpath_first(transaction_target(td), NULL, "%s", _transaction_xpath)){
	    _transaction_error_toggle=1; /* toggle if triggered */
	    clicon_err(OE_XML, 0, "User error");
	    return -1; /* induce fail */
	}
    }
    return 0;
}

int
nacm_complete(clicon_handle    h, 
	      transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

/*! This is called on commit. Identify modifications and adjust machine state
 */
int
nacm_commit(clicon_handle    h, 
	    transaction_data td)
{
    cxobj  *target = transaction_target(td); /* wanted XML tree */

    if (_transaction_log){
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
	if (_transaction_error_toggle==1 &&
	    xpath_first(target, NULL, "%s", _transaction_xpath)){
	    _transaction_error_toggle=0; /* toggle if triggered */
	    clicon_err(OE_XML, 0, "User error");
	    return -1; /* induce fail */
	}
    }
    return 0;
}

int
nacm_commit_done(clicon_handle    h, 
		 transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
nacm_revert(clicon_handle    h, 
	    transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
nacm_end(clicon_handle    h, 
	 transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
nacm_abort(clicon_handle    h, 
	   transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE,  __FUNCTION__);
    return 0;
}

/*! Called to get NACM state data
 * @param[in]    h      Clicon handle
 * @param[in]    nsc    External XML namespace context, or NULL
 * @param[in]    xpath  String with XPATH syntax. or NULL for all
 * @param[in]    xtop   XML tree, <config/> on entry. 
 * @retval       0      OK
 * @retval      -1      Error
 * @see xmldb_get
 * @note this example code returns a static statedata used in testing. 
 * Real code would poll state
 */
int 
nacm_statedata(clicon_handle h, 
	       cvec         *nsc,
	       char         *xpath,
	       cxobj        *xstate)
{
    int     retval = -1;
    cxobj **xvec = NULL;

    /* Example of (static) statedata, real code would poll state */
    if (clixon_xml_parse_string("<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\">"
				"<denied-data-writes>0</denied-data-writes>"
				"<denied-operations>0</denied-operations>"
				"<denied-notifications>0</denied-notifications>"
				"</nacm>", YB_NONE, NULL, &xstate, NULL) < 0)
	goto done;
    retval = 0;
 done:
    if (xvec)
	free(xvec);
    return retval;
}

clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api;

static void api_initialization(void)
{
	strcpy(api.ca_name, "nacm");                                 /* name */
	api.ca_init = clixon_plugin_init;                            /* init - must be called clixon_plugin_init */
	api.ca_start = NULL;                                         /* start */
	api.ca_exit = NULL;                                          /* exit */
	api.u.cau_backend.cb_statedata = nacm_statedata;             /* statedata */
	api.u.cau_backend.cb_trans_begin = nacm_begin;               /* trans begin */
	api.u.cau_backend.cb_trans_validate = nacm_validate;         /* trans validate */
	api.u.cau_backend.cb_trans_complete = nacm_complete;         /* trans complete */
	api.u.cau_backend.cb_trans_commit = nacm_commit;             /* trans commit */
	api.u.cau_backend.cb_trans_commit_done = nacm_commit_done;   /* trans commit done */
	api.u.cau_backend.cb_trans_revert = nacm_revert;             /* trans revert */
	api.u.cau_backend.cb_trans_end = nacm_end;                   /* trans end */
	api.u.cau_backend.cb_trans_abort = nacm_abort;               /* trans abort */
}

/*! Backend plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    char  *nacm_mode;
    int    argc; /* command-line options (after --) */
    char **argv;
    int    c;

    api_initialization();
    clicon_debug(1, "%s backend nacm", __FUNCTION__);
    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
	goto done;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, "rsut:")) != -1)
	switch (c) {
	case 't': /* transaction log */
	    _transaction_log = 1;
	    _transaction_xpath = optarg;
	    break;
	}

    nacm_mode = clicon_option_str(h, "CLICON_NACM_MODE");
    if (nacm_mode==NULL || strcmp(nacm_mode, "disabled") == 0){
	clicon_log(LOG_DEBUG, "%s CLICON_NACM_MODE not enabled: example nacm module disabled", __FUNCTION__);
	/* Skip nacm module if not enabled _unless_ we use transaction tests */
	if (_transaction_log == 0) 
	    return NULL;
    }
    /* Return plugin API */
    return &api;
 done:
    return NULL;
}
