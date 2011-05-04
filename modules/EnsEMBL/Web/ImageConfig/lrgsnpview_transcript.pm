# $Id$

package EnsEMBL::Web::ImageConfig::lrgsnpview_transcript;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  
  $self->set_parameters({
    title            => 'Transcripts',
    show_labels      => 'yes', # show track names on left-hand side
    label_width      => 100,   # width of labels on left-hand side
    opt_halfheight   => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,     # include empty tracks..
  });

  $self->create_menus(
    gsv_transcript => '',
    lrg            => '',
    other          => '',
    spacers        => '',
    gsv_domain     => 'Protein Domains'    
  );
  
  $self->add_tracks('other',
    [ 'lsv_variations', '', 'lsv_variations', { display => 'on', colours => $self->species_defs->colour('variation'), strand => 'r', menu => 'no' }],
  );

  $self->load_tracks;

  $self->add_tracks('spacers',
    [ 'spacer', '', 'spacer', { display => 'normal', strand => 'r', menu => 'no' , height => 10 }],
  );
  
  $self->add_tracks('lrg',
    [ 'lsv_transcript', '', 'lsv_transcript', {
      display     => 'no_labels', 
      name        => 'LRG transcripts', 
      description => 'Shows LRG transcripts', 
      logic_names => [ 'LRG_import' ], 
      logic_name  => 'LRG_import',
      colours     => $self->species_defs->colour('gene'),
      label_key   => '[display_label]',
    }],
  );
  
  $self->modify_configs(
    [ 'gsv_transcript' ],
    { display => 'no_labels' }
  );

  # switch off all transcript unwanted transcript tracks
  foreach my $child ($self->get_node('gsv_transcript')->descendants) {
    $child->set('display', 'off');
    $child->set('menu', 'no');
  }

  $self->modify_configs(
    [ 'gsv_domain' ],
    { display => 'normal' }
  );

  $self->modify_configs(
    [ 'gsv_variations' ],
    { display => 'box' }
  );


}
1;

