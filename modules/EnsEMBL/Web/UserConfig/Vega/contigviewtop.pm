package EnsEMBL::Web::UserConfig::Vega::contigviewtop;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 2;
    $self->{'general'}->{'contigviewtop'} = {
        '_artefacts' => [qw(
        annotation_status encode

	) ],
					    
		'_options'  => [],
					     
	    '_settings' => {
	       'width'            => 700,
	       'draw_red_box'     => 'yes',
	       '_clone_start_at_0'=> 'yes',
	       'default_vc_size'  => 1000000,
	       'clone_based'      => 'no',
	       'clone_start'      => 1,
	       'clone'            => '',
	       'show_contigview'  => 'yes',
	       'imagemap'         => 1,
	       'bgcolor'          => 'background1',
	       'bgcolour1'        => 'background1',
	       'bgcolour2'        => 'background1',
	    },
					     
    };
	$self->ADD_GENE_TRACKS();
#	$self->ADD_SYNTENY_TRACKS();
	my $POS = 0;
	
	$self->add_track( 'annotation_status', 'on'=>'on', 'pos'=> 9998, 'str'=>'x', 'lab'=>'black',
					  'label' => 'Annotation status', 'height'  => 5, 'navigation'  => 'on',
					  'available' => 'features mapset_noannotation');
	$self->add_track( 'contig',   'on'=>'on', 'pos' => $POS++ );
	$self->add_track( 'scalebar', 'on'=>'on', 'pos' => $POS++, 'str' => 'f', 'abbrev' => 'on' );
	$self->add_track( 'marker',   'on'=>'on', 'pos' => $POS++,
					  'col' => 'magenta', 'colours' => {$self->{'_colourmap'}->colourSet( 'marker' )},
					  'labels'    => 'on',
					  'available' => 'features markers'),
	$self->add_track( 'chr_band', 'on'=>'on', 'pos' => $POS++ );
	$self->add_track( 'redbox', 'on'=>'off', 'col' => 'red', 'pos' => 1000100 );
	$self->add_track( 'encode', 'on' => 'on', 'pos' => 9997, 'colour' => 'salmon', 'label'  => 'Encode regions',
                      'str' => 'r', 'available' => 'features mapset_encode');
	$self->add_track( 'hap_clone_matches', 'on' => 'on', 'pos' => 9999, 'colour' => 'gold1', 'label'  => 'Haplotype clones',
                      'height' => 5, 'depth' => 3, 'str' => 'r', 'available' => 'features mapset_hclone');
	$POS = 100000;
	$self->add_track( 'gene_legend', 'str' => 'r', 'on'=>'on', 'pos' => $POS++ );
}

1;
