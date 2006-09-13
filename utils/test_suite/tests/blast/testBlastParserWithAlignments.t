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

$parser->generate_cigar_strings(1);

my @blast_results = $parser->parse();
my $hsp = $blast_results[0];
my $alignment = ${$hsp->alignments}[0];

ok ($hsp->ident eq "AC138128.1.1.38295");
ok ($alignment->identities == 116);
ok ($alignment->score == 980);
ok ($alignment->probability eq "2.5e-174");
ok ($alignment->positives == 120);
ok ($alignment->length == 134);
ok ($alignment->reading_frame == -1);
ok ($alignment->query_start == 205);
ok ($alignment->query_end == 338);
ok ($alignment->subject_start == 4566);
ok ($alignment->subject_end == 4165);
ok ($alignment->cigar_string eq "134M", 'Cigar string is 134M');
