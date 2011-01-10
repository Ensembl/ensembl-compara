# $Id$

package EnsEMBL::Web::ImageConfig::genespliceview_transcript;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title            => 'Transcripts',
    show_buttons     => 'no',  # show +/- buttons
    button_width     => 8,     # width of red "+/-" buttons
    show_labels      => 'yes', # show track names on left-hand side
    label_width      => 100,   # width of labels on left-hand side
    margin           => 5,     # margin
    spacing          => 2,     # spacing
    opt_halfheight   => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,     # include empty tracks..
  });
  
  $self->create_menus(
    gsv_transcript => '',
    other          => '',
    spacers        => '',
    gsv_domain     => 'Protein Domains'    
  );
   
  $self->load_tracks;
  
  $self->add_tracks('spacers',
    [ 'spacer', '', 'spacer', { display => 'normal', strand => 'r', menu => 'no', height => 10 }],
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
}
1;

