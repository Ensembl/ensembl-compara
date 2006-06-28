package EnsEMBL::Web::UserConfig::Vega::snpview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 30;
    $self->{'_add_labels'} = 'yes';
    $self->{'_transcript_names_'} = 'yes';
    $self->{'general'}->{'snpview'} = {
        '_artefacts' => [qw(
                stranded_contig
                ruler
                scalebar
                vega_transcript
                glovar_snp_triangle
                variation_legend
                )],
        '_settings' => {
            'features' => [
                [ 'glovar_snp_triangle' => "SNPs" ],
            ],
            'options' => [
                [ 'opt_empty_tracks' => 'Show empty tracks' ],
            ],
            'opt_empty_tracks' => 1,
            'opt_zclick'     => 1,
            'show_labels'      => 'yes',
            'opt_shortlabels'  => 1,
            'width'   => 600,
            'bgcolor'   => 'background1',
            'bgcolour1' => 'background3',
            'bgcolour2' => 'background1',
        },
        'ruler' => {
            'on'          => "on",
            'pos'         => '2',
            'col'         => 'black',
            'str'         => 'r',
        },
        'stranded_contig' => {
            'on'          => "on",
            'pos'         => '0',
            'navigation'  => 'off'
        },
        'scalebar' => {
            'on'          => "on",
            'nav'         => "off",
            'pos'         => '8000',
            'col'         => 'black',
            'str'         => 'r',
            'abbrev'      => 'on',
            'navigation'  => 'off'
        },
        'glovar_snp_triangle' => {
            'on'          => "on",
            'pos'         => '4521',
            'str'         => 'r',
            'dep'         => '1000',
            'col'         => 'blue',
            'track_height'=> 7,
            'hi'          => 'black',
            'colours' => {$self->{'_colourmap'}->colourSet('variation')},
            'available'=> 'database ENSEMBL_GLOVAR', 
        },
        'variation_legend' => {
            'on'          => "on",
            'str'         => 'r',
            'pos'         => '9999',
        },
    };

    $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'on' );
}
1;
