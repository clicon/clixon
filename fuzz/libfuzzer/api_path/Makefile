#
# Makefile for clixon api-path / instance-id libFuzzer target
#

.PHONY: all clean run

all: fuzz_api_path

fuzz_api_path:
	./build.sh

artifacts_api_path:
	mkdir $@

run: artifacts_api_path fuzz_api_path
	LD_LIBRARY_PATH=/usr/local/lib ./fuzz_api_path corpus_api_path \
	    -fork=4 \
	    -ignore_timeouts=1 -ignore_ooms=1 \
	    -max_len=4096 \
	    -rss_limit_mb=2048 \
	    -timeout=10 \
	    -artifact_prefix=artifacts_api_path/

clean:
	rm -f fuzz_api_path api_path.log artifacts_api_path/*
