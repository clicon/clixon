/*
 * Utility debug tool
 * Static Compile:  gcc -Wall json_xpath.c -o json_xpath -l clixon
gcc -O2 -o json_xpath json_xpath.c clixon_log.o clixon_err.o clixon_json.o clixon_xml.o clixon_xsl.o clixon_json_parse.tab.o clixon_xml_parse.tab.o lex.clixon_json_parse.o lex.clixon_xml_parse.o ../../../cligen/cligen_buf.o ../../../cligen/cligen_var.o ../../../cligen/cligen_gen.o ../../../cligen/cligen_cvec.o ../../../cligen/cligen_handle.o ../../../cligen/getline.o ../../../cligen/cligen_read.o ../../../cligen/cligen_match.o ../../../cligen/cligen_expand.o  ../../../cligen/cligen_print.o
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

static int
usage(char *argv0)
{
    fprintf(stderr, "usage:%s <xpath> # XML/JSON expected on stdin\n"
	    "\t-h    Help\n"
    	    "\t-b    Strip to body value (eg \"<a>val</a>\" --> \"val\"\n"
	    "\t-j    json input (not xml)\n",
	    argv0);
    exit(0);
}

int
main(int argc, char **argv)
{
    int i;
    cxobj     **xv;
    cxobj      *x;
    cxobj      *xn;
    cxobj      *xb;
    char       *xpath;
    int         body = 0;
    int         json = 0;
    size_t      xlen = 0;
    size_t      len;
    size_t      buflen = 128;
    char       *buf;
    char       *p;
    int         retval;
    char        c;

    while ((c = getopt(argc, argv, "?hbj")) != -1)
      switch (c) {
      case '?':
      case 'h':
	usage(argv[0]);
	break;
      case 'b':
	body++;
	break;
      case 'j':
	json++;
	break;
      default:
	usage(argv[0]);
      }
    if (optind >= argc)
      usage(argv[0]);
    xpath=argv[optind];

    clicon_log_init("xpath", 0, CLICON_LOG_STDERR);
    if ((buf = malloc(buflen)) == NULL){
	perror("malloc");
	return -1;
    }
    /* |---------------|-------------| 
     * buf             p             buf+buflen
     */
    p = buf;
    memset(p, 0, buflen);
    while (1){
	if ((retval = read(0, p, buflen-(p-buf))) < 0){
	    perror("read");
	    return -1;
	}
	if (retval == 0)
	    break;
	p += retval; 
	len = p-buf;

	if (buf+buflen-p < 10){ /* allocate more */
	    buflen *= 2;
	    if ((buf = realloc(buf, buflen)) == NULL){
		perror("realloc");
		return -1;
	    }
	    p = buf+len;
	    memset(p, 0, (buf+buflen)-p);
	}
    }
    if (json){
      if (json_parse_str(buf, &x) < 0)
	return -1;
    }
    else
      if (clicon_xml_parse_str(buf, &x) < 0)
	return -1;

    if (xpath_vec(x, xpath, &xv, &xlen) < 0)
	return -1;
    if (xv){
	for (i=0; i<xlen; i++){
	    xn = xv[i];
	    if (body)
	      xb = xml_find(xn, "body");
	    else
	      xb = xn;
	    if (xb){
	      //	      xml2json(stdout, xb, 0);
	      clicon_xml2file(stdout, xb, 0, 0);
	      fprintf(stdout,"\n");
	    }
	}
	free(xv);
    }
    if (x)
	xml_free(x);
    if (buf)
	free(buf);
    return 0;
}
