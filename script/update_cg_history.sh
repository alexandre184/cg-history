#!/bin/bash

rm -rf tmp/puzzle

# Get sometimes a 502 Bad Gateway... so retry!
#for retry in {1..20}; do
for ((retry = 1; retry <= 20; retry++)); do
  echo try $retry
  git restore puzzle
  ruby script/update_docs.rb && {
    ruby script/history/fix_prev_next.rb
    break
  }
done
