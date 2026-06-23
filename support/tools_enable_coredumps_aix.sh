#!/bin/sh

#
# tools_enable_coredumps_aix.sh
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
MKDIR="`which mkdir 2>/dev/null`"
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
check_tool "$MKDIR"
check_tool "$UNAME"

check_os
check_root

if [ ! -d "$COREDIR" ]; then
    $MKDIR -p "$COREDIR" || exit 1
    $ECHO "[OK] Directory $COREDIR created"
else
    $ECHO "[OK] Directory $COREDIR already exists"
fi

$CHDEV -l sys0 -a fullcore=true

if [ $? -ne 0 ]; then
    $ECHO "ERROR: Failed to enable fullcore."
    exit 1
fi

$CHCORE -p on -l "$COREDIR" -d

if [ $? -ne 0 ]; then
    $ECHO "ERROR: Failed to configure core path."
    exit 1
fi

$ECHO "[OK] Full core dumps enabled"
$ECHO ""
$ECHO "Manual action required:"
$ECHO ""
$ECHO "Edit /etc/security/limits"
$ECHO "Update stanza 'default:'"
$ECHO ""
$ECHO "    core  = -1"
$ECHO "    fsize = -1"
$ECHO ""
$ECHO "New login sessions are required"
$ECHO "for updated limits to take effect."

exit 0
