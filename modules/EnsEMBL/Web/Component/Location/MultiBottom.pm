=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::MultiBottom;

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

  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  
  return if $hub->param('show_bottom_panel') eq 'no';
  
  my $threshold = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $image_width     = $self->image_width;
  my $primary_slice   = $object->slice;
  my $primary_species = $hub->species;
  my $primary_strand  = $primary_slice->strand;
  my $slices          = $object->multi_locations;
  my $seq_region_name = $object->seq_region_name;
  my $short_name      = $slices->[0]->{'short_name'};
  my $max             = scalar @$slices;
  my $base_url        = $hub->url($hub->multi_params);
  my $gene_join_types = EnsEMBL::Web::Constants::GENE_JOIN_TYPES;
  my $methods         = { BLASTZ_NET => $hub->param('opt_pairwise_blastz'), LASTZ_NET => $hub->param('opt_pairwise_blastz'), TRANSLATED_BLAT_NET => $hub->param('opt_pairwise_tblat'), LASTZ_PATCH => $hub->param('opt_pairwise_lpatch'), LASTZ_RAW => $hub->param('opt_pairwise_raw') };
  my $join_alignments = grep $_ ne 'off', values %$methods;
  my $join_genes      = $hub->param('opt_join_genes_bottom') eq 'on';

  my $compara_db      = $join_genes ? EnsEMBL::Web::DBSQL::DBConnection->new($primary_species)->_get_compara_database : undef;
  my $i               = 1;
  my $primary_image_config;
  my @images;

  foreach (@$slices) {
    my $image_config   = $hub->get_imageconfig('MultiBottom', "contigview_bottom_$i", $_->{'species'});
    my $highlight_gene = $hub->param('g' . ($i - 1));
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width,
      slice_number    => "$i|3",
      multi           => 1,
      more_slices     => 1,
      compara         => $i == 1 ? 'primary' : $_->{'species'} eq $primary_species ? 'paralogue' : 'secondary',
      base_url        => $base_url,
      join_types      => $gene_join_types
    });

    # allows the 'set as primary' sprite to be shown on an single species view
    if ($image_config->get_parameter('can_set_as_primary') && $i != 1) {
      $image_config->set_parameters({
           compara => 'secondary'
         });
    }
    $image_config->get_node('scalebar')->set('caption', $_->{'short_name'} =~ s/^[^\s]+\s+//r);
    $image_config->get_node('scalebar')->set('name', $_->{'short_name'});
    $image_config->get_node('scalebar')->set('caption_img',"f:24\@-11:".$_->{'species'});
    $_->{'slice'}->adaptor->db->set_adaptor('compara', $compara_db) if $compara_db;
    
    if ($i == 1) {
      $image_config->multi($methods, $seq_region_name, $i, $max, $slices->[$i]) if $join_alignments && $max == 2 && $slices->[$i]{'species_check'} ne $primary_species;
      $image_config->join_genes($i, $max, $slices->[$i]) if $join_genes && $max == 2;
      
      push @images, $primary_slice, $image_config if $max < 3;
      
      $primary_image_config = $image_config;
    } else {
      $image_config->multi($methods, $_->{'target'} || $seq_region_name, $i, $max, $slices->[0]) if $join_alignments && $_->{'species_check'} ne $primary_species;
      $image_config->join_genes($i, $max, $slices->[0]) if $join_genes;
      $image_config->highlight($highlight_gene) if $highlight_gene;
      
      push @images, $_->{'slice'}, $image_config;
      
      if ($max > 2 && $i < $max) {
        # Make new versions of the primary image config because the alignments required will be different each time
        if ($join_alignments || $join_genes) {
          $primary_image_config = $hub->get_imageconfig('MultiBottom', "contigview_bottom_1_$i", $primary_species);
          
          $primary_image_config->set_parameters({
            container_width => $primary_slice->length,
            image_width     => $image_width,
            slice_number    => '1|3',
            multi           => 1,
            more_slices     => 1,
            compara         => 'primary',
            base_url        => $base_url,
            join_types      => $gene_join_types
          });
        }
        
        if ($join_alignments) {
          $primary_image_config->get_node('scalebar')->set('caption', $short_name =~ s/^[^\s]+\s+//r);
          $primary_image_config->get_node('scalebar')->set('name', $short_name);
          $primary_image_config->get_node('scalebar')->set('caption_img',"f:24\@-11:".$slices->[0]->{'species'});
          $primary_image_config->multi($methods, $seq_region_name, 1, $max, map $slices->[$_], $i - 1, $i);
        }
        
        $primary_image_config->join_genes(1, $max, map $slices->[$_], $i - 1, $i) if $join_genes;
        
        push @images, $primary_slice, $primary_image_config;
      }
    }
    
    $i++;
  }
  $images[-1]->set_parameters({ more_slices => 0 });
  
  if ($hub->param('export')) {
    $_->set_parameter('export', 1) for grep $_->isa('EnsEMBL::Web::ImageConfig'), @images;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'bottom';
  
  return $image->render;
}

1;
