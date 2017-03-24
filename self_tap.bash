#! /bin/bash

set -o errexit
set -o nounset

# update system homebrew to latest (no, really latest)
HOMEBREW_REPOSITORY="$(brew --repo)"
sudo chown -R "$USER" "$HOMEBREW_REPOSITORY"
git -C "$HOMEBREW_REPOSITORY" reset --hard origin/master
brew update || brew update

# link the current directory as a tap named for this repo
HOMEBREW_TAP_DIR="$(brew --repo "$TRAVIS_REPO_SLUG")"
echo "PWD is $PWD"
echo "HOMEBREW_TAP_DIR is $HOMEBREW_TAP_DIR"
rm -rf "$HOMEBREW_TAP_DIR"
TAP_DIR_DIR="$(dirname "$HOMEBREW_TAP_DIR")"
if [[ ! -d "$TAP_DIR_DIR" ]]
then
  mkdir "$TAP_DIR_DIR"
fi
ln -s "$PWD" "$HOMEBREW_TAP_DIR"
