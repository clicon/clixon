#
# Makefile for clixon YANG libFuzzer target
#

.PHONY: all clean run

all: fuzz_yang

fuzz_yang:
	./build.sh

artifacts_yang:
	mkdir $@

run: artifacts_yang fuzz_yang
	  ./fuzz_yang corpus_yang \
	    -dict=../yang.dict \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=4096 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_yang/

clean:
	rm -f fuzz_yang yang.log artifacts_yang/*
