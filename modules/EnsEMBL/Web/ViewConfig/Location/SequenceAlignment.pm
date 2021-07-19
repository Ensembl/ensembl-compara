=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Location::SequenceAlignment;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable;

  $self->set_default_options({
    'display_width'   => 120,
    'exon_ori'        => 'all',
    'match_display'   => 'dot',
    'snp_display'     => 'on',
    'line_numbering'  => 'sequence',
    'codons_display'  => 'off',
    'strand'          => 1,
    %{$self->_strains}
  });

  $self->title('Resequencing');
}

sub field_order {
  ## Abstract method implementation
  return (
    qw(display_width strand exon_ori match_display),
    $_[0]->variation_fields,
    qw(line_numbering codons_display title_display reference_sample),
    sort keys %{$_[0]->_strains});
}

sub form_fields {
  ## Abstract method implementation
  my $self        = shift;
  my $markup      = $self->get_markup_options({ 'no_consequence' => 1, 'snp_display_label' => 'Highlight resequencing differences' });
  my $ref_strain  = ($self->species_defs->databases->{'DATABASE_VARIATION'} || {})->{'REFERENCE_STRAIN'};
  my $fields      = {};

  # Exon to highlight field
  push @{$markup->{'exon_ori'}{'values'}}, { 'value' => 'off', 'caption' => 'None' };
  $markup->{'exon_ori'}{'label'} = 'Exons to highlight';

  # Matching basepairs field
  $markup->{'match_display'} = {
    'type'    => 'DropDown',
    'select'  => 'select',
    'name'    => 'match_display',
    'label'   => 'Matching basepairs',
    'values'  => [
      { 'value' => 'off', 'caption' => 'Show all' },
      { 'value' => 'dot', 'caption' => 'Replace matching bp with dots' }
    ]
  };

  # Reference strain field
  if ($ref_strain) {
    my $strain_type = $self->hub->species_defs->STRAIN_TYPE || 'strain';
    $markup->{'reference_sample'} = {
      'type'  => 'NoEdit',
      'name'  => 'reference_sample',
      'label' => "Reference $strain_type",
      'value' => $ref_strain
    };
  }

  # Other strains
  for (keys %{$self->_strains}) {
    $markup->{$_} = {
      'type'  => 'CheckBox',
      'label' => $_,
      'name'  => $_,
      'value' => 'on',
    }
  }

  for ($self->field_order) {
    next unless $markup->{$_};
    $fields->{$_} = $markup->{$_};
  }
  return $fields;
}

sub _strains {
  ## @private
  ## Gets a list of all strains
  my $self = shift;

  if (!$self->{'_var_strains'}) {
    my $variations  = $self->species_defs->databases->{'DATABASE_VARIATION'} || {};
    my $ref_strain  = $variations->{'REFERENCE_STRAIN'};
    my $strains     = {};

    $strains->{$_} = 'on'   for grep $_ ne $ref_strain, @{$variations->{'DEFAULT_STRAINS'} || []};
    $strains->{$_} = 'off'  for grep $_ ne $ref_strain, @{$variations->{'DISPLAY_STRAINS'} || []};

    $self->{'_var_strains'} = $strains;
  }

  return $self->{'_var_strains'};
}

1;
