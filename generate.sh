#!/bin/sh -eu

error() {
  printf "ERROR: %s\n" "$1"
  exit 1
}

substitute() {
  RESULT=$1
  RESULT=$( printf '%s' "$RESULT" | sed s/\$PACKAGE/"$PACKAGE"/ )
  RESULT=$( printf '%s' "$RESULT" | sed s/\$VERSION/"$VERSION"/ )
  printf '%s' "$RESULT"
}

generate() {
  INPUT="$1"

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

  while IFS='=' read -r lhs rhs
  do
    KEY=$( printf %s "$lhs" | awk '{$1=$1};1' )
    VALUE=$( printf %s "$rhs" | awk '{$1=$1};1' )
  
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
  done < "$INPUT"
  
  [ -z "$PACKAGE" ] && error "PACKAGE missing"
  [ -z "$VERSION" ] && error "VERSION missing"

  # These values are interpolated
  PATCH=$( substitute "$PATCH" )
  URL=$( substitute "$URL" )
  GIT=$( substitute "$GIT" )

  { 
    printf '.POSIX:\n';
    printf 'all: %s\n' "$PACKAGE";
    printf '\n';
    printf '%s: %s-%s.tar.gz\n' "$PACKAGE" "$PACKAGE" "$VERSION";
    printf '\n';
  
    if [ -n "$URL" ]
    then
      FILENAME="${URL##*/}";
      printf 'src:\n';
      printf '\tcurl -sSLO %s\n' "$URL";
      printf '\ttar xf %s\n' "$FILENAME";
      printf '\trm %s\n' "$FILENAME";
      printf '\tmv %s-%s src\n' "$PACKAGE" "$VERSION";
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
        printf "\tcmake -S src -B build %s\n" "$CMAKE_OPTIONS";
        printf "\tmake -C build %s\n" "$TARGET";
        printf "\tmake -C build %s\n" "$INSTALL_TARGET";
        printf '\n';
      ;;
      "automake")
        printf "out: src\n";
        printf "\tcd src; ./configure %s\n" "$AUTOMAKE_OPTIONS";
        printf "\tmake -C src %s\n" "$TARGET";
        printf "\tmake -C src %s\n" "$INSTALL_TARGET";
        printf '\n';
      ;;
    esac
  
    printf '%s-%s.tar.gz: out\n' "$PACKAGE" "$VERSION";
    printf '\tcd out; tar -czf ../%s-%s.tgz .\n' "$PACKAGE" "$VERSION";
    printf '\n';
    printf 'clean:\n';
    printf '\trm -rf build out %s-%s.tgz\n' "$PACKAGE" "$VERSION";
    printf '\n';
    printf 'distclean: clean\n';
    printf '\trm -rf src\n';
  } > Makefile
}

generate "$1"
