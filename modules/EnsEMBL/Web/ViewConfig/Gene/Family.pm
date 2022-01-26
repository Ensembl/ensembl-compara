=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

sub _new {
  ## @override
  my $self = shift->SUPER::_new(@_);

  $self->{'code'} = 'Gene::Family';

  return $self;
}

sub init_cacheable {
  ## Abstract method implementation
  my $self    = shift;
  my %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $self->set_default_options({
    map({ 'species_' . lc($_) => 'yes' } $self->species_defs->valid_species),
    map({ 'opt_'     . lc($_) => 'yes' } keys %formats)
  });

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

  # Select species fieldset
  $form->add_species_fieldset;

  # Selected databases fieldset
  for (sort keys %formats) {
    $form->add_form_element({
      'fieldset'  => 'Selected databases',
      'type'      => 'checkbox',
      'label'     => $formats{$_}{'name'},
      'name'      => 'opt_' . lc $_,
      'value'     => 'yes',
    });
  }

  return $form;
}

1;
