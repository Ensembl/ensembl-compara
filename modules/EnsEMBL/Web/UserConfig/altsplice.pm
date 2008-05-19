package EnsEMBL::Web::UserConfig::altsplice;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 12;
  # $self->{'fakecore'} = 1;

  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'altsplice'} = {
    '_artefacts'    => [ qw(ruler scalebar contig variation regulatory_regions 
                            regulatory_search_regions ) ],
    '_options'      => [qw(pos col known unknown)],
    'fakecore' => 1,
    '_settings'     => {
      'features' => [ 
		     [ 'variation' => "SNPs" ],
                     [ 'regulatory_regions' => 'Regulatory regions'  ],
                     [ 'regulatory_search_regions' => 'Regulatory search regions'  ],
		    ],
      'show_labels'  => 'yes',
      'show_buttons' => 'no',
      'opt_zclick'   => 1,
      'opt_lines'    => 1,
      'width'        => 800,
      'bgcolor'      => 'background1',
      'bgcolour1'    => 'background1',
      'bgcolour2'    => 'background1',
    },

    'scalebar' => {
      'on' => 'on',
      'pos' => '100000',
      'col'       => 'black',
      'label'     => 'on',
      'max_division'  => '12',
      'str'       => 'b',
      'subdivs'     => 'on',
      'abbrev'    => 'on',
      'navigation'  => 'off'
    },
    'ruler' => {
      'on'  => "on",
      'pos' => '99999',
      'str'   => 'b',
      'col' => 'black',
    },        
    'contig' => {
      'on'  => "on",
      'pos' => '0',
      'col' => 'black',
      'navigation'  => 'off',
    },
    'variation' => {
      'on'  => "off",
      'pos' => '4520',
      'str' => 'r',
      'col' => 'blue',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION',
    }, 
    # col is for colours. Not needed here as overwritten in Glyphset
    'regulatory_regions' => {
      'on'  => "off",
      'pos' => '12',
      'str' => 'b',
      'available'=> 'database_tables ENSEMBL_DB.regulatory_feature', 
    },
   'regulatory_search_regions' => {
      'on'  => "off",
      'pos' => '13',
      'str' => 'b',
      'available'=> 'database_tables ENSEMBL_DB.regulatory_search_region',
    },

  };
  $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'off', 'compact'     => 0 );
  $self->ADD_ALL_PREDICTIONTRANSCRIPTS( 0, 'on' => 'off', 'compact'     => 0 );
}
1;

