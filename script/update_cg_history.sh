
rm -rf tmp/puzzle

# Get sometimes a 502 Bad Gateway... so retry!
for retry in {1..20}; do
  echo try $retry
  ruby script/update_docs.rb && {
    ruby script/history/fix_prev_next.rb
    break
  }
done
