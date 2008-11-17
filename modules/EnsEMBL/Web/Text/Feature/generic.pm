package EnsEMBL::Web::Text::Feature::generic;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname   	{  return $_[0]->{'__raw__'}[1]; }
sub rawstart 	{  return $_[0]->{'__raw__'}[2]; }
sub rawend 		{  return $_[0]->{'__raw__'}[3]; }
sub id       	{  return $_[0]->{'__raw__'}[4]; }

1;
