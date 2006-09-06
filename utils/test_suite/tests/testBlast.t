#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

use vars qw($filename $tool);

BEGIN {
  use_ok( 'EnsEMBL::Web::Blast' );
  use_ok( 'EnsEMBL::Web::Blast::Parser' );
  use_ok( 'EnsEMBL::Web::Blast::Result::HSP' );
  use_ok( 'EnsEMBL::Web::Blast::Result::Alignment' );
}

BEGIN {
  $filename = "./files/blast/blastview.fosb.txt";
  $tool = EnsEMBL::Web::Blast->new({'filename' => $filename});
}

ok ($tool, 'Parser instantiated');
ok ($tool->filename eq $filename); 

## Check to see if the warnings are being handled correctly

my @warnings = ("Warning 1", "Warning 2", "Warning 3", "Warning 4");
my $tool = EnsEMBL::Web::Blast->new();
$tool->warnings(@warnings);

my @return = @{ $tool->warnings };

ok ($#warnings == $#return);
my $count = 0;
for my $warning (@warnings) {
  ok ($warning eq $return[$count]);
  $count++;
}

