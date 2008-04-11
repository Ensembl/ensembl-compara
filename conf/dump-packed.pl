#!/software/bin/perl

use Data::Dumper;
use strict;
use Storable qw(lock_retrieve);

my $T = lock_retrieve( $ARGV[0] );
$Data::Dumper::Indent = 1;
print Data::Dumper::Dumper( $T );

