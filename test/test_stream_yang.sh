#!/usr/bin/env bash
# Notifications without a YANG definition must not reach stream subscribers.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

fyang=$dir/example.yang
cfile=$dir/stream_yang.c
app=$dir/stream_yang

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;

    notification event {
        leaf severity {
            type string;
        }
    }
}
EOF

cat <<EOF > $cfile
#include <stdio.h>
#include <cligen/cligen.h>
#include <clixon/clixon.h>

static int notifications;

static int
notification_cb(clixon_handle h, int op, cxobj *event, void *arg)
{
    notifications++;
    return 0;
}

static int
notify_xml(clixon_handle h, const char *event)
{
    cxobj *xt = NULL;
    int    retval = -1;

    if (clixon_xml_parse_string(event, YB_NONE, NULL, &xt, NULL) < 0)
        goto done;
    if (xml_rootchild(xt, 0, &xt) < 0)
        goto done;
    retval = stream_notify_xml(h, "EXAMPLE", xt);
 done:
    if (xt)
        xml_free(xt);
    return retval;
}

int
main(int argc, char **argv)
{
    clixon_handle h = NULL;
    yang_stmt    *yspec;
    int           valid_str;
    int           invalid_str;
    int           valid_xml;
    int           invalid_xml;
    int           status = 1;

    if (argc != 2)
        return 2;
    if ((h = clixon_handle_init()) == NULL){
        fprintf(stderr, "clixon_handle_init failed\n");
        goto done;
    }
    if (clixon_err_init(h) < 0)
        goto done;
    xml_init(h);
    yang_init(h);
    yang_start(h);
    if ((yspec = yspec_new1(h, YANG_DOMAIN_TOP, YANG_DATA_TOP)) == NULL){
        fprintf(stderr, "yspec_new1 failed\n");
        goto done;
    }
    if (yang_spec_parse_file(h, argv[1], yspec) < 0){
        fprintf(stderr, "yang_spec_parse_file failed\n");
        goto done;
    }
    if (stream_add(h, "EXAMPLE", "Example event stream", 0, NULL) < 0){
        fprintf(stderr, "stream_add failed\n");
        goto done;
    }
    if (stream_ss_add(h, "EXAMPLE", NULL, NULL, NULL, notification_cb, NULL) == NULL){
        fprintf(stderr, "stream_ss_add failed\n");
        goto done;
    }
    valid_str = stream_notify(h, "EXAMPLE",
                              "<event xmlns=\"urn:example:clixon\"><severity>major</severity></event>");
    invalid_str = stream_notify(h, "EXAMPLE",
                                "<unknown xmlns=\"urn:example:unknown\"><severity>major</severity></unknown>");
    valid_xml = notify_xml(h, "<event xmlns=\"urn:example:clixon\"><severity>major</severity></event>");
    invalid_xml = notify_xml(h, "<unknown xmlns=\"urn:example:unknown\"><severity>major</severity></unknown>");
    printf("valid_str=%d invalid_str=%d valid_xml=%d invalid_xml=%d notifications=%d\n",
           valid_str, invalid_str, valid_xml, invalid_xml, notifications);
    if (valid_str == 0 && invalid_str == -1 &&
        valid_xml == 0 && invalid_xml == -1 && notifications == 2)
        status = 0;
 done:
    if (h){
        stream_delete_all(h, 1);
        xml_exit(h);
        yang_exit(h);
        clixon_handle_exit(h);
    }
    return status;
}
EOF

: ${CLIXON_PREFIX:=/usr/local}
: ${CLIGEN_PREFIX:=${CLIXON_PREFIX}}
if [ "$LINKAGE" = static ]; then
    COMPILE="$CC ${CFLAGS} -I${CLIXON_PREFIX}/include -I${CLIGEN_PREFIX}/include $cfile -o $app -L${CLIGEN_PREFIX}/lib ${CLIXON_PREFIX}/lib/libclixon${LIBSTATIC_SUFFIX} ${LIBS}"
else
    COMPILE="$CC ${CFLAGS} -I${CLIXON_PREFIX}/include -I${CLIGEN_PREFIX}/include $cfile -o $app -L${CLIXON_PREFIX}/lib -L${CLIGEN_PREFIX}/lib -lclixon -lcligen"
fi

new "compile $cfile -> $app"
expectpart "$($COMPILE)" 0 ""

new "validate notifications against YANG definitions"
expectpart "$($app $fyang)" 0 "valid_str=0 invalid_str=-1 valid_xml=0 invalid_xml=-1 notifications=2"

rm -rf $dir
new "endtest"
endtest
