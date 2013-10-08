#!/usr/bin/perl

#testing use of STDIN
$line = <STDIN>;
print $line, "\n";
print $line, <STDIN>, "\n";

while ($line = <STDIN>) {
    print $line;
}

$num = <STDIN> + 3;

#more complex print statements:
print $line, $var, "message";
print ((($line, $var, "message")));
print ($line, $var, "\\n");
print ($var, "\\n", $var);
print 
   (
 (
( 
   "\$\\n"
 )
  )
    );

print (";");
print "";
print ")";
print "\n,";
