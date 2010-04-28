package EnsEMBL::Web::Text::Feature::SNP_EFFECT;

### Ensembl output format for SNP Effect Predictor

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname {
  my $self = shift;
  my @A = split('_', $self->{'__raw__'}[0]; 
  return $A[0];
}

sub rawstart {
  my $self = shift;
  my @A = split('_', $self->{'__raw__'}[0]; 
  return $A[1];
}

sub rawend { return $self->rawstart; }

sub allele_string {
  my $self = shift;
  my @A = split('_', $self->{'__raw__'}[0]; 
  return $A[2];
}

sub location        { return $_[0]->{'__raw__'}[1]; }
sub gene            { return $_[0]->{'__raw__'}[2]; }
sub transcript      { return $_[0]->{'__raw__'}[3]; }
sub consequence     { return $_[0]->{'__raw__'}[4]; }
sub external_data   { return undef; }

sub id       { my $self = shift; return $self->{'__raw__'}[0]; }

sub coords {
  my ($self, $data) = @_;
  my ($seq_region, $start) = split(':', $data->[1]);
  return ($seq_region, $start, $start);
}


1;
