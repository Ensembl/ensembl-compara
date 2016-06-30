=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use warnings;

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## @override
  my $self    = shift;
  my %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $self->set_default_options({
    map({ 'species_' . lc($_) => 'yes' } $self->species_defs->valid_species),
    map({ 'opt_'     . lc($_) => 'yes' } keys %formats)
  });

  $self->code('Gene::Family');
  $self->title('Ensembl protein families');
}

sub field_order { } # no default fields
sub form_fields { } # no default fields

sub init_form {
  ## @override
  ## Fields are added according to species and formats
  my $self          = shift;
  my $form          = $self->SUPER::init_form(@_);
  my %formats       = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;
  my $species_defs  = $self->species_defs;
  my %species       = map { $species_defs->species_label($_) => $_ } $species_defs->valid_species;

  $form->add_fieldset('Selected species');

  for (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %species) {
    $form->add_form_element({
      'type'  => 'checkbox',
      'label' => $_,
      'name'  => 'species_' . lc $species{$_},
      'value' => 'yes',
    });
  }

  $form->add_fieldset('Selected databases');

  for (sort keys %formats) {
    $form->add_form_element({
      'type'  => 'checkbox',
      'label' => $formats{$_}{'name'},
      'name'  => 'opt_' . lc $_,
      'value' => 'yes',
    });
  }

  return $form;
}

1;
