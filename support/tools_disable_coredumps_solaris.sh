#!/sbin/sh

# tools_disable_coredumps_solaris.sh
#
# Version 1.0
# Written by Y.Voinov (C) 2026

# /var/core
COREDIR="/var/core"

# System utilities
COREADM="`which coreadm`"
CUT="`which cut`"
ECHO="`which echo`"
ID="`which id`"
RMDIR="`which rmdir`"
SVCADM="`which svcadm`"
UNAME="`which uname`"

OS_VER="`$UNAME -r | $CUT -f2 -d'.'`"
OS_NAME="`$UNAME -s | $CUT -f1 -d' '`"

check_os()
{
  if [ "$OS_NAME" != "SunOS" ]; then
    $ECHO "ERROR: Unsupported OS $OS_NAME. Exiting..."
    exit 1
  elif [ "$OS_VER" -lt "10" ]; then
    $ECHO "ERROR: Unsupported $OS_NAME version $OS_VER. Exiting..."
    exit 1
  fi
}

check_root()
{
  if [ ! "`$ID | $CUT -f1 -d' '`" = "uid=0(root)" ]; then
    $ECHO "ERROR: You must be super-user to run this script."
    exit 1
  fi
}

check_os
check_root

# Check and remove directory
[ -d "$COREDIR" ] && $RMDIR $COREDIR && \
$ECHO "Directory $COREDIR removed"

$COREADM -g $COREDIR/core.%f.%p -i $COREDIR/core.%f.%p -d global -d global-setid -d log -d process -d proc-setid

if [ "$OS_VER" -lt "11" ]; then
  $COREADM -u
fi

$SVCADM -v restart coreadm:default

# Show settings
$COREADM

exit 0
