#!/bin/sh

#####################################################################################
## The script intended to disable own Python malloc on Linux.
## It sets PYTHONMALLOC to use libC. This require when using custom allocators to
## prevent segfaults.
##
## Version 1.0
## Written by Y.Voinov (C) 2022-2023
#####################################################################################

# Global environment file
GLOBAL_ENV="/etc/environment"

# Subroutines
usage_note()
{
 echo "The script sets PYTHONMALLOC to use libC on Linux."
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

check_os
check_root

if [ -f "$GLOBAL_ENV" ]; then
  echo "PYTHONMALLOC='malloc'" >> $GLOBAL_ENV
else
  echo "File $GLOBAL_ENV not found. Set PYTHONMALLOC in different place. Exiting..."
  exit 1
fi

echo "Done. Please reboot this system now."
exit 0
