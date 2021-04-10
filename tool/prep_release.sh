git pull
rm -rf doc/api
dartdoc
dart pub publish --dry-run
dart pub publish