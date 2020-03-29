#!/bin/sh -eu

PACKAGE=""
VERSION=""
PATCH=""
URL=""
GIT=""
TEMPLATE="automake"
TARGET=""
INSTALL_TARGET="DESTDIR=$PWD/out install"

AUTOMAKE_OPTIONS="--prefix=''"

CMAKE_OPTIONS=""

error() {
  printf "ERROR: %s\n" "$1"
  exit 1
}

input="$1"
while IFS=':' read -r lhs rhs
do
  KEY=$(printf %s "$lhs" | awk '{$1=$1};1')
  VALUE=$(printf %s "$rhs" | awk '{$1=$1};1')

  case $KEY in
    "#"*) ;; # Skip comments
    '') ;; # Skip blank lines
    'PACKAGE') PACKAGE=$VALUE ;;
    'VERSION') VERSION=$VALUE ;;
    'PATCH') PATCH=$VALUE ;;
    'URL') URL=$VALUE ;;
    'GIT') GIT=$VALUE ;;
    'TEMPLATE') TEMPLATE=$VALUE ;;
    'TARGET') TARGET=$VALUE ;;
    'INSTALL_TARGET') INSTALL_TARGET=$VALUE ;;
    'AUTOMAKE_OPTIONS') AUTOMAKE_OPTIONS=$VALUE ;;
    'CMAKE_OPTIONS') CMAKE_OPTIONS=$VALUE ;;
    *) error "Unkown key $KEY" ;;
  esac
done < "$input"

[ -z "$PACKAGE" ] && error "PACKAGE missing"
[ -z "$VERSION" ] && error "VERSION missing"

{ 
  printf '.POSIX:\n';
  printf 'PACKAGE=%s\n' "$PACKAGE";
  printf 'VERSION=%s\n' "$VERSION";
  printf '\n';

  printf 'all: out\n';
  printf '\n';

  if [ -n "$URL" ]
  then
    FILENAME="${URL##*/}";
    printf 'src:\n';
    printf '\tcurl -sSLO %s\n' "$URL";
    printf '\ttar xf %s\n' $FILENAME;
    printf '\trm %s\n' $FILENAME;
    printf '\tmv ${PACKAGE}-${VERSION} src\n';
    [ -z "$PATCH" ] || printf '\tpatch -p1 -i %s\n' "$PATCH";
    printf '\n';
  fi

  if [ -n "$GIT" ]
  then
    printf 'src:\n';
    printf '\tgit clone %s src\n' "$GIT";
    [ -z "$PATCH" ] || printf '\tpatch -p1 -i %s\n' "$PATCH";
    printf '\n';
  fi

  case $TEMPLATE in
    "cmake")
      printf "out: src\n";
      printf "\tcmake -S src -B build $CMAKE_OPTIONS\n";
      printf "\tmake -C build $TARGET\n";
      printf "\tmake -C build $INSTALL_TARGET\n";
      printf '\n';
    ;;
    "automake")
      printf "out: src\n";
      printf "\tcd src; ./configure $AUTOMAKE_OPTIONS\n";
      printf "\tmake -C src $TARGET\n";
      printf "\tmake -C src $INSTALL_TARGET\n";
      printf '\n';
    ;;
  esac

  printf 'clean:\n';
  printf '\trm -rf build out\n';
  printf '\n';
  printf 'distclean: clean\n';
  printf '\trm -rf src\n';
} > Makefile
