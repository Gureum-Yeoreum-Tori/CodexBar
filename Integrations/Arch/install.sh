#!/usr/bin/env bash
# Build the upstream Qt desktop against the current Arch/CachyOS Qt libraries.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
build_dir="$repo/.local/linux-build"
build_only=false
if [[ ${1:-} == --build-only ]]; then
    build_only=true
    shift
fi
if [[ ${1:-} == --help ]]; then
    printf 'Usage: bash Integrations/Arch/install.sh [--build-only] [Linux installer options]\n'
    printf 'Example: bash Integrations/Arch/install.sh --cli "$HOME/.local/bin/codexbar"\n'
    exit 0
fi
for tool in qmake6 make g++ python3 pkg-config; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Missing %s. Install base-devel python qt6-base qt6-declarative qt6-svg.\n' "$tool" >&2
        exit 1
    fi
done
pkg-config --exists Qt6Widgets Qt6Quick Qt6QuickControls2 Qt6Network Qt6DBus Qt6Svg
if [[ ${XDG_SESSION_TYPE:-} == wayland ]]; then
    plugin_dir=$(qmake6 -query QT_INSTALL_PLUGINS)
    if ! compgen -G "$plugin_dir/platforms/libqwayland*.so" >/dev/null; then
        printf 'Qt Wayland platform plugin missing; install the package providing it for your Qt version.\n' >&2
        exit 1
    fi
fi
mkdir -p "$build_dir"
(
    cd -- "$build_dir"
    CODEXBAR_DESKTOP_VERSION=0.1.0-arch qmake6 "$repo/Integrations/Linux/codexbar-linux.pro"
    make -j"${CODEXBAR_BUILD_JOBS:-4}"
)
if [[ $build_only == false ]]; then
    python3 "$repo/Integrations/Linux/install.py" --binary "$build_dir/codexbar-linux" "$@"
fi
