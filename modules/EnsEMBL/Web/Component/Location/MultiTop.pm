=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::MultiTop;

use strict;

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  
  return if $self->param('show_top_panel') eq 'no';
  
  my $threshold       = 1e6 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1); # get a slice corresponding to the region to be shown for Navigational Overview
  my $image_width     = $self->image_width;
  my $primary_species = $hub->species;
  my $object          = $self->object || $self->hub->core_object('location');
  my $slices          = $object->multi_locations;
  my $max             = scalar @$slices;
  my $i               = 1;
  my $gene_connection_types = EnsEMBL::Web::Constants::GENE_JOIN_TYPES;
  my $compara_db      = EnsEMBL::Web::DBSQL::DBConnection->new($primary_species)->_get_compara_database;
  my $connect_genes   = $self->param('opt_join_genes_top') eq 'on';
  my @images;
  
  foreach (@$slices) {
    my $highlight_gene    = $hub->param('g' . ($i - 1));
    my $slice             = $_->{'slice'};
    my $image_config      = $hub->get_imageconfig({type => 'MultiTop', cache_code => "contigviewtop_$i", species => $_->{'species'}});
    my $annotation_status = $image_config->get_node('annotation_status');
    
    if ($slice->length <= $threshold) {
      if ($_->{'length'} < $threshold) {
        $slice = $slice->adaptor->fetch_by_region($slice->coord_system->name, $slice->seq_region_name, 1, $slice->seq_region_length, 1);
      } else {
        my $c = int $slice->centrepoint;
        my $s = ($c - $threshold / 2) + 1;
           $s = 1 if $s < 1;
        my $e = $s + $threshold - 1;
        
        if ($e > $slice->seq_region_length) {
          $e = $slice->seq_region_length;
          $s = $e - $threshold - 1;
        }
        
        $slice = $slice->adaptor->fetch_by_region($slice->coord_system->name, $slice->seq_region_name, $s, $e, 1);
      }
    }
    
    $image_config->set_parameters({
      container_width   => $slice->length,
      image_width       => $image_width,
      slice_number      => "$i|2",
      multi             => 1,
      compara           => $i == 1 ? 'primary' : $_->{'species'} eq $primary_species ? 'paralogue' : 'secondary',
      connection_types  => $gene_connection_types
    });
    
    if ($annotation_status) {
      $annotation_status->set('caption', '');
      $annotation_status->set('menu', 'no');
    };
    
    $image_config->get_node('ruler')->set('caption', $_->{'short_name'} =~ s/^[^\s]+\s+//r);
    $image_config->get_node('ruler')->set('caption_img',"f:24\@-6:".$_->{'species'});
    $image_config->highlight($highlight_gene) if $highlight_gene;
    
    if ($connect_genes) {
      $image_config->connect_genes($slices->[$i-1]{'slice'}->seq_region_name, map $_ >= 0 && $_ < $max ? $slices->[$_] : {}, $i-2, $i);
      $slice->adaptor->db->set_adaptor('compara', $compara_db);
    }
    
    push @images, $slice, $image_config;
    
    $i++;
  }

  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'top';
  
  return $image->render;
}

1;
