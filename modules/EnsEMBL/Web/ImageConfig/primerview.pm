package EnsEMBL::Web::ImageConfig::primerview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 30;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'primerview'} = {
           '_artefacts' => [qw(stranded_contig ruler scalebar primer_forward primer_reverse transcript_lite)],
           '_options'  => [qw(pos col known unknown)],
           '_settings' => {
               'width'   => 800,
               'bgcolor'   => 'background1',
               'bgcolour1' => 'background1',
               'bgcolour2' => 'background1',
              },
           'ruler' => {
                 'on'          => "on",
                 'pos'         => '10000',
                 'col'         => 'black',
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

           'transcript_lite' => {
                     'on'          => "on",
                     'pos'         => '21',
                     'str'         => 'b',
                     'src'         => 'all', # 'ens' or 'all'
                     'colours' => {$self->{'_colourmap'}->colourSet( 'core_gene' )},
                     
                    },
          
           'primer_forward' => {
                  'on'          => "on",
                  'pos'         => '4520',
                  'str'         => 'f',
                  'dep'         => '15',
                  'col'         => 'blue',
                  'track_height'=> 20,
                  'hi'          => 'black',
                    'navigation'  => 'on',
                  'colours'     => {
                        '_forward'       => 'red',
                    #    '_reverse'          => 'orange',
                        
                    #    'label_forward'  => 'white',
                    #    'label_reverse'     => 'black',  
                       },
                 },

           'primer_reverse' => {
                  'on'          => "on",
                  'pos'         => '4521',
                  'str'         => 'r',
                  'dep'         => '16',
                  'col'         => 'blue',
                  'track_height'=> 20,
                  'hi'          => 'black',
                  'colours'     => {
                      #  '_forward'       => 'red',
                        '_reverse'          => 'orange',
                      # 'label_forward'  => 'white',
                      #  'label_reverse'     => 'black', 
                       },
                 },
                      
           'primer_legend' => {
                   'on'          => "on",
                   'str'         => 'r',
                   'pos'         => '9999',
                  },
           
  };
}
1;
