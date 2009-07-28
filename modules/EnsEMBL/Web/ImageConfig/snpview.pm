package EnsEMBL::Web::ImageConfig::snpview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Overview panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'    => 1, # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks'  => 0, # include empty tracks..
    'opt_lines'         => 1, # draw registry lines
    'opt_restrict_zoom' => 1, # when we get "zoom" working draw restriction enzyme info on it!!
  });



  $self->create_menus(
    'transcript'  => 'Genes',
    'prediction'  => 'Prediction transcripts',
    'sequence'    => 'Sequence',
    'variation'   => 'Variation',
    'information' => 'Information', 
    'other'       => 'Decorations',
  );


  $self->add_tracks( 'sequence',
    [ 'contig',    'Contigs',              'stranded_contig', { 'display' => 'normal',  'strand' => 'r'  } ],
  );

  $self->add_tracks( 'information',
    [ 'variation_legend',      '',   'variation_legend',     { 'display' => 'normal', 'strand' => 'r', 'name' => 'Variation Legend',  'caption' => 'Variation legend'         } ],
  ); 
  $self->add_tracks( 'other',
    [ 'ruler',     '',            'ruler',           { 'display' => 'normal',  'strand' => 'b', 'name' => 'Ruler'      } ],
    [ 'scalebar',  '',            'scalebar',        { 'display' => 'normal',  'strand' => 'r', 'name' => 'Scale bar'  } ],
  );


  $self->load_tracks();

  $self->modify_configs(
    [qw(variation)],
    {qw(style box depth 100000)}
  );
 
  $self->modify_configs(
   [qw(gene_legend)],
   {qw(display off menu no)}
  );

  $self->modify_configs(
    [qw(variation_feature_variation)],
    {qw(display normal)}
  );



}

1;


=head1 ImageConfig::snpview

=head2 SYNOPSIS

=head2 DESCRIPTION

=head2 METHODS

 Artefacts contains what is turned on.

 Settings: configures what is in the drop down yellow menus
 
 bgcolour: configures the background colours of the tracks. Alternate them to get differing shades: e.g.
     'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bg

=head2 OPTIONS


=head3 B<strand>

Description: Configures this track on the forward (forward :   'str' => 'f') or reverse (reverse :   'str' => 'r',) strand 

=head3 B<position>

Example: 'pos'         => '4525',

Description: Position of the track within the drawable container and in comparison with all other tracks configured in this imageconfig.

=head3 B<on/off>

  Example:   'on' => 'on',
             'on' => 'off',

  Description: Whether this track is displayed by default ('on' => 'on'), or off by default ('on' => 'off').


=head3 B<available>

  Description: This track only displays if the availability criteria is met.  For example checking the database is there (e.g. 'databases DATABASE_VARIATION' ) or a specific table is there.

