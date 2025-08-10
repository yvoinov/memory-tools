#!/bin/sh

#####################################################################################
## The script for disable custom allocator global preload.
##
## Version 1.0
## Written by Y.Voinov (C) 2025
#####################################################################################

# Variables
# Global preload config
PRELOAD_CONF="/etc/ld.so.preload"
# Set bitness for alocator. 64 by default
BITNESS=64
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Find allocator binary
ALLOCATOR_SYMLINK_PATH=`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep $BITNESS | cut -d":" -f1`

# Subroutines
usage_note()
{
  echo "The script for disable custom allocator global preload."
  echo "Must be run as root."
  echo "Example: `basename $0`"
  exit 0
}

check_os()
{
  if [ "`uname`" != "Linux" ]; then
    echo "ERROR: Unsupported OS."
    exit 1
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 2
  fi
}

# Main
while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    *) shift
    ;;
    esac
done

check_os
check_root

if [ ! -f $PRELOAD_CONF ]; then
  echo "Disabled already or not enabled. Exiting..."
  exit 0
else
  if [ ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH`" ]; then
    chattr -i $PRELOAD_CONF
    mv $PRELOAD_CONF $PRELOAD_CONF.orig
    echo "File $PRELOAD_CONF renamed to $PRELOAD_CONF.orig."
  else
    echo "File $PRELOAD_CONF exists."
    echo "File content: "
    cat $PRELOAD_CONF
    echo "Disabled already or not enabled. Exiting..."
    exit 0
  fi
fi

echo "Completed. Reboot now to apply changes globally."

exit 0
