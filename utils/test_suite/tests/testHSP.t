#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

use vars qw($filename $parser);

BEGIN {
  use_ok( 'EnsEMBL::Web::Blast' );
  use_ok( 'EnsEMBL::Web::Blast::Result::HSP' );
  use_ok( 'EnsEMBL::Web::Blast::Result::Alignment' );
}

my $self = shift();
my $id = "test id";
my $type = "test type";
my $chromosome = 19;
my $score = 1000;
my $probability = 9.23E-17;
my $reading_frame = -1;

my $hsp = EnsEMBL::Web::Blast::Result::HSP->new({
		id => $id,
		type => $type,
		chromosome => $chromosome,
		score => $score,
		probability => $probability,
		reading_frame => $reading_frame,
		});

ok ($id eq $hsp->id);
ok ($type eq $hsp->type);
ok ($chromosome == $hsp->chromosome);
ok ($score == $hsp->score);
ok ($probability == $hsp->probability);
ok ($reading_frame == $hsp->reading_frame);
