#!/usr/bin/env perl
# A JIG: any program that prints Heck.  This one prints a fence.
# It is handed its values as  Name=value  - lengths as plain inches.
use strict; use warnings;
my %v = map { /^(\w+)=(.*)$/ ? ($1 => $2) : () } @ARGV;
my $posts   = $v{Posts}   // 6;
my $spacing = $v{Spacing} // 24;
my $height  = $v{Height}  // 36;
my $north   = $v{North}   // 0;
my $east    = $v{East}    // 0;

for my $i (0 .. $posts - 1) {
    my $x = $east + $i * $spacing;
    print qq{line = $x" east, $north" north, 0 up to + $height" up\n};
}
my $end = $east + ($posts - 1) * $spacing;
for my $rail ($height * 0.3, $height * 0.8) {
    print qq{line = $east" east, $north" north, $rail" up to $end" east, $north" north, $rail" up\n};
}
