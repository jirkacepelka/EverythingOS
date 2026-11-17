# Nothing-style session: red dot prompt, fastfetch with the dot-matrix logo.
function fish_greeting; end
function fish_prompt
    set_color D71921; echo -n "● "; set_color normal
end
function fish_right_prompt
    set_color 666666; echo -n (prompt_pwd); set_color normal
end
clear
fastfetch -c ~/.config/fastfetch/nothing.jsonc
