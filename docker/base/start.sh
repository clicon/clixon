#!/bin/bash
# Usage: ./startup.sh
# Debug: DBG=1 ./startup.sh
# See also cleanup.sh

>&2 echo "Running script: $0"


# Start clixon-example backend
sudo docker run  --name clixon --rm -td clixon/clixon || err "Error starting clixon"

>&2 echo "clixon started"




