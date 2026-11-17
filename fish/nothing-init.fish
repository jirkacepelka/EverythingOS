# EverythingOS terminal session: quiet prompt, fastfetch with dot-matrix logo.
function fish_greeting; end
function fish_prompt
    set_color 737373; echo -n (prompt_pwd)
    set_color ffffff; echo -n "  ● "
    set_color normal
end
function fish_right_prompt
end
clear
fastfetch -c ~/.config/fastfetch/nothing.jsonc
echo
