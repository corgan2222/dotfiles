perl -0777 -ne '
    while (/^((?:[ \t]*\#.*\n)*)               # preceding comments
             [ \t]*(?:(\w+)[ \t]*\(\)|         # foo ()
                      function[ \t]+(\w+).*)   # function foo
             ((?:\n[ \t]+\#.*)*)               # following comments
           /mgx) {
        $name = "$2$3";
        $comments = "$1$4";
        $comments =~ s/^[ \t]*#+/#/mg;
        chomp($comments);
        print "$name\n$comments\n";
    }' .dot/.bash_functions.sh