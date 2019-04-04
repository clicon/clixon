/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 * NACM code according to RFC8341 Network Configuration Access Control Model
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <limits.h>
#include <fnmatch.h>
#include <stdint.h>
#include <assert.h>
#include <syslog.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_string.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_options.h"
#include "clixon_data.h"
#include "clixon_netconf_lib.h"
#include "clixon_xpath_ctx.h"
#include "clixon_xpath.h"
#include "clixon_yang_module.h"
#include "clixon_datastore.h"
#include "clixon_nacm.h"

/*! Match nacm access operations according to RFC8341 3.4.4.  
 * Incoming RPC Message Validation Step 7 (c)
 *  The rule's "access-operations" leaf has the "exec" bit set or
 *  has the special value "*".
 * @param[in] mode  Primary mode, eg read, create, update, delete, exec
 * @param[in] mode2 Secondary mode, eg "write"
 * @retval 0  No match
 * @retval 1  Match
 * @note access_operations is bit-fields
 */
static int
match_access(char *access_operations,
	     char *mode,
	     char *mode2)
{
    if (access_operations==NULL)
	return 0;
    if (strcmp(access_operations,"*")==0)
	return 1;
    if (strstr(access_operations, mode)!=NULL)
	return 1;
    if (mode2 && strstr(access_operations, mode2)!=NULL)
	return 1;
    return 0;
}

/*! Match nacm single rule. Either match with access or deny. Or not match.
 * @param[in]  rpc    rpc name
 * @param[in]  module Yang module name
 * @param[in]  xrule  NACM rule XML tree
 * @param[out] cbret  Cligen buffer result. Set to an error msg if retval=0.
 * @retval -1  Error
 * @retval  0  Matching rule AND Not access and cbret set
 * @retval  1  Matching rule AND Access
 * @retval  2  No matching rule Goto step 10
 * @see RFC8341 3.4.4.  Incoming RPC Message Validation
 7.(cont) A rule matches if all of the following criteria are met: 
        *  The rule's "module-name" leaf is "*" or equals the name of
           the YANG module where the protocol operation is defined.

        *  Either (1) the rule does not have a "rule-type" defined or
           (2) the "rule-type" is "protocol-operation" and the
           "rpc-name" is "*" or equals the name of the requested
           protocol operation.

        *  The rule's "access-operations" leaf has the "exec" bit set or
           has the special value "*".
 */
static int
nacm_rule_rpc(char         *rpc,
	      char         *module,
	      cxobj        *xrule)
{
    int    retval = -1;
    char  *module_rule; /* rule module name */
    char  *rpc_rule;
    char  *access_operations;
    
    /*  7a) The rule's "module-name" leaf is "*" or equals the name of
	the YANG module where the protocol operation is defined. */
    if ((module_rule = xml_find_body(xrule, "module-name")) == NULL)
	goto nomatch;
    if (strcmp(module_rule,"*") && strcmp(module_rule,module))
	goto nomatch;
    /*  7b) Either (1) the rule does not have a "rule-type" defined or
	(2) the "rule-type" is "protocol-operation" and the
	"rpc-name" is "*" or equals the name of the requested
	protocol operation. */
    if ((rpc_rule = xml_find_body(xrule, "rpc-name")) == NULL){
	if (xml_find_body(xrule, "path") || xml_find_body(xrule, "notification-name"))
	    goto nomatch;
    }
    if (rpc_rule && (strcmp(rpc_rule, "*") && strcmp(rpc_rule, rpc)))
	goto nomatch;
    /* 7c) The rule's "access-operations" leaf has the "exec" bit set or
	has the special value "*". */
    access_operations = xml_find_body(xrule, "access-operations");
    if (!match_access(access_operations, "exec", NULL))
	goto nomatch;
    retval = 1;
 done:
    return retval;
 nomatch:
    retval = 0;
    goto done;
}

/*! Process nacm incoming RPC message validation steps
 * @param[in]  module   Yang module name
 * @param[in]  rpc      rpc name
 * @param[in]  username User name of requestor
 * @param[in]  xnacm    NACM xml tree
 * @param[out] cbret Cligen buffer result. Set to an error msg if retval=0.
 * @retval -1  Error
 * @retval  0  Not access and cbret set
 * @retval  1  Access
 * @see RFC8341 3.4.4.  Incoming RPC Message Validation
 * @see nacm_datanode_write
 * @see nacm_datanode_read
 */
int
nacm_rpc(char         *rpc,
	 char         *module,
	 char         *username,
	 cxobj        *xnacm,
	 cbuf         *cbret)
{
    int     retval = -1;
    cxobj  *xrule;
    cxobj **gvec = NULL; /* groups */
    size_t  glen;
    cxobj  *rlist;
    cxobj **rlistvec = NULL; /* rule-list */
    size_t  rlistlen;
    cxobj **rvec = NULL; /* rules */
    size_t  rlen;
    int     i, j;
    char   *exec_default = NULL;
    char   *gname;
    char   *action;
    int     match= 0;
    
    /* 3.   If the requested operation is the NETCONF <close-session>
       protocol operation, then the protocol operation is permitted.
    */
    if (strcmp(rpc, "close-session") == 0)
	goto permit;
    /* 4.   Check all the "group" entries to see if any of them contain a
       "user-name" entry that equals the username for the session
       making the request.  (If the "enable-external-groups" leaf is
       "true", add to these groups the set of groups provided by the
       transport layer.)	       */
    if (username == NULL)
	goto step10;
    /* User's group */
    if (xpath_vec(xnacm, "groups/group[user-name='%s']", &gvec, &glen, username) < 0)
	goto done;
    /* 5. If no groups are found, continue with step 10. */
    if (glen == 0)
	goto step10;
    /* 6. Process all rule-list entries, in the order they appear in the
        configuration.  If a rule-list's "group" leaf-list does not
        match any of the user's groups, proceed to the next rule-list
        entry. */
    if (xpath_vec(xnacm, "rule-list", &rlistvec, &rlistlen) < 0)
	goto done;
    for (i=0; i<rlistlen; i++){
	rlist = rlistvec[i];
	/* Loop through user's group to find match in this rule-list */
	for (j=0; j<glen; j++){
	    gname = xml_find_body(gvec[j], "name");
	    if (xpath_first(rlist, ".[group='%s']", gname)!=NULL)
		break; /* found */
	}
	if (j==glen) /* not found */
	    continue;
	/* 7. For each rule-list entry found, process all rules, in order,
	   until a rule that matches the requested access operation is
	   found. 
	*/
	if (xpath_vec(rlist, "rule", &rvec, &rlen) < 0)
	    goto done;
	for (j=0; j<rlen; j++){
	    xrule = rvec[j];
	    if ((match = nacm_rule_rpc(rpc, module, xrule)) < 0)
		goto done;
	    if (match)
		break;
	}
	if (match)
	    break;
	if (rvec){
	    free(rvec);
	    rvec=NULL;
	}
    }
    if (match){
	if ((action = xml_find_body(xrule, "action")) == NULL)
	    goto step10;
	if (strcmp(action, "deny")==0){
	    if (netconf_access_denied(cbret, "application", "access denied") < 0)
		goto done;
	    goto deny;
	}
	else if (strcmp(action, "permit")==0)
	    goto permit;

    }
 step10:
    /*   10.  If the requested protocol operation is defined in a YANG module
        advertised in the server capabilities and the "rpc" statement
        contains a "nacm:default-deny-all" statement, then the protocol
        operation is denied. */
    /* 11.  If the requested protocol operation is the NETCONF
        <kill-session> or <delete-config>, then the protocol operation
        is denied. */
    if (strcmp(rpc, "kill-session")==0 || strcmp(rpc, "delete-config")==0){
	if (netconf_access_denied(cbret, "application", "default deny") < 0)
	    goto done;
	goto deny;
    }
    /*   12.  If the "exec-default" leaf is set to "permit", then permit the
	 protocol operation; otherwise, deny the request. */
    exec_default = xml_find_body(xnacm, "exec-default");
    if (exec_default ==NULL || strcmp(exec_default, "permit")==0)
	goto permit;
    if (netconf_access_denied(cbret, "application", "default deny") < 0)
	goto done;
    goto deny;
 permit:
    retval = 1;
 done:
    clicon_debug(1, "%s retval:%d (0:deny 1:permit)", __FUNCTION__, retval);
    if (gvec)
	free(gvec);
    if (rlistvec)
	free(rlistvec);
    if (rvec)
	free(rvec);
    return retval;
 deny: /* Here, cbret must contain a netconf error msg */
    assert(cbuf_len(cbret));
    retval = 0;
    goto done;
}

/*---------------------------------------------------------------
 * Datanode/module read and write
 */

/*! We have a rule matching user group. Now match proper write operation and module
 * @retval -1 Error
 * @retval  0 No Match
 * @retval  1 Match
 * @see RFC8341 3.4.5.  Data Node Access Validation point (6)
 */
static int
nacm_rule_datanode(cxobj           *xt,
		   cxobj           *xr,
		   cxobj           *xrule,
		   enum nacm_access access)
{
    int        retval = -1;
    char      *path;
    char      *access_operations;
    char      *module_rule; /* rule module name */
    yang_stmt *ys;
    yang_stmt *ymod;
    char      *module;
    cxobj     *xpath; /* xpath match */
    cxobj     *xp; /* parent */
   
    /* 6a) The rule's "module-name" leaf is "*" or equals the name of
     * the YANG module where the requested data node is defined. */
    if ((module_rule = xml_find_body(xrule, "module-name")) == NULL)
	goto nomatch;
    if (strcmp(module_rule,"*")!=0){
	if ((ys = xml_spec(xr)) == NULL)
	    goto nomatch;
	ymod = ys_module(ys);
	module = ymod->ys_argument;
	if (strcmp(module, module_rule) != 0)
	    goto nomatch;
    }

    /*  6b) Either (1) the rule does not have a "rule-type" defined or
	(2) the "rule-type" is "data-node" and the "path" matches the
	requested data node, action node, or notification node.  A
	path is considered to match if the requested node is the node
	specified by the path or is a descendant node of the path.*/    
    if ((path = xml_find_body(xrule, "path")) == NULL){
	if (xml_find_body(xrule, "rpc-name") ||xml_find_body(xrule, "notification-name"))
	    goto nomatch;
    }
    access_operations = xml_find_body(xrule, "access-operations");
    switch (access){
    case NACM_READ:
	/* 6c) For a "read" access operation, the rule's "access-operations"
	   leaf has the "read" bit set or has the special value "*" */
	if (!match_access(access_operations, "read", NULL))
	    goto nomatch;
	break;
    case NACM_CREATE:
	/* 6d) For a "create" access operation, the rule's "access-operations" 
	   leaf has the "create" bit set or has the special value "*". */
	if (!match_access(access_operations, "create", "write"))
	    goto nomatch;
	break;
    case NACM_DELETE:
        /* 6e) For a "delete" access operation, the rule's "access-operations" 
	   leaf has the "delete" bit set or has the  special value "*". */
	if (!match_access(access_operations, "delete", "write"))
	    goto nomatch;
	break;
    case NACM_UPDATE:
        /* 6f) For an "update" access operation, the rule's "access-operations"
	   leaf has the "update" bit set or has the special value "*". */ 
	if (!match_access(access_operations, "update", "write"))
	    goto nomatch;
	break;
    default:
	break;
    }
    /* Here module is matched, now check for path if any NYI */
    if (path){ 
	if ((xpath = xpath_first(xt, "%s", path)) == NULL)
	    goto nomatch;
	/* The requested node xr is the node specified by the path or is a 
	 * descendant node of the path:
	 * xmatch is one of xvec[] or an ancestor of the xvec[] nodes.
	 */
	xp = xr;
	do {
	    if (xpath == xp)
		goto match;
	} while ((xp = xml_parent(xp)) != NULL);
    }
 match:
    retval = 1;
 done:
    return retval;
 nomatch:
    retval = 0;
    goto done;
}

/*! Go through all rules for a requested node
 * @param[in]  xt       XML root tree with "config" label 
 * @param[in]  xr       Requested node (node in xt)
 * @param[in]  gvec     NACM groups where user is member
 * @param[in]  glen     Length of gvec
 * @param[in]  rlistvec NACM rule-list entries
 * @param[in]  rlistlen Length of rlistvec
 * @param[out] xrulep  If set, then points to matching rule
 */
static int
nacm_data_read_xr(cxobj  *xt,
		  cxobj  *xr,
		  cxobj **gvec,
		  size_t  glen,
		  cxobj **rlistvec,
		  size_t  rlistlen,
		  cxobj **xrulep)
{
    int retval = -1;
    int i, j;
    cxobj  *rlist;
    char   *gname;
    cxobj **rvec = NULL; /* rules */
    size_t  rlen;
    cxobj  *xrule = NULL;
    int     match = 0;

    for (i=0; i<rlistlen; i++){ 	/* Loop through rule list */
	rlist = rlistvec[i];
	/* Loop through user's group to find match in this rule-list */
	for (j=0; j<glen; j++){
	    gname = xml_find_body(gvec[j], "name");
	    if (xpath_first(rlist, ".[group='%s']", gname)!=NULL)
		break; /* found */
	}
	if (j==glen) /* not found */
	    continue;
	/* 6. For each rule-list entry found, process all rules, in order,
	   until a rule that matches the requested access operation is
	   found. (see 6 sub rules in nacm_rule_datanode
	*/
	if (xpath_vec(rlist, "rule", &rvec, &rlen) < 0)
	    goto done;
	for (j=0; j<rlen; j++){ /* Loop through rules */
	    xrule = rvec[j];
	    if ((match = nacm_rule_datanode(xt, xr, xrule, NACM_READ)) < 0)
		goto done;
	    if (match) /* xrule match */
		break;
	}
	if (rvec){
	    free(rvec);
	    rvec=NULL;
	}
	if (match) /* xrule match */
	    break;
    }
    if (match)
	*xrulep = xrule;
    else
	*xrulep = NULL;
    retval = 0;
 done:
    if (rvec)
	free(rvec);
    return retval;
}

/*! Make nacm datanode and module rule read access validation
 * Just purge nodes that fail validation (dont send netconf error message)
 * @param[in]  xt       XML root tree with "config" label 
 * @param[in]  xrvec    Vector of requested nodes (sub-part of xt)
 * @param[in]  xrlen    Length of requsted node vector
 * @param[in]  username 
 * @param[in]  xnacm     NACM xml tree
 * @retval -1  Error
 * @retval  0  Not access and cbret set
 * @retval  1  Access
 * 3.2.4: <get> and <get-config> Operations
 * Data nodes to which the client does not have read access are silently
 * omitted, along with any descendants, from the <rpc-reply> message.
 * For NETCONF filtering purposes, the selection criteria are applied to the
 * subset of nodes that the user is authorized to read, not the entire datastore.
 * @note assume mode is internal or external, not disabled
 * @node There is unclarity on what "a data node" means wrt a read operation.
 * Suppose a tree is accessed. Is "the data node" just the top of the tree?
 * (1) Or is it all nodes, recursively, in the data-tree?
 * (2) Or is the datanode only the requested tree, NOT the whole datatree?
 * Example: 
 * - r0 default permit/deny *
 * - rule r1 to permit/deny /a
 * - rule r2 to permit/deny /a/b
 * - rule r3 to permit/deny /a/b/c
 * - rule r4 to permit/deny /d

 * - read access on /a/b which returns <a><b><c/><d/></b></a>?
 * permit - t; deny - f
 *    r1  |  r2  |  r3  | result (r0 and r4 are dont cares - dont match)
 *  ------+------+------+---------
 *    t   |  t   |  t   | <a><b><c/><d/></b></a>  
 *    t   |  t   |  f   | <a><b><d/></b></a>
 *    t   |  f   |  t   | <a/>       
 *    t   |  f   |  f   | <a/>     
 *    f   |  t   |  t   | 
 *    f   |  t   |  f   | 
 *    f   |  f   |  t   | 
 *    f   |  f   |  f   | 
 *
 * - read access on / which returns <d/><e/>?
 * permit - t; deny - f
 *    r0  |  r4  | result
 *  ------+------+---------
 *    t   |  t   | <d/><e/>
 *    t   |  f   | <e/>
 *    f   |  t   | <d/>
 *    f   |  f   | 
 * Algorithm 1, based on an xml tree XT:
 * The special variable ACTION can have values: 
 *      permit/deny/default
 * 1. Traverse through all nodes x in xt. Set ACTION to default
 *   - Find first exact matching rule r of non-default rules r1-rn on x
 *     - if found set ACTION to r->action (permit/deny).
 *   - if ACTION is deny purge x and all descendants
 *   - if ACTION is permit, mark x as PERMIT
 *   - continue traverse
 * 2. If default action is 
 * 2. Traverse through all nodes x in xt. Set ACTION to default r0->action
 *   - if x is marked as PERMIT
 *   - if ACTION is deny deny purge x and all descendants
 *
 * Algorithm 2 (based on requested node set XRS which are sub-trees in XT).
 * For each XR in XRS, check match with rule r1-rn, r0.
 * 1. XR is PERMIT 
 *     - Recursively match subtree to find reject sub-trees and purge.
 * 2. XR is REJECT. Purge XR.
 * Module-rule w no path is implicit rule on top node.
 *
 * A module rule has the "module-name" leaf set but no nodes from the
 * "rule-type" choice set.
 * @see RFC8341 3.4.5.  Data Node Access Validation
 * @see nacm_datanode_write
 * @see nacm_rpc
 */
int
nacm_datanode_read(cxobj  *xt,
		   cxobj **xrvec,
		   size_t  xrlen,    
		   char   *username,
		   cxobj  *xnacm)
{
    int     retval = -1;
    cxobj **gvec = NULL; /* groups */
    size_t  glen;
    cxobj  *xr;
    cxobj **rlistvec = NULL; /* rule-list */
    size_t  rlistlen;
    int     i;
    char   *read_default = NULL;
    cxobj  *xrule;
    char   *action;
    
    /* 3.   Check all the "group" entries to see if any of them contain a
       "user-name" entry that equals the username for the session
       making the request.  (If the "enable-external-groups" leaf is
       "true", add to these groups the set of groups provided by the
       transport layer.)	       */
    if (username == NULL)
	goto step9;
    /* User's group */
    if (xpath_vec(xnacm, "groups/group[user-name='%s']", &gvec, &glen, username) < 0)
	goto done;
    /* 4. If no groups are found (glen=0), continue and check read-default 
          in step 11. */
    /* 5. Process all rule-list entries, in the order they appear in the
        configuration.  If a rule-list's "group" leaf-list does not
        match any of the user's groups, proceed to the next rule-list
        entry. */
    if (xpath_vec(xnacm, "rule-list", &rlistvec, &rlistlen) < 0)
	goto done;
    /* read-default has default permit so should never be NULL */
    if ((read_default = xml_find_body(xnacm, "read-default")) == NULL){
	clicon_err(OE_XML, EINVAL, "No nacm read-default rule");
	goto done;
    }
    for (i=0; i<xrlen; i++){     /* Loop through requested nodes */
	xr = xrvec[i]; /* requested node XR */
	/* Loop through rule-list (steps 5,6,7) to find match of requested node
	 */
	xrule = NULL;
	/* Skip if no groups */
	if (glen && nacm_data_read_xr(xt, xr, gvec, glen, rlistvec, rlistlen,
				      &xrule) < 0) 
	    goto done;
	if (xrule){ /* xrule match requested node xr */
	    if ((action = xml_find_body(xrule, "action")) == NULL)
		continue;
	    if (strcmp(action, "deny")==0){
		if (xml_purge(xr) < 0)
		    goto done;
	    }
	    else if (strcmp(action, "permit")==0)
		;/* XXX recursively find denies in xr and purge them 
		  * ie call nacm_data_read_xr recursively?
		  */
	}
	else{ /* no rule matching xr, apply default */
    /*11.  For a "read" access operation, if the "read-default" leaf is set
        to "permit", then include the requested data node in the reply;
        otherwise, do not include the requested data node or any of its
        descendants in the reply.*/
	    if (strcmp(read_default, "deny")==0)
		if (xml_purge(xr) < 0)
		    goto done;
	}
    } /* xr */
    goto ok;
    /* 8.   At this point, no matching rule was found in any rule-list
       entry. */
 step9:
    /*    9.   For a "read" access operation, if the requested data node is
        defined in a YANG module advertised in the server capabilities
        and the data definition statement contains a
        "nacm:default-deny-all" statement, then the requested data node
        and all its descendants are not included in the reply.
    */
    for (i=0; i<xrlen; i++)     /* Loop through requested nodes */
	if (xml_purge(xrvec[i]) < 0)
	    goto done;
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (gvec)
	free(gvec);
    if (rlistvec)
	free(rlistvec);
    return retval;
}
	      
/*! Make nacm datanode and module rule write access validation
 * The operations of NACM are: create, read, update, delete, exec
 *  where write is short-hand for create+delete+update
 * @param[in]  xt       XML root tree with "config" label. XXX?
 * @param[in]  xr       XML requestor node (part of xt)
 * @param[in]  op       NACM access of xr
 * @param[in]  username User making access
 * @param[in]  xnacm    NACM xml tree
 * @param[out] cbret Cligen buffer result. Set to an error msg if retval=0.
 * @retval -1  Error
 * @retval  0  Not access and cbret set
 * @retval  1  Access
 * @see RFC8341 3.4.5.  Data Node Access Validation
 * @see nacm_datanode_read
 * @see nacm_rpc
 */
int
nacm_datanode_write(cxobj           *xt,
		    cxobj           *xr,
		    enum nacm_access access,
		    char            *username,
		    cxobj           *xnacm,
		    cbuf            *cbret)
{
    int retval = -1;
    cxobj **gvec = NULL; /* groups */
    size_t  glen;
    cxobj **rlistvec = NULL; /* rule-list */
    size_t  rlistlen;
    cxobj  *rlist;
    cxobj **rvec = NULL; /* rules */
    size_t  rlen;
    int     i, j;
    char   *gname;
    cxobj  *xrule;
    int     match = 0;
    char   *action;
    char   *write_default = NULL;
    
    if (xnacm == NULL)
	goto permit;
    /* 3.   Check all the "group" entries to see if any of them contain a
       "user-name" entry that equals the username for the session
       making the request.  (If the "enable-external-groups" leaf is
       "true", add to these groups the set of groups provided by the
       transport layer.)	       */
    if (username == NULL)
	goto step9;
    /* User's group */
    if (xpath_vec(xnacm, "groups/group[user-name='%s']", &gvec, &glen, username) < 0)
	goto done;
    /* 4. If no groups are found, continue with step 9. */
    if (glen == 0)
	goto step9;
    /* 5. Process all rule-list entries, in the order they appear in the
        configuration.  If a rule-list's "group" leaf-list does not
        match any of the user's groups, proceed to the next rule-list
        entry. */
    if (xpath_vec(xnacm, "rule-list", &rlistvec, &rlistlen) < 0)
	goto done;
    for (i=0; i<rlistlen; i++){
	rlist = rlistvec[i];
    	/* Loop through user's group to find match in this rule-list */
	for (j=0; j<glen; j++){
	    gname = xml_find_body(gvec[j], "name");
	    if (xpath_first(rlist, ".[group='%s']", gname)!=NULL)
		break; /* found */
	}
	if (j==glen) /* not found */
	    continue;
	if (xpath_vec(rlist, "rule", &rvec, &rlen) < 0)
	    goto done;
	/* 6. For each rule-list entry found, process all rules, in order,
	   until a rule that matches the requested access operation is
	   found. (see 6 sub rules in nacm_rule_data_write)
	*/
	for (j=0; j<rlen; j++){ /* Loop through rules */
	    xrule = rvec[j];
	    if ((match = nacm_rule_datanode(xt, xr, xrule, access)) < 0)
		goto done;
	    if (match) /* match */
		break;
	}
	if (match)
	    break;
	if (rvec){
	    free(rvec);
	    rvec = NULL;
	}
    }
    if (match){
	if ((action = xml_find_body(xrule, "action")) == NULL)
	    goto step9;
	if (strcmp(action, "deny")==0){
	    if (netconf_access_denied(cbret, "application", "access denied") < 0)
		goto done;
	    goto deny;
	}
	else if (strcmp(action, "permit")==0)
	    goto permit;

    }
    /*  8.   At this point, no matching rule was found in any rule-list
	entry. */
 step9:   
    /* 10.  For a "write" access operation, if the requested data node is
        defined in a YANG module advertised in the server capabilities
        and the data definition statement contains a
        "nacm:default-deny-write" or a "nacm:default-deny-all"
        statement, then the access request is denied for the data node
        and all its descendants.
	XXX
    */
    /*12.  For a "write" access operation, if the "write-default" leaf is
        set to "permit", then permit the data node access request;
        otherwise, deny the request.*/
    /* write-default has default permit so should never be NULL */
    if ((write_default = xml_find_body(xnacm, "write-default")) == NULL){
	clicon_err(OE_XML, EINVAL, "No nacm write-default rule");
	goto done;
    }
    if (strcmp(write_default, "permit") != 0){
	if (netconf_access_denied(cbret, "application", "default deny") < 0)
	    goto done;
	goto deny;
    }
 permit:
    retval = 1;
 done:
    clicon_debug(1, "%s retval:%d (0:deny 1:permit)", __FUNCTION__, retval);
    if (gvec)
	free(gvec);
    if (rlistvec)
	free(rlistvec);
    if (rvec)
	free(rvec);
    return retval;
 deny: /* Here, cbret must contain a netconf error msg */
    assert(cbuf_len(cbret));
    retval = 0;
    goto done;
}

/*---------------------------------------------------------------
 * NACM pre-procesing
 */

/*! NACM intial pre- access control enforcements 
 * Initial NACM steps and common to all NACM access validation.
 * If retval=0 continue with next NACM step, eg rpc, module, 
 * etc. If retval = 1 access is OK and skip next NACM step.
 * @param[in]  h        Clicon handle
 * @param[in]  xnacm    NACM XML tree, root should be "nacm"
 * @param[in]  username User name of requestor
 * @retval -1  Error
 * @retval  0  OK but not validated. Need to do NACM step using xnacm
 * @retval  1  OK permitted. You do not need to do next NACM step
 * @code
 *   if ((ret = nacm_access(mode, xnacm, username)) < 0)
 *     err;
 *   if (ret == 0){
 *      // Next step NACM processing
 *      xml_free(xnacm);
 *   }
 * @endcode
 * @see RFC8341 3.4 Access Control Enforcement Procedures
 */
int
nacm_access(char          *mode,
	    cxobj         *xnacm,
	    char          *username)
{
    int     retval = -1;
    cxobj  *xnacm0 = NULL;
    char   *enabled;
    cxobj  *x;
    
    clicon_debug(1, "%s", __FUNCTION__);
    if (mode == NULL || strcmp(mode, "disabled") == 0)
	goto permit;
    /* 0. If nacm-mode is external, get NACM defintion from separet tree,
       otherwise get it from internal configuration */
    if (strcmp(mode, "external") && strcmp(mode, "internal")){
	clicon_err(OE_XML, 0, "Invalid NACM mode: %s", mode);
	goto done;
    }
    /* If config does not exist, then the operation is permitted. (?) */
    if (xnacm == NULL)
	goto permit;
    /* Do initial nacm processing common to all access validation in
     * RFC8341 3.4 */
    /* 1.   If the "enable-nacm" leaf is set to "false", then the protocol
       operation is permitted. */
    if ((x = xpath_first(xnacm, "enable-nacm")) == NULL)
	goto permit;
    enabled = xml_body(x);
    if (strcmp(enabled, "true") != 0)
	goto permit;
    /* 2.   If the requesting session is identified as a recovery session,
       then the protocol operation is permitted. NYI */
    if (username && strcmp(username, NACM_RECOVERY_USER) == 0)
	goto permit;

    retval = 0; /* not permitted yet. continue with next NACM step */
 done:
    if (retval != 0 && xnacm0)
	xml_free(xnacm0);
    clicon_debug(1, "%s retval:%d (0:deny 1:permit)", __FUNCTION__, retval);
    return retval;
 permit:
    retval = 1;
    goto done;
}

/*! NACM intial pre- access control enforcements 
 * Initial NACM steps and common to all NACM access validation.
 * If retval=0 continue with next NACM step, eg rpc, module, 
 * etc. If retval = 1 access is OK and skip next NACM step.
 * @param[in]  h        Clicon handle
 * @param[in]  username User name of requestor
 * @param[in]  point  NACM access control point
 * @param[out] xncam    NACM XML tree, set if retval=0. Free after use
 * @retval -1  Error
 * @retval  0  OK but not validated. Need to do NACM step using xnacm
 * @retval  1  OK permitted. You do not need to do next NACM step
 * @code
 *   cxobj *xnacm = NULL;
 *   if ((ret = nacm_access_pre(h, username, &xnacm)) < 0)
 *     err;
 *   if (ret == 0){
 *      // Next step NACM processing
 *      xml_free(xnacm);
 *   }
 * @endcode
 * @see RFC8341 3.4 Access Control Enforcement Procedures
 */
int
nacm_access_pre(clicon_handle  h,
		char          *username,
		enum nacm_point point,
		cxobj        **xnacmp)
{
    int    retval = -1;
    char  *mode;
    cxobj *x;
    cxobj *xnacm0 = NULL;
    cxobj *xnacm = NULL;
    
    if ((mode = clicon_option_str(h, "CLICON_NACM_MODE")) != NULL){
	if (strcmp(mode, "external")==0){
	    if ((x = clicon_nacm_ext(h)))
		if ((xnacm0 = xml_dup(x)) == NULL)
		    goto done;
	}
	else if (strcmp(mode, "internal")==0){
	    if (xmldb_get(h, "running", "nacm", &xnacm0, NULL) < 0)
		goto done;
	}
    }
    /* If config does not exist then the operation is permitted(?) */
    if (xnacm0 == NULL)
	goto permit;
    /* If config does not exist then the operation is permitted(?) */
    if ((xnacm = xpath_first(xnacm0, "nacm")) == NULL)
	goto permit;
    if (xml_rootchild_node(xnacm0, xnacm) < 0)
	goto done;
    xnacm0 = NULL;
    if ((retval = nacm_access(mode, xnacm, username)) < 0)
	goto done;
    if (retval == 0){ /* if retval == 0 then return an xml nacm tree */
	*xnacmp = xnacm;
	xnacm = NULL;
    }
 done:
    if (xnacm0)
	xml_free(xnacm0);
    else if (xnacm)
	xml_free(xnacm);
    return retval;
 permit:
    retval = 1;
    goto done;
}

