#!/bin/sh
#
# tools_analyze_core_linux.sh
#
# Generate backtrace from a Linux core dump.
#
# Version: 1.0
# Written by Y.Voinov (C) 2026

PROGRAM_NAME=$(basename "$0")

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
    $PROGRAM_NAME core.12345 -e ./my_program
EOF
}

info()
{
  printf '[INFO] %s\n' "$*"
}

ok()
{
  printf '[OK] %s\n' "$*"
}

fail()
{
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

check_os()
{
  [ "$(uname)" = "Linux" ] || { fail "Unsupported OS"; }
  ok "Running on Linux"
}

cleanup()
{
  if [ -n "$TEMP_CORE" ] && [ -f "$TEMP_CORE" ]; then
    rm -f -- "$TEMP_CORE"
  fi

  if [ -n "$OUTPUT_TEMP" ] && [ -f "$OUTPUT_TEMP" ]; then
    rm -f -- "$OUTPUT_TEMP"
  fi
}

trap cleanup EXIT INT TERM

create_temp_file()
{
  if command -v mktemp >/dev/null 2>&1; then
    template="${TMPDIR:-/tmp}/tools_analyze_core.XXXXXX"

    tempfile=$(mktemp "$template") || \
    fail "Unable to create temporary file."

    printf '%s\n' "$tempfile"
    return 0
  fi

  fail "mktemp is not available."
}

absolute_path()
{
  path=$1

  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
    return $?
  fi

  case "$path" in
    /*)
      printf '%s\n' "$path"
      ;;

    *)
      dir=$(dirname -- "$path") || return 1
      base=$(basename -- "$path") || return 1

      (
        cd "$dir" 2>/dev/null &&
        printf '%s/%s\n' "$(pwd -P)" "$base"
      )
      ;;
  esac
}

rotate_output()
{
  outfile=$1

  i=0
  while [ -e "${outfile}.${i}" ]; do
    i=$((i + 1))
  done

  while [ "$i" -gt 0 ]; do
    prev=$((i - 1))
    if [ -e "${outfile}.${prev}" ]; then
      mv -- "${outfile}.${prev}" "${outfile}.${i}" || \
        fail "rotation failed"
    fi
    i=$((i - 1))
  done

  if [ -e "$outfile" ]; then
    mv -- "$outfile" "${outfile}.0" || \
      fail "rotation failed"
  fi
}

detect_debugger()
{
  if command -v gdb >/dev/null 2>&1; then
    DEBUGGER="gdb"
    return 0
  fi

  if command -v lldb >/dev/null 2>&1; then
    DEBUGGER="lldb"
    return 0
  fi

  fail "No supported debugger found (gdb/lldb)."
}

prepare_core()
{
  ANALYSIS_CORE="$CORE_FILE"

  case "$CORE_FILE" in

    *.gz)
        info "Decompressing gzip core..."

        TEMP_CORE=$(create_temp_file)

        gzip -cd -- "$CORE_FILE" >"$TEMP_CORE" || \
          fail "Unable to decompress $CORE_FILE."

        ANALYSIS_CORE="$TEMP_CORE"
        ;;

    *.xz)
        info "Decompressing xz core..."

        TEMP_CORE=$(create_temp_file)

        xz -cd -- "$CORE_FILE" >"$TEMP_CORE" || \
          fail "Unable to decompress $CORE_FILE."

        ANALYSIS_CORE="$TEMP_CORE"
        ;;

    *.zst)
        info "Decompressing zstd core..."

        TEMP_CORE=$(create_temp_file)

        zstd -cd -- "$CORE_FILE" >"$TEMP_CORE" || \
          fail "Unable to decompress $CORE_FILE."

        ANALYSIS_CORE="$TEMP_CORE"
        ;;

    *)
        ;;
  esac

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
        -iex "set debuginfod enabled on" \
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
  OUTPUT_TEMP=$(create_temp_file)

  info "Running debugger: $DEBUGGER"

  {
    printf 'Executable : %s\n' "$(absolute_path "$EXECUTABLE")"
    printf 'Core file  : %s\n' "$(absolute_path "$CORE_FILE")"
    printf 'Debugger   : %s\n' "$DEBUGGER"
    printf 'Generated  : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '\n----------------------------------------\n\n'
  } >"$OUTPUT_TEMP"

  if ! run_debugger >>"$OUTPUT_TEMP" 2>&1; then
    cat "$OUTPUT_TEMP" >&2
    rm -f -- "$OUTPUT_TEMP"
    OUTPUT_TEMP=""
    fail "Debugger execution failed."
  fi

  # GDB/LLDB-specific noise cleanup
  sed \
    -e '/^\[New LWP /d' \
    -e '/Thread debugging/d' \
    -e '/libthread_db/d' \
    "$OUTPUT_TEMP" > "${OUTPUT_TEMP}.new" || {
      rm -f -- "$OUTPUT_TEMP" "${OUTPUT_TEMP}.new"
      OUTPUT_TEMP=""
      fail "Post-processing failed."
  }

  mv -- "${OUTPUT_TEMP}.new" "$OUTPUT_TEMP"

  rotate_output "$OUTPUT_FILE"

  mv -- "$OUTPUT_TEMP" "$OUTPUT_FILE"

  OUTPUT_TEMP=""

  ok "Backtrace saved to:"
  printf '    %s\n' "$(absolute_path "$OUTPUT_FILE")"
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
  while [ $# -gt 0 ]; do
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
          else
            fail "Only one core file may be specified."
          fi
          ;;
    esac

      shift
  done

  [ -n "$CORE_FILE" ] || {
    usage_note
    exit 1
  }

  [ -f "$CORE_FILE" ] || \
    fail "Core file does not exist."

  [ -r "$CORE_FILE" ] || \
    fail "Core file is not readable."

  check_os
  detect_debugger
  find_executable
  prepare_core

  OUTPUT_FILE=$(basename -- "$CORE_FILE")
  OUTPUT_FILE="${OUTPUT_FILE}.bt.txt"

  analyze_core
}

main "$@"
exit 0
