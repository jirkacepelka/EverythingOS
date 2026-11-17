# EverythingOS terminal session: starship prompt (Nothing style) + fastfetch.
set -gx STARSHIP_CONFIG $HOME/.config/starship-nothing.toml
function fish_greeting; end
starship init fish | source
clear
echo
fastfetch -c ~/.config/fastfetch/nothing.jsonc
