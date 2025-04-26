#!/bin/bash
cat log.txt | grep -oP 'UCP_PARALLELRUN:[^,]+' | sort -u | sed 's/.*/disable & \n/'  > output.txt
