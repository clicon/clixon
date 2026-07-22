#
# Makefile for clixon JSON libFuzzer target
#

.PHONY: all clean run

all: fuzz_json

fuzz_json:
	./build.sh

artifacts_json:
	mkdir $@

run: artifacts_json fuzz_json
	  ./fuzz_json corpus_json \
	    -dict=../json.dict \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=4096 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_json/

clean:
	rm -f fuzz_json json.log artifacts_json/*
