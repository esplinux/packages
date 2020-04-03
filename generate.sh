#!/bin/sh -eu

PACKAGES=""
CURDIR=$(pwd)

error() {
  printf "ERROR: %s\n" "$1"
  exit 1
}

substitute() {
  RESULT=$1
  RESULT=$( printf '%s' "$RESULT" | sed s?\$PACKAGE?"$PACKAGE"? )
  RESULT=$( printf '%s' "$RESULT" | sed s?\$VERSION?"$VERSION"? )
  RESULT=$( printf '%s' "$RESULT" | sed s?\$OUT?"$OUT"? )
  printf '%s' "$RESULT"
}

generate() {
  INPUT=$(realpath "$1")
  BASE=$(dirname "$INPUT")

  PACKAGE=''
  VERSION=''
  PATCH=''
  URL=''
  GIT=''
  SRC='$PACKAGE-$VERSION'
  BUILD='build'
  OUT='out'
  TEMPLATE='automake'
  TARGET=''
  INSTALL_TARGET='DESTDIR=$OUT install'
  AUTOMAKE_OPTIONS="--prefix=''"
  CMAKE_OPTIONS=''

  while IFS='=' read -r lhs rhs
  do
    KEY=$( printf %s "$lhs" | awk '{$1=$1};1' )
    VALUE=$( printf %s "$rhs" | awk '{$1=$1};1' )
  
    case $KEY in
      "#"*) ;; # Skip comments
      '') ;; # Skip blank lines
      'PACKAGE') PACKAGE=$VALUE ;;
      'VERSION') VERSION=$VALUE ;;
      'OUT') OUT=$VALUE ;;
      'PATCH') PATCH=$VALUE ;;
      'URL') URL=$VALUE ;;
      'GIT') GIT=$VALUE ;;
      'SRC') SRC=$VALUE ;;
      'BUILD') BUILD=$VALUE ;;
      'TEMPLATE') TEMPLATE=$VALUE ;;
      'TARGET') TARGET=$VALUE ;;
      'INSTALL_TARGET') INSTALL_TARGET=$VALUE ;;
      'AUTOMAKE_OPTIONS') AUTOMAKE_OPTIONS=$VALUE ;;
      'CMAKE_OPTIONS') CMAKE_OPTIONS=$VALUE ;;
      *) error "Unkown key $KEY" ;;
    esac
  done < "$INPUT"
  
  [ -z "$PACKAGE" ] && error "PACKAGE missing"
  [ -z "$VERSION" ] && error "VERSION missing"

  # Add to default target
  PACKAGES="$PACKAGE $PACKAGES"

  # These values are interpolated
  OUT=$( substitute "$OUT" )
  OUT="$BASE/$OUT"
  SRC=$( substitute "$SRC" )
  SRC="$BASE/$SRC"
  BUILD=$( substitute "$BUILD" )
  BUILD="$BASE/$BUILD"
  PATCH=$( substitute "$PATCH" )
  URL=$( substitute "$URL" )
  GIT=$( substitute "$GIT" )
  TARGET=$( substitute "$TARGET" )
  INSTALL_TARGET=$( substitute "$INSTALL_TARGET" )

  { 
    printf '%s: %s-%s.tar.gz\n' "$PACKAGE" "$PACKAGE" "$VERSION";
    printf '\n';
  
    if [ -n "$URL" ]
    then
      printf '%s:\n' "$SRC";
      printf '\tcurl -sSL %s | tar -xz\n' "$URL";
      [ -z "$PATCH" ] || printf '\tpatch -p1 -i %s\n' "$PATCH";
      printf '\n';
    fi
  
    if [ -n "$GIT" ]
    then
      printf '%s:\n' "$SRC";
      printf '\tgit clone %s %s\n' "$GIT" "$SRC";
      [ -z "$PATCH" ] || printf '\tpatch -p1 -i %s\n' "$PATCH";
      printf '\n';
    fi
  
    case $TEMPLATE in
      "cmake")
        printf '%s: %s\n' "$OUT" "$SRC";
        printf '\tcmake -S %s -B %s %s\n' "$SRC" "$BUILD" "$CMAKE_OPTIONS";
	printf '\t$(MAKE) -C %s %s\n' "$BUILD" "$TARGET";
	printf '\t$(MAKE) -C %s %s\n' "$BUILD" "$INSTALL_TARGET";
        printf '\n';
      ;;
      "automake")
        printf '%s: %s\n' "$OUT" "$SRC";
        printf '\tcd %s; ./configure %s\n' "$SRC" "$AUTOMAKE_OPTIONS";
	printf '\tcd %s; $(MAKE) %s\n' "$SRC" "$TARGET";
	printf '\tcd %s; $(MAKE) %s\n' "$SRC" "$INSTALL_TARGET";
        printf '\n';
      ;;
    esac
  
    printf '%s-%s.tar.gz: %s\n' "$PACKAGE" "$VERSION" "$OUT";
    printf '\tcd %s; tar -czf ../%s-%s.tgz .\n' "$OUT" "$PACKAGE" "$VERSION";
    printf '\n';
    printf 'clean:\n';
    printf '\trm -rf %s %s %s-%s.tgz\n' "$BUILD" "$OUT" "$PACKAGE" "$VERSION";
    printf '\n';
    printf 'distclean: clean\n';
    printf '\trm -rf %s\n' "$SRC";
    printf '\n';
  } >> .Makefile
}

{
  printf '.POSIX:\n';
  printf 'default: all\n';
  printf '\n';
} > .Makefile

generate "$1"

printf 'all: %s\n' "$PACKAGES" >> .Makefile

mv .Makefile Makefile
