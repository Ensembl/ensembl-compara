package EnsEMBL::Web::ImageConfig::supporting_evidence_transcript;
use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
    my ($self) = @_;
    $self->set_parameters({
	'title'         => 'Supporting Evidence',
	'show_buttons'  => 'no',   # show +/- buttons
	'button_width'  => 8,       # width of red "+/-" buttons
	'show_labels'   => 'yes',   # show track names on left-hand side
	'label_width'   => 100,     # width of labels on left-hand side
	'margin'        => 5,       # margin
	'spacing'       => 2,       # spacing
	'bgcolor'       => 'background1',
	'bgcolour1'     => 'background2',
	'bgcolour2'     => 'background3',
    });

    $self->create_menus(
	'TSE_transcript'      => 'Genes',
    );

    ## Add in additional
    $self->load_tracks();

    #switch off all transcript unwanted transcript tracks
    foreach my $child ( $self->get_node('TSE_transcript')->descendants ) {
	$child->set( 'display' => 'off' );
    }

    $self->add_tracks( 'TSE_transcript',
	   [ 'non_can_intron',          'Non-canonical splicing', 'non_can_intron',          { 'display' => 'on',
								        		    'strand' => 'r',
											    'colours'  => $self->species_defs->colour('feature'), } ],
	   [ 'TSE_generic_match_label', 'Transcript evidence:', 'TSE_generic_match_label', { 'display' => 'on',
											    'strand' => 'r' } ],
	   [ 'TSE_generic_match',       '',                    'TSE_generic_match',       { 'display' => 'on',
											    'strand' => 'r',
											    'colours'  => $self->species_defs->colour('feature'), } ],
	   [ 'SE_generic_match_label',  'Exon evidence:',       'SE_generic_match_label',  { 'display' => 'on', 
											    'strand' => 'r' } ],
	   [ 'SE_generic_match',        '',                    'SE_generic_match',        { 'display' => 'on',
											    'strand' => 'r',
											    'colours'  => $self->species_defs->colour('feature'), } ],
	   [ 'TSE_background_exon',     '',                    'TSE_background_exon',     { 'display' => 'on', 
											    'strand' => 'r' } ],
	   [ 'TSE_legend',              'Legend',              'TSE_legend',              { 'display' => 'on', 
											    'strand' => 'r',
											    'colours'  => $self->species_defs->colour('feature') } ],
		   );	
}

1;
