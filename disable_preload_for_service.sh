#!/bin/sh

#####################################################################################
## The script for disable global preload any custom allocator per specified systemd
## service.
## Service name specified as script argument (without any suffix, only service name).
##
## Version 1.0
## Written by Y.Voinov (C) 2024
#####################################################################################

# Variables
# Service name from command line argument
SERVICE_NAME=$1
# Set bitness for all, including libC. 64 by default
BITNESS=64
# Library search prefix: from where to find library
LIBRARY_PREFIX="/usr"
# Set library name to preload
LIBRARY_NAME="libc.so"

# Find libc binary
LIBC_ABSOLUTE_PATH=`find $LIBRARY_PREFIX -name $LIBRARY_NAME.? -exec file {} \; | grep $BITNESS | cut -d":" -f1`
CONF_FILE_NAME="override_env.conf"

# Subroutines
usage_note()
{
 echo "The script for disable global preload any custom allocator per specified systemd service."
 echo "Must be run as root."
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
if [ -z $SERVICE_NAME ]; then
  usage_note
fi

# Parse command line
if [ "x$*" != "x" ]; then
  arg_list=$*
  # Read arguments
  for i in $arg_list
  do
    case $i in
      -h|-H|\?) usage_note;;
      *) shift
      ;;
    esac
  done
fi

check_os
check_root
check_service

if [ ! -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
  mkdir -p /usr/lib/systemd/system/$SERVICE_NAME.service.d/
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d created."
else
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d exists."
fi

if [ ! -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
  echo "[Service]" > /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  echo "Environment='LD_PRELOAD=$LIBC_ABSOLUTE_PATH'" >> /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
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
