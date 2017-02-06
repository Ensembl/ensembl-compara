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
                    'title' => 'Location',
                    'pages' => ['Karyotype', 'Assembly Information', 'Chromosome Image', 'Chromosome Statistics', 'Region Overview', 'Scrolling Browser', 'Region in Detail', 'Synteny Image', 'Synteny Gene Table', 'Alignment Image', 'Alignment Tree', 'Aligned Sequence', 'Region Comparison', 'Linkage Data'],
                    'icon'  => 'karyotype.png',
                    'hide' => 1, ## Only one category, so don't show navigation bar
                  },
                ];

  return $self->format_gallery('Location', $layout, $self->_get_pages);
}


sub _get_pages {
  ## Define these in a separate method to make content method cleaner
  my $self = shift;
  my $hub = $self->hub;
  my $species_defs = $hub->species_defs;
  my $r = $hub->param('r');

  my $builder   = EnsEMBL::Web::Builder->new($hub);
  my $factory   = $builder->create_factory('Location');
  my $object    = $factory->object;

  if (!$object) {
    return $self->warning_panel('Invalid coordinates', 'Sorry, those coordinates could not be found. Please try again.');
  }
  else {
    
    my $no_chromosomes = scalar @{$species_defs->ENSEMBL_CHROMOSOMES||[]} ? 0 : 1;

    my $no_synteny = $no_chromosomes;
    unless ($no_synteny) {
      my %synteny_hash = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
      $no_synteny = 1 unless scalar keys %{$synteny_hash{$hub->species} || {}};
    }

    my $variation_db  = $hub->species_defs->databases->{'DATABASE_VARIATION'};
    my $opt_variants  = $variation_db ? ', optionally with variants marked' : '';
    my $has_LD        = ($variation_db && $variation_db->{'DEFAULT_LD_POP'}) ? 1 : 0;

    return {
            'Karyotype' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Genome',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_karyotype',
                                  'caption'   => 'View the entire karyotype for this species, and add markers to indicate the position of individual genes',
                                  'disabled'  => $no_chromosomes,
                                  'message'   => 'This species has not been assembled into chromosomes',
                                },
            'Assembly Information' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Genome',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_stats',
                                  'caption'   => 'Table showing genome size, gene counts and other statistics',
                                },
            'Chromosome Image' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Chromosome',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_chromosome',
                                  'caption'   => 'View gene and variation densities along the entire genome',
                                  'disabled'  => $no_chromosomes,
                                  'message'   => 'This species has not been assembled into chromosomes',
                                },
            'Chromosome Statistics' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Chromosome',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_chrstats',
                                  'caption'   => 'Table showing chromosome size, gene counts and other statistics',
                                  'disabled'  => $no_chromosomes,
                                  'message'   => 'This species has not been assembled into chromosomes',
                                },
            'Region Overview' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Overview',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_overview',
                                  'caption'   => 'View genes and other major features in a large genomic region',
                                },
            'Scrolling Browser' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'View',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_genoverse',
                                  'caption'   => 'Explore this region in our fully scrollable genome browser',
                                },
            'Region in Detail' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'View',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_view',
                                  'caption'   => 'Zoom in on your region of interest and display your own data alongside Ensembl tracks',
                                },
            'Synteny Image' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Synteny',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_synteny',
                                  'caption'   => 'Display synteny between your chosen region and one other species',
                                  'disabled'  => $no_synteny,
                                  'message'   => 'No synteny data for this species',
                                },
            'Synteny Gene Table' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Synteny',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_synteny_genes',
                                  'caption'   => 'Table of homologous genes in the chosen region',
                                  'disabled'  => $no_synteny,
                                  'message'   => 'No synteny data for this species',
                                },
            'Alignment Image' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Compara_Alignments',
                                                  'function'  => 'Image',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_align',
                                  'caption'   => 'Align your region with one or more species, displaying gaps in the alignment',
                                },
            'Aligned Sequence' => {
                                  'link_to'   => {'type'      => 'Location',
                                                  'action'    => 'Compara_Alignments',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_aligntext',
                                  'caption'   => 'View the sequence of your region aligned to that of one or more other species'.$opt_variants,
                                },
            'Region Comparison' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'Multi',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'location_compare',
                                  'caption'   => 'View a genomic region compared to the corresponding region in a species of your choice',
                                },
            'Linkage Data' => {
                                  'link_to'   => {'type'    => 'Location',
                                                  'action'  => 'HighLD',
                                                  'r'      => $r,
                                                 },
                                  'img'       => 'variation_ld_image',
                                  'caption'   => 'Show LD values for your region in one or more populations',
                                  'disabled'  => !$has_LD,
                                  'message'   => 'No LD data for this species',
                                },

            };
  }

}

1;
