=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Info::LocationGallery;

## 

use strict;

use base qw(EnsEMBL::Web::Component::Info::Gallery);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;

  my $layout = [
                  {
                    'title' => 'Locations',
                    'pages' => ['Whole Genome', 'Chromosome Summary', 'Region overview', 'Region in Detail', 'Synteny', 'Alignments (image)', 'Alignments (text)', 'Region Comparison', 'Linkage Data'],
                    'icon'  => 'karyotype.png',
                  },
                ];

  return $self->format_gallery('Location', $layout, $self->_get_pages);
}


sub _get_pages {
  ## Define these in a separate method to make content method cleaner
  my $self = shift;
  my $hub = $self->hub;
  my $r = $hub->param('r');

  my $builder   = EnsEMBL::Web::Builder->new($hub);
  my $factory   = $builder->create_factory('Location');
  my $object    = $factory->object;

  if (!$object) {
    return $self->warning_panel('Invalid coordinates', 'Sorry, those coordinates could not be found. Please try again.');
  }
  else {
    
    my $no_chromosomes = scalar @{$hub->species_defs->ENSEMBL_CHROMOSOMES||[]} ? 0 : 1;

    return {
            'Whole genome' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Genome',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_genome',
                                  'caption'   => 'View the entire karyotype for this species',
                                  'disabled'  => $no_chromosomes,
                                },
            'Chromosome summary' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Chromosome',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_chromosome',
                                  'caption'   => '',
                                },
            'Region overview' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Overview',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_overview',
                                  'caption'   => '',
                                },
            'Region in Detail' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'View',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_view',
                                  'caption'   => '',
                                },
            'Synteny' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Synteny',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_synteny',
                                  'caption'   => '',
                                },
            'Alignments (image)' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Compara_Alignments',
                                                  'function'  => 'Image',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_alignimage',
                                  'caption'   => '',
                                },
            'Alignments (text)' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Compara_Alignments',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_aligntext',
                                  'caption'   => '',
                                },
            'Region comparison' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Multi',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_comparison',
                                  'caption'   => '',
                                },
            'Linkage data' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'HighLD',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_ld',
                                  'caption'   => '',
                                },

            };
  }

}

1;
