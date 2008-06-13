#!/usr/local/bin/perl -w

use strict;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use vars qw( $SERVERROOT );
warn $SERVERROOT = dirname( $Bin );

open I,"$SERVERROOT/conf/packed/dhtml.ini";
my %X;
while(<I>) {
  chomp;
  my($k,$v) = /^(\w+)\s*=\s*(\w+)$/;
  $X{$k} = $v;
}

foreach my $d (qw(minified merged packed.0 packed)) {
  opendir DH, "$SERVERROOT/htdocs/$d";
  while(my $f = readdir(DH)) {
    my( $code,$type ) = split /\./,$f;
    next unless exists $X{$type};
    unlink "$SERVERROOT/htdocs/$d/$f" if ($type eq 'css' || $type eq 'js') && $code ne $X{$type};
  }
}
