# $Id$

package EnsEMBL::Web::ImageConfig::generegview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift; 

  $self->set_parameters({
    sortable_tracks => 1,  # allow the user to reorder tracks
    opt_lines       => 1,  # draw registry lines
  });

  $self->create_menus(qw(
    transcript
    prediction
    functional
    other
    information
  ));

  $self->load_tracks;
 
  $self->add_tracks('other',
    [ 'ruler',     '',  'ruler',     { display => 'normal', strand => 'r', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '',  'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'scalebar',  '',  'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }],
  );

  $self->modify_configs(
    [ 'functional' ],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [ 'gene_legend' ],
    { display => 'off' }
  );
  
  # hack to stop zmenus having the URL ZMenu/Transcript/Regulation, since this causes a ZMenu::Regulation to be created instead of a ZMenu::Transcript
  $_->data->{'zmenu'} ||= 'x' for $self->get_node('transcript')->nodes;
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );
  
  $self->modify_configs(
    [ 'regulatory_regions_funcgen_feature_set' ],
    { depth => 25, height => 6 }
  );
  
  $self->load_configured_das('functional');
  
  # Turn off cell line wiggle tracks
  my @cell_lines = sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  
  foreach my $cell_line (@cell_lines) {
    $cell_line =~ s/\:\d*//;
    
    # Turn off core and supporting evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line", "reg_feats_other_$cell_line" ],
      { display => 'off' }
    );
  }
}

1;
