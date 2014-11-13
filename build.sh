#!/bin/bash

# Build script for Synthese
#
# This script builds Synthese with some default values


# Default CMAKE args
CMAKE_ARGS="-DBOOST_INCLUDEDIR=/opt/boost_1_42_0/dist/include/ -DBOOST_LIBRARYDIR=/opt/boost_1_42_0/dist/lib/ -DWITH_MYSQL:BOOL=ON -DCMAKE_BUILD_TYPE=debug -DWITH_TEST:BOOL=OFF -DWITH_PACKAGES:BOOL=OFF -DWITH_PROJECTS:BOOL=OFF -DWITH_TOOLS:BOOL=OFF -DWITH_UTILS:BOOL=OFF"

# Default MAKE args
MAKE_ARGS="-j $(distcc -j)"

# Source path
SRC="/src/synthese"

# Build dir
BUILD="$SRC/build"

# Install dir
INSTALL="$BUILD/dist"


# Prints and execute the given command
# If the first parameter is "debug", the command will not be executed, only printed
# If the command fail, exit with code 1
function log ()
{
	if [[ $1 == "debug" ]]; then
		echo "${@:2}"
	else
		echo "$@"
		$@ || exit 1
	fi
}


# Print the help & usage
function help ()
{
	echo "Synthese Build script for OpenSuse 12.3"
	
	echo -e "
This script need the Synthese source to be at $SRC
You must use Docker's -v flag to specify the Synthese source to use.

Example : docker run -i -t -v /home/toto/synthese/branches/sae:$SRC ...
"
	
	echo -e "
Directories :
	Source : \t $SRC
	Install : \t $INSTALL
	Build : \t $BUILD
"

	echo -e "
Default compilation option :
	CMake : $CMAKE_ARGS
	Make  : $MAKE_ARGS
"

	echo -e "
Usage : 
	help : \t\t Show this message
	C=XXX : \t Add this flag to CMake
	M=XXX : \t Add this flag to Make 
	build=XXX : \t Set the build directory
	install=XXX : \t Set the install directory
	debug : \t If set, print the compilation steps but do not execute them
"
}

DEBUG=""

# Parse the arguments
for a in $*; do

	case "$a" in
		"help" )
			help
			exit 0;;
		"debug" )
			DEBUG="debug" ;;
		
		C* )
			CMAKE_ARGS="$CMAKE_ARGS ${a:2}" ;;
		M* )
			MAKE_ARGS="$MAKE_ARGS ${a:2}" ;;
		install* )
			INSTALL=${a:8} ;;
		build* )
			BUILD=${a:6} ;;
			
		* )
			echo "Invalid option : $a"
			help
			exit 1;;
	esac
	
done


# Check the source directory
if [[ ! -s "$SRC/CMakeLists.txt" ]]; then
	echo "Invalid source directory : $SRC"
	help
	exit 1;
fi

# If it exists, specify the install directory to CMAKE
CID=""
[[ $INSTALL != "" ]] &&	CID="-DCMAKE_INSTALL_PREFIX=$INSTALL"


# Creates the build directory if it doesn't exist
log $DEBUG mkdir -vp "$BUILD"
log $DEBUG pushd "$BUILD"

# Launch cmake
log $DEBUG cmake $SRC $CID $CMAKE_ARGS || exit 1

# Launch make
log $DEBUG make $MAKE_ARGS || exit 1

# If an install directory is specified, install in it
if [[ $INSTALL != "" ]]; then
	log $DEBUG make install
fi

# Fetch the source directory user, to build as him
USER=$(ls -ln "$SRC/CMakeLists.txt" | awk '{print $3}')
log $DEBUG chown $USER:$USER -R "$BUILD" "$INSTALL"

log $DEBUG popd "$BUILD"

