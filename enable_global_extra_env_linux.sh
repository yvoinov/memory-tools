#!/bin/sh

#####################################################################################
## The script for enable extra env drop-ins for all running systemd services.
## This script was written to workaround the lack of a global environment for systemd
## services.
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
  echo "The script for enable extra env drop-ins for all running systemd services."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo '    -e, -E, -e|-E "VAR1=value VAR2=value ...", extra environment variables'
  echo 'Example: `basename $0` -e "FOO=value1 BAR=value2"'
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
      shift
      ;;
    *)
      usage_note
    ;;
    esac
    shift
done

if [ -z $EXTRA_ENV ]; then
  usage_note
fi

check_os
check_root

systemd_services=`systemctl list-units --type=service --state=running --no-legend --no-pager --plain | awk '{ print $1 }'`

for svc_name in $systemd_services; do
  if [ ! -d $DROP_IN_DIR/$svc_name.service.d ]; then
    mkdir -p $DROP_IN_DIR/$svc_name.service.d/
    echo "Directory $DROP_IN_DIR/$svc_name.service.d created."
  else
    echo "Directory $DROP_IN_DIR/$svc_name.service.d exists."
  fi

  if [ -f $DROP_IN_DIR/$svc_name.service.d/$CONF_EXTRA_ENV_FILE ]; then
    echo "File $DROP_IN_DIR/$svc_name.service.d/$CONF_EXTRA_ENV_FILE exists."
    echo "File content: "
    cat $DROP_IN_DIR/$svc_name.service.d/$CONF_EXTRA_ENV_FILE
    echo "The file will be overwritten."
  fi

  echo "[Service]" > $DROP_IN_DIR/$svc_name.service.d/$CONF_EXTRA_ENV_FILE
  for pair in $EXTRA_ENV; do
    echo "Environment='$pair'" >> $DROP_IN_DIR/$svc_name.service.d/$CONF_EXTRA_ENV_FILE
  done

  echo "New file content: "
  cat $DROP_IN_DIR/$svc_name.service.d/$CONF_EXTRA_ENV_FILE

  systemctl daemon-reload
done

echo "Completed. Reboot system."

exit 0
