# bash/zsh git prompt support
#
# Copyright (C) 2016 David Xu
#
# Based on the earlier work by Shawn O. Pearce <spearce@spearce.org>
# Distributed under the GNU General Public License, version 2.0.
#
# This script allows you to see the current branch in your prompt,
# posh-git style.
#
# You will most likely want to make use of either `__posh_git_ps1` or
# `__posh_git_echo`. Refer to the documentation of the functions for additional
# information.
#
#
# CONFIG OPTIONS
# ==============
#
# This script should work out of the box. Available options are set through
# your git configuration files. This allows you to control the prompt display on a
# per-repository basis.
# ```
# bash.describeStyle
# bash.enableFileStatus
# bash.enableGitStatus
# bash.showStatusWhenZero
# bash.showUpstream
# ```
#
# bash.describeStyle
# ------------------
#
# This option controls if you would like to see more information about the
# identity of commits checked out as a detached `HEAD`. This is also controlled
# by the legacy environment variable `GIT_PS1_DESCRIBESTYLE`.
#
# Option   | Description
# -------- | -----------
# contains | relative to newer annotated tag `(v1.6.3.2~35)`
# branch   | relative to newer tag or branch `(master~4)`
# describe | relative to older annotated tag `(v1.6.3.1-13-gdd42c2f)`
# default  | exactly matching tag
#
# bash.enableFileStatus
# ---------------------
#
# Option | Description
# ------ | -----------
# true   | _Default_. The script will query for all file indicators every time.
# false  | No file indicators will be displayed. The script will not query
#          upstream for differences. Branch color-coding information is still
#          displayed.
#
# bash.enableGitStatus
# --------------------
#
# Option | Description
# ------ | -----------
# true   | _Default_. Color coding and indicators will be shown.
# false  | The script will not run.
#
# bash.showStashState
# -------------------
#
# Option | Description
# ------ | -----------
# true   | _Default_. An indicator will display if the stash is not empty.
# false  | An indicator will not display the stash status.
#
# bash.showStatusWhenZero
# -----------------------
#
# Option | Description
# ------ | -----------
# true   | Indicators will be shown even if there are no updates to the index or
#          working tree.
# false  | _Default_. No file change indicators will be shown if there are no
#          changes to the index or working tree.
#
# bash.showUpstream
# -----------------
#
# By default, `__posh_git_ps1` will compare `HEAD` to your `SVN` upstream if it can
# find one, or `@{upstream}` otherwise. This is also controlled by the legacy
# environment variable `GIT_PS1_SHOWUPSTREAM`.
#
# Option | Description
# ------ | -----------
# legacy | Does not use the `--count` option available in recent versions of
#          `git-rev-list`
# git    | _Default_. Always compares `HEAD` to `@{upstream}`
# svn    | Always compares `HEAD` to `SVN` upstream
###############################################################################

# Convenience function to set PS1 to show git status. Must supply two
# arguments that specify the prefix and suffix of the git status string.
#
# This function should be called in PROMPT_COMMAND or similar.
__posh_git_ps1 ()
{
    local ps1pc_prefix=
    local ps1pc_suffix=
    case "$#" in
        2)
            ps1pc_prefix=$1
            ps1pc_suffix=$2
            ;;
        *)
            echo __posh_git_ps1: bad number of arguments >&2
            return
            ;;
    esac
    local gitstring=$(__posh_git_echo)
    PS1=$ps1pc_prefix$gitstring$ps1pc_suffix
}

__posh_color () {
    if [ -n "$ZSH_VERSION" ]; then
        echo %{$1%}
    elif [ -n "$BASH_VERSION" ]; then
        echo \\[$1\\]
    else
        # assume Bash anyway
        echo \\[$1\\]
    fi
}

# Echoes the git status string.
__posh_git_echo () {
    if [ "$(git config --bool bash.enableGitStatus)" = 'false' ]; then
        return;
    fi

    local DefaultForegroundColor=$(__posh_color '\e[m') # Default no color
    local DefaultBackgroundColor=

    local BeforeText=' ['
    local BeforeForegroundColor=$(__posh_color '\e[1;33m') # Yellow
    local BeforeBackgroundColor=
    local DelimText=' |'
    local DelimForegroundColor=$(__posh_color '\e[1;33m') # Yellow
    local DelimBackgroundColor=

    local AfterText=']'
    local AfterForegroundColor=$(__posh_color '\e[1;33m') # Yellow
    local AfterBackgroundColor=

    local BranchIdenticalStatusToSymbol=$'\xE2\x89\xA1' # Three horizontal lines
    local BranchAheadStatusSymbol=$'\xE2\x86\x91' # Up Arrow
    local BranchBehindStatusSymbol=$'\xE2\x86\x93' # Down Arrow
    local BranchBehindAndAheadStatusSymbol=$'\xE2\x86\x95' # Up and Down Arrow

    local BranchForegroundColor=$(__posh_color '\e[1;36m')  # Cyan
    local BranchBackgroundColor=
    local BranchAheadForegroundColor=$(__posh_color '\e[1;32m') # Green
    local BranchAheadBackgroundColor=
    local BranchBehindForegroundColor=$(__posh_color '\e[0;31m') # Red
    local BranchBehindBackgroundColor=
    local BranchBehindAndAheadForegroundColor=$(__posh_color '\e[1;33m') # Yellow
    local BranchBehindAndAheadBackgroundColor=

    local BeforeIndexText=''
    local BeforeIndexForegroundColor=$(__posh_color '\e[1;32m') # Dark green
    local BeforeIndexBackgroundColor=

    local IndexForegroundColor=$(__posh_color '\e[1;32m') # Dark green
    local IndexBackgroundColor=

    local WorkingForegroundColor=$(__posh_color '\e[0;31m') # Dark red
    local WorkingBackgroundColor=

    local StashForegroundColor=$(__posh_color '\e[0;34m') # Darker blue
    local StashBackgroundColor=
    local StashText='$'

    local RebaseForegroundColor=$(__posh_color '\e[0m') # reset
    local RebaseBackgroundColor=

    local EnableFileStatus=`git config --bool bash.enableFileStatus`
    case "$EnableFileStatus" in
        true)  EnableFileStatus=true ;;
        false) EnableFileStatus=false ;;
        *)     EnableFileStatus=true ;;
    esac
    local ShowStatusWhenZero=`git config --bool bash.showStatusWhenZero`
    case "$ShowStatusWhenZero" in
        true)  ShowStatusWhenZero=true ;;
        false) ShowStatusWhenZero=false ;;
        *)     ShowStatusWhenZero=false ;;
    esac
    local ShowStashState=`git config --bool bash.showStashState`
    case "$ShowStashState" in
        true)  ShowStashState=true ;;
        false) ShowStashState=false ;;
        *)     ShowStashState=true ;;
    esac

    # these globals are updated by __posh_git_ps1_upstream_divergence
    __POSH_BRANCH_AHEAD_BY=0
    __POSH_BRANCH_BEHIND_BY=0

    local is_detached=false

    local g=$(__posh_gitdir)
    if [ -z "$g" ]; then
        return # not a git directory
    fi
    local rebase=''
    local b=''
    local step=''
    local total=''
    if [ -d "$g/rebase-merge" ]; then
        b=$(cat "$g/rebase-merge/head-name" 2>/dev/null)
        step=$(cat "$g/rebase-merge/msgnum" 2>/dev/null)
        total=$(cat "$g/rebase-merge/end" 2>/dev/null)
        if [ -f "$g/rebase-merge/interactive" ]; then
            rebase='|REBASE-i'
        else
            rebase='|REBASE-m'
        fi
    else
        if [ -d "$g/rebase-apply" ]; then
            step=$(cat "$g/rebase-apply/next")
            total=$(cat "$g/rebase-apply/last")
            if [ -f "$g/rebase-apply/rebasing" ]; then
                rebase='|REBASE'
            elif [ -f "$g/rebase-apply/applying" ]; then
                rebase='|AM'
            else
                rebase='|AM/REBASE'
            fi
        elif [ -f "$g/MERGE_HEAD" ]; then
            rebase='|MERGING'
        elif [ -f "$g/CHERRY_PICK_HEAD" ]; then
            rebase='|CHERRY-PICKING'
        elif [ -f "$g/REVERT_HEAD" ]; then
            rebase='|REVERTING'
        elif [ -f "$g/BISECT_LOG" ]; then
            rebase='|BISECTING'
        fi

        b=$(git symbolic-ref HEAD 2>/dev/null) || {
            is_detached=true
            local output=$(git config -z --get bash.describeStyle)
            if [ -n "$output" ]; then
                GIT_PS1_DESCRIBESTYLE=$output
            fi
            b=$(
            case "${GIT_PS1_DESCRIBESTYLE-}" in
            (contains)
                git describe --contains HEAD ;;
            (branch)
                git describe --contains --all HEAD ;;
            (describe)
                git describe HEAD ;;
            (* | default)
                git describe --tags --exact-match HEAD ;;
            esac 2>/dev/null) ||

            b=$(cut -c1-7 "$g/HEAD" 2>/dev/null)... ||
            b='unknown'
            b="($b)"
        }
    fi

    if [ -n "$step" ] && [ -n "$total" ]; then
        rebase="$rebase $step/$total"
    fi

    local isDirtyUnstaged=''
    local isDirtyStaged=''
    local hasStash=false
    local isBare=''

    if [ 'true' = "$(git rev-parse --is-inside-git-dir 2>/dev/null)" ]; then
        if [ 'true' = "$(git rev-parse --is-bare-repository 2>/dev/null)" ]; then
            isBare='BARE:'
        else
            b='GIT_DIR!'
        fi
    elif [ 'true' = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
        if $ShowStashState; then
            git rev-parse --verify refs/stash >/dev/null 2>&1 && hasStash=true
        fi
        __posh_git_ps1_upstream_divergence
    fi

    # show index status and working directory status
    if $EnableFileStatus; then
        local indexAdded=0
        local indexModified=0
        local indexDeleted=0
        local indexUnmerged=0
        local filesAdded=0
        local filesModified=0
        local filesDeleted=0
        local filesUnmerged=0
        while IFS="\n" read -r tag rest
        do
            case "${tag:0:1}" in
                A )
                    (( indexAdded++ ))
                    ;;
                M )
                    (( indexModified++ ))
                    ;;
                R )
                    (( indexModified++ ))
                    ;;
                C )
                    (( indexModified++ ))
                    ;;
                D )
                    (( indexDeleted++ ))
                    ;;
                U )
                    (( indexUnmerged++ ))
                    ;;
            esac
            case "${tag:1:1}" in
                \? )
                    (( filesAdded++ ))
                    ;;
                A )
                    (( filesAdded++ ))
                    ;;
                M )
                    (( filesModified++ ))
                    ;;
                D )
                    (( filesDeleted++ ))
                    ;;
                U )
                    (( filesUnmerged++ ))
                    ;;
            esac
        done <<< "`git status --porcelain 2>/dev/null`"
    fi

    local gitstring=
    local branchstring="$isBare${b##refs/heads/}"

    # before-branch text
    gitstring="$BeforeBackgroundColor$BeforeForegroundColor$BeforeText"

    # branch
    if (( $__POSH_BRANCH_BEHIND_BY > 0 && $__POSH_BRANCH_AHEAD_BY > 0 )); then
        gitstring+="$BranchBehindAndAheadBackgroundColor$BranchBehindAndAheadForegroundColor$branchstring $BranchBehindAndAheadStatusSymbol"
    elif (( $__POSH_BRANCH_BEHIND_BY > 0 )); then
        gitstring+="$BranchBehindBackgroundColor$BranchBehindForegroundColor$branchstring $BranchBehindStatusSymbol"
    elif (( $__POSH_BRANCH_AHEAD_BY > 0 )); then
        gitstring+="$BranchAheadBackgroundColor$BranchAheadForegroundColor$branchstring $BranchAheadStatusSymbol"
    else
        gitstring+="$BranchBackgroundColor$BranchForegroundColor$branchstring $BranchIdenticalStatusToSymbol"
    fi

    # index status
    if $EnableFileStatus; then
        local indexCount="$(( $indexAdded + $indexModified + $indexDeleted + $indexUnmerged ))"
        local workingCount="$(( $filesAdded + $filesModified + $filesDeleted + $filesUnmerged ))"
        if (( $indexCount != 0 )) || $ShowStatusWhenZero; then
            gitstring+="$IndexBackgroundColor$IndexForegroundColor +$indexAdded ~$indexModified -$indexDeleted"
        fi
        if (( $indexUnmerged != 0 )); then
            gitstring+=" $IndexBackgroundColor$IndexForegroundColor!$indexUnmerged"
        fi
        if (( $indexCount != 0 && ($workingCount != 0 || $ShowStatusWhenZero) )); then
            gitstring+="$DelimBackgroundColor$DelimForegroundColor$DelimText"
        fi
        if (( $workingCount != 0 )) || $ShowStatusWhenZero; then
            gitstring+="$WorkingBackgroundColor$WorkingForegroundColor +$filesAdded ~$filesModified -$filesDeleted"
        fi
        if (( $filesUnmerged != 0 )); then
            gitstring+=" $WorkingBackgroundColor$WorkingForegroundColor!$filesUnmerged"
        fi
    fi
    gitstring+="$RebaseBackgroundColor$RebaseForegroundColor${rebase:+'\e[0m'$rebase}"

    # after-branch text
    gitstring+="$AfterBackgroundColor$AfterForegroundColor$AfterText"

    if $ShowStashState && $hasStash; then
        gitstring+="$StashBackgroundColor$StashForegroundColor"$StashText
    fi
    gitstring+="$DefaultBackgroundColor$DefaultForegroundColor"
    echo "$gitstring"
}

# Returns the location of the .git/ directory.
__posh_gitdir ()
{
    # Note: this function is duplicated in git-completion.bash
    # When updating it, make sure you update the other one to match.
    if [ -z "${1-}" ]; then
        if [ -n "${__posh_git_dir-}" ]; then
            echo "$__posh_git_dir"
        elif [ -n "${GIT_DIR-}" ]; then
            test -d "${GIT_DIR-}" || return 1
            echo "$GIT_DIR"
        elif [ -d .git ]; then
            echo .git
        else
            git rev-parse --git-dir 2>/dev/null
        fi
    elif [ -d "$1/.git" ]; then
        echo "$1/.git"
    else
        echo "$1"
    fi
}

# Updates the global variables `__POSH_BRANCH_AHEAD_BY` and `__POSH_BRANCH_BEHIND_BY`.
__posh_git_ps1_upstream_divergence ()
{
    local key value
    local svn_remote svn_url_pattern
    local upstream=git          # default
    local legacy=''

    svn_remote=()
    # get some config options from git-config
    local output="$(git config -z --get-regexp '^(svn-remote\..*\.url|bash\.showUpstream)$' 2>/dev/null | tr '\0\n' '\n ')"
    while read -r key value; do
        case "$key" in
        bash.showUpstream)
            GIT_PS1_SHOWUPSTREAM="$value"
            if [ -z "${GIT_PS1_SHOWUPSTREAM}" ]; then
                return
            fi
            ;;
        svn-remote.*.url)
            svn_remote[ $((${#svn_remote[@]} + 1)) ]="$value"
            svn_url_pattern+="\\|$value"
            upstream=svn+git # default upstream is SVN if available, else git
            ;;
        esac
    done <<< "$output"

    # parse configuration values
    for option in ${GIT_PS1_SHOWUPSTREAM}; do
        case "$option" in
        git|svn) upstream="$option" ;;
        legacy)  legacy=1  ;;
        esac
    done

    # Find our upstream
    case "$upstream" in
    git)    upstream='@{upstream}' ;;
    svn*)
        # get the upstream from the "git-svn-id: ..." in a commit message
        # (git-svn uses essentially the same procedure internally)
        local svn_upstream=($(git log --first-parent -1 \
                    --grep="^git-svn-id: \(${svn_url_pattern#??}\)" 2>/dev/null))
        if (( 0 != ${#svn_upstream[@]} )); then
            svn_upstream=${svn_upstream[ ${#svn_upstream[@]} - 2 ]}
            svn_upstream=${svn_upstream%@*}
            local n_stop="${#svn_remote[@]}"
            local n
            for ((n=1; n <= n_stop; n++)); do
                svn_upstream=${svn_upstream#${svn_remote[$n]}}
            done

            if [ -z "$svn_upstream" ]; then
                # default branch name for checkouts with no layout:
                upstream=${GIT_SVN_ID:-git-svn}
            else
                upstream=${svn_upstream#/}
            fi
        elif [ 'svn+git' = "$upstream" ]; then
            upstream='@{upstream}'
        fi
        ;;
    esac

    __POSH_BRANCH_AHEAD_BY=0
    __POSH_BRANCH_BEHIND_BY=0
    # Find how many commits we are ahead/behind our upstream
    if [ -z "$legacy" ]; then
        IFS=$' \t\n' read -r __POSH_BRANCH_BEHIND_BY __POSH_BRANCH_AHEAD_BY <<< "`git rev-list --count --left-right $upstream...HEAD 2>/dev/null`"
    else
        # produce equivalent output to --count for older versions of git
        while IFS=$' \t\n' read -r commit; do
            case "$commit" in
            "<*") (( __POSH_BRANCH_BEHIND_BY++ )) ;;
            ">*") (( __POSH_BRANCH_AHEAD_BY++ ))  ;;
            esac
        done <<< "`git rev-list --left-right $upstream...HEAD 2>/dev/null`"
    fi
    : ${__POSH_BRANCH_AHEAD_BY:=0}
    : ${__POSH_BRANCH_BEHIND_BY:=0}
}
