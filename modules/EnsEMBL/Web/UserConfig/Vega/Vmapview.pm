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
			Vannot_TotPCod
			Vannot_TotPTrans
            Vannot_TotPseudo
			Vannot_TotIgSeg
			Vannot_TotTEC
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
				PCodDensity
     			PTransDensity
                PseudoGeneDensity
			    IgSegDensity
				TECGeneDensity
            )],
	},
       
	'_colours' => {
	    $self->{'_colourmap'}->colourSet( 'vega_gene_havana' ),
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

	    'Vannot_TotPCod' => {
	        'on' => 'on',
	        'pos' => '10',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Prot.Cod."],
            'colour' => [qw(protein_coding)],
    	    'logicname' => 'PCodDensity',
		},

	    'Vannot_TotPTrans' => {
	        'on' => 'on',
	        'pos' => '12',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Proc.Trans."],
            'colour' => [qw(processed_transcript)],
    	    'logicname' => 'PTransDensity',
    	},

	    'Vannot_TotPseudo' => {
	        'on' => 'on',
	        'pos' => '15',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Pseudo."],
            'colour' => [qw(pseudogene)],
    	    'logicname' => 'PseudoGeneDensity',
    	},

	    'Vannot_TotIgSeg' => {
	        'on' => 'on',
	        'pos' => '18',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["Ig Seg."],
            'colour' => [qw(ig_segment)],
    	    'logicname' => 'IgSegDensity',
    	},

	    'Vannot_TotTEC' => {
	        'on' => 'on',
	        'pos' => '21',
	        'width' => 40,
            'glyphset' => 'Vgenedensity_vega',
            'label' => ["TEC"],
            'colour' => [qw(tec)],
    	    'logicname' => 'TECGeneDensity',
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
