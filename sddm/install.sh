#!/usr/bin/env bash
# EverythingOS SDDM installer / helper. Needs root: run it through pkexec
# (the Login settings page does) or with sudo.
#
#   install.sh install                      theme + font + state dir, set EverythingOS as the SDDM theme
#   install.sh apply THEME AUTOLOGIN SESSION
#                                           write /etc/sddm.conf.d/20-everythingos.conf
#                                           (AUTOLOGIN: user name or "-"; SESSION: file name like hyprland.desktop or "-")
#   install.sh uninstall                    remove our theme + conf (SDDM falls back to the packaged default)
#
# Nothing else on the system is touched. Pre-existing conf files stay as they
# are: ours (20-...) simply sorts after e.g. 10-pop-sddm.conf and wins.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
THEMES=/usr/share/sddm/themes
CONF=/etc/sddm.conf.d/20-everythingos.conf
STATE=/var/lib/panacea
FONTS=/usr/share/fonts/everythingos

[ "$(id -u)" = 0 ] || { echo "must run as root (use pkexec)" >&2; exit 1; }

# the human who asked for this (pkexec / sudo both tell us)
uid="${PKEXEC_UID:-${SUDO_UID:-}}"
[ -n "$uid" ] || { echo "cannot tell the invoking user" >&2; exit 1; }
owner="$(getent passwd "$uid" | cut -d: -f1)"

valid_user()    { getent passwd "$1" >/dev/null && [ "$(getent passwd "$1" | cut -d: -f3)" -ge 1000 ]; }
valid_session() { [[ "$1" =~ ^[A-Za-z0-9._-]+\.desktop$ ]] && { [ -f "/usr/share/wayland-sessions/$1" ] || [ -f "/usr/share/xsessions/$1" ]; }; }
valid_theme()   { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] && [ -f "$THEMES/$1/metadata.desktop" ]; }

install_theme() {
    rm -rf "$THEMES/everythingos"
    install -d "$THEMES/everythingos"
    install -m644 "$SRC"/everythingos/* "$THEMES/everythingos/"
    # greeter fonts: user fonts in ~ are invisible to the sddm user
    fsrc="$SRC/fonts"; [ -d "$fsrc" ] || fsrc="$SRC/../fonts"
    if [ -d "$fsrc" ]; then
        install -d "$FONTS"
        for f in SpaceMono-Regular.ttf SpaceMono-Bold.ttf Doto-Variable.ttf; do
            if [ -f "$fsrc/$f" ]; then install -m644 "$fsrc/$f" "$FONTS/$f"; fi
        done
        fc-cache -f "$FONTS" >/dev/null 2>&1 || true
    fi
    # world-readable dir the shell (user) writes and the greeter reads
    install -d -o "$owner" -m755 "$STATE"
}

write_conf() { # theme autologin session
    local theme="$1" auto="$2" sess="$3"
    install -d /etc/sddm.conf.d
    {
        echo "# Written by EverythingOS (sddm/install.sh). Remove this file to go back."
        echo "[Theme]"
        echo "Current=$theme"
        if [ "$auto" != "-" ] || [ "$sess" != "-" ]; then
            echo
            echo "[Autologin]"
            [ "$auto" != "-" ] && echo "User=$auto"
            [ "$sess" != "-" ] && echo "Session=$sess"
        fi
    } > "$CONF"
    chmod 644 "$CONF"
}

case "${1:-}" in
install)
    install_theme
    write_conf everythingos - -
    echo "installed EverythingOS SDDM theme"
    ;;
apply)
    theme="${2:-}"; auto="${3:--}"; sess="${4:--}"
    [ "$theme" = everythingos ] && install_theme
    valid_theme "$theme" || { echo "bad theme: $theme" >&2; exit 1; }
    [ "$auto" = "-" ] || valid_user "$auto" || { echo "bad user: $auto" >&2; exit 1; }
    [ "$sess" = "-" ] || valid_session "$sess" || { echo "bad session: $sess" >&2; exit 1; }
    write_conf "$theme" "$auto" "$sess"
    echo "applied: theme=$theme autologin=$auto session=$sess"
    ;;
uninstall)
    rm -f "$CONF"
    rm -rf "$THEMES/everythingos" "$FONTS"
    echo "removed"
    ;;
*)
    echo "usage: install.sh install | apply THEME AUTOLOGIN|- SESSION|- | uninstall" >&2
    exit 1
    ;;
esac
