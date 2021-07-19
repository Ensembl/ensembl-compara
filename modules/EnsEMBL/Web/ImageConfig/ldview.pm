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

package EnsEMBL::Web::ImageConfig::ldview;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub _menus {
  return (qw(
    ld_population
    transcript
    simple
    misc_feature
    prediction
    variation
    somatic
    other
    information
  ));
}

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  my $colours = $self->species_defs->colour('variation');

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
    label_width => 100
  });

  $self->create_menus($self->_menus);

  $self->load_tracks;

  my $r2_html = 'r&sup2;';
  my $r2_tag  = 'r<sup>2</sup>';

  $self->add_tracks('ld_population',
    [ 'text',       '', 'text',       { display => 'normal', strand => 'r', menu    => 'no'                                                                                         }],
    [ 'ld_r2',      '', 'ld',         { display => 'normal', strand => 'r', colours => $colours, caption => "LD ($r2_html)", name => "LD ($r2_tag)", key => 'r2',                   }],
    [ 'ld_d_prime', '', 'ld',         { display => 'normal', strand => 'r', colours => $colours, caption => "LD (D')",       name => "LD (D')",      key => 'd_prime'               }],
  );

  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar', description => 'Shows the scalebar'                             }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
  );

  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );

  $self->modify_configs(
    ['simple', 'misc_feature'],
    { display => 'off', menu => 'no'}
  );

  $self->modify_configs(
    ['simple_otherfeatures_human_1kg_hapmap_phase_2'],
    {'display' => 'tiling', menu => 'yes'}
  );

  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', strand => 'r' }
  );
}

sub init_slice {
  my ($self, $parameters) = @_;

  $self->set_parameters({
    %$parameters,
    _userdatatype_ID   => 30,
    _transcript_names_ => 'yes',
    context            => 20000,
  });

  $self->get_node('ld_population')->remove;
}

sub init_population {
  my ($self, $parameters, $pop_name) = @_;

  $self->set_parameters($parameters);

  $self->{'_ld_population'} = [ $pop_name ];

  $self->get_node('text')->set_data('text', $pop_name);
  $_->remove for grep $_, map $self->get_node($_), grep $_ ne 'ld_population', $self->_menus;
}

1;

