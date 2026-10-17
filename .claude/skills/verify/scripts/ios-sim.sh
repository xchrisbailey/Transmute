#!/usr/bin/env bash
# Drives the Transmute iPhone app on a simulator this script creates, and no other.
# Usage: [VERIFY_PLATFORM=watch] ios-sim.sh <command> [args]
#   build                  Build TransmuteiOS for the simulator (scripts/build-apps.sh)
#   start                  Create, boot and record a private simulator; make this run's evidence dir
#   install                Install the built Transmute.app on it
#   launch [launch args]   (Re)launch Transmute with these launch arguments, e.g. -seedSample -openLink transmute://plan
#   doctor                 Read-only: is this session worth driving? Exit 1 with the reason if not
#   shot <name>            Screenshot to <evidence dir>/<name>.png and print the path
#   workout-id [n|running] Print the id of the n-th (default 1st) finished workout, newest first, or the running one, from the app's store
#   stop                   Tear down: terminate the app, shut down and delete the simulator this run created
# State lives in build/verify/.session; evidence in build/verify/<timestamp>/ and is never deleted here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VERIFY="$ROOT/build/verify"
# VERIFY_PLATFORM=watch drives the standalone Apple Watch app on a watchOS simulator instead.
PLATFORM="${VERIFY_PLATFORM:-ios}"
case "$PLATFORM" in
  ios)
    SCHEME="TransmuteiOS"
    SESSION="$VERIFY/.session"
    BUNDLE="computer.srcery.transmute"
    APP="$ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/Transmute.app"
    DEVICE_TYPE="${VERIFY_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
    RUNTIME="${VERIFY_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}"
    ;;
  watch)
    SCHEME="TransmuteWatch"
    SESSION="$VERIFY/.session-watch"
    BUNDLE="computer.srcery.transmute.watchkitapp"
    APP="$ROOT/build/DerivedData/Build/Products/Debug-watchsimulator/Transmute.app"
    DEVICE_TYPE="${VERIFY_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-12-46mm}"
    RUNTIME="${VERIFY_RUNTIME:-com.apple.CoreSimulator.SimRuntime.watchOS-27-0}"
    ;;
  *) echo "ios-sim: VERIFY_PLATFORM must be ios or watch" >&2; exit 1 ;;
esac

die() { echo "ios-sim: $*" >&2; exit 1; }

load() {
  [ -f "$SESSION" ] || die "no session: run '$0 start' first"
  # shellcheck disable=SC1090
  . "$SESSION"
}

# Only ever act on the device recorded in the session, and only if we named it.
guard() {
  case "$(xcrun simctl list devices | grep "$UDID" || true)" in
    *"$NAME"*) ;;
    *) die "device $UDID ($NAME) is gone or is not ours; refusing to touch it" ;;
  esac
}

cmd_build() { (cd "$ROOT" && scripts/build-apps.sh "$SCHEME"); }

cmd_start() {
  [ ! -f "$SESSION" ] || die "a session already exists ($(cat "$SESSION" | tr '\n' ' ')); run '$0 stop' first"
  mkdir -p "$VERIFY"
  local run name udid
  run="$(date +%Y%m%dT%H%M%S)"
  name="verify-$run-$$"
  udid="$(xcrun simctl create "$name" "$DEVICE_TYPE" "$RUNTIME")"
  # Record before booting so a failed boot can still be cleaned up.
  mkdir -p "$VERIFY/$run"
  printf 'UDID=%s\nNAME=%s\nRUN=%s\n' "$udid" "$name" "$VERIFY/$run" >"$SESSION"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "simulator $name $udid booted"
  echo "evidence $VERIFY/$run"
}

cmd_install() {
  load; guard
  [ -d "$APP" ] || die "no build at $APP: run '$0 build'"
  xcrun simctl install "$UDID" "$APP"
  echo "installed $APP"
}

cmd_launch() {
  load; guard
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "$@"
  sleep "${VERIFY_SETTLE:-3}"
}

cmd_shot() {
  load; guard
  local name="${1:?usage: shot <name>}"
  xcrun simctl io "$UDID" screenshot "$RUN/$name.png" 2>/dev/null
  echo "$RUN/$name.png"
}

store_path() {
  local data
  data="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
  find "$data" -name '*.store' -not -name '*-wal' -not -name '*-shm' | head -1
}

cmd_workout_id() {
  load; guard
  local store
  store="$(store_path)"
  [ -n "$store" ] || die "no store yet: launch the app once"
  # SwiftData keeps the UUID as a 16-byte blob; print it as a dashed lowercase UUID.
  local where="ZENDEDAT IS NOT NULL" offset=0
  if [ "${1:-}" = running ]; then where="ZENDEDAT IS NULL"; else offset=$(( ${1:-1} - 1 )); fi
  sqlite3 "file:$store?mode=ro" \
    "SELECT lower(substr(h,1,8)||'-'||substr(h,9,4)||'-'||substr(h,13,4)||'-'||substr(h,17,4)||'-'||substr(h,21)) FROM (SELECT hex(ZID) AS h FROM ZWORKOUT WHERE $where ORDER BY ZSTARTEDAT DESC LIMIT 1 OFFSET $offset);"
}

cmd_doctor() {
  local fail=0
  ok() { echo "ok    $*"; }
  bad() { echo "FAIL  $*"; fail=1; }
  xcode-select -p >/dev/null 2>&1 && ok "Xcode: $(xcodebuild -version | head -1)" || bad "no Xcode"
  xcrun simctl list runtimes | grep -q "$RUNTIME" && ok "runtime $RUNTIME installed" || bad "runtime $RUNTIME missing"
  command -v sqlite3 >/dev/null && ok "sqlite3 present" || bad "sqlite3 missing"
  [ -d "$APP" ] && ok "built app $APP (built $(stat -f %Sm "$APP"))" || bad "no built app: run '$0 build'"
  if [ -f "$SESSION" ]; then
    . "$SESSION"
    line="$(xcrun simctl list devices | grep "$UDID" || true)"
    case "$line" in
      *"$NAME"*"(Booted)"*) ok "our simulator $NAME is Booted" ;;
      *"$NAME"*) bad "our simulator $NAME is not Booted: $line" ;;
      *) bad "session points at $UDID but no such device named $NAME" ;;
    esac
    xcrun simctl get_app_container "$UDID" "$BUNDLE" >/dev/null 2>&1 && ok "Transmute installed on it" || bad "Transmute not installed: run '$0 install'"
    [ -d "$RUN" ] && ok "evidence dir $RUN" || bad "evidence dir missing"
  else
    bad "no session: run '$0 start'"
  fi
  others="$(xcrun simctl list devices booted | grep -c Booted || true)"
  echo "info  $others booted simulator(s) in total; any that is not ours is someone else's: leave it alone"
  return $fail
}

cmd_stop() {
  [ -f "$SESSION" ] || { echo "no session; nothing to stop"; return 0; }
  load
  if xcrun simctl list devices | grep "$UDID" | grep -q "$NAME"; then
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
    xcrun simctl delete "$UDID"
    echo "deleted simulator $NAME"
  fi
  rm -f "$SESSION"
  echo "evidence kept in $RUN"
}

case "${1:-}" in
  build) cmd_build ;;
  start) cmd_start ;;
  install) cmd_install ;;
  launch) shift; cmd_launch "$@" ;;
  shot) shift; cmd_shot "$@" ;;
  workout-id) shift; cmd_workout_id "$@" ;;
  doctor) cmd_doctor ;;
  stop) cmd_stop ;;
  *) sed -n '2,16p' "$0"; exit 2 ;;
esac
