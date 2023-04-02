#!/bin/sh

#####################################################################################
## The script sets up the service to manage THP (Transparent Huge Pages) on Linux.
## After installation and reboot, THP will be turned off globally.
## To turn it back on, do systemctl disable disable-thp && systemctl stop disable-thp
## 
## Version 1.1
## Written by Y.Voinov (C) 2022
#####################################################################################

# Path to write unit
UNIT_PATH="/etc/systemd/system"

# Unit name
UNIT_FILE_NAME="disable-thp.service"

#Path to write value
VALUE_PATH_BASE="/sys/kernel/mm"
VALUE_PATH_COMMON="transparent_hugepage"
VALUE_PATH_RH="redhat_transparent_hugepage"

# Subroutines
usage_note()
{
 echo "The script creates and installs a service that disables THP on Linux."
 echo "Just run it and reboot system. Must be run as root."
 echo "Example: `basename $0` && reboot"
 exit 0
}

check_os()
{
  if [ "`uname`" != "Linux" ]; then
    echo "ERROR: This script is for Linux only."
    exit 2
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 3
  fi
}

check_and_set_thp_path()
{
  if [ -d "$VALUE_PATH_BASE/$VALUE_PATH_COMMON" ]; then
    echo "$VALUE_PATH_BASE/$VALUE_PATH_COMMON"
  elif [ -d "$VALUE_PATH_BASE/$VALUE_PATH_RH" ]; then
    echo "$VALUE_PATH_BASE/$VALUE_PATH_RH"
  else
    echo "ERROR: THP path not found."
    exit 1
  fi
}

write_service()
{
  echo '[Unit]'
  echo 'Description=Disable Transparent Huge Pages (THP)'
  echo '[Service]'
  echo 'Type=simple'
  echo 'ExecStart=/bin/sh -c "echo 'never' > '`check_and_set_thp_path`'/enabled && echo 'never' > '`check_and_set_thp_path`'/defrag"'
  echo '[Install]'
  echo 'WantedBy=multi-user.target'
}

# Main
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

if [ ! -f "$UNIT_PATH/$UNIT_FILE_NAME" ]; then
  write_service > $UNIT_PATH/$UNIT_FILE_NAME
else
  echo "WARNING: Unit already exists."
fi

systemctl daemon-reload
if [ "`systemctl --version | grep systemd | awk '{ print $2 }'`" -ge "220" ]; then
  systemctl enable --now disable-thp
else
  systemctl start disable-thp
  systemctl enable disable-thp
fi

echo "Done. Please reboot this system now."
exit 0
