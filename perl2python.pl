#!/usr/bin/perl

# written by karlk@cse.unsw.edu.au September 2013
# for a COMP2041 assignment 
# http://cgi.cse.unsw.edu.au/~cs2041/13s2/assignments/perl2python

use warnings;
use strict;

sub main {
    my @tokens = ();

    while (my $line = <>) {
        if ($line =~ /^#!/ and $. == 1) {
            print("#!/usr/bin/python2.7 -u\n");
        } else {
            my @result = lex($line);
            foreach my $item (@result) {
                print "token: " . $$item[0] . "    ";
                print "word: " .  $$item[1] . "\n";
            }
            push(@tokens, @result);
        }

        if ($. == 1) {
            print("import sys\n");
        }
    }
    
    print(parse(\@tokens, 0, 0));
}

sub lex {
    my $str = $_[0];
    my @tokens = ();
    #Generate all regexps to match tokens.
    my @regexps = (["comment", qr/(^#[^\n]*\n)/s],
                   ["string", qr/(^("(\\.|[^\\"])*"|'[^']*'))/s],
                   ["num", qr/(^[0-9]+(\.[0-9]+)?)/s],
                   ["keyWord", getKeyWords()],
                   ["builtin", getBuiltins()],
                   ["diamond", qr/^(<[A-Z]*>)/],
                   ["range", qr/^(\.\.)/],
                   ["post", qr/^(((\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)(\+\+|--))/],
                   ["pre", qr/^((\+\+|--)(\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)/],
                   ["variable", qr/(^(\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)/s],
                   ["semiColon", qr/^(;)/s],
                   ["comma", qr/^(,)/s],
                   ["leftParen", qr/^([{(])/s],
                   ["rightParen", qr/^([})])/s],
                   ["operator", getOperators()],
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
    return qr/(^(if|while|foreach|for|elsif|else|last|next|in))/s;
}

sub getBuiltins {
    return qr/^(print|chomp|split|join)/s;
}

sub getOperators {
    #TODO FIX ORDERING
    return qr/(^(<=|>=|<<|>>|<|>|!=|==|\|\||&&|!|and|or|not|\||\^|&|~|\+|-|\/|%|\*\*|\*))/s;
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

        if ($$tokens[0][0] eq "comment") {
            $str = $str . $$tokens[0][1]; 
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "variable") {
            $$tokens[0][1] =~ s/^(.)//;
            $str = $str . $$tokens[0][1];
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "post") {
            $$tokens[0][1] =~ /(.)$/;
            $operator = $1;
            $$tokens[0][1] =~ s/^.(.*)(\+\+|--)/$1/;
            $temp = $$tokens[0][1];
            shift(@$tokens);
            $str = $str . $temp;
            $str = $str . parse($tokens, 0, 1) . "\n";
            $str = $str . $temp . $operator . "= 1";
        } elsif ($$token[0][0] eq "diamond") {
            parseDiamond(shift(@$tokens));
        } elsif ($$tokens[0][0] eq "pre") {
            #TODO fill this out. 
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "operator") {
            $str = $str . " " . $$tokens[0][1] . " ";
            shift(@$tokens);
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
                shift(@$tokens);
                $str = $str . "(";
                $str = $str . parse($tokens, $indentLevel, $readLine);
            }
        } elsif ($$tokens[0][0] eq "rightParen") {
            if ($$tokens[0][1] eq "}") {
                $str = $str . "\n";
            } elsif ($$tokens[0][1] eq ")") {
                $str = $str . ")";
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

sub parseKeyword {
    (my $tokenRef, my $indentLevel) = @_;
    my $str = "";
    my $readLine;
    my $temp;

    if ($$tokenRef[0][1] eq "if" or $$tokenRef[0][1] eq "while") {
        $str = $str . ${shift(@$tokenRef)}[1] . " ";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\)$//;
        $str = $str . ":\n";
        if (@$tokenRef and $$tokenRef[0][1] eq "{") {
            $readLine = 0;
            shift(@$tokenRef);
        } else {
            $readLine = 1;
        }
        $str = $str . parse($tokenRef, $indentLevel + 4, $readLine);            
    } elsif ($$tokenRef[0][1] eq "for") {
        shift(@$tokenRef);
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, $indentLevel, 1) . "\n";
        shift(@$tokenRef);
        $str = $str . "while " . parse($tokenRef, 0, 1) . ":\n";
        shift(@$tokenRef);
        $temp = parse($tokenRef, $indentLevel + 4, 0);
        $temp = "\n" . $temp;
        $temp =~ s/\)$/\n/;
        if (@$tokenRef and $$tokenRef[0][1] eq "{") {
            $readLine = 0;
            shift(@$tokenRef);
        } else {
            $readLine = 1;
        }

        $str = $str . parse($tokenRef, $indentLevel + 4, $readLine);
        $str =~ s/\s*$//;
        $str = $str . $temp;
    } elsif ($$tokenRef[0][1] eq "foreach") {
        $str = "for ";
        shift(@$tokenRef);
        $$tokenRef[0][1] =~ s/^.//;
        $str = $str . $$tokenRef[0][1] . " in ";
        shift(@$tokenRef);
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\)$//;
        $str = $str . ":\n";
        if ($$tokenRef[0][1] eq "{") {
            $readLine = 0;
            shift(@$tokenRef);
        } else {
            $readLine = 1;
        }
        $str = $str . parse($tokenRef, $indentLevel + 4, $readLine);
    } elsif ($$tokenRef[0][1] eq "next") {
        $str = "continue";
        shift(@$tokenRef);
    } elsif ($$tokenRef[0][1] eq "last") {
        $str = "break";
        shift(@$tokenRef);
    } else {
        $str = "#" . $$tokenRef[0][1];
        shift(@$tokenRef);
    }

    return $str; 
}

sub parseBuiltin {
    my $tokenRef = $_[0];
    my $str = "";
    my $temp;
    #TODO print to file
    if ($$tokenRef[0][1] eq "print") {
        $str = "print";
        shift(@$tokenRef);
        if ($$tokenRef[0][1] eq "(") {
            $str = $str . "(";
            shift(@$tokenRef);
            $str = $str . parse($tokenRef, 0, 1);
        }
        $str =~ s/(\)?)$/,$1/;
        $str =~ s/\\n",(\)?)$/"$1/;
        $str =~ s/\s*\+?\s*""//;
    } elsif ($$tokenRef[0][1] eq "chomp") {
        shift(@$tokenRef);
        if ($$tokenRef[0][0] eq "leftParen") {
            shift(@$tokenRef);
            $str = $str . parse($tokenRef, 0, 1);
            $str =~ s/\)$//;
        } else {
            $str = $str . parse($tokenRef, 0, 1);
        }
        $str = $str . ".strip()";
    } elsif ($$tokenRef[0][1] eq "join") {
        shift(@$tokenRef);
        if ($$tokenRef[0][0] eq "leftParen") {
            shift(@$tokenRef);
            $str = $$tokenRef[0][1] . ".join(";
            shift(@$tokenRef);
            shift(@$tokenRef);
            $str = $str . parse($tokenRef, 0, 1);
        } else {
            $str = $$tokenRef[0][1] . ".join(";
            shift(@$tokenRef);
            shift(@$tokenRef);
            $str = $str . parse($tokenRef, 0, 1) . ")";
        }
    #} elsif ($$tokenRef[0][1] eq "split") {
    #    shift(@$tokenRef);
    #    if () {
    #
    #    }
    } else {
        $str = $str . " ";
        $str = $str . parse($tokenRef, 0, 1);
    }

    return $str;
}

sub parseStr {
    my $str = $_[0];
    $str =~ s/\n/\\n/g;
    if (not ($str =~ /\$'[^']*'^/)) {
        #TODO FIX THE HACK
        $str =~ s/\\\\/unlikelyword123/g;
        $str =~ s/([^\\])\$(([a-z]|[A-Z]|[0-9]|_)+)/$1" \+ str($2) \+ "/g;
        $str =~ s/([^\\])\$\{(([a-z]|[A-Z]|[0-9]|_)+)\}/$1" \+ str($2) \+ "/g;
        $str =~ s/unlikelyword123/\\\\/g;
        $str =~ s/\+\s*""\s*\+/ \+ /g;
        $str =~ s/""\s*\+\s*//g;
        $str =~ s/\s*\+""\s*//g;
    }

    return $str;
}

main();
