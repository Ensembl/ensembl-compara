# $Id$

package EnsEMBL::Web::ImageConfig::generegview;

use strict;

sub init {
  my $self = shift; 

  $self->set_parameters({
    title           => 'Regulation Image',
    sortable_tracks => 1,     # allow the user to reorder tracks
    show_labels     => 'yes', # show track names on left-hand side
    label_width     => 113,   # width of labels on left-hand side
    opt_lines       => 1,     # draw registry lines
  });

  $self->create_menus(
    transcript   => 'Genes',
    prediction   => 'Prediction transcripts',
    functional   => 'Functional genomics',
    other        => 'Decorations',
    information  => 'Information',
  );

  $self->load_tracks;
 
  $self->add_tracks('other',
    [ 'ruler',     '',  'ruler',     { display => 'normal', strand => 'r', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '',  'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'scalebar',  '',  'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }],
  );

  $self->modify_configs(
    [qw(functional)],
    { display => 'normal' }
  );
  
  $self->modify_configs(
    [qw(gene_legend)],
    { display => 'off' }
  );
  
  $self->modify_configs(
    [qw(transcript_core_ensembl)],
    { display => 'transcript_label' }
  );
  
  $self->modify_configs(
    [qw(regulatory_regions_funcgen_feature_set)],
    { depth => 25, height => 6 }
  );
  
  # Turn off cell line wiggle tracks
  my @cell_lines = sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  
  foreach my $cell_line (@cell_lines){
    $cell_line =~ s/\:\d*//;
    
    # Turn on core and supporting evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line", "reg_feats_other_$cell_line" ],
      { display => 'off' }
    );
  }
}

1;
