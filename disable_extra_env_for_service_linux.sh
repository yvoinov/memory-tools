#!/bin/sh

#####################################################################################
## The script for disable extra env for specified systemd service.
## Service name specified as script argument (without any suffix, only service name).
## Linux version.
##
## Version 1.0
## Written by Y.Voinov (C) 2026
#####################################################################################

# Variables

# Drop-in directory
DROP_IN_DIR="/usr/lib/systemd/system"

# Drop-in extra env
CONF_EXTRA_ENV_FILE="mt_extra_env.conf"

# Subroutines
usage_note()
{
  echo "The script for disable extra env for specified systemd service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service_name> [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "Example (completely disable extra env): `basename $0` apache2"
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

disable_drop_in()
{
  drop_in_file_name=$1
  if [ -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d found."
    if [ -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$drop_in_file_name ]; then
      rm -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$drop_in_file_name
      echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$drop_in_file_name removed."
      rmdir $DROP_IN_DIR/$SERVICE_NAME.service.d
      if [ ! -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
        echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d removed."
      fi
    fi
  else
    echo "ERROR: Directory $DROP_IN_DIR/$SERVICE_NAME.service.d does not exists."
    exit 4
  fi
}

# Main
if [ -z $1 ]; then
  usage_note
fi

SERVICE_NAME=""

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

if [ ! -z $SERVICE_NAME ]; then
  disable_drop_in $CONF_EXTRA_ENV_FILE
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
