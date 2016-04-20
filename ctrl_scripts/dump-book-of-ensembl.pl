#! /usr/bin/env perl

use strict;
use warnings;

use DB_File;
use JSON;
use Compress::Zlib;
use Fcntl qw(SEEK_SET);

my $idx = shift @ARGV;
( my $dat = $idx ) =~ s/\.idx$/.dat/;

tie(my %idx,'DB_File',$idx,O_RDONLY,0600,$DB_HASH) or die;
open(DAT,'<:raw',$dat) or die;
while(my ($k,$v) = each %idx) {
  next if $k eq '.versions';
  my $d = JSON->new->decode($v);
  seek DAT,$d->[0],SEEK_SET;
  my $out;
  read(DAT,$out,$d->[1]);
  $out = Compress::Zlib::memGunzip($out);
  print "$k ->\n$out\n";
}

1;
