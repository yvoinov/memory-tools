#!/bin/sh

#####################################################################################
## The script for disable global preload any non-system allocator per specified systemd
## service or remove per-service allocator preload.
## Service name specified as script argument (without any suffix, only service name).
## Linux version.
##
## Version 1.3
## Written by Y.Voinov (C) 2024-2025
#####################################################################################

# Variables
# Set bitness for all, including libC. 64 by default
BITNESS=64
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr"
# Set library name to preload
LIBRARY_NAME="libc.so"

# Find libc binary
LIBC_ABSOLUTE_PATH=`find $LIBRARY_PREFIX -name $LIBRARY_NAME.? -exec file {} \; | grep $BITNESS-bit | cut -d":" -f1`
CONF_FILE_NAME="override_env.conf"

# Subroutines
usage_note()
{
  echo "The script for disable global preload any non-system allocator per specified systemd service"
  echo "by add preload libC first. To disable per-service preload, use -d option."
  echo "Must be run as root."
  echo "Example 1 (per-service workaround): `basename $0` apache2"
  echo "Example 2 (completely disable): `basename $0` apache2 -d"
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

disable_preload()
{

  if [ -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
    echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d found."
    if [ -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
      rm -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
      rmdir /usr/lib/systemd/system/$SERVICE_NAME.service.d
      if [ ! -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
        echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d removed."
      fi
    fi
  else
    echo "ERROR: Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d does not exists."
    exit 4
  fi
}

write_file_content()
{
  echo "[Service]" > /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  echo "Environment='LD_PRELOAD=$LIBC_ABSOLUTE_PATH'" >> /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
}

# Main
if [ -z $1 ]; then
  usage_note
fi

disable_full="0"
SERVICE_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    -d|-D)
      disable_full="1"
    ;;
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

if [ "$disable_full" = "1" ]; then
  disable_preload
  exit 0
fi

if [ ! -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
  mkdir -p /usr/lib/systemd/system/$SERVICE_NAME.service.d/
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d created."
else
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d exists."
fi

if [ ! -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
  write_file_content
  echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME created."
else
  echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME exists."
  if [ "`grep alloc.so /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME`" ]; then
    # Overwrite file content if preload exist
    write_file_content
    echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME overwrited."
  fi
  echo "New file content:"
  cat /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  exit 4
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
