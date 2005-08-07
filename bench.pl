#!/usr/bin/perl

use Benchmark ':all';

open my $m, "/proc/$$/maps" or die "ERROR: Cannot open /proc/$$/maps: $!\n";
open my $s, "/proc/$$/smaps" or die "ERROR: Cannot open /proc/$$/smaps: $!\n";

cmpthese timethese 200000,
  {
   'maps'=>sub { seek $m, 0, 0; scalar <$m>; },
   'smaps'=>sub { seek $s, 0, 0; scalar <$s>; },
  };
