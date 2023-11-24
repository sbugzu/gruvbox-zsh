# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](https://iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# If using with "light" variant of the Solarized color schema, set
# SOLARIZED_THEME variable to "light". If you don't specify, we'll assume
# you're using the "dark" variant.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='3';;
    *)     CURRENT_FG='0';;
esac

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0' # 
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  # if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    # prompt_segment 237 7 "%(!.%{%F{3}%}.)%n@%m"
  # fi
  case "$OSTYPE" in
    darwin*)  OS_LOGO="\ue29e" ;; # 
    linux*)   OS_LOGO="\ue712" ;; # 
  esac
  prompt_segment 237 7 $OS_LOGO
}

# Git: branch/detached head, dirty status
function +vi-git-st() {
    local ahead behind
    local -a gitstatus

    # Exit early in case the worktree is on a detached HEAD
    #git rev-parse ${hook_com[branch]}@{upstream} >/dev/null 2>&1 || return 0

    local -a ahead_and_behind=(
        $(git rev-list --left-right --count HEAD...${hook_com[branch]}@{upstream} 2>/dev/null)
    )
		local -a stat=("$(git status --porcelain)")
    local -a untracked=(
    	$(echo "$stat" | grep '^??' | wc -l)
    )
    local -a modified=(
		$(echo "$stat" | grep '^.M' | wc -l)
    )
    local -a staged=(
        $(echo "$stat" | grep '^[AM]' | wc -l)
    )

    ahead=${ahead_and_behind[1]}
    behind=${ahead_and_behind[2]}

    (( $modified )) && gitstatus+=( "%{\033[1m%}${modified}●" )
    (( $staged )) && gitstatus+=( "%{\033[1m%}${staged}" )
    (( $untracked )) && gitstatus+=( "%{\033[1m%}${untracked}" )
    (( $ahead )) && gitstatus+=( '' )
    (( $behind )) && gitstatus+=( '' )

    if [[ gitstatus != '' ]] then
	    hook_com[misc]+=' '
    fi
    hook_com[misc]+=${(j:  :)gitstatus}
}

prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'         # 
  }
  local ref dirty mode repo_path

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment 3 0
    else
      prompt_segment 2 $CURRENT_FG
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    #zstyle ':vcs_info:*' stagedstr '✚'
    #zstyle ':vcs_info:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %m'
    zstyle ':vcs_info:*' actionformats ' %m'
    zstyle ':vcs_info:git*+set-message:*' hooks git-st
    vcs_info
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_bzr() {
    (( $+commands[bzr] )) || return
    if (bzr status >/dev/null 2>&1); then
        status_mod=`bzr status | head -n1 | grep "modified" | wc -m`
        status_all=`bzr status | head -n1 | wc -m`
        revision=`bzr log | head -n2 | tail -n1 | sed 's/^revno: //'`
        if [[ $status_mod -gt 0 ]] ; then
            prompt_segment 3 0
            echo -n "bzr@"$revision "✚ "
        else
            if [[ $status_all -gt 0 ]] ; then
                prompt_segment 3 0
                echo -n "bzr@"$revision

            else
                prompt_segment 2 0
                echo -n "bzr@"$revision
            fi
        fi
    fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev st branch
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment 1 7
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment 3 0
        st='±'
      else
        # if working copy is clean
        prompt_segment 2 $CURRENT_FG
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment 1 0
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment 3 0
        st='±'
      else
        prompt_segment 2 $CURRENT_FG
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment 4 $CURRENT_FG '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    #prompt_segment 4 0 "(`basename $virtualenv_path`)"
    prompt_segment 2 0 "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols

  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{1}%}\Uf02d4" #󰋔
  [[ $UID -eq 0 ]] && symbols+="%{%F{11}%}\ue77a" #
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{15}%}\ufb36" #󰘷

  [[ -n "$symbols" ]] && prompt_segment 166 7 "$symbols"
}

#setup defaults for vi-mode (colours here are selected to match gruvbox in vim)
VI_MODE_PROMPT_SEG="I"
VI_MODE_COLOUR=12

#create zle hook to update on keymap change
zle-keymap-select() {
	#switch prompt indicator and colour
	if [ "${KEYMAP}" = 'vicmd' ]; then
		VI_MODE_PROMPT_SEG="N"
		VI_MODE_COLOUR=7
	else
		VI_MODE_PROMPT_SEG="I"
		VI_MODE_COLOUR=12
	fi
	zle reset-prompt
	
	#change cursor (this feels a bit like scope creep but I imagine most people
	#want this feature and you can only have one of these hooks)
	if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'

  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi

}
zle -N zle-keymap-select

#fix bug where finishing in command mode will show next line as command mode
zle-line-finish() {
	VI_MODE_PROMPT_SEG="I"
	VI_MODE_COLOUR=12
}
zle -N zle-line-finish

#fix bug where C-c in command mode will show next line as command mode, by
#catching C-c, changing mode on prompt and passing through error
TRAPINT() {
	VI_MODE_PROMPT_SEG="I"
	VI_MODE_COLOUR=12
	return $(( 128 + $1 ))
}

prompt_vi() {
	#this checks if you are in vi mode and displays segment only if yes...
	#although probably not very robust
	if bindkey | grep '"\^\[" vi-cmd-mode' &> /dev/null ; then
		#prompt_seperator 0 0
		prompt_segment $VI_MODE_COLOUR 0 "%{\033[1m%}"$VI_MODE_PROMPT_SEG
	fi
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_git
  prompt_bzr
  prompt_hg
	prompt_vi
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
