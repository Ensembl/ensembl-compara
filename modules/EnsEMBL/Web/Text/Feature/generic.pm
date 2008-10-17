package Data::Bio::Text::Feature::generic;
use strict;
use Data::Bio::Text::Feature;
use vars qw(@ISA);
@ISA = qw(Data::Bio::Text::Feature);

sub seqname   	{  return $_[0]->{'__raw__'}[1]; }
sub rawstart 	{  return $_[0]->{'__raw__'}[2]; }
sub rawend 		{  return $_[0]->{'__raw__'}[3]; }
sub id       	{  return $_[0]->{'__raw__'}[4]; }

1;
