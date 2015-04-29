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
