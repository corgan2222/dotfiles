# -*- mode: sh -*-
# shellcheck disable=SC1090,SC2039
#
# Utility functions for development.

#from https://github.com/albertodonato/bash.d/blob/master/lib/devel.sh 

# Delete files ending with a tilde in specified tree (by default the current
# directory).
deltilde() {
    find "$@" -name \*~ -exec rm {} \;
}

# Delete .pyc files in specified tree (by default the current directory).
delpyc() {
    find "$@" -type d -name __pycache__ -print0 | xargs --null rm -rf
    find "$@" -name \*.pyc -exec rm {} \;
}

# Activate a python virtualenv. List available ones if no name is specified.
ve() {
    local name="$1"

    local dir="$HOME/virtualenv"
    local activate="$dir/$name/bin/activate"

    if [ -z "$name" ]; then
        echo "Available virtualenv:"
        find "$dir" -mindepth 1 -maxdepth 1 | sed 's,.*/, ,' | sort
        return
    fi

    if [ ! -f "$activate" ]; then
        echo "Virtualenv not found" >&2
        return 2
    fi

    prompt_set_flag virtualenv solarized.red "$name" ve
    VIRTUAL_ENV_DISABLE_PROMPT=1 . "$activate"
}

# Create a virtualenv with the specified name (and optionally version).
mkve() {
    local name="$1"
    local version="$2"

    if [ -z "$name" ]; then
        echo "Missing virtualenv name"
        return 1
    fi

    local dir="$HOME/virtualenv/$name"
    local interpreter="python${version}"
    if [ -z "$version" ]; then
        # shellcheck disable=SC2012
        interpreter="$(ls /usr/bin/python?.? | sort -r | head -1)"
    fi

    virtualenv --python="$interpreter" "$dir"
}

# Create a script with the specified name.
shebang() {
    local filename="$1"
    local shebang="/bin/sh"

    if [ -z "$filename" ]; then
        echo "Missing filename"
        return 1
    fi

    shift 1
    [ $# -gt 0 ] && shebang="$*"

    echo -e "#!$shebang\\n" > "$filename"
    chmod +x "$filename"
}
