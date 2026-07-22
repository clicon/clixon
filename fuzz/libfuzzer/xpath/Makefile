#
# Makefile for clixon XPath libFuzzer target
#

.PHONY: all clean run

all: fuzz_xpath

fuzz_xpath:
	./build.sh

artifacts_xpath:
	mkdir $@

run: artifacts_xpath fuzz_xpath
	  LD_LIBRARY_PATH=/usr/local/lib ./fuzz_xpath corpus_xpath \
	    -dict=../xpath.dict \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=4096 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_xpath/

clean:
	rm -f fuzz_xpath xpath.log artifacts_xpath/*
