#!/sbin/sh

#
# tools_enable_coredumps_solaris.sh
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
MKDIR="/usr/bin/mkdir"
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
check_tool "$MKDIR"
check_tool "$SVCADM"
check_tool "$UNAME"

check_os
check_root

# Check and create directory
if [ ! -d "$COREDIR" ]; then
  $MKDIR -p "$COREDIR" || exit 1
  $ECHO "[OK] Directory $COREDIR created"
else
  $ECHO "[OK] Directory $COREDIR already exists"
fi

$COREADM \
  -g $COREDIR/core.%f.%p \
  -i $COREDIR/core.%f.%p \
  -e global \
  -e global-setid \
  -e log \
  -e process \
  -e proc-setid

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

$ECHO "[OK] Core dumps enabled"

# Show settings
$COREADM

exit 0
