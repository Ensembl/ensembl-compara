package EnsEMBL::Web::UserConfig::geneview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  my $species = $self->{'species'};
  my $reg_feat_label = "cisRED/miRANDA";
  if ($species=~/Drosophila/){ $reg_feat_label = "REDfly"; }

  $self->{'_userdatatype_ID'} = 11; 
  $self->{'fakecore'} = 1;

  $self->{'general'}->{'geneview'} = {
    '_artefacts' => [qw(ruler regulatory_search_regions regulatory_regions)],
    '_options'  => [qw(pos col known unknown)],
 'fakecore' => 1,
    '_settings' => {
      'features' => [
         [ 'regulatory_regions'       => $reg_feat_label  ],
         [ 'regulatory_search_regions'=> 'cisRED search regions'  ],
      ],
      'show_labels'       => 'no',
      'show_buttons'      => 'no',
      'width'             => 500,
      'opt_zclick'        => 1,
      'show_empty_tracks' => 'yes',
      'show_empty_tracks' => 'yes',
      'bgcolor'           => 'background1',
      'bgcolour1'         => 'background1',
      'bgcolour2'         => 'background1',
    },
    'ruler' => {
      'on'  => 'on',
      'str' => 'r',
      'pos' => '10',
      'col' => 'black',
    },
   # col is for colours. Not needed here as overwritten in Glyphset
   'regulatory_regions' => {
      'on'  => "on",
      'pos' => '12',
      'str' => 'b',
      'available'=> 'database_tables ENSEMBL_FUNCGEN.feature_set', 
    },

 'regulatory_search_regions' => {
      'on'  => "on",
      'pos' => '13',
       'str' => 'b',
      'available'=> 'features REGFEATURES_CISRED',
    },


  };
  $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'off', 'compact' => 0 );
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 0, 'on' => 'off', 'compact' => 0 );
}
1;
