package EnsEMBL::Web::ImageConfig::lrgsnpview_transcript;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  
  $self->set_parameters({
    'title'            => 'Transcripts',
    'show_buttons'     => 'no',    # show +/- buttons
    'button_width'     => 8,       # width of red "+/-" buttons
    'show_labels'      => 'yes',   # show track names on left-hand side
    'label_width'      => 100,     # width of labels on left-hand side
    'margin'           => 5,       # margin
    'spacing'          => 2,       # spacing
    'opt_halfheight'   => 0,    # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks' => 0,    # include empty tracks..
  });

  $self->create_menus(
    'gsv_transcript'  => '',
    'lrg'    => '',
    'other'           => '',
    'spacers'          => '',
    'gsv_domain'      => 'Protein Domains'    
  );


   $self->add_tracks( 'other',
     [ 'lsv_variations',   '',   'lsv_variations',     { 'display' => 'on', 'colours' => $self->species_defs->colour('variation'),  'strand' => 'r', 'menu' => 'no' } ],
   );

  $self->load_tracks();

 
  $self->add_tracks( 'spacers',
    [ 'spacer',           '',     'spacer',            { 'display' => 'normal',  'strand' => 'r', 'menu' => 'no' , 'height' => 10         } ],
  );


  $self->add_tracks('lrg',
    [ 'lsv_transcript',  '', 'lsv_transcript',  
      { display => 'no_labels', 
	name => 'LRG transcripts', 
	description => 'Shows LRG transcripts', 
	logic_names=>['LRG_import'], 
	logic_name=>'LRG_import',
        'colours'     => $self->species_defs->colour( 'gene' ),
        'label_key'   => '[display_label]',
}],
  );


  $self->modify_configs(
    [qw(gsv_transcript)],
    {qw(display no_labels) }
  );
 
  #switch off all transcript unwanted transcript tracks
  foreach my $child ( $self->get_node('gsv_transcript')->descendants ) {
    $child->set( 'display' => 'off' );
    $child->set( 'menu' => 'no' );
  }

  $self->modify_configs(
    [qw(gsv_domain)],
    {qw(display normal) }
  );

  $self->modify_configs(
    [qw(gsv_variations)],
    {qw(display box) }
  );


}
1;

