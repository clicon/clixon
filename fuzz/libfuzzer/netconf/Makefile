#
# Makefile for clixon NETCONF libFuzzer target
#

.PHONY: all clean run

all: fuzz_netconf

fuzz_netconf:
	./build.sh

artifacts_netconf:
	mkdir $@

run: artifacts_netconf fuzz_netconf
	  ./fuzz_netconf corpus_netconf \
	    -dict=../xml.dict \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=4096 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_netconf

clean:
	rm -f fuzz_netconf netconf.log artifacts_netconf/*
