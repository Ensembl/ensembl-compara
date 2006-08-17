package EnsEMBL::Web::UserConfig::Vega::Vmap2view;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {

    my ($self) = @_;
    $self->{'_label'}           = 'above';
    $self->{'_uppercase_label'} = 'no';
    $self->{'_band_labels'}     = 'on';
    $self->{'_image_height'}    = 450;
    $self->{'_top_margin'}      = 40;
    $self->{'_spacing'}		= 8; # spacing between lanes in ideogram
    $self->{'_band_links'}      = 'yes';
    $self->{'_userdatatype_ID'} = 109;

    $self->{'general'}->{'Vmap2view'} = {
	'_artefacts'   => [qw(
            Vannotation_status_left
            Vannotation_status_right
      	    Vannot_knownPCod
   	        Vannot_knownPTrans
    	    Vannot_novelPCod
	        Vannot_novelPTrans
			Vannot_putativePTrans
    	    Vannot_ig_and_ig_pseudo
	        Vannot_predictedPCod
	        Vannot_pseudo
            Vsnps
	        Vpercents
    	    Videogram
	)],

	'_options'   => [],

	'_settings' => {
	    'width'     => 500, # really height <g>
	    'bgcolor'   => 'background1',
	    'bgcolour1' => 'background1',
	    'bgcolour2' => 'background1',
            'scale_values' => [qw(
                 knownPCodDensity
	   			 knownPTransDensity
                 novelPCodDensity
                 novelPTransDensity
                 putativePTransDensity
                 predictedPCodDensity
                 IgSegDensity
                 IgPseudoSegDensity
                 pseudoGeneDensity
            )],
	    'labels' => 1,
	},
       
	'_colours' => {
	    $self->{'_colourmap'}->colourSet( 'vega_gene' ),
        },

        'Vannotation_status_left' => {
            'on'          => 'on',
            'pos'         => '1',
            'colour'      => 'gray85',
            'glyphset'    => 'Vannotation_status',
            'tag_pos'     => 1,
        },

        'Vannotation_status_right' => {
            'on'          => 'on',
            'pos'         => '1000',
            'colour'      => 'gray85',
            'glyphset'    => 'Vannotation_status',
            'tag_pos'     => 0,
        },

        'Vsnps' => {
            'on'          => 'off',
            'pos'         => '20',
            'width'       => 40,
            'col'         => 'blue',
            'logicname' => 'snpDensity',
        },

       'Vannot_knownPCod' => {
	        'on' => 'on',
    	    'pos' => '11',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Kn_Pc"],
            'colour' => [qw(protein_coding_KNOWN)],
    	    'logicname' => [qw(knownPCodDensity)],
		},

	    'Vannot_novelPCod' => {
	        'on' => 'on',
	        'pos' => '12',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["No_Pc"],
            'colour' => [qw(protein_coding_NOVEL)],
    	    'logicname' => [qw(novelPCodDensity)],
    	},

       'Vannot_knownPTrans' => {
	        'on' => 'on',
	        'pos' => '11',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Kn_Pt"],
            'colour' => [qw(processed_transcript_KNOWN)],
    	    'logicname' => [qw(knownPTransDensity)],
		},

    	'Vannot_novelPTrans' => {
	        'on' => 'on',
	        'pos' => '13',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["No_Pt"],
            'colour' => [qw(processed_transcript_NOVEL)],
    	    'logicname' => [qw(novelPTransDensity)],
    	},	

	    'Vannot_predictedPCod' => {
	        'on' => 'on',
	        'pos' => '15',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Pr_Pc"],
            'colour' => [qw(protein_coding_PREDICTED)],
    	    'logicname' => [qw(predictedPCodDensity)],
    	},

	    'Vannot_putativePTrans' => {
	        'on' => 'on',
	        'pos' => '16',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Pu_Pt"],
            'colour' => [qw(processed_transcript_PUTATIVE)],
    	    'logicname' => [qw(putativePTransDensity)],
    	},

    	'Vannot_pseudo' => {
	        'on' => 'on',
	        'pos' => '17',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["To_Ps"],
            'colour' => [qw(pseudogene_UNKNOWN)],
    	    'logicname' => [qw(pseudoGeneDensity)],
	    },

	    'Vannot_ig_and_ig_pseudo' => {
	        'on' => 'on',
	        'pos' => '18',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["IgS", "IgP"],
            'colour' => [qw(Ig_segment_NOVEL Ig_pseudogene_segment_UNKNOWN)],
    	    'logicname' => [qw(IgSegDensity IgPseudoSegDensity)],
	    },

    	'Vpercents' => {
	        'on' => 'on',
	        'pos' => '99',
	        'width' => 30,
	        'col_gc' => 'red',
	        'col_repeat' => 'black',
	        'logicname' => 'PercentageRepeat PercentGC'
    	},		

    	'Videogram' => {
	        'on'  => "on",
	        'pos' => '100',
	        'width' => 24,
	        'bandlabels' => 'on',
	        'totalwidth' => 100,
	        'col' => 'g',
	        'padding'   => 6,
    	},
    };
}
1;
