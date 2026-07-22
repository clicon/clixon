#
# Makefile for clixon HTTP/1 libFuzzer target
#

.PHONY: all clean run

RESTCONF = ../../../apps/restconf
INCLUDES = -I$(RESTCONF) \
           -I../../../lib/clixon -I../../../lib/src -I../../../lib \
           -I../../../include -I../../..

# Locate libstdc++ search path the same way build.sh does
STDCPPDIR := $(shell dirname "$$(gcc -print-file-name=libstdc++.so 2>/dev/null)" 2>/dev/null)
STDCPPFLAG := $(if $(STDCPPDIR),-L$(STDCPPDIR),)

all: fuzz_http1

fuzz_http1: fuzz_http1.c \
            $(RESTCONF)/clixon_http1_parse.tab.c \
            $(RESTCONF)/lex.clixon_http1_parse.c
	clang -g -O1 -fsanitize=fuzzer,address \
	    $(INCLUDES) \
	    -DHAVE_CONFIG_H \
	    fuzz_http1.c \
	    $(RESTCONF)/clixon_http1_parse.tab.c \
	    $(RESTCONF)/lex.clixon_http1_parse.c \
	    -o fuzz_http1 \
	    -L/usr/local/lib $(STDCPPFLAG) -lclixon -lcligen

run: fuzz_http1
	mkdir -p corpus_http1 artifacts_http1
	LD_LIBRARY_PATH=/usr/local/lib ./fuzz_http1 corpus_http1 \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=16384 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_http1/

clean:
	rm -f fuzz_http1
	rm -rf corpus_http1 artifacts_http1
