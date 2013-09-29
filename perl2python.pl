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
            print ("#!/usr/bin/python2.7 -u\n");
        } else {
            my @result = lex($line);
            foreach my $item (@result) {
                print "token: " . $item->[0] . "    ";
                print "word: " .  $item->[1] . "\n";
            }
            push(@tokens, @result);
        }
    }

    parse(@tokens);
}

sub lex {
    my $str = $_[0];
    my @tokens = ();
    
    #Generate all regexps to match tokens.
    my $comments = qr/(^#)/s;
    my $strings = qr/(^("(\\.|[^\\"])*"|'[^']*'))/s;
    my $keyWords = getKeyWords();
    my $builtins = getBuiltins();
    my $variables = qr/(^(\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)/s;
    my $whiteSpaces = qr/(^\s+)/s;

    while (not ($str eq "")) {
        my @result = ();  
        if ($str =~ /$comments/) {
            $result[0] = "comment";
            $result[1] = $1;
            $str =~ s/$comments//s;
        } elsif ($str =~ /$strings/) {
            $result[0] = "string";
            $result[1] = $1;
            $str =~ s/$strings//;
        } elsif ($str =~ /$keyWords/) {
            $result[0] = "keyword";
            $result[1] = $1;
            $str =~ s/^$keyWords//;
        } elsif ($str =~ /$builtins/) {
            $result[0] = "builtin";
            $result[1] = $1;
            $str =~ s/$builtins//;
        } elsif ($str =~ /$variables/) {
            $result[0] = "variable";
            $result[1] = $1;
            $str =~ s/$variables//;
        } elsif ($str =~ /$whiteSpaces/) {
            $result[0] = "whiteSpace";
            $result[1] = $1;
            $str =~ s/$whiteSpaces//;
        } else {
            $result[0] = "error";
            $result[1] = $str;
            $str = "";
        }
        push(@tokens, \@result);
    }

    return @tokens;
}

sub parse {
    $tokens = \@_;

    while (@$tokens) {
        print($token->[0][0]);
        if ($token->[0][0]) {
            print("hi\n");
        }
    }
}

sub getKeyWords {
    return qr/(^(if|while|for|foreach|elsif|else|break|continue|in))/s;
}

sub getBuiltins {
    return qr/(^print)/s;
}

main();
