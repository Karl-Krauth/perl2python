#!/usr/bin/perl

# written by karlk@cse.unsw.edu.au September 2013
# for a COMP2041 assignment 
# http://cgi.cse.unsw.edu.au/~cs2041/13s2/assignments/perl2python

sub main() {
    while ($line = <>) {
        if ($line =~ /^#!/ and $. == 1) {
            print ("#!/usr/bin/python2.7 -u\n");
        } elsif ($line =~ /^\s*#/ or $line =~ /^\s*$/) {
            print ($line);
        }
    }
}

sub lexer {
    $_ = 
}

main();
