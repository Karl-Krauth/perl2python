#!/usr/bin/perl

# written by karlk@cse.unsw.edu.au September 2013
# for a COMP2041 assignment 
# http://cgi.cse.unsw.edu.au/~cs2041/13s2/assignments/perl2python

#use warnings;
#use strict;
use Switch;

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
            print("import re, sys, fileinput\n");
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

#Given a string of valid perl returns an array of tokens for that perl code.
sub lex {
    my $str = $_[0];
    my @tokens = ();
    #Generate all regexps to match tokens.
    my @regexps = (["comment", qr/(^#[^\n]*\n)/s],
                   ["string", qr/(^("(\\.|[^\\"])*"|'[^']*'))/s],
                   ["regex", qr/^=~\s*((m?\/(\\.|[^\\\/])*\/|s\/(\\.|[^\\\/])*\/(\\.|[^\\\/])*\/)[a-z]*)/s],
                   ["num", qr/^([0-9]+(\.[0-9]+)?)/s],#|[0-9]*\.[0-9]+))/s],
                   ["keyWord", getKeyWords()],
                   ["builtin", getBuiltins()],
                   ["diamond", qr/^(<[A-Z]*>)/],
                   ["range", qr/^(\.\.)/],
                   ["inc", getInc()],
                   ["pre", qr/^((\+\+|--)(\$|@|%|&)([a-z]|[0-9]|_|[A-Z])+)/],
                   ["concat", qr/^(\.=|\.)/],
                   ["arrLen", qr/^(\$#[a-zA-Z_][a-zA-Z0-9_]*)/],
                   ["array", qr/^(\$[a-zA-Z_][a-zA-Z0-9_]*\[)/],
                   ["hash", qr/^(\$[a-zA-Z_][a-zA-Z0-9_]*\{[^\}]*\})/],
                   ["leftRightOp", qr/^(\|\||&&|and|or|>>|<<|&|\||\^)/],
                   ["arithmetic", qr/^((\||\^\|&|\+|-|\/|\*\*|\*)=?)/],
                   ["stringComp", qr/^(ne|eq|lt|gt)/],
                   ["arithComp", qr/^(<=|>=|!=|==|>|<)/],
                   ["leftOp", qr/^(!|~|not)/],
                   ["mod", qr/^(%=|%)/],
                   ["variable", qr/(^(\$|@|%|&)([a-z]|_|[A-Z])([a-z]|_|[0-9]|[A-Z])*)/s],
                   ["semiColon", qr/^(;)/s],
                   ["comma", qr/^(,)/s],
                   ["assignment", qr/^(=)/s],
                   ["leftParen", qr/^([\{\(])/s],
                   ["rightParen", qr/^([\}\)\]])/s],
                   ["error", qr/^((.))/s]);

    while (not ($str eq "")) {
        my @result = ();
        $str =~ s/^\s*//s;

        for (my $i = 0; $i < @regexps; $i++) {
            #if we match add token to token list, remo from str and keep going.
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

sub getInc {
    return qr/^((\+\+|--)\$[A-Za-z_][A-Za-z0-9_]*|\$[A-Za-z_][A-Za-z0-9_]*(\+\+|--))/s;
}
sub getKeyWords {
    return qr/(^(if|while|foreach|for|elsif|else|last|next))/s;
}

sub getBuiltins {
    return qr/^(printf|print|chomp|split|join|push|pop|reverse|shift|unshift)/s;
}

#General parse fuction, given a list of valid tokens will
#transform it into python code. Will terminate when there are no
#more tokens to parse or when there is a non matching right bracket.
#if readLin = 1 returns when it reaches a semicolon too.
sub parse {
    (my $tokens, my $indentLevel, my $readLine) = @_;
    my $str = "";
    my $temp;
    my $operator;
    my $break = 0;

    while (scalar @$tokens) {
        $temp = "";

        #print indenting.
        if ($str eq "" or $str =~ /\n$/) {
            $str = $str . " " x $indentLevel;
        }

        switch ($$tokens[0][0]) {
            case "comment"    {$temp = shiftVal($tokens)}    
            case "arrLen"     {$temp = parseArrLen(shiftVal($tokens))}
            case "variable"   {$temp = parseVariable(shiftVal($tokens))}
            case "array"      {$temp = parseIndex($tokens)}
            case "hash"       {$temp = parseIndex($tokens)}
            case "inc"        {$temp = parseInc(shiftVal($tokens))}
            case "diamond"    {$temp = parseDiamond(shiftVal($tokens))}
            case "comma"      {$temp = shiftVal($tokens) . " "}
            case "string"     {$temp = parseStr(shiftVal($tokens))}
            case "num"        {$temp = shiftVal($tokens)}
            case "builtin"    {$temp = parseBuiltin($tokens, $indentLevel)}
            case "keyWord"    {$temp = parseKeyword($tokens, $indentLevel)}
            case "leftOp"     {$temp = parseOperator(shiftVal($tokens)) . " "}
            case "leftParen"  {$temp = parseLeftParen($tokens, $indentLevel)}
            case "error"      {$temp = errorRecovery($tokens)}
            case "rightParen" {$str .= parseRightParen(shiftVal($tokens), $indentLevel);
                               $break = 1}
            case "semiColon"  {if ($readLine) {$break = 1}
                               else {$temp = "\n"; shift(@$tokens)}}
        }

        last if $break;
        if (not defined $$tokens[0][0]) {
            shift(@$tokens);
        }

        if (scalar @$tokens) {
            $str = $str . lookAhead($temp, $tokens);
        } else {
            $str = $str . $temp;
        }
    }
    
    return $str;
}

#tries to handle error tokens graciously
sub errorRecovery {
    my $tokenRef = $_[0];
    my $str = "#" . shiftVal($tokenRef);
    while (scalar @$tokenRef and not $$tokenRef[0][0] =~ /(Paren|semiColon)/) {
        $str = $str . shiftVal($tokenRef);
    }
    
    return $str;
}

sub shiftVal {
    my $tokenRef = $_[0];
    return ${shift(@$tokenRef)}[1];
}

#parses simple use of pre and post increment
sub parseInc {
    my $inc = $_[0];
    my $val;    
    my $operator;    

    $inc =~ s/\$([A-Za-z0-9_][A-Za-z0-9_]*)//;
    $val = $1;
    $inc =~ /(\+|-)/; 
    $operator = $1;
    return $val . " " . $operator . "= 1";
}

sub parseLeftParen {
    (my $tokenRef, my $indentLevel) = @_;
    my $str = "";

    if ($$tokenRef[0][1] eq "{") {
        shift(@$tokenRef);
        $str = parse($tokenRef, $indentLevel + 4, 0);
    } else {
        $str = shiftVal($tokenRef);
        $str = $str . parse($tokenRef, 0, 0);
    }

    return $str;    
}

sub parseRightParen {
    my $paren = $_[0];
    my $str;

    if ($paren eq "}") {
        $str = "\n";
    } else {
        $str = $paren;
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
    my $str = shiftVal($tokenRef) . " ";
    $str =~ s/elsif/elif/;    

    #parse the conditional if there is one.
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
    my $str = shiftVal($tokenRef) . " ";
   
    #shift the left paren 
    shift(@$tokenRef);
    #parse the conditional and replace the right paren
    $str = $str . parse($tokenRef, 0, 0);
    $str =~ s/\)$/:\n/;
    #account for: while ()
    $str =~ s/^while\s*:\n$/while True:\n/;
    #account for while($var = <>)
    if ($str =~ /([a-zA-Z_][a-zA-Z_0-9]*)\s*=\s*sys\.stdin\.readline\(\)/) {
        $str = "for $1 in sys.stdin:\n";
    } elsif ($str =~ /([a-zA-Z_][a-zA-Z_0-9]*)\s*=\s*fileinput.input\(\)/) {
        $str = "for $1 in fileinput.input():\n";
    }
    #account for while $i++
    if ($str =~ /([a-zA-Z_][a-zA-Z0-9_]*\s*\+=\s*1)/) {
        $str =~ s/([a-zA-Z_][a-zA-Z0-9_]*)\s*\+=\s*1/$1/;
        $str = $str . " "x($indentLevel + 4) . $1 . " += 1\n"
    }
    #parse the body
    shift(@$tokenRef);
    $str = $str . parse($tokenRef, $indentLevel + 4, 0); 

    return $str;           
}

sub parseFor {
    (my $tokenRef, my $indentLevel) = @_;
   
    my $str;
    my $temp = "";

    #remove for/foreach
    shift(@$tokenRef);
    if ($$tokenRef[0][0] eq "variable") {
        #translate to a for in loop
        $$tokenRef[0][1] =~ s/^.//;
        $str = "for " . shiftVal($tokenRef) . " in ";
        shift(@$tokenRef);
        #parse array
        $str = $str . parse($tokenRef, 0, 0);
        $str =~ s/\)$//;
    } else {
        #translate from a for(;;) loop
        #first stage of (;;)
        shift(@$tokenRef);
        $str = parse($tokenRef, 0, 1) . "\n";
        #second stage
        shift(@$tokenRef);
        $temp = parse($tokenRef, 0, 1);
        $temp =~ s/^$/True/;
        shift(@$tokenRef);
        #third stage
        $str = $str . "while " . $temp;
        $temp = parse($tokenRef, $indentLevel + 4, 0) . "\n";
        $temp =~ s/\)$//;
        $temp =~ s/^\n$//;
    }

    shift(@$tokenRef);
    $str = $str . ":\n";
    #parse the body
    $str = $str . parse($tokenRef, $indentLevel + 4, 0);
    $str = $str . $temp;

    return $str;
}

#-----------------------------------------------------------------#

sub lookAhead {
    (my $prevStr, my $tokens) = @_;
    my $assign = 0;
    my $str = "";
    
    #determine if we have an assignment of the form +=, *= etc...
    if ($$tokens[0][1] =~ /^.=/) {
        $assign = 1;
    }
    if ($$tokens[0][0] eq "range") { 
            $str = parseRange($prevStr, $tokens);
    } elsif ($$tokens[0][0] eq "concat") {
            $str = parseCast("str", $prevStr, $assign, $tokens);
    } elsif ($$tokens[0][0] eq "regex") {
        $str = parseRegex($prevStr, $$tokens[0][1]);
        shift(@$tokens);
    } elsif ($$tokens[0][0] eq "leftRightOp") {
        $str = parseCast("", $prevStr, $assign, $tokens);
    } elsif ($$tokens[0][0] eq "arithmetic") {
        $str = parseCast("", $prevStr, $assign, $tokens);
    } elsif ($$tokens[0][0] eq "arithComp") {
        $str = parseCast("float", $prevStr, $assign, $tokens);
    } elsif ($$tokens[0][0] eq "stringComp") {
        $str = parseCast("str", $prevStr, $assign, $tokens);
    } elsif ($$tokens[0][0] eq "mod") {
        $str = parseCast("int", $prevStr, $assign, $tokens);
    } elsif ($$tokens[0][0] eq "assignment") {
        $str = parseCast("", $prevStr, 1, $tokens);
    } else {
        $str = $prevStr; 
    }

    return $str;
}

#a function that casts the expression before (if $assign = 1)
#and after the given operator to $cast.
sub parseCast {
    (my $cast, my $prevStr, my $assign, my $tokenRef) = @_;
    my $str = "";
    my $operator;
    my $nextStr; 
    $operator = parseOperator(shiftVal($tokenRef));
    if ($cast ne "") {
        if (not $assign and $prevStr ne "") {
            $prevStr = "$cast(" . $prevStr . ")";
        }
        $nextStr = "$cast(" . parseNext($tokenRef) . ")";
    } else {
        $nextStr = parseNext($tokenRef);
    }
    $str = $prevStr . " " . parseOperator($operator) . " " . $nextStr;
    
    if (@$tokenRef) {
        $str = $str . lookAhead("", $tokenRef);
    }
    return $str;
}

#a function that parses the use of the .. range operator
#must be given the previous expression
sub parseRange {
    my $range1 = $_[0];
    my $tokenRef = $_[1];
    my $str = "xrange(" . $range1 . ", ";
    shift(@$tokenRef);

    $str = $str . parseNext($tokenRef);
    $str = $str . " + 1)";
    return $str;
}

#parses the next expression, if it hits arithmetic operators
#it will recursively call itself until it reaches and expression
sub parseNext {
    my $tokenRef = $_[0];
    my $str = "";

    if ($$tokenRef[0][0] eq "leftParen") {
        $str = $str . shiftVal($tokenRef);
        $str = $str . parse($tokenRef, 0, 0);
    } elsif ($$tokenRef[0][0] =~ /(array|hash)/) {
        $str = $str . parseIndex($tokenRef);
    } elsif ($$tokenRef[0][0] eq "builtin") {
        $str = parseBuiltin($tokenRef);
    } elsif ($$tokenRef[0][0] eq "arithmetic") {
        $str = shiftVal($tokenRef) . parseNext($tokenRef); 
    } else {
        my @temp = (shift(@$tokenRef));
        $str = $str . parse(\@temp, 0, 0);
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

#parses a token of the form $baz{expr}
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
        #extract var name from token.
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
    } elsif ($$tokenRef[0][1] eq "push") {
        $str = parsePush($tokenRef);
    } elsif ($$tokenRef[0][1] eq "pop") {
        $str = parsePop($tokenRef);
    } elsif ($$tokenRef[0][1] eq "reverse") {
        $str = parseReverse($tokenRef);
    } elsif ($$tokenRef[0][1] eq "shift") {
        $str = parseShift($tokenRef);
    } elsif ($$tokenRef[0][1] eq "unshift") {
        $str = parseUnshift($tokenRef);
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

    #remove the printf keyword
    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        if (contains($tokenRef, ",")) {
            @tokens = findNext($tokenRef, ",");
            shift(@$tokenRef);
            $str = $str . parse(\@tokens, 0, 0) . " % (";
            $str = $str . parse($tokenRef, 0, 0) .  ")";
        } else {
            $str = $str . parse($tokenRef, 0, 0);
        }
    } else {
        if (contains($tokenRef, ",")) {
            @tokens = findNext($tokenRef, ",");
            $str = $str . parse(\@tokens, 0, 0) . " % (";
            shift(@$tokenRef);
            $str = $str . parse($tokenRef, 0, 1) . "))";
            $str =~ s/\n\)\)$/\)\)/;
        } else {
            $str = $str . parse($tokenRef, 0, 1) . ")";
            $str =~ s/\n\)$/\)/;
        }
    }

    return $str;
}

sub contains {
    (my $tokenRef, my $key) = @_;

    for my $token (@$tokenRef) {
        if ($$token[1] eq $key) {
            return 1;
        } elsif ($$token[1] eq ";") {
            return 0;
        }
    }

    return 0;
}

sub parsePrint {
    my $tokenRef = $_[0];
    my $remParen = 0;
    my $str = "print";
    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        $remParen = 1;
    }
    $str = $str . " " . parse($tokenRef, 0, 1);
    $str =~ s/\\\\/unlikelyword123/g;
    if ($remParen) {
        $str =~ s/(\)?)$/,/;
    } else {
        $str =~ s/$/,/;
    }
    $str =~ s/(,\s*"\\n",\s*)$//;
    $str =~ s/\\n",$/"/;
    $str =~ s/\s*\+?\s+""//;
    $str =~ s/unlikelyword123/\\\\/g;
    $str =~ s/print\s*,\s*$//;
    $str =~ s/,\s*,$/,/;
    return $str;
}

sub parsePush {
    my $tokenRef = $_[0];
    my $str = "";
    
    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        $str = parseVariable(shiftVal($tokenRef)) . ".append(";
        shift(@$tokenRef);
        $str .= parse($tokenRef, 0, 1);
    } else {
        $str = parseVariable(shiftVal($tokenRef)) . ".append(";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 1) . ")";
    }

    return $str;
}

sub parsePop {
    my $tokenRef = $_[0];
    my $str;

    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
    }

    $str = parseVariable(shiftVal($tokenRef)) . ".pop()"; 
    parse($tokenRef, 0, 1);

    return $str;
}

sub parseShift {
    my $tokenRef = $_[0];
    my $str = "";

    shift(@$tokenRef);

    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
    }

    $str = parseVariable(shiftVal($tokenRef)) . ".pop(0)";
    parse($tokenRef, 0, 1);
    return $str;
}

sub parseUnshift {
    my $tokenRef = $_[0];
    my $str = "";

    shift(@$tokenRef);

    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        $str = parseVariable(shiftVal($tokenRef)) . ".insert(0, ";
        shift(@$tokenRef);
        $str = $str . parse($tokenRef, 0, 1);
    } else {
        $str = parseVariable(shiftVal($tokenRef)) . ".insert(0, ";
        $str = $str . parse($tokenRef, 0, 1) . ")";
    }

    return $str;    
}

sub parseReverse {
    my $tokenRef = $_[0];
    my $str;

    shift(@$tokenRef);
    if ($$tokenRef[0][1] eq "(") {
        shift(@$tokenRef);
        $str = "(" . parse($tokenRef, 0, 1) . "[::-1]";
    } else {
        $str = "(" . parse($tokenRef, 0 ,1) . ")[::-1]";
    }

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
    if ($str =~ /\s*([^=]*)\s*=\s*(.*)/s) {
        $str = $1 . " = (" . $2 . ")" . ".rstrip()";
    } else {    
        $str = $str . " = (" . $str . ")" . ".rstrip()";
    }

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
        $str = "(" . parse($tokenRef, 0, 1) . ")";
        $str = $str . ".split(" . parse(\@temp, 0, 1) . ")";
    }

    if ($str =~ /\.split\(([a-zA-Z_][a-zA-Z_0-9]*|'[^']*'|"(\\.|[^\\"])*"),/) {
        $str =~ s/\.split\(/.split([/;
        $str =~ s/\)$/])/;
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

    if ($str =~ /\.join\(([a-zA-Z_][a-zA-Z_0-9]*|'[^']*'|"(\\.|[^\\"])*"),/) {
        $str =~ s/\.join\(/.join([/;
        $str =~ s/\)$/])/;
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
    } elsif ($operator eq ".") {
        $str = "+";
    } elsif ($operator eq ".=") {
        $str = "+=";
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

    while (@$tokenRef and $$tokenRef[0][1] ne $key) {
        push(@arr, shift(@$tokenRef));
    }

    return @arr;
}

#MAGIC VOODOO CODE
sub parseStr {
    my $str = $_[0];
    $str =~ s/\n/\\n/g;
    my @arr;
 
    if (not ($str =~ /\$'[^']*'^/)) {
        $str =~ s/\\\\/unlikelyword123/g;
        $str =~ s/([^\\])(\$[a-zA-Z0-9_]+\[[^\]]*\])/
        @arr = lex($2); 
        "$1\"" . " \+ " . "str(" . parse(\@arr,0,0) . ") \+ \""/eg;
        $str =~ s/([^\\])(\$#[a-zA-Z0-9_]+)/
        @arr = lex($2); 
        "$1\"" . " \+ " . "str(" . parse(\@arr,0,0) . ") \+ \""/eg;
        $str =~ s/([^\\])\$(([a-z]|[A-Z]|[0-9]|_)+)/$1" \+ str($2) \+ "/g;
        $str =~ s/([^\\])\$\{(([a-z]|[A-Z]|[0-9]|_)+)\}/$1" \+ str($2) \+ "/g;
        $str =~ s/([^\\])(@([a-z]|[A-Z]|[0-9]|_)+)/
        @arr = lex($2);
        "$1\" + ' '.join(map(str, " . parse(\@arr, 0, 0) . ")) \+ \""/eg;
        $str =~ s/([^\\])\@\{(([a-z]|[A-Z]|[0-9]|_)+)\}/$1" \+ ' '.join(map(str, $2)) \+ "/g;
        
        $str =~ s/unlikelyword123/\\\\/g;
        $str =~ s/\+\s*""\s*\+/ \+ /g;
        $str =~ s/""\s*\+\s*//g;
        $str =~ s/\s*\+\s*""\s*//g;
    }

    return $str;
}

main();
