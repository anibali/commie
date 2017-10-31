#!/bin/bash -e

remotedir=commie

while getopts ":s:p:c:n" opt; do
  case $opt in
    s)
      server=$OPTARG
      ;;
    p)
      projdir=$OPTARG
      ;;
    c)
      cmd=$OPTARG
      ;;
    n)
      noscreen="true"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

use_git() {
  git rev-parse --git-dir 2> /dev/null
}

list_unignored_files() {
  (
    # Untracked files
    git status -u --short | grep '^?' | cut -d\  -f2- &&
    # Tracked files
    git ls-files
  ) |
  # Remove duplicates
  sort -u |
  # Remove files not on disk (ie files which were renamed or removed)
  ( xargs -d '\n' -- stat -c%n 2>/dev/null  ||: ) |
  # Use absolute paths
  xargs -r realpath -s
}

if [ -z "$server" ]
then
  echo "Required parameter: -s <server>"
  exit 1
fi

if [ -z "$projdir" ]
then
  projdir="$PWD"
fi

projdir="$(realpath -s "$projdir")"

cd "$projdir"

ssh $server mkdir -p $remotedir

# Get files to sync
if use_git
then
  files="$(list_unignored_files)"
else
  files="$(find "$projdir")"
fi

# Copy files to server
echo "$files" | rsync -av --files-from=- / $server:$remotedir

if [ -n "$cmd" ]
then
  # Run remote command
  if [ -z "$noscreen" ]
  then
    ssh -t $server \
      "cd $remotedir$projdir &&" \
      "screen -L sh -c $(printf "%q" "$cmd") &&" \
      "less +G screenlog.0"
  else
    ssh -t $server \
      "cd $remotedir$projdir &&" \
      "sh -c $(printf "%q" "$cmd")"
  fi
fi
