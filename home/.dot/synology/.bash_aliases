echo "syno alias were loaded"

alias py3='python3'
alias py='py3'
alias p3='py3'
alias p='py3'


# ------------------------------------------------------------------------------
# | Navigation                                                                 |
# ------------------------------------------------------------------------------

alias cdknaak='cd /var/www/vhosts/knaak.org/httpdocs'
alias cd_Aptlist='cd /etc/apt/'
alias cd_git="cd $HOME/git"
alias cd_Scripts="cd $HOME/git/scripts"

# ------------------------------------------------------------------------------
# | Apt                                                                        |
# ------------------------------------------------------------------------------

alias ap='apt-get install'
alias aptGetVersion="dpkg -l | grep -i "
alias aptList="dpkg -l"

# ------------------------------------------------------------------------------
# | php                                                                        |
# ------------------------------------------------------------------------------

alias listLoadedPhpInis7="php --ini"
alias listLoadedPhpInis73="php73 --ini"

# tree (with fallback)
if which tree >/dev/null 2>&1; then
  # displays a directory tree
  alias tree="tree -Csu"
  # displays a directory tree - paginated
  alias ltree="tree -Csu | less -R"
else
  alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
  alias ltree="tree | less -R"
fi


# ------------------------------------------------------------------------------
# | auto-completion (for bash)                                                 |
# ------------------------------------------------------------------------------

# Automatically add completion for all aliases to commands having completion functions
# source: http://superuser.com/questions/436314/how-can-i-get-bash-to-perform-tab-completion-for-my-aliases
alias_completion()
{
  local namespace="alias_completion"

  # parse function based completion definitions, where capture group 2 => function and 3 => trigger
  local compl_regex='complete( +[^ ]+)* -F ([^ ]+) ("[^"]+"|[^ ]+)'
  # parse alias definitions, where capture group 1 => trigger, 2 => command, 3 => command arguments
  local alias_regex="alias ([^=]+)='(\"[^\"]+\"|[^ ]+)(( +[^ ]+)*)'"

  # create array of function completion triggers, keeping multi-word triggers together
  eval "local completions=($(complete -p | sed -rne "/$compl_regex/s//'\3'/p"))"
  (( ${#completions[@]} == 0 )) && return 0

  # create temporary file for wrapper functions and completions
  rm -f "/tmp/${namespace}-*.XXXXXXXXXX" # preliminary cleanup
  local tmp_file="$(mktemp "/tmp/${namespace}-${RANDOM}.XXXXXXXXXX")" || return 1

  # read in "<alias> '<aliased command>' '<command args>'" lines from defined aliases
  local line; while read line; do
    eval "local alias_tokens=($line)" 2>/dev/null || continue # some alias arg patterns cause an eval parse error
    local alias_name="${alias_tokens[0]}" alias_cmd="${alias_tokens[1]}" alias_args="${alias_tokens[2]# }"

    # skip aliases to pipes, boolan control structures and other command lists
    # (leveraging that eval errs out if $alias_args contains unquoted shell metacharacters)
    eval "local alias_arg_words=($alias_args)" 2>/dev/null || continue

    # skip alias if there is no completion function triggered by the aliased command
    [[ " ${completions[*]} " =~ " $alias_cmd " ]] || continue
    local new_completion="$(complete -p "$alias_cmd")"

    # create a wrapper inserting the alias arguments if any
    if [[ -n $alias_args ]]; then
     local compl_func="${new_completion/#* -F /}"; compl_func="${compl_func%% *}"
     # avoid recursive call loops by ignoring our own functions
     if [[ "${compl_func#_$namespace::}" == $compl_func ]]; then
       local compl_wrapper="_${namespace}::${alias_name}"
         echo "function $compl_wrapper {
           (( COMP_CWORD += ${#alias_arg_words[@]} ))
           COMP_WORDS=($alias_cmd $alias_args \${COMP_WORDS[@]:1})
           $compl_func
         }" >> "$tmp_file"
         new_completion="${new_completion/ -F $compl_func / -F $compl_wrapper }"
     fi
    fi

    # replace completion trigger by alias
    new_completion="${new_completion% *} $alias_name"
    echo "$new_completion" >> "$tmp_file"
  done < <(alias -p | sed -rne "s/$alias_regex/\1 '\2' '\3'/p")
  source "$tmp_file" && rm -f "$tmp_file"
}
if [ -n "$BASH_VERSION" ]; then
  alias_completion
fi
unset -f alias_completion

[[ -s "/etc/grc.bashrc" ]] && source /etc/grc.bashrc

 # Use GRC for additionnal colorization
  if which grc >/dev/null 2>&1; then
    alias colour="grc -es --colour=auto"
    alias as="colour as"
    alias configure="colour ./configure"
    alias diff="colour diff"
    alias dig="colour dig"
    alias g++="colour g++"
    alias gas="colour gas"
    alias gcc="colour gcc"
    alias head="colour head"
    alias ifconfig="colour ifconfig"
    alias ld="colour ld"
    alias ls="colour ls"
    alias make="colour make"
    alias mount="colour mount"
    alias netstat="colour netstat"
    alias ping="colour ping"
    alias ps="colour ps"
    alias tail="colour tail"
    alias traceroute="colour traceroute"
    alias syslog="sudo colour tail -f -n 100 /var/log/syslog"
  fi