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
    foreach my $item (@result) {
        print "token: " . $$item[0] . "    ";
        print "word: " .  $$item[1] . "\n";
    }
    push(@tokens, @result);
    
    print(parse(\@tokens, 0, 0));
}

sub lex {
    my $str = $_[0];
    my @tokens = ();
    #Generate all regexps to match tokens.
    my @regexps = (["comment", qr/(^#[^\n]*\n)/s],
                   ["string", qr/(^("(\\.|[^\\"])*"|'[^']*'))/s],
                   ["num", qr/(^([0-9]+(\.[0-9]+)?|[0-9]*\.[0-9]+))/s],
                   ["keyWord", getKeyWords()],
                   ["builtin", getBuiltins()],
                   ["diamond", qr/^(<[A-Z]*>)/],
                   ["range", qr/^(\.\.)/],
                   ["post", qr/^(((\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)(\+\+|--))/],
                   ["pre", qr/^((\+\+|--)(\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)/],
                   ["array", qr/^(\$[a-zA-Z_][a-zA-Z0-9_]*\[[^\]]*\])/],
                   ["hash", qr/^(\$[a-zA-Z_][a-zA-Z0-9_]*\{[^\}]*\})/],
                   ["variable", qr/(^(\$|@|%|&)([a-z]|_|[A-Z])([a-z]|_|[0-9]|[A-Z])*)/s],
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
    return qr/(^(if|while|foreach|for|elsif|else|last|next))/s;
}

sub getBuiltins {
    return qr/^(print|chomp|split|join)/s;
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

        if (@$tokens >= 2 and $$tokens[1][0] eq "range" 
        and $$tokens[0][1] ne ")") {
            $str = $str . parseRange(${shift(@$tokens)}[1], $tokens);
        } elsif ($$tokens[0][0] eq "comment") {
            $str = $str . $$tokens[0][1]; 
            shift(@$tokens);
        } elsif ($$tokens[0][0] eq "variable") {
            $$tokens[0][1] =~ s/^(.)//;
            $str = $str . $$tokens[0][1];
            shift(@$tokens);
        } elsif ($$tokens[0][0] =~ /^(array|hash)$/) {
            $str = $str . parseIndex($$tokens[0][1]);
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
        } elsif ($$tokens[0][0] eq "diamond") {
            $str = $str . parseDiamond(${shift(@$tokens)}[1]);
        } elsif ($$tokens[0][0] eq "pre") {
            #TODO fill this out. 
        } elsif ($$tokens[0][0] eq "operator") {
            $str = $str . " " . parseOperator($$tokens[0][1]) . " ";
            $str =~ s/\n (not|~) $/\nnot /;
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
                $temp = "(";
                $temp = $temp . parse($tokens, $indentLevel, $readLine);
                if (@$tokens and $$tokens[0][0] eq "range") {
                    $str = $str . parseRange($temp, $tokens);
                } else {
                    $str = $str . $temp;
                }
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
        $str = "for " . ${shift(@$tokenRef)}[1] . "in ";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, $indentLevel + 4, 0);
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

    if ($$tokenRef[0][1] eq "(") {
        $str = $str . ${shift(@$tokenRef)}[1];
        $str = $str . parse($tokenRef, 0, 0);
    } else {
        $str = $str . ${shift(@$tokenRef)}[1];
    }
    
    $str = $str . ")";
    return $str;
}

sub parseIndex {
    my $index = $_[0];
    my $str = "";
    my @tokens = (); 
    
    if ($index =~ /^\$ARGV\[/) {
        $str = "sys.argv[";
        $index =~ s/^\$ARGV\[//;
        $index =~ s/\]$//;
        @tokens = lex($index);
        $str = $str . parse(\@tokens, 0, 0) . " + 1]";

    } else {
        $index =~ s/^\$([^\[\{]*)(\[|\{)//;
        $str = $1 . "[";     
        $index =~ s/(\]|\})$//;
        print $index . "\n\n\n";
        @tokens = lex($index);
        $str = $str . parse(\@tokens, 0, 0) . "]";

    }

    return $str;
}

sub parseDiamond {
    my $diamond = $_[0];
    my $str = "";

    if ($diamond =~ /<STDIN>/) {
        $str = "sys.stdin.readline()";
    }
}

#-----------------------------------------------------------------#
#------------------------builtin functions------------------------#
#-----------------------------------------------------------------#
sub parseBuiltin {
    my $tokenRef = $_[0];
    my $str = "";
    my $temp;
    #TODO print to file
    if ($$tokenRef[0][1] eq "print") {
        $str = parsePrint($tokenRef);
    } elsif ($$tokenRef[0][1] eq "chomp") {
        $str = parseChomp($tokenRef);
    } elsif ($$tokenRef[0][1] eq "join") {
        $str = parseJoin($tokenRef);
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


sub parsePrint {
    my $tokenRef = $_[0];
    my $str = "print";
    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
    }
    $str = $str . " " . parse($tokenRef, 0, 1);

    $str =~ s/(\)?)$/,/;
    $str =~ s/(,\s*"\n",\s*)$//;
    $str =~ s/\\n",$/"/;
    $str =~ s/\s*\+?\s+""//;

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
    $str = $str . ".strip()";

    return $str;
}

sub parseJoin {
    my $tokenRef = $_[0];
    my $str = "";

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

    return $str;
}

#-----------------------------------------------------------------#

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

sub findNext {
    (my $char, my $tokenRef) = @_;
    my @tokens = ();
    
    while ($$tokenRef[0][1] ne $char) {
        push(@tokens, shift(@$tokenRef));
    }

    return @tokens;
}

sub findMatching {
    (my $char, my $tokenRef) = @_;
    my @tokens = ();
    my %matches = ("(" => ")",
                   "{" => "}");    

    while ($$tokenRef[0][1] ne $matches{$char}) {
        if ($$tokenRef[0][1] eq $char) {
            push(@tokens, shift(@$tokenRef));
            push(@tokens, findMatching($char, $tokenRef));
            push(@tokens, shift(@$tokenRef));
        } else {
            push(@tokens, shift(@$tokenRef));
        }
    }

    return @tokens;
}

main();
