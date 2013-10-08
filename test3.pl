#!/usr/bin/perl

$var1 = 3;

#simple if
if ($var1 > 2) {
    print $var1, "\n";    
}

#simple while
while ($var1 < 10) {
    print $var1, "\n";
    $var1 = $var1 + 1;
}

#simple for
for ($i = 0; $i < 20; $i = $i + 1) {
    print $i, "\n";
}

#empty conditionals and use of last/next
$var1 = 3;
$var2 = 0;
for (;;) {
    $var1 = 3;
    while () {
        if ($var1 == 10) {
            last;
        } else {
            $var1 = $var1 + 1;
        }
    }
    print $var1, "\n";
    if ($var2 == 20) {
        last;
    } elsif ($var2 != 20) {
        $var2 = $var2 + 1;
        next;
    } else {
        print "this never gets printed!\n";
    }
    print "Neither does this!!\n";    
}

$var1 = "hello world";
#strange formatting more complex conditionls
for
(
    $i = 0
;
$i < 200 and
 $var1 eq "hello world"
;$i=$i+1
)
{}

print $i, "\n";
