#!/bin/sh

#####################################################################################
## The script for disable non-system allocator global preload. AIX version.
##
## Version 1.2
## Written by Y.Voinov (C) 2025-2026
#####################################################################################

# Variables
# Global preload config
PRELOAD_CONF="/etc/environment"
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Find allocator binary
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_SYMLINK_PATH_32="`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep 32 | cut -d':' -f1`"
ALLOCATOR_SYMLINK_PATH_64="`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep 64 | cut -d':' -f1`"

# Subroutines
usage_note()
{
  echo "The script for disable non-system allocator global preload."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "Note: The script DOES NOT REMOVE additional global environment variables if they were defined."
  echo "      You must remove them manually if necessary."
  exit 0
}

check_os()
{
  if [ "`uname`" != "AIX" ]; then
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
 # Parse command line
if [ "x$*" != "x" ]; then
  arg_list=$*
  # Read arguments
  for i in $arg_list
  do
    case $i in
      -h|-H|\?)
        usage_note
      ;;
      *) shift
      ;;
    esac
  done
fi

check_os
check_root

if [ ! -f $PRELOAD_CONF ] && [ -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH_32`" -o -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH_64`" ]; then
  echo "$PRELOAD_CONF contents: `cat $PRELOAD_CONF`"
  echo "Disabled already or not enabled. Exiting..."
  exit 0
else
  if [ ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH_32`" -o ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH_64`" ]; then
    cp $PRELOAD_CONF "$PRELOAD_CONF.orig"
    sed "/LDR_PRELOAD/d" $PRELOAD_CONF > $PRELOAD_CONF.$$ && mv $PRELOAD_CONF.$$ $PRELOAD_CONF
    sed "/LDR_PRELOAD64/d" $PRELOAD_CONF > $PRELOAD_CONF.$$ && mv $PRELOAD_CONF.$$ $PRELOAD_CONF
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
