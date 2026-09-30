# Disguise: the shell is Windows PowerShell (5.1, the one Windows 11's Terminal opens by default).
# Linked to ~/.config/zsh/setup.zsh while Disguise is the setup; ~/.zshrc calls setup_banner instead
# of fastfetch and setup_shell last. It's still zsh: everything else works as before.
#
#   the banner, the "PS C:\Users\av> " prompt (paths shown Windows-style), PSReadLine's colours,
#   the window title "Windows PowerShell", PowerShell's "not recognized" error, and the commands a
#   Windows user types: dir / ls / gci, cls, pwd, ipconfig, whoami, hostname, explorer, start,
#   notepad, type, copy, move, del, ren, md, rd, Get-Date, Get-Location, Set-Location, Clear-Host.
#   The real tools are still there: eza, command ls, command cat…

PS_HELPER="$HOME/.config/zsh/ps/ps.py"
# oh-my-zsh would title the window with the directory; Windows Terminal says "Windows PowerShell"
DISABLE_AUTO_TITLE=true

setup_banner() {
    print "Windows PowerShell"
    print "Copyright (C) Microsoft Corporation. All rights reserved."
    print
    print "Install the latest PowerShell for new features and improvements! https://aka.ms/PSWindows"
    print
}

# /home/av/Documents -> C:\Users\av\Documents, /etc -> C:\etc
_ps_path() {
    local p=${1:-$PWD}
    if [[ $p == $HOME || $p == $HOME/* ]]; then p="C:/Users/$USER${p#$HOME}"; else p="C:$p"; fi
    p=${p//\//\\}
    print -r -- "$p"
}

_ps_title() { print -Pn "\e]0;Windows PowerShell\a" }

command_not_found_handler() {
    local c=$1 u=${(l:${#1}::~:)}
    print -u2 -P "%F{9}$c : The term '$c' is not recognized as the name of a cmdlet, function, script file, or operable"
    print -u2 -P "program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again."
    print -u2 -P "At line:1 char:1"
    print -u2 -rP -- "+ ${(q-)@}"
    print -u2 -P "+ $u"
    print -u2 -P "    + CategoryInfo          : ObjectNotFound: ($c:String) [], CommandNotFoundException"
    print -u2 -P "    + FullyQualifiedErrorId : CommandNotFoundException%f"
    print -u2
    return 127
}

setup_shell() {
    # no starship, no eza listing on every cd (PowerShell prints nothing when you change directory)
    precmd_functions=(${precmd_functions:#starship_precmd})
    preexec_functions=(${preexec_functions:#starship_preexec})
    add-zsh-hook -d chpwd auto_ls 2>/dev/null
    add-zsh-hook precmd _ps_title
    setopt prompt_subst
    PROMPT='PS ${$(_ps_path)//\%/%%}> '
    RPROMPT=''

    # PSReadLine's colours: commands yellow, parameters grey, strings dark cyan, variables green
    typeset -gA ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES[command]='fg=11'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=11'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=11'
    ZSH_HIGHLIGHT_STYLES[function]='fg=11'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=11'
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=10'
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=8'
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=8'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=6'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=6'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=6'
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=10'
    ZSH_HIGHLIGHT_STYLES[path]='none'
    ZSH_HIGHLIGHT_STYLES[globbing]='none'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=9'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=8'
    ZSH_HIGHLIGHT_STYLES[redirection]='fg=8'
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

    # PowerShell's aliases and the classic cmd ones
    unalias ls cat find cd 2>/dev/null
    alias cd='z'
    ls()   { python3 "$PS_HELPER" dir "$@" }
    alias dir='ls' gci='ls' Get-ChildItem='ls'
    pwd()  { print; print "Path"; print "----"; _ps_path; print }
    alias Get-Location='pwd' gl='pwd'
    alias Set-Location='cd' sl='cd' chdir='cd'
    alias cls='clear' Clear-Host='clear'
    ipconfig() { python3 "$PS_HELPER" ipconfig "$@" }
    whoami()   { print -r -- "${(L)HOST%%.*}\\$USER" }
    hostname() { print -r -- "${(U)HOST%%.*}" }
    explorer() { thunar "${1:-.}" >/dev/null 2>&1 &! }
    start()    { xdg-open "${1:-.}" >/dev/null 2>&1 &! }
    alias ii='start' Invoke-Item='start'
    notepad()  { ${EDITOR:-nvim} "$@" }
    alias type='command cat' gc='command cat' Get-Content='command cat'
    alias copy='cp' cpi='cp' Copy-Item='cp'
    alias move='mv' mi='mv' Move-Item='mv'
    alias del='rm' erase='rm' ri='rm' Remove-Item='rm'
    alias ren='mv' Rename-Item='mv'
    alias md='mkdir' New-Item='touch'
    alias rd='rmdir'
    alias Get-Date='LC_TIME=en_US.UTF-8 date "+%A, %B %-d, %Y %-I:%M:%S %p"'
    alias Write-Host='print -r --' Write-Output='print -r --'
}
