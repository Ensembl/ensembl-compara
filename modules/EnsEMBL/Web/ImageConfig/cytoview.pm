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

package EnsEMBL::Web::ImageConfig::cytoview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks  => 'drag', # allow the user to reorder tracks on the image
    show_labels      => 'yes',  # show track names on left-hand side
    opt_halfheight   => 1,      # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,      # include empty tracks..
    opt_lines        => 1,      # draw registry lines
  });
  
  $self->create_menus(qw(
    sequence
    marker
    transcript
    misc_feature
    synteny
    variation
    somatic
    external_data
    user_data
    decorations
    information
  ));
  
  $self->add_track('sequence', 'contig', 'Contigs', 'contig', { display => 'off', strand => 'r', description => 'Track showing underlying assembly contigs' });
  
  $self->add_tracks('information',
    [ 'missing', '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary' }],
    [ 'info',    '', 'text', { display => 'normal', strand => 'r', name => 'Information' }]
  );
  
  foreach my $alt_assembly (@{$self->species_defs->ALTERNATIVE_ASSEMBLIES || []}) {
    $self->add_track('misc_feature', "${alt_assembly}_assembly", "$alt_assembly assembly", 'alternative_assembly', { 
      display       => 'off',
      strand        => 'r',  
      colourset     => 'alternative_assembly' ,  
      description   => "Track indicating $alt_assembly assembly", 
      assembly_name => $alt_assembly
    });
  }

  $self->load_tracks;
  $self->load_configured_das({ strand => 'r' });
  $self->image_resize = 1;
  
  $self->modify_configs(
    [ 'transcript' ],
    { strand => 'r' }
  );
  
  $self->modify_configs(
    [ 'marker' ],
    { labels => 'off' }
  );

  $self->modify_configs(
    [ 'variation', 'somatic' ],
    { display => 'off', menu => 'no' }
  );
  
  $self->modify_configs(
    [ 'variation_feature_structural_larger', 'variation_feature_structural_smaller', 'somatic_sv_feature' ],
    { display => 'off', menu => 'yes' }
  );
  
  $self->modify_configs(
    [ 'structural_variation_external' ],
    {  menu => 'yes' }
  );
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

1;
