package EnsEMBL::Web::Text::Feature::SNP;

### Ensembl format for SNP data (e.g. for Variant Effect Predictor)

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $args ) = @_;
  
  return bless { '__raw__' => $args }, $class;
}


sub seqname   	    { return $_[0]->{'__raw__'}[0]; }
sub allele_string   { return $_[0]->{'__raw__'}[3]; }
sub strand          { return $_[0]->{'__raw__'}[4]; }
sub extra           { return $_[0]->{'__raw__'}[5]; }
sub external_data   { return undef; }

sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub id       { my $self = shift; return $self->{'__raw__'}[3]; }

sub coords {
  my ($self, $data) = @_;
  return ($data->[0], $data->[1], $data->[2]);
}
 

1;
