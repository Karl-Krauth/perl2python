#!/usr/bin/perl

#testing simple use of chomp
$line = "oh myyyyyyy\n";
chomp($line);
print $line;

#stranger uses of chomp
chomp($line = <STDIN>);
print $line;

#testing simple use of split
print split('b', 'abc'), "\n";

#use of split with concat
$line = 'fs0dsdfdsf0s0dfs0f0sf0sd';
print split('|', 'hi' . "|" . "my" . "|" . 'name | is | karl'), "\n";
@arr = split('0', $line . "bla0bla0bla0" . $line);
print @arr, "\n";
print split(' ', <STDIN>), "\n";

#simple use of join
$line = join(":", @arr);
print $line;

#join with multiple strings
$var = "name is karl";
$line = join(" ", "hello", "world", "my", $var, "\n");
print $line;

#join with multiple strings and arr
$line = join(":", "bla", $var, @arr);

#join used with split
$line = join(" ", split("|", "sdf|sfds|asdas|dsad|ds"), $line);
print $line . "\n";
print split(' ', join(" ", @arr, $line));
