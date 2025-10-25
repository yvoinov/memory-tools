#!/bin/sh

#####################################################################################
## The script for enable non-system allocator preload per specified systemd service.
## Service name specified as script argument (without any suffix, only service name).
## Linux version.
##
## Version 1.4
## Written by Y.Voinov (C) 2024-2025
#####################################################################################

# Variables
# Set bitness for alocator. 64 by default
BITNESS=64
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Find allocator binary
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_SYMLINK_PATH="`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep $BITNESS | cut -d':' -f1`"
CONF_FILE_NAME="override_env.conf"

# Subroutines
usage_note()
{
  echo "The script for enable non-system allocator preload per specified systemd service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service-name> [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "Example: `basename $0` clamav-daemon"
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

check_service()
{
  if [ ! -z "`systemctl status $SERVICE_NAME | grep 'could not be found.'`" ]; then
    echo "ERROR: Service $SERVICE_NAME could not be found."
    exit 3
  fi
}

check_symlink()
{
  if [ ! -z "$ALLOCATOR_SYMLINK_PATH" -a -f "$ALLOCATOR_SYMLINK_PATH" ]; then
    echo "Allocator: `ls $ALLOCATOR_SYMLINK_PATH`"
  else
    echo "ERROR: Symlink to library could not be found. Check allocator installed."
    exit 4
  fi
}

# Main
while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    *)
    # Accumulate to one string
      if [ -z "$SERVICE_NAME" ]; then
        SERVICE_NAME=$1
      else
        SERVICE_NAME="$SERVICE_NAME $1"
      fi
    ;;
    esac
    shift
done

if [ -z $SERVICE_NAME ]; then
  usage_note
fi

check_os
check_root
check_service
check_symlink

if [ ! -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
  mkdir -p /usr/lib/systemd/system/$SERVICE_NAME.service.d/
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d created."
else
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d exists."
fi

if [ ! -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
  echo "[Service]" > /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  echo "Environment='LD_PRELOAD=$ALLOCATOR_SYMLINK_PATH'" >> /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME created."
else
  echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME exists."
  echo "File content: "
  cat /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  exit 4
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
