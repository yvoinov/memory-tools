#!/bin/sh

#####################################################################################
## The script for enable extra env per specified systemd service.
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
  echo "The script for enable extra env per specified systemd service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service-name> [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo '    -e, -E, -e|-E "VAR1=value VAR2=value ...", extra environment variables'
  echo "Example: `basename $0` apache2"
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

# Main
# Defaults
EXTRA_ENV=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    -e|-E)
      shift
      [ $# -eq 0 ] && usage_note
      if [ -z "$EXTRA_ENV" ]; then
        EXTRA_ENV="$1"
      else
        EXTRA_ENV="$EXTRA_ENV $1"
      fi
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

if [ ! -z "$EXTRA_ENV" ]; then
  if [ ! -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
    mkdir -p $DROP_IN_DIR/$SERVICE_NAME.service.d/
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d created."
  else
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d exists."
  fi

  if [ -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE ]; then
    echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE exists."
    echo "File content: "
    cat $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE
    echo "The file will be overwritten."
  fi

  echo "[Service]" > $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE
  for pair in $EXTRA_ENV; do
    echo "Environment='$pair'" >> $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE
  done

  echo "New file content: "
  cat $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE
else
  echo "ERROR: Extra env does not specified. Exiting..."
  exit 4
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
