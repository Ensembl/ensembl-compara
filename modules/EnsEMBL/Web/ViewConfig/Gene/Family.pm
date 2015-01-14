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

package EnsEMBL::Web::ViewConfig::Gene::Family;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self    = shift;
  my %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $self->set_defaults({
    map({ 'species_' . lc($_) => 'yes' } $self->species_defs->valid_species),
    map({ 'opt_'     . lc($_) => 'yes' } keys %formats)
  });
  
  $self->code  = 'Gene::Family';
  $self->title = 'Ensembl protein families';
}

sub form {
  my $self         = shift;
  my %formats      = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;
  my $species_defs = $self->species_defs;
  my %species      = map { $species_defs->species_label($_) => $_ } $species_defs->valid_species;
  
  $self->add_fieldset('Selected species');
  
  foreach (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %species) {
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => 'species_' . lc $species{$_},
      value => 'yes',
      raw   => 1
    });
  }
  
  $self->add_fieldset('Selected databases');
  
  foreach(sort keys %formats) {
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $formats{$_}{'name'},
      name  => 'opt_' . lc $_,
      value => 'yes', 
      raw   => 1
    });
  }
}

1;
