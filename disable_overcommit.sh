#!/bin/sh

#####################################################################################
## The script sets up LMA OS-wide performance prerequisites.
##
## Version 1.2
## Written by Y.Voinov (C) 2022
#####################################################################################

# Sysctl config path
CONFIG_BASE="/etc"
SYSCTL_PATH="$CONFIG_BASE/sysctl.d"
SYSCTL_FILE="$CONFIG_BASE/sysctl.conf"
CONFIG_NAME="10-lma.conf"

# Write file content
SYSCTL_FILE_STR1="# System tweaks by TCW"
# Note: Don't set swappiness too low on Proxmox/KVM or create big enough swap.
SYSCTL_FILE_STR2="vm.swappiness = 50"
SYSCTL_FILE_STR3="vm.vfs_cache_pressure = 50"
SYSCTL_FILE_STR4="vm.overcommit_ratio = 99"
# Note: When run aerospike with small memory footprint, set vm.overcommit_memory=1. Otherwise asd will fail to start.
SYSCTL_FILE_STR5="vm.overcommit_memory = 2"

# Existence flags
SYSCTL_STR1_EXIST=""
SYSCTL_STR2_EXIST=""
SYSCTL_STR3_EXIST=""
SYSCTL_STR4_EXIST=""
SYSCTL_STR5_EXIST=""

# Subroutines
usage_note()
{
 echo "The script sets up LMA OS-wide prerequisites."
 echo "Reboot is recommended, but non-required. Must be run as root."
 echo "Example: `basename $0`"
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

check_config()
{
  if [ ! -z "`sysctl --system | grep "\b$SYSCTL_FILE_STR1\b"`" ]; then
    echo "Value $SYSCTL_FILE_STR1 exists."
    SYSCTL_STR1_EXIST="1"
  fi
  if [ ! -z "`sysctl --system | grep "\b$SYSCTL_FILE_STR2\b"`" ]; then
    echo "Value $SYSCTL_FILE_STR2 exists."
    SYSCTL_STR2_EXIST="1"
  fi
  if [ ! -z "`sysctl --system | grep "\b$SYSCTL_FILE_STR3\b"`" ]; then
    echo "Value $SYSCTL_FILE_STR3 exists."
    SYSCTL_STR3_EXIST="1"
  fi
  if [ ! -z "`sysctl --system | grep "\b$SYSCTL_FILE_STR4\b"`" ]; then
    echo "Value $SYSCTL_FILE_STR4 exists."
    SYSCTL_STR4_EXIST="1"
  fi
  if [ ! -z "`sysctl --system | grep "\b$SYSCTL_FILE_STR5\b"`" ]; then
    echo "Value $SYSCTL_FILE_STR5 exists."
    SYSCTL_STR5_EXIST="1"
  fi
}

write_file()
{
  file=$1
  if [ -z "$SYSCTL_STR1_EXIST" ]; then
    if [ -z "`grep "\b$SYSCTL_FILE_STR1\b" $file`" ]; then
      echo $SYSCTL_FILE_STR1
    fi
  fi
  if [ -z "$SYSCTL_STR2_EXIST" ]; then
    if [ -z "`grep "\b$SYSCTL_FILE_STR2\b" $file`" ]; then
      echo $SYSCTL_FILE_STR2
    fi
  fi
  if [ -z "$SYSCTL_STR3_EXIST" ]; then
    if [ -z "`grep "\b$SYSCTL_FILE_STR3\b" $file`" ]; then
      echo $SYSCTL_FILE_STR3
    fi
  fi
  if [ -z "$SYSCTL_STR4_EXIST" ]; then
    if [ -z "`grep "\b$SYSCTL_FILE_STR4\b" $file`" ]; then
      echo $SYSCTL_FILE_STR4
    fi
  fi
  if [ -z "$SYSCTL_STR5_EXIST" ]; then
    if [ -z "`grep "\b$SYSCTL_FILE_STR5\b" $file`" ]; then
      echo $SYSCTL_FILE_STR5
    fi
  fi
}

set_config()
{
  # Modern OS
  if [ -d "$SYSCTL_PATH" ]; then
    if [ ! -f "$SYSCTL_PATH/$CONFIG_NAME" ]; then
      echo "Writing $SYSCTL_PATH/$CONFIG_NAME..."
      write_file $SYSCTL_PATH/$CONFIG_NAME > $SYSCTL_PATH/$CONFIG_NAME
    fi
  # Old-fashiones OS
  elif [ -f "$SYSCTL_FILE" ]; then
    echo "Writing $SYSCTL_FILE..."
    write_file $SYSCTL_PATH/$CONFIG_NAME >> $SYSCTL_FILE
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
     -h|-H|\?) usage_note;;
     *) shift
     ;;
    esac
  done
fi

check_os
check_root

check_config
set_config

sysctl --system >/dev/null 2>&1

echo "Done. Reboot recommended but non-required."
exit 0
