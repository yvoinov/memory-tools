#!/sbin/sh

#
# tools_disable_coredumps_solaris.sh
#
# Version 1.1
# Written by Y.Voinov (C) 2026
#

# /var/core
COREDIR="/var/core"

# System utilities
COREADM="/bin/coreadm"
CUT="/usr/bin/cut"
ECHO="/usr/bin/echo"
ID="/usr/bin/id"
RMDIR="/usr/bin/rmdir"
SVCADM="/usr/sbin/svcadm"
UNAME="/usr/bin/uname"

OS_VER="`$UNAME -r | $CUT -f2 -d'.'`"
OS_NAME="`$UNAME -s | $CUT -f1 -d' '`"

check_tool()
{
  if [ ! -x "$1" ]; then
    $ECHO "ERROR: Required utility not found: $1"
    exit 1
  fi
}

check_os()
{
  if [ "$OS_NAME" != "SunOS" ]; then
    $ECHO "ERROR: Unsupported OS $OS_NAME. Exiting..."
    exit 1
  elif [ "$OS_VER" -lt "10" ]; then
    $ECHO "ERROR: Unsupported $OS_NAME version $OS_VER. Exiting..."
    exit 1
  fi

  $ECHO "[OK] Detected $OS_NAME $OS_VER"
}

check_root()
{
  if [ ! "`$ID | $CUT -f1 -d' '`" = "uid=0(root)" ]; then
    $ECHO "ERROR: You must be super-user to run this script."
    exit 1
  fi

  $ECHO "[OK] Running as root"
}

check_tool "$COREADM"
check_tool "$CUT"
check_tool "$ECHO"
check_tool "$ID"
check_tool "$RMDIR"
check_tool "$SVCADM"
check_tool "$UNAME"

check_os
check_root

# Check and remove directory
if [ -d "$COREDIR" ]; then
  if $RMDIR "$COREDIR" 2>/dev/null; then
    $ECHO "[OK] Directory $COREDIR removed"
  else
    $ECHO "[INFO] Directory $COREDIR not empty, leaving intact"
  fi
fi

$COREADM \
  -g $COREDIR/core.%f.%p \
  -i $COREDIR/core.%f.%p \
  -d global \
  -d global-setid \
  -d log \
  -d process \
  -d proc-setid

if [ $? -ne 0 ]; then
  $ECHO "ERROR: Failed to configure coreadm."
  exit 1
fi

if [ "$OS_VER" -lt "11" ]; then
  $COREADM -u
fi

$SVCADM -v restart coreadm:default

if [ $? -ne 0 ]; then
  $ECHO "ERROR: Failed to restart coreadm service."
  exit 1
fi

$ECHO "[OK] Core dumps disabled"

# Show settings
$COREADM

exit 0
