#!/bin/sh
#
# tools_analyze_core_solaris.sh
#
# Generate backtrace from a FreeBSD core dump.
#
# Version: 1.0
# Written by Y.Voinov (C) 2026

PROGRAM_NAME=`basename "$0"`

TEMP_CORE=""
CORE_FILE=""
EXECUTABLE=""
ANALYSIS_CORE=""
OUTPUT_FILE=""
OUTPUT_TEMP=""
DEBUGGER=""

usage_note()
{
cat <<EOF
Usage: $PROGRAM_NAME CORE [options]

Options:
  -e, -E FILE      Specify executable image
  -h, -H, --help   Show this help

Examples:
    $PROGRAM_NAME /var/core/core.1234 -e /path/to/program
EOF
}

info()
{
  echo "[INFO] $*"
}

ok()
{
  echo "[OK] $*"
}

fail()
{
  echo "[FAIL] $*" >&2
  exit 1
}

check_os()
{
  os=`uname`

  if [ "$os" != "FreeBSD" ]; then
    fail "Unsupported OS"
  fi

  ok "Running on FreeBSD"
}

cleanup()
{
  if [ -n "$TEMP_CORE" ]; then
    if [ -f "$TEMP_CORE" ]; then
      rm -f "$TEMP_CORE"
    fi
  fi

  if [ -n "$OUTPUT_TEMP" ]; then
    if [ -f "$OUTPUT_TEMP" ]; then
      rm -f "$OUTPUT_TEMP"
    fi
  fi
}

trap 'cleanup' EXIT INT TERM

create_temp_file()
{
  if type mktemp >/dev/null 2>&1; then
    tempfile=`mktemp /tmp/tools_analyze_core.XXXXXX` || \
      fail "Unable to create temporary file."

    echo "$tempfile"
    return 0
  fi

  fail "mktemp is not available."
}

absolute_path()
{
  path=$1

  if type realpath >/dev/null 2>&1; then
    realpath "$path"
    return $?
  fi

  case "$path" in
    /*)
      echo "$path"
      ;;

    *)
      dir=`dirname "$path"` || return 1
      base=`basename "$path"` || return 1

      (
        cd "$dir" 2>/dev/null || exit 1
        echo "`pwd -P`/$base"
      )
    ;;
  esac
}

rotate_output()
{
  outfile=$1
  i=0

  while :
  do
    file="$outfile.$i"

    if [ -f "$file" ]; then
      i=`expr "$i" + 1`
    else
      break
    fi
  done

  while [ "$i" -gt 0 ]
  do
    prev=`expr "$i" - 1`

    from="$outfile.$prev"
    to="$outfile.$i"

    if [ -f "$from" ]; then
      mv "$from" "$to" || \
          fail "Rotation failed."
    fi

    i=$prev
  done

  if [ -f "$outfile" ]; then
    mv "$outfile" "$outfile.0" || \
      fail "Rotation failed."
  fi
}

detect_debugger()
{
  if type gdb >/dev/null 2>&1; then
    DEBUGGER=gdb
    return 0
  fi

  if type lldb >/dev/null 2>&1; then
    DEBUGGER=lldb
    return 0
  fi

  fail "No supported debugger found (gdb/lldb)."
}

prepare_core()
{
  ANALYSIS_CORE="$CORE_FILE"

  [ -f "$ANALYSIS_CORE" ] || \
    fail "Core file does not exist."

  [ -r "$ANALYSIS_CORE" ] || \
    fail "Unable to read core file."
}

run_debugger()
{
  case "$DEBUGGER" in

    gdb)
      gdb \
        --batch \
        --nx \
        --quiet \
        -ex "set pagination off" \
        -ex "set confirm off" \
        -ex "set print thread-events off" \
        -ex "set width 0" \
        -ex "set height 0" \
        -ex "info threads" \
        -ex "echo \n" \
        -ex "thread apply all bt" \
        "$EXECUTABLE" \
        "$ANALYSIS_CORE"
      ;;

    lldb)
      lldb \
        -b \
        -o "thread backtrace all" \
        -o "quit" \
        -c "$ANALYSIS_CORE" \
        -- \
       "$EXECUTABLE"
      ;;

    *)
      fail "Unsupported debugger backend: $DEBUGGER"
      ;;
  esac
}

analyze_core()
{
  OUTPUT_TEMP=`create_temp_file`

  info "Running debugger: $DEBUGGER"

  {
    echo "Executable : `absolute_path "$EXECUTABLE"`"
    echo "Core file  : `absolute_path "$CORE_FILE"`"
    echo "Debugger   : $DEBUGGER"
    echo "Generated  : `date '+%Y-%m-%d %H:%M:%S'`"
    echo
    echo "----------------------------------------"
    echo
  } >"$OUTPUT_TEMP"

  run_debugger >>"$OUTPUT_TEMP" 2>&1 || {
    cat "$OUTPUT_TEMP" >&2
    rm -f "$OUTPUT_TEMP"
    OUTPUT_TEMP=""
    fail "Debugger execution failed."
  }

  case "$DEBUGGER" in

    gdb)
      grep -E '(^#0|^[0-9]+[[:space:]]|Thread [0-9])' "$OUTPUT_TEMP" >/dev/null 2>&1 || {
        cat "$OUTPUT_TEMP" >&2
        rm -f "$OUTPUT_TEMP"
        OUTPUT_TEMP=""
        fail "GDB did not produce a usable backtrace."
      }
      ;;

    lldb)
      grep 'frame #0' "$OUTPUT_TEMP" >/dev/null 2>&1 || {
        cat "$OUTPUT_TEMP" >&2
        rm -f "$OUTPUT_TEMP"
        OUTPUT_TEMP=""
        fail "LLDB did not produce a usable backtrace."
      }
      ;;

    *)
      rm -f "$OUTPUT_TEMP"
      OUTPUT_TEMP=""
      fail "Unsupported debugger backend."
      ;;
  esac

  rotate_output "$OUTPUT_FILE"

  mv "$OUTPUT_TEMP" "$OUTPUT_FILE" || {
    rm -f "$OUTPUT_TEMP"
    OUTPUT_TEMP=""
    fail "Unable to create output file."
  }

  OUTPUT_TEMP=""

  ok "Backtrace saved to:"
  echo
  echo "    `absolute_path "$OUTPUT_FILE"`"
}

find_executable()
{
  if [ -z "$EXECUTABLE" ]; then
    fail "Executable image is not specified. Use -e|-E FILE."
  fi

  [ -f "$EXECUTABLE" ] || \
    fail "Executable file does not exist."

  [ -r "$EXECUTABLE" ] || \
    fail "Executable file is not readable."
}

main()
{
  while [ $# -gt 0 ]
  do
    case "$1" in

      -e|-E)
        shift
        [ $# -gt 0 ] || \
          fail "Missing argument for -e|-E"

        EXECUTABLE=$1
        ;;

      -h|-H|--help)
        usage_note
        exit 0
        ;;

      -*)
        fail "Unknown option: $1"
        ;;

      *)
        if [ -z "$CORE_FILE" ]; then
          CORE_FILE=$1
        elif [ -z "$EXECUTABLE" ]; then
          EXECUTABLE=$1
        else
          fail "Too many positional arguments."
        fi
        ;;
    esac

    shift
  done

  if [ -z "$CORE_FILE" ]; then
    usage_note
    exit 1
  fi

  [ -f "$CORE_FILE" ] || \
    fail "Core file does not exist."

  [ -r "$CORE_FILE" ] || \
    fail "Core file is not readable."

  check_os
  detect_debugger

  # optional executable check only if provided or required by debugger
  find_executable

  prepare_core

  OUTPUT_FILE=`basename "$CORE_FILE"`
  OUTPUT_FILE="${OUTPUT_FILE}.bt.txt"

  analyze_core
}

main "$@"
exit 0
