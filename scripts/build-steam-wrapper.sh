#!/bin/sh
# Builds the Windows program that keeps Steam's window from staying black
# (see Sources/WinHubRuntime/SteamWebHelperWrapper.swift). Needs mingw-w64.
#
#   ./scripts/build-steam-wrapper.sh [saída]   (padrão: .build/steamwebhelper-wrapper.exe)
#
# package-app.sh puts it in the app. For `swift run`:
#   WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
set -eu

cd "$(dirname "$0")/.."
OUT="${1:-.build/steamwebhelper-wrapper.exe}"
MINGW_CC="${MINGW_CC:-x86_64-w64-mingw32-gcc}"
command -v "$MINGW_CC" >/dev/null || { echo "Falta o $MINGW_CC (instale com: brew install mingw-w64)" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
"$MINGW_CC" -municode -mwindows -O2 -s -Wall -Wextra -Werror \
    -o "$OUT" Support/steamwebhelper-wrapper/steamwebhelper_wrapper.c
echo "$OUT"
