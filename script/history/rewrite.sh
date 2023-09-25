
echo back to the future !

# tiny modif to try filter-branch utility
# rename a commit where the date were not present
#git filter-branch --msg-filter 'sed "s/Update [^2F].*/Update 2020-03-22/"'
#git push --force

# ok that works, now change everything
# reformat file => .tsv => .csv
# 2022-01-21 => CG puzzle renaming
# multi/amazonial.tsv                multi/wondev-woman.tsv (but in 2023-01-07, come back?)
# multi/broomstick-flyers.tsv        multi/fantastic-bits.tsv (but in 2023-01-07, come back?)
# multi/cyborg-uprising.tsv          multi/ghost-in-the-cell.tsv (but in 2023-01-07, come back?)
# multi/galleon-wars.tsv             multi/coders-of-the-caribbean.tsv (but in 2023-01-07, come back?)
# multi/line-racing.tsv              multi/tron-battle.tsv (but in 2023-01-07, come back?)
# multi/mad-pod-racing.tsv           multi/coders-strike-back.tsv
# multi/soul-snatchers.tsv           multi/codebusters.tsv (but in 2023-01-07, come back?)
# multi/time-travelers.tsv           multi/back-to-the-code.tsv (but in 2023-01-07, come back?)
# optim/brain-fork.tsv               optim/code-of-the-rings.tsv (but in 2022-10-13, come back?)
git filter-branch -f --tree-filter "
  root_folder=$PWD "$'
  # grrr "commit" variable seems to be used by filter-branch (equal to $GIT_COMMIT)
  commit_msg="`git log --pretty=%B -n 1 $GIT_COMMIT`"
  if [[ "$commit_msg" =~ "Update 2021-06-23" ]]; then
    after20210623=ok
    echo after 2021-06-23
  fi
  if [[ "$commit_msg" =~ "Update 2022-01-21" ]]; then
    multi=rename
    optim=rename
    echo start rename
  fi
  if [[ "$commit_msg" =~ "Update 2022-10-13" ]]; then
    optim=delete
    echo stop rename optim
  fi
  if [[ "$commit_msg" =~ "Update 2023-01-07" ]]; then
    multi=delete
    echo stop rename multi
  fi
  if [ "$multi" = rename ]; then
    mv multi/amazonial.tsv multi/wondev-woman.tsv
    mv multi/broomstick-flyers.tsv multi/fantastic-bits.tsv
    mv multi/cyborg-uprising.tsv multi/ghost-in-the-cell.tsv
    mv multi/galleon-wars.tsv multi/coders-of-the-caribbean.tsv
    mv multi/line-racing.tsv multi/tron-battle.tsv
    rm multi/coders-strike-back.tsv
    mv multi/soul-snatchers.tsv multi/codebusters.tsv
    mv multi/time-travelers.tsv multi/back-to-the-code.tsv
  fi
  if [ "$multi" = delete ]; then
    rm multi/amazonial.tsv
    rm multi/broomstick-flyers.tsv
    rm multi/cyborg-uprising.tsv
    rm multi/galleon-wars.tsv
    rm multi/line-racing.tsv
    rm multi/coders-strike-back.tsv
    rm multi/soul-snatchers.tsv
    rm multi/time-travelers.tsv
  fi
  if [ -e multi/coders-strike-back.tsv ]; then
    mv multi/coders-strike-back.tsv multi/mad-pod-racing.tsv
  fi
  if [ "$optim" = rename ]; then
    mv optim/brain-fork.tsv optim/code-of-the-rings.tsv
  fi
  if [ "$optim" = delete ]; then
    rm optim/brain-fork.tsv
  fi

  find . -name "*.tsv" -exec bash -c \'
    sed -i "" -e "y/\t ,/,T|/" "$0"
    mv "${0}" "${0%.tsv}.csv"
  \' {} \\;

  if [ -d golf ]; then
    rm -rf challenge
    find optim multi -name "*.csv" -exec bash -c \'
      mkdir "${0%.csv}"
      mv "${0}" "${0%.csv}/all.csv"
    \' {} \\;
    mkdir puzzle
    mv [^p]*/ puzzle/.
  fi

  # easier in ruby for that part :)
  ruby $root_folder/script/history/refactor.rb "$root_folder" "$after20210623"
  ruby $root_folder/script/history/event.rb "$root_folder"

'

ruby script/history/fix_prev_next.rb
rm -f script/history/db_dates.hash
rm -rf script/history/puzzle


# Available variable in filter-branch

# GIT_AUTHOR_DATE=@1567844123 +0200
# GIT_AUTHOR_EMAIL=xx@xx.xxx
# GIT_AUTHOR_NAME=My name
# GIT_COMMIT=74baae4d070bb138d6dc0d09d2901e19d05c4e28
# GIT_COMMITTER_DATE=@1567844123 +0200
# GIT_COMMITTER_EMAIL=xx@xxx.xxx
# GIT_COMMITTER_NAME=My name
# GIT_DIR=/absolute/path/to/repo/.git
# GIT_EXEC_PATH=/absolute/path/to/git-core
# GIT_INDEX_FILE=/absolute/path/to/repo/.git-rewrite/t/../index
# GIT_INTERNAL_GETTEXT_SH_SCHEME=gnu
# GIT_WORK_TREE=.