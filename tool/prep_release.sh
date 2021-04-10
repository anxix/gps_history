#!/bin/bash

# Requires: git, dart, dartdoc, github CLI
git pull
rm -rf doc/api
dartdoc
dart pub publish --dry-run
read -p 'Release name (e.g. 1.0.2): ' relname
read -p Preparing to release $relname on GitHub. Press ENTER to continue.
gh release create $relname -F CHANGELOG.md
read -p Preparing to publish $relname on pub.dev. Press ENTER to continue.
dart pub publish