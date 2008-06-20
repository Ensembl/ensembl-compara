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
    '_artefacts' => [qw(ruler ctcf fg_regulatory_features regulatory_search_regions regulatory_regions)],
    '_options'  => [qw(pos col known unknown)],
 'fakecore' => 1,
    '_settings' => {
      'features' => [
         [ 'regulatory_regions'       => $reg_feat_label  ],
         [ 'regulatory_search_regions'=> 'cisRED search regions'  ],
         [ 'fg_regulatory_features'       => 'Reg. Features'  ],
         [ 'ctcf'=> 'CTCF' ],
      ],
      'show_labels'       => 'no',
      'show_buttons'      => 'no',
      'width'             => 800,
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
      'pos' => '22',
      'str' => 'b',
      'available'=> 'database_tables ENSEMBL_FUNCGEN.feature_set', 
    },

 'regulatory_search_regions' => {
      'on'  => "on",
      'pos' => '23',
       'str' => 'b',
      'available'=> 'features REGFEATURES_CISRED',
    },

    'fg_regulatory_features' => {
      'on'  => "on",
      'bump_width' => 0,
      'dep' => 6,
      'pos' => '29',
      'str' => 'r',
      'col' => 'blue',
      'label' => 'FG Reg.features',
      'glyphset'    => 'fg_regulatory_features',
      'db_type'    => "funcgen",
      'colours' => {$self->{'_colourmap'}->colourSet('fg_regulatory_features')},
      'available'=> 'species Homo_sapiens',
    },

   'ctcf' =>{
      'on'  => "on",
      'dep' => 0.1,
      'pos' => '30',
      'str' => 'r',
      'col' => 'blue',
      'compact'  => 0,
      'threshold' => '500',
      'label' => 'CTCF',
      'glyphset'    => 'ctcf',
      'db_type'    => "funcgen",
      'wiggle_name' => 'tiling array data',
      'block_name' => 'predicted features',
      'available'=> 'species Homo_sapiens',
 
  }



  };
  $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'off', 'compact' => 0 );
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 0, 'on' => 'off', 'compact' => 0 );
  $self->add_track( 'fg_regulatory_features_legend',  'on' => 'on', 'str' => 'r', 'pos' => 2000200, '_menu' => 'options', 'caption' => 'Reg. feats legend'  );

}
1;
