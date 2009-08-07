package EnsEMBL::Web::Text::Feature::GENERIC;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname   	{  return $_[0]->{'__raw__'}[1]; }
sub rawstart 	{  return $_[0]->{'__raw__'}[2]; }
sub rawend 		{  return $_[0]->{'__raw__'}[3]; }
sub id       	{  return $_[0]->{'__raw__'}[4]; }
sub external_data { return undef; }

sub coords {
  my ($self, $data) = @_;
  return ($data->[1], $data->[2], $data->[3]);
}
 

1;
