# EverythingOS terminal session: one-line prompt (folder, branch, red dot) + fastfetch.
function fish_greeting; end
function fish_prompt
    set -l p (string replace -r "^$HOME/?" "" $PWD)
    test -z "$p"; and set p Home
    set -l parts (string split / $p)
    set_color D71921; echo -n "  "
    if test (count $parts) -gt 1
        set -l parent (string join / $parts[1..-2])
        set_color 5f5f5f; echo -n "$parent/"
    end
    set_color --bold ffffff; echo -n $parts[-1]
    set_color normal
    set -l b (git branch --show-current 2>/dev/null)
    if test -n "$b"
        set_color 8a8a8a; echo -n "   $b"
    end
    echo -n "  "
    set_color normal
end
function fish_right_prompt; end
function __nothing_gap --on-event fish_postexec; echo; end
clear
fastfetch -c ~/.config/fastfetch/nothing.jsonc
echo
