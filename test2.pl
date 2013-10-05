#!/usr/bin/perl

#initial assignments
$var1 = 3;
$var2 = 0;
$var3 = -2;

#test of logical operators
    1 || 0; 1&&0; !0;
    3 and 0; 5 or 2;
!
!
!
not
!
!
not
1
;

$var3
=    (($var1 || $var2)     and not not ! ($var3 and not not !$var3))
or ! not ((($var2) or $var1) and not ($var1 or $var2));

print $var1, " ", $var2, " ", $var3, " ", ($var3 or $var2) && ($var1), "\n";

#test of bitwise operators
    6&0;4 |3; 7 ^  2; 6 << 2; 2 >> 4; ~2;

$var1 = ($var1 & 3)
|
$var1^$var1^$var1
|(((3|2& $var1| ($var2 ^$var1)) | 4  ) & 2398);

print $var1, "\n";

#test of bitwise operators with logical operators
$var2 = (3&&4)&(2||4);
$var3 = (3||2)|(2||6);

print $var2, " ", $var3, "\n";
