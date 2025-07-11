#!/usr/bin/env bash

set -e

clean=0
prune=0
xflag=""
dir="$PWD"
prune_since="2.weeks.ago"
expire_since="30.days.ago"

usage() {
  echo "Deep clean git or repo project"
  echo
  echo "Usage:"
  echo "  Options:"
  echo "    -c Clean and reset source"
  echo "    -d target Directory"
  echo "    -e Expire since date (default: '30.days.ago', use 'now' for aggressive)"
  echo "    -g git Gc and prune (caution: time-consuming)"
  echo "    -p Prune since date (default: '2.weeks.ago', use 'now' for aggressive)"
  echo "    -x run git clean with -ffd + X"
  echo
  echo "  Example:"
  echo "    $ ./clean-git-repo.sh -cgx -d /path/to/chromium/src"
  echo
  exit 1
}

run_cmd() {
  local cmd="$1"
  if [[ ${REPO_PREFIX} ]]
  then
    echo "Running cmd: ${REPO_PREFIX} ${cmd}"
    ${REPO_PREFIX} "${cmd}" &>/dev/null || true
  else
    echo "Running cmd: ${cmd}"
    ${cmd} &>/dev/null || true
  fi
}

run_cmd_with_submodules() {
  local cmd="$1"

  run_cmd "${cmd}"
  run_cmd "git submodule foreach '${cmd}'"
}

OPTIND=1
while getopts ":d:e:p:cgx" opt; do
  case $opt in
    c) clean=1 ;;
    d) dir=$OPTARG ;;
    e) expire_since=$OPTARG ;;
    g) prune=1 ;;
    p) prune_since=$OPTARG ;;
    x) xflag=x ;;
    \?) echo -e "Invalid option:-$OPTARG\n"
       usage ;;
  esac
done
shift $((OPTIND-1))

# Reset source
clean_src() {
  echo -e "\nClean and Reset src in ${dir}"

  for cmd in am cherry-pick rebase revert merge
  do
    run_cmd_with_submodules "git ${cmd} --abort"
  done
  run_cmd_with_submodules "git bisect reset"
  run_cmd_with_submodules "git add --all"
  run_cmd_with_submodules "git reset --hard"
  run_cmd_with_submodules "git clean -ffd${xflag}"
}

# Address loose object warnings; gc and prune
prune_src() {
  echo -e "\nExpire reflog and Prune src in ${dir}"

  run_cmd_with_submodules "git stash clear"
  run_cmd_with_submodules "git remote prune origin"
  run_cmd_with_submodules "git worktree prune"
  run_cmd_with_submodules "git lfs prune"
  run_cmd_with_submodules "git for-each-ref --format=\"%(refname)\" refs/original/ | xargs -r -n 1 git update-ref -d"
  run_cmd_with_submodules "git reflog expire --all --expire-unreachable=${expire_since}"
  run_cmd_with_submodules "git gc --aggressive --prune=${prune_since}"
}

pushd "${dir}" >/dev/null

if [[ -d "./.git" ]]
then
  echo "Git Project Detected"
elif [[ -d "./.repo" ]]
then
  REPO_PREFIX="repo forall -c" && echo "Repo Project Detected"
else
  echo "Not a Git or Repo project. Nothing to do" && usage
fi

[[ "$clean" == "1" ]] && clean_src
[[ "$prune" == "1" ]] && prune_src

popd >/dev/null
unset REPO_PREFIX clean dir prune prune_since expire_since xflag

