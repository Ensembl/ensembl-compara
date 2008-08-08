#########
# Author: rmp
# Maintainer: rmp
# Created: 2003
# Last Modified: 2003-05-02
# configuration for BLAST HSP-drawing canvases
#
package EnsEMBL::Web::ImageConfig::hsp_query_plot;
use strict;
use vars qw(@ISA);
use EnsEMBL::Web::ImageConfig;
@ISA = qw( EnsEMBL::Web::ImageConfig );
#use Sanger::Graphics::WebImageConfig;
#@ISA = qw(Sanger::Graphics::WebImageConfig);

sub init {
  my ($self) = @_;
  #my $cmap   = $self->colourmap();

  $self->{'general'}->{'queryview'} = 
    {
     '_artefacts' => [
                      'HSP_query_plot',
                      'HSP_scalebar',
                      'HSP_coverage',
                     ],
     '_options'   => [qw(on pos col hi known unknown)],
     '_names'     => {
                      'on'  => 'activate',
                      'pos' => 'position',
                      'col' => 'colour',
                      'dep' => 'bumping depth',
                      'str' => 'strand',
                      'hi'  => 'highlight colour',
                     },
     '_settings' => {
                     'opt_zclick' => 1,
                     'width'           => 600,
                     'bgcolor'   => 'background1',
                    },
     'HSP_query_plot' => {
                          'dep'  => 50, 
                          'on'   => "on",
                          'pos'  => '30',
                          'txt'  => 'black',
                          'str'  => 'b', 
                          'col'  => 'red',
                          'mode' => "allhsps",
                         },
     'HSP_scalebar' => {
                    'on'         => "on",
                    'pos'        => '11',
                    'col'        => 'black',
                    'str'        => 'f',
                    'label'      => 'foobar',
                   },
     'HSP_coverage' => {
                        'on'         => "on",
                        'pos'        => '20',
                        'str'        => 'f',
                       },
    };
}
1;
