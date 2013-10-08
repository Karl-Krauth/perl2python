#pre/post increment

$var = 2;
$var++;$var--;++$var;--$var;print $var, " = 2\n";

#range operator

for $i (1..10) {#standard operator
$i++;
print $i, "\n";
}

for $i ((1 + 2) .. (10+2)) {#more complicated range
    $i++;
    print $i, "\n";
}

foreach $i (((1+2*3-6) && 7 || 0    - (not 7))..    (((24 * 7 / 7 - 13)))) {
    print $i, "\n";
}

$num = 12;
foreach $biggerVar (($var - $num + 2) .. ($num ** $var - 1)) {
    print $biggerVar, "\n";
}
