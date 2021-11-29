#!/bin/bash

release_submodule() {

  VERSION_OLD="$1"
  VERSION_NEW="$2"
  SUBMODULE="$3"

  printf '\nReleasing %s\n\n' "$SUBMODULE"

  if [[ $(git status --porcelain) ]]; then
    echo "Git changes detected, either add and commit these or remove them before installing. Exiting"
    exit
  fi

  GIT_STATUS_POR_BRA=$(git status --porcelain --branch)

  if [[ "$GIT_STATUS_POR_BRA" == *"ahead"* ]]; then
    echo "Local commits are ahead of upstream, push these before releasing. Exiting."
    exit
  fi

  if [[ "$GIT_STATUS_POR_BRA" == *"behind"* ]]; then
    echo "Local commits are behind upstream, pull and/or merge these before releasing. Exiting."
    exit
  fi

  if ! [[ "$GIT_STATUS_POR_BRA" == *"## master"* ]]; then
    echo "Currently not on master branch, move to master branch before releasing. Exiting."
    exit
  fi

  TEST_LOG=$(curl -L "https://img.shields.io/github/workflow/status/ivy-dl/$SUBMODULE/nightly-tests")

  if [ -z "$TEST_LOG" ]; then
    echo "The test log returned empty, so cannot determine if the tests are passing or failing. Exiting."
    exit
  fi

  if [[ "$TEST_LOG" == *"failing"* ]]; then
    echo "The tests for the latest commit are failing, fix these failing tests before releasing. Exiting."
    exit
  fi

  if ! [[ "$TEST_LOG" == *"passing"* ]]; then
    echo "The tests for the latest commit are not passing, fix these failing tests before releasing. Exiting."
    exit
  fi

  if [ -z "$VERSION_OLD" ]; then
      echo "You need to provide an old version number"
      exit
  fi

  if [ -z "$VERSION_NEW" ]; then
      echo "You need to provide a release version number"
      exit
  fi

  if ! grep -Fq "$VERSION_OLD" setup.py; then
      echo "The old version is not present in setup.py. Exiting"
      exit
  fi

  if grep -Fq "$VERSION_NEW" setup.py; then
      echo "The new version already exists in setup.py. Exiting"
      exit
  fi

  # shellcheck disable=SC2005
  PACKAGE_NAME=$(echo "$(grep -F "name=" setup.py)" | cut -f2 -d"'")
  PIP_RET=$(python3 -m pip index versions "$PACKAGE_NAME")
  PIP_HAS_OLD=$(echo "$PIP_RET" | grep -F "$VERSION_OLD")

  if [ -z "$PIP_HAS_OLD" ]; then
      echo "The old version not found in PyPI. Exiting"
      exit
  fi

  PIP_HAS_NEW=$(echo "$PIP_RET" | grep -F "$VERSION_NEW")

  if [ -n "$PIP_HAS_NEW" ]; then
      echo "The new version already in PyPI. Exiting"
      exit
  fi

  sed -i "s/$1/$2/g" setup.py
  git add -A
  git commit -m "version $2"
  git push
  git tag -a "v$2" -m "version $2"
  git push origin "v$2"
}

VERSION_OLD="$1"
VERSION_NEW="$2"
THIRD="$3"

if [[ "$THIRD" == "all" ]]; then
  SUBMODULES="ivy mech vision robot gym memory builder models"
else
  SUBMODULES="${*:3}"
fi

for SUBMODULE in $SUBMODULES
do
  cd "$SUBMODULE" || exit
  release_submodule "$VERSION_OLD" "$VERSION_NEW" "$SUBMODULE"
  cd ..
done