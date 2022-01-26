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

package EnsEMBL::Web::ViewConfig::Transcript::PopulationImage;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::ViewConfig);

sub _new {
  ## @override
  my $self = shift->SUPER::_new(@_);

  $self->{'code'} = 'Transcript::SNPView';

  return $self;
}

sub init_cacheable {
  ## Abstract method implementation
  my $self      = shift;
  my %fields    = (%{$self->_variation_strains}, %{$self->_variation_sources}, %{$self->_variation_options});
  my %defaults  = map { $_ => $fields{$_}{'value'} } keys %fields;

  $self->title('Population comparison');
  $self->set_default_options({'context' => 100, 'consequence_format' => 'label', %defaults});
}

sub field_order {
  ## Abstract method implementation
  my $self = shift;

  return sort keys %{$self->_variation_strains}, sort keys %{$self->_variation_sources}, sort keys %{$self->_variation_options}, qw(context consequence_format);
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $strains = $self->_variation_strains;
  my $sources = $self->_variation_sources;
  my $options = $self->_variation_options;
  my $fields  = {};

  # Add selected samples
  for (keys %$strains) {
    $fields->{$_} = {
      'fieldset'  => 'Selected samples',
      'type'      => 'CheckBox',
      'name'      => $_,
      'label'     => $strains->{$_}{'label'},
      'value'     => $strains->{$_}{'value'},
    };
  }

  # Add source selection
  for (keys %$sources) {
    $fields->{$_} = {
      'fieldset'  => 'Variation source',
      'type'      => 'CheckBox',
      'name'      => $_,
      'label'     => $sources->{$_}{'label'},
      'value'     => $sources->{$_}{'value'},
    };
  }

  # Add consequence type and variation class
  my %fieldsets = ('type' => 'Consequence type', 'class' => 'Variation class');
  for (keys %$options) {
    $fields->{$_} = {
      'fieldset'  => $fieldsets{$options->{$_}{'category'}},
      'type'      => 'CheckBox',
      'name'      => $_,
      'label'     => $options->{$_}{'label'},
      'value'     => $options->{$_}{'value'},
    };
  }

  # Add selection
  $fields->{'consequence_format'} = {
    'fieldset'  => 'Consequence options',
    'type'      => 'DropDown',
    'label'     => 'Type of consequences to display',
    'name'      => 'consequence_format',
    'values'    => [
      { 'value' => 'label',   'caption' => 'Sequence Ontology terms' },
      { 'value' => 'display', 'caption' => 'Old Ensembl terms'       },
    ]
  };

  # Add context selection
  $fields->{'context'} = {
    'fieldset'  => 'Intron Context',
    'type'      => 'DropDown',
    'name'      => 'context',
    'label'     => 'Intron Context',
    'values'    => [
      { 'value' => '20',   'caption' => '20bp'         },
      { 'value' => '50',   'caption' => '50bp'         },
      { 'value' => '100',  'caption' => '100bp'        },
      { 'value' => '200',  'caption' => '200bp'        },
      { 'value' => '500',  'caption' => '500bp'        },
      { 'value' => '1000', 'caption' => '1000bp'       },
      { 'value' => '2000', 'caption' => '2000bp'       },
      { 'value' => '5000', 'caption' => '5000bp'       },
      { 'value' => 'FULL', 'caption' => 'Full Introns' }
    ]
  };

  return $fields;
}

sub _variation_strains {
  ## @private
  ## Gets a list of all strains
  my $self = shift;

  if (!$self->{'_var_strains'}) {
    my $variations  = $self->species_defs->databases->{'DATABASE_VARIATION'} || {};
    my $ref_strain  = $variations->{'REFERENCE_STRAIN'};
    my $strains     = {};

    $strains->{"opt_pop_$_"} = {'label' => $_, 'value' => 'on'}   for grep $_ ne $ref_strain, @{$variations->{'DEFAULT_STRAINS'} || []};
    $strains->{"opt_pop_$_"} = {'label' => $_, 'value' => 'off'}  for grep $_ ne $ref_strain, @{$variations->{'DISPLAY_STRAINS'} || []};

    $self->{'_var_strains'} = $strains;
  }

  return $self->{'_var_strains'};
}

sub _variation_sources {
  ## @private
  ## Gets all the variation source fields
  my $self = shift;

  if (!$self->{'_var_sources'}) {

    $self->{'_var_sources'} = {};

    for (keys %{$self->hub->table_info('variation', 'source')->{'counts'} || {}}) {
      $self->{'_var_sources'}{'opt_' . lc($_) =~ s/\s+/_/gr} = {'label' => $_, 'value' => 'on'};
    }
  }

  return $self->{'_var_sources'};
}

sub _variation_options {
  ## @private
  ## Gets all the variation options from EnsEMBL::Web::Constants
  my $self = shift;

  if (!$self->{'_var_options'}) {

    $self->{'_var_options'} = {};
    my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS;

    foreach my $category (qw(type class)) {

      foreach my $key (keys %{$options{$category}}) {
        $self->{'_var_options'}{lc $key} = {
          'category'  => $category,
          'label'     => $options{$category}{$key}[1],
          'value'     => $options{$category}{$key}[0],
        };
      }
    }
  }

  return $self->{'_var_options'};
}

1;
