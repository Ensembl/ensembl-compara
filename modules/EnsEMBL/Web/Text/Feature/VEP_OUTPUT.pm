=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Text::Feature::VEP_OUTPUT;

### Ensembl output format for Variant Effect Predictor

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname {
  my $self = shift;
  my @A = split(':', $self->{'__raw__'}[1]); 
  return $A[0];
}

sub rawstart {
  my $self = shift;
  my @A = split(':', $self->{'__raw__'}[1]); 
  my @B = split('-', $A[1]);
  return $B[0];
}

sub rawend {
  my $self = shift;
  my @A = split(':', $self->{'__raw__'}[1]); 
  my @B = split('-', $A[1]);
  return $B[-1];
}

sub allele_string {
  my $self = shift;
  my @A = split('_', $self->{'__raw__'}[0]); 
  return $A[2];
}

sub id                { return $_[0]->{'__raw__'}[0]; }
sub location          { return $_[0]->{'__raw__'}[1];  }
sub allele            { return $_[0]->{'__raw__'}[2];  }
sub gene              { return $_[0]->{'__raw__'}[3];  }
sub feature           { return $_[0]->{'__raw__'}[4];  }
sub feature_type      { return $_[0]->{'__raw__'}[5];  }
sub consequence       { return $_[0]->{'__raw__'}[6];  }
sub cdna_position     { return $_[0]->{'__raw__'}[7];  }
sub cds_position      { return $_[0]->{'__raw__'}[8];  }
sub protein_position  { return $_[0]->{'__raw__'}[9];  }
sub aa_change         { return $_[0]->{'__raw__'}[10];  }
sub codons            { return $_[0]->{'__raw__'}[11]; }
sub snp               { return $_[0]->{'__raw__'}[12]; }
sub extra_col         { return $_[0]->{'__raw__'}[13]; }

sub external_data   { return $_[0]->{'__extra__'}; }
sub extra           { return $_[0]->{'__extra__'}; }


sub coords {
  my ($self, $data) = @_;
  ## Not sure why this method is parsing a string, but 
  ## I don't want to break things by removing it!
  if ($data->[1] =~ /:|-/) {
    my ($seq_region, $start) = split(':|-', $data->[1]);
    return ($seq_region, $start, $start);
  }
  else {
    return @$data[0..2];
  }
}


1;
