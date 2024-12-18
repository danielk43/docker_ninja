#!/usr/bin/env bash

set -e

clean=0
prune=0
dir="$PWD"

usage() {
  echo "Deep clean git or repo project"
  echo
  echo "Usage:"
  echo "  Options:"
  echo "    -c Clean and reset source"
  echo "    -d target Directory"
  echo "    -g git Gc and prune (caution: time-consuming)"
  echo "    -x run git clean with -ffd + X"
  echo
  echo "  Example:"
  echo "    $ cd /path/to/chromium/src"
  echo "    $ ./clean-git-repo.sh -cgx"
  echo
  exit 1
}

while getopts ":d:cgx" opt; do
  case $opt in
    c) clean=1 ;;
    d) dir=$OPTARG ;;
    g) prune=1 ;;
    x) xflag=x ;;
    \?) echo -e "Invalid option:-$OPTARG\n"
       usage ;;
  esac
done
shift $((OPTIND-1))

# Reset source
clean_src() {
  rm -rf out releases ./*.zip
  find . -type f -name "index.lock" -delete
  echo -e "\nClean and Reset src in $dir"
  for cmd in am cherry-pick merge rebase revert; do
    echo "Running cmd: ${REPO_PREFIX} git $cmd --abort"
    ${REPO_PREFIX} git "$cmd" --abort 2>/dev/null || true
    echo "Running cmd: ${REPO_PREFIX} git submodule foreach git $cmd --abort"
    ${REPO_PREFIX} git submodule foreach "git $cmd --abort" 2>/dev/null || true
  done
  for cmd in "add --all" "reset --hard" "clean -ffd${xflag}"
  do
    echo "Running cmd: ${REPO_PREFIX} git $cmd"
    ${REPO_PREFIX} git "$cmd" || true
    echo "Running cmd: ${REPO_PREFIX} git submodule foreach git $cmd"
    ${REPO_PREFIX} git submodule foreach "git $cmd" 2>/dev/null || true
  done
}

# Address loose object warnings; gc and prune
prune_src() {
  echo "Expire reflog and Prune src in $dir"
  echo "Running cmd: ${REPO_PREFIX} git reflog expire --all --expire-unreachable=now"
  ${REPO_PREFIX} git reflog expire --all --expire-unreachable=now || true
  echo "Running cmd: ${REPO_PREFIX} git gc --aggressive --prune=now"
  ${REPO_PREFIX} git gc --aggressive --prune=now || true
  echo "Running cmd: ${REPO_PREFIX} git submodule foreach git reflog expire --all --expire-unreachable=now"
  ${REPO_PREFIX} git submodule foreach "git reflog expire --all --expire-unreachable=now" || true
  echo "Running cmd: ${REPO_PREFIX} git submodule foreach git gc --aggressive --prune=now"
  ${REPO_PREFIX} git submodule foreach "git gc --aggressive --prune=now" || true
}

# Allow existing repo to work in container (will change some ownership to root)
repo_safe_dir() {
  if [[ -d "./.git" && -f /.dockerenv ]]
  then
    git config --global --add safe.directory "${PWD}"
    # shellcheck disable=SC2046
    for repository in $(dirname $(find . -type d -name .git -printf "%P\n")) 
    do
      git config --global --add safe.directory "${PWD}"/"${repository}"
    done
  elif [[ -d "./.repo" && -f "/.dockerenv" ]]
  then
    git config --global --add safe.directory "${PWD}/.repo/manifests"
    git config --global --add safe.directory "${PWD}/.repo/repo"
    for path in $(repo list -fp)
    do
      git config --global --add safe.directory "${path}"
    done
  fi
}

cd "$dir"

if [[ -d "./.git" ]]
then
  echo "Git Project Detected"
elif [[ -d "./.repo" ]]
then
  REPO_PREFIX="repo forall -c" && echo "Repo Project Detected"
else
  echo "Not a Git or Repo project. Nothing to do" && usage
fi

repo_safe_dir
[[ "$clean" == "1" ]] && clean_src
[[ "$prune" == "1" ]] && prune_src

exit 0
