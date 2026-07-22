#
# Makefile for clixon text_syntax libFuzzer target
#

.PHONY: all clean run

all: fuzz_text_syntax

fuzz_text_syntax:
	./build.sh

artifacts_test_syntax:
	mkdir $@

run: artifacts_test_syntax fuzz_text_syntax
	./fuzz_text_syntax corpus_text_syntax \
	    -dict=../text_syntax.dict \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=4096 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_text_syntax/

clean:
	rm -f fuzz_text_syntax text_syntax.log artifacts_text_syntax/*
