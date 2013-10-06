#!/usr/bin/perl

# written by karlk@cse.unsw.edu.au September 2013
# for a COMP2041 assignment 
# http://cgi.cse.unsw.edu.au/~cs2041/13s2/assignments/perl2python

use warnings;
use strict;

sub main {
    my @tokens = ();
    my $program = "";

    while (my $line = <>) {
        if ($line =~ /^#!/ and $. == 1) {
            print("#!/usr/bin/python2.7 -u\n");
        } else {
            $program .= $line; 
        }

        if ($. == 1) {
            print("import sys\n");
        }
    }

    my @result = lex($program);
#    foreach my $item (@result) {
#        print "token: " . $$item[0] . "    ";
#        print "word: " .  $$item[1] . "\n";
#    }
    push(@tokens, @result);
    
    print(parse(\@tokens, 0, 0));
}

sub lex {
    my $str = $_[0];
    my @tokens = ();
    #Generate all regexps to match tokens.
    my @regexps = (["comment", qr/(^#[^\n]*\n)/s],
                   ["string", qr/(^("(\\.|[^\\"])*"|'[^']*'))/s],
                   ["regex", qr/^=~\s*((m?\/(\\.|[^\\\/])*\/|s\/(\\.|[^\\\/])*\/(\\.|[^\\\/])*\/)[a-z])/s],
                   ["num", qr/(^([0-9]+(\.[0-9]+)?|[0-9]*\.[0-9]+))/s],
                   ["keyWord", getKeyWords()],
                   ["builtin", getBuiltins()],
                   ["diamond", qr/^(<[A-Z]*>)/],
                   ["range", qr/^(\.\.)/],
                   ["post", qr/^(((\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)(\+\+|--))/],
                   ["pre", qr/^((\+\+|--)(\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)/],
                   ["concat", qr/^(\.=|\.)/],
                   ["arrLen", qr/^(\$#[a-zA-Z_][a-zA-Z0-9_]*)/],
                   ["array", qr/^(\$[a-zA-Z_][a-zA-Z0-9_]*\[)/],
                   ["hash", qr/^(\$[a-zA-Z_][a-zA-Z0-9_]*\{[^\}]*\})/],
                   ["operator", getOperators()],
                   ["variable", qr/(^(\$|@|%|&)?([a-z]|_|[A-Z])([a-z]|_|[0-9]|[A-Z])*)/s],
                   ["semiColon", qr/^(;)/s],
                   ["comma", qr/^(,)/s],
                   ["leftParen", qr/^([\{\(])/s],
                   ["rightParen", qr/^([\}\)\]])/s],
                   ["assignment", qr/^(=)/s],
                   ["error", qr/^([^\n]\n?)/s]);

    while (not ($str eq "")) {
        my @result = ();
        $str =~ s/^\s*//s;

        for (my $i = 0; $i < @regexps; $i++) {
            if ($str =~ /$regexps[$i][1]/) {
                $result[0] = $regexps[$i][0];
                $result[1] = $1;
                $str =~ s/$regexps[$i][1]//;
                push(@tokens, \@result);
                last;
            }   
        }

    }

    return @tokens;
}

sub getKeyWords {
    return qr/(^(if|while|foreach|for|elsif|else|last|next))/s;
}

sub getBuiltins {
    return qr/^(printf|print|chomp|split|join)/s;
}

sub getOperators {
    #TODO FIX ORDERING
    return qr/(^(ne|eq|<=|>=|<<|>>|<|>|!=|==|\|\||&&|!|and|or|not|\||\^|&|~|\+|-|\/|%|\*\*|\*))/s;
}

sub parse {
    (my $tokens, my $indentLevel, my $readLine) = @_;
    my $str = "";
    my $temp;
    my $operator;

    while (@$tokens) {
        if ($str eq "" or $str =~ /\n$/) {
            $str = $str . " " x $indentLevel;
        }

        if (@$tokens >= 2 and $$tokens[0][1] ne ")") {
            if ($$tokens[1][0] eq "range") { 
                $str = $str . parseRange(${shift(@$tokens)}[1], $tokens);
                next;
            } elsif ($$tokens[1][0] eq "concat") {
                $str = $str . parseConcat(${shift(@$tokens)}[1], $tokens);
                next;
            } elsif ($$tokens[1][0] eq "regex") {
                $str = $str . parseRegex(${shift(@$tokens)}[1], $$tokens[0][1]);
                shift(@$tokens);
                next;
            }
        } 
        
        if ($$tokens[0][0] eq "comment") {
            $str = $str . $$tokens[0][1]; 
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "arrLen") {
            $str = $str . parseArrLen($$tokens[0][1]);
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "variable") {
            $str = $str . parseVariable($$tokens[0][1]);
            shift(@$tokens);
        } elsif ($$tokens[0][0] =~ /^(array|hash)$/) {
            $str = $str . parseIndex($tokens);
        } elsif ($$tokens[0][0] =~ /(post|pre)/) {
            $$tokens[0][1] =~ s/\$([A-Za-z_][A-Za-z_0-9]*)//;
            $str = $str . $1;
            $$tokens[0][1] =~ /(\+|-)/;
            $str = $str . " " . $1 . "= 1";
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "diamond") {
            $str = $str . parseDiamond(${shift(@$tokens)}[1]);
        } elsif ($$tokens[0][0] eq "operator") {
            $str = $str . " " . parseOperator($$tokens[0][1]);
            shift(@$tokens);
            if (@$tokens and $$tokens[0][1] eq "=") {
                $str = $str . ${shift(@$tokens)}[1];
            }
            $str = $str . " ";
            $str =~ s/\n (not|~) $/\n$1 /;
        } elsif ($$tokens[0][0] eq "comma") {
            $str = $str . ", ";
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "assignment") {
            $str = $str . " = ";
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "string") {
            $str = $str . parseStr($$tokens[0][1]);
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "num") {
            $str = $str . $$tokens[0][1];
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "builtin") {
            $str = $str . parseBuiltin($tokens, $indentLevel);
        } elsif ($$tokens[0][0] eq "keyWord") {
            $str = $str . parseKeyword($tokens, $indentLevel);
        } elsif ($$tokens[0][0] eq "semiColon") {
            if ($readLine) {
                last;
            } else {
                $str = $str . "\n";
                shift(@$tokens);
            }
        } elsif ($$tokens[0][0] eq "leftParen") {
            if ($$tokens[0][1] eq "{") {
                shift(@$tokens);
                $str = $str . parse($tokens, $indentLevel + 4, 0);
            } else {
                $temp = ${shift(@$tokens)}[1];
                $temp = $temp . parse($tokens, $indentLevel, $readLine);
                if (@$tokens and $$tokens[0][0] eq "range") {
                    $str = $str . parseRange($temp, $tokens);
                } elsif(@$tokens and $$tokens[0][0] eq "concat") {
                    $str = $str . parseRange($temp, $tokens);
                } elsif (@$tokens and $$tokens[0][0] eq "regex") { 
                    $str = $str . parseRegex($temp, $tokens);  
                } else {
                    $str = $str . $temp;
                }
            }
        } elsif ($$tokens[0][0] eq "rightParen") {
            if ($$tokens[0][1] eq "}") {
                $str = $str . "\n";
            } elsif ($$tokens[0][1] =~ /([\)\]])/) {
                $str = $str . $1;
            }
            shift(@$tokens);
            last;
        } elsif ($$tokens[0][0] eq "error") {
            $str = $str . "#";
            while (@$tokens and not ($$tokens[0][1] =~ /[;\n}\)]/)) {
                $str = $str . $$tokens[0][1];
                shift(@$tokens);
            }
        } else {
            shift(@$tokens);
        }

    }
    return $str;
}


#-----------------------------------------------------------------#
#----------------------------Keywords-----------------------------#
#-----------------------------------------------------------------#
sub parseKeyword {
    (my $tokenRef, my $indentLevel) = @_;
    my $str = "";
    my $readLine;
    my $temp;

    if ($$tokenRef[0][1] =~ /^(if|elsif|else)$/) {
        $str = parseIfs($tokenRef, $indentLevel);
    } elsif ($$tokenRef[0][1] eq "while") {
        $str = parseWhile($tokenRef, $indentLevel);
    } elsif ($$tokenRef[0][1] =~ /^for/) {
        $str = parseFor($tokenRef, $indentLevel); 
    } elsif ($$tokenRef[0][1] eq "next") {
        $str = "continue";
        shift(@$tokenRef);
    } elsif ($$tokenRef[0][1] eq "last") {
        $str = "break";
        shift(@$tokenRef);
    } else {
        shift(@$tokenRef);
    }

    return $str; 
}

sub parseIfs {
    (my $tokenRef, my $indentLevel) = @_;

    #shift the keyword (if/elsif/else)
    my $str = ${shift(@$tokenRef)}[1] . " ";
    $str =~ s/elsif/elif/;    

    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\)$//;
    }

    $str = $str . ":\n";
    #now parse the body.
    shift(@$tokenRef);
    $str = $str . parse($tokenRef, $indentLevel + 4, 0);
    
    return $str;
}

sub parseWhile {
    (my $tokenRef, my $indentLevel) = @_;

    #shift the while
    my $str = ${shift(@$tokenRef)}[1] . " ";
   
    #shift the left paren 
    shift(@$tokenRef);
    #parse the conditional and replace the right paren
    $str = $str . parse($tokenRef, 0, 0);
    $str =~ s/\)$/:\n/;
    $str =~ s/^while\s*:\n$/while True:\n/;

    #parse the body
    shift(@$tokenRef);
    $str = $str . parse($tokenRef, $indentLevel + 4, 0); 

    return $str;           
}

sub parseFor {
    (my $tokenRef, my $indentLevel) = @_;
   
    my $str;
    my $temp = "";
    shift(@$tokenRef);
    if ($$tokenRef[0][0] eq "variable") {
        $$tokenRef[0][1] =~ s/^.//;
        $str = "for " . ${shift(@$tokenRef)}[1] . " in ";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\)$//;
    } else {
        shift(@$tokenRef);
        $str = parse($tokenRef, 0, 1) . "\n";
        shift(@$tokenRef);
        $temp = parse($tokenRef, 0, 1);
        $temp =~ s/^$/True/;
        shift(@$tokenRef);
        $str = $str . "while " . $temp;
        $temp = parse($tokenRef, $indentLevel + 4, 0) . "\n";
        $temp =~ s/\)$//;
        $temp =~ s/^\n$//;
    }

    shift(@$tokenRef);
    $str = $str . ":\n";
    $str = $str . parse($tokenRef, $indentLevel + 4, 0);
    $str = $str . $temp;

    return $str;
}

#-----------------------------------------------------------------#

sub parseRange {
    my $range1 = $_[0];
    my $tokenRef = $_[1];
    my $str = "xrange(" . $range1 . ", ";
    shift(@$tokenRef);

    $range1 =~ s/^\$//;
    if ($$tokenRef[0][1] eq "(") {
        $str = $str . ${shift(@$tokenRef)}[1];
        $str = $str . parse($tokenRef, 0, 0);
    } else {
        $str = $str . ${shift(@$tokenRef)}[1];
    }
    
    $str = $str . " + 1)";
    return $str;
}

sub parseConcat {
    (my $prevStr, my $tokenRef) = @_;
    my $str = "";

    $$tokenRef[0][1] =~ s/\./\+/;
    if ($$tokenRef[0][1] eq "+") {
        $prevStr = "str(" . $prevStr . ")"
    }

    $str = $prevStr . " " . ${shift(@$tokenRef)}[1] . " str(";
    if ($$tokenRef[0][0] eq "leftParen") {
        $str = $str . parse($tokenRef, 0, 0) . ")";
    } else {
        $str = $str . ${shift(@$tokenRef)}[1] . ")"
    }

    return $str;
}

sub parseVariable {
    my $var = $_[0];
    my $str = "";
    if ($var eq '@ARGV') {
        $str = "sys.argv[1:]";
    } else {
        $var =~ s/^(\$|%|&|@)//;
        $str = $var;
    }

    return $str;
}

sub parseIndex {
    my $tokenRef = $_[0];
    my $str = "";
    
    if ($$tokenRef[0][1] =~ /^\$ARGV\[/) {
        shift(@$tokenRef);
        $str = "sys.argv[";
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\]$//;
        $str = $str . " + 1]";
    } else {
        $$tokenRef[0][1] =~ s/^\$([^\[\{]*)(\[|\{)//;
        $str = $1 . "[";
        shift(@$tokenRef);     
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\n$/\]/;
    }

    return $str;
}

sub parseDiamond {
    my $diamond = $_[0];
    my $str = "";

    if ($diamond =~ /<STDIN>/) {
        $str = "sys.stdin.readline()";
    } elsif ($diamond eq "<>") {
        $str = "fileinput.input()"
    }
}

#-----------------------------------------------------------------#
#------------------------builtin functions------------------------#
#-----------------------------------------------------------------#
sub parseBuiltin {
    my $tokenRef = $_[0];
    my $str = "";

    if ($$tokenRef[0][1] eq "print") {
        $str = parsePrint($tokenRef);
    } elsif ($$tokenRef[0][1] eq "printf") {
        $str = parsePrintf($tokenRef);
    } elsif ($$tokenRef[0][1] eq "chomp") {
        $str = parseChomp($tokenRef);
    } elsif ($$tokenRef[0][1] eq "join") {
        $str = parseJoin($tokenRef);
    } elsif ($$tokenRef[0][1] eq "split") {
        $str = parseSplit($tokenRef);
    } else {
        $str = $str . " ";
        $str = $str . parse($tokenRef, 0, 1);
    }

    return $str;
}

sub parsePrintf {
    my $tokenRef = $_[0];
    my $str = "sys.stdout.write(";
    my @tokens = ();

    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        @tokens = findNext($tokenRef, ",");
        $str = $str . parse(\@tokens, 0, 0) . " % (";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 0) . ")";
    } else {
        @tokens = findNext($tokenRef, ",");
        $str = $str . parse(\@tokens, 0, 0) . " % (";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 0) . "))";
    }

    return $str;
}

sub parsePrint {
    my $tokenRef = $_[0];
    my $str = "print";
    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
    }
    $str = $str . " " . parse($tokenRef, 0, 1);

    $str =~ s/\\\\/unlikelyword123/g;
    $str =~ s/(\)?)$/,/;
    $str =~ s/(,\s*"\\n",\s*)$//;
    $str =~ s/\\n",$/"/;
    $str =~ s/\s*\+?\s+""//;
    $str =~ s/unlikelyword123/\\\\/g;
    return $str;
}

sub parseChomp {
    my $tokenRef = $_[0];
    my $str = "";

    shift(@$tokenRef);
    if ($$tokenRef[0][0] eq "leftParen") {
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 1);
        $str =~ s/\)$//;
    } else {
        $str = $str . parse($tokenRef, 0, 1);
    }
    $str = $str . " = (" . $str . ")" . ".strip()";

    return $str;
}

sub parseSplit {
    my $tokenRef = $_[0];
    my $str = "";
    my @temp = ();    
    shift(@$tokenRef);
    if ($$tokenRef[0][0] eq "leftParen") {
        shift(@$tokenRef);
        @temp = findNext($tokenRef, ","); 
        shift(@$tokenRef);
        $str = "(" . parse($tokenRef, 0, 0);
        $str = $str . ".split(" . parse(\@temp, 0, 0) . ")";
    } else {
        @temp = findNext($tokenRef, ",");
        shift(@$tokenRef);
        $str = "(" . parse($tokenRef, 0, 0) . ")";
        $str = $str . ".split(" . parse(\@temp, 0, 0) . ")";
    }

    return $str;
}

sub parseJoin {
    my $tokenRef = $_[0];
    my $str = "";
    my @temp;

    shift(@$tokenRef);
    if ($$tokenRef[0][0] eq "leftParen") {
        shift(@$tokenRef);
        @temp = findNext($tokenRef, ",");
        $str = "(" . parse(\@temp, 0, 0) . ")" . ".join(";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 1);
    } else {
        @temp = findNext($tokenRef, ",");
        $str = "(" . parse(\@temp, 0, 0) . ")" . ".join(";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 1) . ")";
    }

    return $str;
}

#-----------------------------------------------------------------#

sub parseArrLen {
    my $var = $_[0];
    my $str;

    if ($var eq "\$#ARGV") {
        $str = "(len(sys.argv) - 2)";
    } else {
        $var =~ s/^\$#//;
        $str = "(len($var) - 1)";
    }

    return $str;
}

sub parseOperator {
    my $operator = $_[0];
    my $str = "";

    if ($operator eq "eq") {
        $str = "==";
    } elsif ($operator eq "ne") {
        $str = "!=";
    } elsif ($operator eq "||") {
        $str = "or";
    } elsif ($operator eq "&&") {
        $str = "and";
    } elsif ($operator eq "!") {
        $str = "not";
    } else {
        $str = $operator;
    }

    return $str;
}

sub parseRegex {
    (my $val, my $regex) = @_;
    my $str = "";
    my $options;

    $regex =~ s/\/([a-z]*)$/\//;    
    $options = $1;
    
    if ($regex =~ s/^s//) {
        $regex =~ /^\/(.*)\/(.*)\/$/;
        $str = $val . " = " . "re.sub('$1', '$2', $val)";
    } elsif ($regex =~ s/^m?//) {
        $regex =~ /^\/(.*)\/$/;
        $str = "re.match('$1', $val)";
    }

    return $str;
}

sub findNext {
    my $tokenRef = $_[0];
    my $key = $_[1];
    my @arr = ();

    while ($$tokenRef[0][1] ne $key) {
        push(@arr, shift(@$tokenRef));
    }

    return @arr;
}

sub parseStr {
    my $str = $_[0];
    $str =~ s/\n/\\n/g;
    if (not ($str =~ /\$'[^']*'^/)) {
        #TODO FIX THE HACK
        $str =~ s/\\\\/unlikelyword123/g;
        $str =~ s/([^\\])\$(([a-z]|[A-Z]|[0-9]|_)+)/$1" \+ str($2) \+ "/g;
        $str =~ s/([^\\])\$\{(([a-z]|[A-Z]|[0-9]|_)+)\}/$1" \+ str($2) \+ "/g;
        $str =~ s/([^\\])\@(([a-z]|[A-Z]|[0-9]|_)+)/$1" \+ ' '.join(map(str, $2)) \+ "/g;
        $str =~ s/([^\\])\@\{(([a-z]|[A-Z]|[0-9]|_)+)\}/$1" \+ ' '.join(map(str, $2)) \+ "/g;
        $str =~ s/unlikelyword123/\\\\/g;
        $str =~ s/\+\s*""\s*\+/ \+ /g;
        $str =~ s/""\s*\+\s*//g;
        $str =~ s/\s*\+""\s*//g;
    }

    return $str;
}

main();
