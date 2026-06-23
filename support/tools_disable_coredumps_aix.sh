#!/bin/sh

#
# tools_disable_coredumps_aix.sh
#
# Version 1.0
# Written by Y.Voinov (C) 2026
#

# /var/core
COREDIR="/var/core"

# System utilities
CHCORE="`which chcore 2>/dev/null`"
CHDEV="`which chdev 2>/dev/null`"
CUT="`which cut 2>/dev/null`"
ECHO="`which echo 2>/dev/null`"
ID="`which id 2>/dev/null`"
UNAME="`which uname 2>/dev/null`"

OS_NAME="`$UNAME -s`"

check_tool()
{
    if [ ! -x "$1" ]; then
        $ECHO "ERROR: Required utility not found: $1"
        exit 1
    fi
}

check_os()
{
    if [ "$OS_NAME" != "AIX" ]; then
        $ECHO "ERROR: Unsupported OS $OS_NAME. Exiting..."
        exit 1
    fi

    $ECHO "[OK] Detected $OS_NAME"
}

check_root()
{
    if [ ! "`$ID | $CUT -f1 -d' '`" = "uid=0(root)" ]; then
        $ECHO "ERROR: You must be super-user to run this script."
        exit 1
    fi

    $ECHO "[OK] Running as root"
}

check_tool "$CHCORE"
check_tool "$CHDEV"
check_tool "$CUT"
check_tool "$ECHO"
check_tool "$ID"
check_tool "$UNAME"

check_os
check_root

$CHDEV -l sys0 -a fullcore=false

if [ $? -ne 0 ]; then
    $ECHO "ERROR: Failed to disable fullcore."
    exit 1
fi

$CHCORE -p off -d

if [ $? -ne 0 ]; then
    $ECHO "ERROR: Failed to disable core path."
    exit 1
fi

$ECHO "[OK] Full core dumps disabled"
$ECHO ""
$ECHO "If required, restore original values"
$ECHO "in /etc/security/limits manually."

exit 0
