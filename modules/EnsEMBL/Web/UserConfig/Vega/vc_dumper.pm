package EnsEMBL::Web::UserConfig::Vega::vc_dumper;
use strict;
no strict 'refs';
use EnsWeb;
use EnsEMBL::Web::UserConfigAdaptor;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self, $das_sources ) = @_;
    my $cmap = $self->colourmap();

    $self->{'_userdatatype_ID'} = 8;
    $self->{'_add_labels'} = 'yes';
    $self->{'_transcript_names_'} = 'yes';

    # import config from contigviewbottom
    my $uca = EnsEMBL::Web::UserConfigAdaptor->new(EnsWeb::species_defs->ENSEMBL_SITETYPE);
    my $import_config = $uca->getUserConfig('contigviewbottom');
    $self->{'general'}->{'vc_dumper'} = $import_config->{'general'}->{'contigviewbottom'};

    # add additional settings
    $self->add_settings( {
        '_settings' => {
            'URL'             => '',
            'show_contigview' => 'yes',
            'name'            => qq(VC Dumper Detailed Window),
            'width'           => 700,
            'clone_based'     => 'no',
            'clone_start'     => '1',
            'clone'           => 1,
            'default_vc_size' => 100000,
            'imagemap'        => 1,
            'opt_empty_tracks' => 0,
            'opt_zmenus'       => 1,
            'bgcolor'         => 'background1',
            'bgcolour1'       => 'background2',
            'bgcolour2'       => 'background3',
        },
						
        'chr_band' => {
            'on'  => "on",
            'str' => 'f',
            'pos' => '9000',
        },
        'marker_label' => {
            'on'  => "on",
            'pos' => '4102',
            'col' => 'magenta',
            'available' => 'database_tables ENSEMBL_LITE.landmark_marker'
        },
        'nod_bacs' => {
            'on'  => "on",
            'pos' => '8910',
            'col' => 'red',
            'lab' => 'black',
            'available' => 'features mapset_nod_bacs',
            'str' => 'r',
            'dep' => '9999999',
            'threshold_navigation' => '100000',
            'outline_threshold'    => '350000'
        },
        'cloneset' => {
            'on'  => "on",
            'pos' => '8909',
            'colours' => {
                'col_BACENDS' => 'yellow',
                'col_BLAST'   => 'red',
                'col_SK'      => 'blue',
                'col_CAROL'   => 'green',
                'col_ENSEMBL' => 'gold',
                'lab_BACENDS' => 'black',
                'lab_BLAST'   => 'white',
                'lab_SK'      => 'white',
                'lab_CAROL'   => 'black',
                'lab_ENSEMBL' => 'black',
                'seq_len' => 'black',
                'fish_tag' => 'black',
            },
            'str' => 'r',
            'dep' => '6',
            'threshold_navigation' => '10000000',
            'fish' => 'FISH',
            'available' => 'features mapset_cloneset',
        },
        'bac_map' => {
            'on'  => "on",
            'pos' => '8900',
            'col' => 'green',
            'lab' => 'black',
            'available' => 'features mapset_bac_map',
            'colours' => {
                'col_Free'          => 'gray80',
                'col_Phase0Ac'      => 'thistle2',
                'col_Committed'     => 'mediumpurple1',
                'col_PreDraftAc'    => 'plum',
                'col_Redundant'     => 'gray80',
                'col_Reserved'      => 'gray80',
                'col_DraftAc'       => 'gold2',
                'col_FinishAc'      => 'gold3',
                'col_Abandoned'     => 'gray80',
                'col_Accessioned'   => 'thistle2',
                'col_Unknown'     => 'gray80',
                'col_'              => 'gray80',
                'lab_Free'          => 'black',
                'lab_Phase0Ac'      => 'black',
                'lab_Committed'     => 'black',
                'lab_PreDraftAc'    => 'black',
                'lab_Redundant'     => 'black',
                'lab_Reserved'      => 'black',
                'lab_DraftAc'       => 'black',
                'lab_FinishAc'      => 'black',
                'lab_Abandoned'     => 'black',
                'lab_Accessioned'   => 'black',
                'lab_Unknown'        => 'black',
                'lab_'              => 'black',
                'bacend'            => 'black',
                'seq_len'           => 'black',
            },
            'str' => 'r',
            'dep' => '9999999',
            'threshold_navigation' => '10000000',
            'full_threshold'       => '100000000',
            'outline_threshold'    => '350000'
        },
        'supercontigs' => {
            'on'  => "on",
            'pos' => '8902',
            'col' => 'green',
            'lab' => 'black',
            'available' => 'features mapset_superctgs',
            'colours' => {
                'col1' => 'darkgreen',
                'col2' => 'green',
                'lab1' => 'white',
                'lab2' => 'black',
            },
            'str' => 'r',
            'dep' => '9999999',
            'threshold_navigation' => '10000000'
        },
        'ntcontigs' => {
            'on'  => "on",
            'pos' => '8903',
            'col' => 'green',
            'lab' => 'black',
            'available' => 'features mapset_ntctgs',
            'colours' => {
                'col1' => 'darkgreen',
                'col2' => 'green',
                'lab1' => 'black',
                'lab2' => 'black',
            },
            'str' => 'r',
            'dep' => '0',
            'threshold_navigation' => '10000000'
        },

    } );

    # add additional artefacts
    $self->add_artefacts(qw(
                chr_band
                marker_label
                cloneset
                ntcontigs
                bac_map
                supercontigs
                nod_bacs
    ));

    ## turn on all artefacts
    # this doesn't turn on artefacts which are not listed in
    # $self->{'general'}->{$self->script}}->{'_artefacts'}
    # (e.g. managed artefacts like sub_repeat)
    # take care of these separately
    $self->turn_on($self->get_available_artefacts);
	      
}
1;
