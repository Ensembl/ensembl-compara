#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

use vars qw($filename $parser);

BEGIN {
  use_ok( 'EnsEMBL::Web::Blast' );
  use_ok( 'EnsEMBL::Web::Blast::Parser' );
  use_ok( 'EnsEMBL::Web::Blast::Result::HSP' );
  use_ok( 'EnsEMBL::Web::Blast::Result::Alignment' );
}

BEGIN {
  $filename = "./files/blast/blastview.fosb.txt";
  $parser = EnsEMBL::Web::Blast::Parser->new({'filename' => $filename});
}

ok ($parser, 'Parser instantiated');

my @blast_results = $parser->parse();

ok ($#blast_results == 499, '500 blast results found');

my $hsp = $blast_results[0];

ok ($hsp->chromosome == 19);
ok ($hsp->score == 980);
ok ($hsp->probability == 2.5e-174);
ok ($hsp->reading_frame == -1);
ok ($hsp->ident eq "AC138128.1.1.38295");

my $ident = "AC138128.1.1.38295";
$hsp = $parser->get_hsp_by_ident($ident);
ok ($hsp->ident eq $ident);
