if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting
    set -Ux EDITOR helix
    set -Ux VISUAL helix

    # Редакторы
    alias hx="helix"
    alias vim="helix"
    alias nano="helix"

    # Современные замены
    alias ls="eza --icons --group-directories-first"
    alias cat="bat"
    alias grep="rg"
    alias find="fd"
    alias df="duf"

    function weather
        curl "wttr.in/$argv[1]"

    end

    function rate
        curl -sL "rate.sx/$argv[1]"
    end

    function myip
        curl -sL "ifconfig.me/$argv"
    end

    fastfetch

end

# OpenClaw Completion
source "/home/vex/.openclaw/completions/openclaw.fish"

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/vex/.lmstudio/bin
# End of LM Studio CLI section
