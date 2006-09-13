#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

use vars qw($filename $parser);

BEGIN {
  use_ok( 'EnsEMBL::Web::Blast' );
  use_ok( 'EnsEMBL::Web::Blast::Result::HSP' );
  use_ok( 'EnsEMBL::Web::Blast::Result::Alignment' );
}

my $score = 980;
my $probability = 2.5e-174;
my $reading_frame= +1;
my $identities = 135;
my $positives = 120;
my $length = 150;
my $start = 4567;
my $end = 4789;

my $alignment = EnsEMBL::Web::Blast::Result::Alignment->new({
		score => $score,
		probability => $probability,
		reading_frame => $reading_frame,
		identities => $identities,
		positives => $positives,
		length => $length,
		start => $start,
		end => $end,
		});

ok ($alignment->score == $score, 'Score set');
ok ($alignment->probability == $probability, 'Probability set');
ok ($alignment->reading_frame == $reading_frame, 'Reading frame set');
ok ($alignment->identities == $identities, 'Identities set');
ok ($alignment->positives == $positives, 'Positives set');
ok ($alignment->length == $length, 'Length set');
ok ($alignment->start == $start, 'Start set');
ok ($alignment->end == $end, 'End set');
