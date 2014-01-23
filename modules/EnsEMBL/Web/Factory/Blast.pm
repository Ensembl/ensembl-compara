=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Factory::Blast;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub blast_adaptor {
  my $self    = shift;
  my $species = shift || $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  my $blast_adaptor; 

  eval {
    $blast_adaptor = $self->hub->databases_species($species, 'blast')->{'blast'};
  };

  return $blast_adaptor if $blast_adaptor;

  # Still here? Something gone wrong!
  warn "Can not connect to blast database: $@";
}

sub createObjects {   
  my $self = shift;    

  ## Create a very lightweight object, as the data required for a blast page is very variable
  $self->DataObjects($self->new_object('Blast', {
    tickets => undef,
    adaptor => $self->blast_adaptor,
  }, $self->__data));
}

1;
