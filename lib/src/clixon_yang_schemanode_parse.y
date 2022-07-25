/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

  Just syntax check, return no data

 * descendant-schema-nodeid RFC7950 14
   descendant-schema-nodeid = node-identifier
                         [absolute-schema-nodeid]

   absolute-schema-nodeid = 1*("/" node-identifier)

   node-identifier     = [prefix ":"] identifier

   prefix              = identifier
   identifier          = (ALPHA / "_")
                         *(ALPHA / DIGIT / "_" / "-" / ".")

 */
%union {
    char *string;
    void *stack;
    int number;
}

%token MY_EOF
%token <string>   IDENTIFIER

%start top

%lex-param     {void *_if} /* Add this argument to parse() and lex() function */
%parse-param   {void *_if}

%{
/* Here starts user C-code */
    
/* typecast macro */
#define _IF ((clixon_yang_schemanode_yacc *)_if)
#define _YYERROR(msg) {clicon_err(OE_YANG, 0, "%s", (msg)); YYERROR;}
    
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdlib.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_string.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_yang_module.h"
#include "clixon_xml_vec.h"
#include "clixon_data.h"
#include "clixon_yang_sub_parse.h"
#include "clixon_yang_schemanode_parse.h"

/* Enable for debugging, steals some cycles otherwise */
#if 0
#define _PARSE_DEBUG(s) clicon_debug(1,(s))
#else
#define _PARSE_DEBUG(s)
#endif
 
void 
clixon_yang_schemanode_parseerror(void *arg,
				  char *s) 
{
    clixon_yang_schemanode_yacc *ife = (clixon_yang_schemanode_yacc *)arg;

    clicon_err_fn(NULL, 0, OE_YANG, 0, "yang_schemanode_parse: file:%s:%d \"%s\" %s: at or before: %s", 
	       ife->if_mainfile,
	       ife->if_linenum,
	       ife->if_parse_string,
	       s,
	       clixon_yang_schemanode_parsetext); 
    return;
}

%} 
 
%%

/* See RFC 7950 Sec 14 refine-arg-str / usage-augment-arg-str */
top        : descendant_schema_nodeid MY_EOF
                    {
			_PARSE_DEBUG("top->descendant-schema-nodeid");
			if (_IF->if_accept == YA_DESC_SCHEMANODEID){
			    YYACCEPT;
			}
			else{
			    _YYERROR("descendant-schema-nodeid unexpected"); 
			}
		    }
           | absolute_schema_nodeid MY_EOF
                    {
			_PARSE_DEBUG("top->absolute-schema-nodeid");
			if (_IF->if_accept == YA_ABS_SCHEMANODEID){
			    YYACCEPT;
			}
			else{
			    _YYERROR("absolute-schema-nodeid unexpected"); 
			}
		    }
           ;

descendant_schema_nodeid
           : node_identifier
                    {
			_PARSE_DEBUG("descendant-schema-nodeid->node-identifier");
		    }
           | node_identifier absolute_schema_nodeid
	            {
			_PARSE_DEBUG("descendant-schema-nodeid->absolute-schema-nodeid");
		    }
           ;

absolute_schema_nodeid
           : absolute_schema_nodeid '/'  node_identifier 
                    {
			_PARSE_DEBUG("absolute-schema-nodeid->absolute-schema-nodeid '/' node-identifier");
		    }
           | '/'  node_identifier 
	            {
			_PARSE_DEBUG("absolute-schema-nodeid->'/' node-identifier");
		    }
           ;

/*   node-identifier     = [prefix ":"] identifier */
node_identifier : identifier
		   {
		       _PARSE_DEBUG("node-identifier -> identifier");
		       if (_IF->if_accept == YA_ID_REF){
			   YYACCEPT;
		       }
		   }
                | prefix ':' identifier
		{
		    _PARSE_DEBUG("node_identifier -> prefix : identifier");
		    if (_IF->if_accept == YA_ID_REF){
			YYACCEPT;
		    }
		}
                ;

prefix   : IDENTIFIER
		{
		    _PARSE_DEBUG("prefix -> IDENTIFIER");
		    free($1);
		}
         ;

identifier : IDENTIFIER
		{
		    _PARSE_DEBUG("identifier -> IDENTIFIER");
		    free($1);
		}
         ;

%%

