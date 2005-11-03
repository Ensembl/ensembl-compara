package EnsEMBL::Web::UserConfig::Vega::Vmapview;
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
    $self->{'_spacing'}		= 6; # spacing between lanes in ideogram
    $self->{'_band_links'}      = 'yes';
    $self->{'_userdatatype_ID'} = 109;

    $self->{'general'}->{'Vmapview'} = {
	'_artefacts'   => [qw(
            Vannotation_status_left
            Vannotation_status_right
    	    Vannot_known 
    	    Vannot_cds 
	        Vannot_novel_trans 
    	    Vannot_ig_and_ig_pseudo 
	        Vannot_predicted
			Vannot_putative
	        Vannot_pseudo_and_poly
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
                knownGeneDensity
                novelCDSDensity
                novelTransDensity
                IgSegDensity
                IgPseudoSegDensity
                putativeTransDensity
                predictedTransDensity
                pseudoGeneDensity
            )],
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

        'Vannot_known' => {
	    'on' => 'on',
	    'pos' => '11',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Kn_Pc"],
            'colour' => [qw(protein_coding_KNOWN)],
    	    'logicname' => [qw(knownGeneDensity)],
	},

	'Vannot_cds' => {
	    'on' => 'on',
	    'pos' => '12',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["No_Pc"],
            'colour' => [qw(protein_coding_NOVEL)],
    	    'logicname' => [qw(novelCDSDensity)],
	},

	'Vannot_novel_trans' => {
	    'on' => 'on',
	    'pos' => '13',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["No_Pt"],
            'colour' => [qw(processed_transcript_NOVEL)],
    	    'logicname' => [qw(novelTransDensity)],
	},	
		     
	'Vannot_predicted' => {
	    'on' => 'on',
	    'pos' => '15',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Pu_Pt"],
            'colour' => [qw(processed_transcript_PUTATIVE)],
    	    'logicname' => [qw(putativeTransDensity)],
	},

	'Vannot_putative' => {
	    'on' => 'on',
	    'pos' => '16',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Pr_Pc"],
            'colour' => [qw(protein_coding_PREDICTED)],
    	    'logicname' => [qw(predictedTransDensity)],
	},
	'Vannot_pseudo_and_poly' => {
	    'on' => 'on',
	    'pos' => '17',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["To_Ps"],
            'colour' => [qw(pseudogene_NOVEL)],
    	    'logicname' => [qw(pseudoGeneDensity)],
	},

	'Vannot_ig_and_ig_pseudo' => {
	    'on' => 'on',
	    'pos' => '18',
	    'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["No_IgS", "No_IgP"],
            'colour' => [qw(Ig_segment_NOVEL Ig_pseudogene_segment_NOVEL)],
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
	}
    };
}
1;
