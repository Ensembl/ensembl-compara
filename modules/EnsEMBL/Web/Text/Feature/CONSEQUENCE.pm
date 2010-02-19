package EnsEMBL::Web::Text::Feature::CONSEQUENCE;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname   	    { return $_[0]->{'__raw__'}[0]; }
sub start   	      { return $_[0]->{'__raw__'}[1]; }
sub end 	  	      { return $_[0]->{'__raw__'}[2]; }
sub allele_string   { return $_[0]->{'__raw__'}[3]; }
sub strand          { return $_[0]->{'__raw__'}[4]; }
sub consequence     { return $_[0]->{'__raw__'}[5]; }
sub extra           { return $_[0]->{'__raw__'}[6]; }
sub external_data   { return undef; }

sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub id       { my $self = shift; return $self->{'__raw__'}[3]; }

sub coords {
  my ($self, $data) = @_;
  return ($data->[0], $data->[1], $data->[2]);
}
 

1;
