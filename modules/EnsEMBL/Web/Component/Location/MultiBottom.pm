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

package EnsEMBL::Web::Component::Location::MultiBottom;

use strict;
use warnings;

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
  my $object = $self->object || $self->hub->core_object('location');
  
  return if $self->param('show_bottom_panel') eq 'no';
  
  my $threshold = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $image_width     = $self->image_width;
  my $padding         = $hub->create_padded_region();
  my $primary_slice   = $object->slice->expand($padding->{flank5}, $padding->{flank3});
  my $primary_species = $hub->species;
  my $primary_strand  = $primary_slice->strand;
  my $slices          = $object->multi_locations;
  my $seq_region_name = $object->seq_region_name;
  my $short_name      = $slices->[0]->{'short_name'};
  my $max             = scalar @$slices;
  my $base_url        = $hub->url($hub->multi_params);
  my $gene_connection_types = EnsEMBL::Web::Constants::GENE_JOIN_TYPES;
  my $methods         = { 
                          BLASTZ_NET => $self->param('opt_pairwise_blastz') || '',
                          LASTZ_NET => $self->param('opt_pairwise_blastz') || '',
                          TRANSLATED_BLAT_NET => $self->param('opt_pairwise_tblat') || '',
                          LASTZ_PATCH => $self->param('opt_pairwise_lpatch') || '',
                          LASTZ_RAW => $self->param('opt_pairwise_raw') || '',
                          CACTUS_HAL_PW => $self->param('opt_pairwise_cactus_hal_pw') || ''
                        };

  my ($join_alignments, $cacti);

  while (my($key, $opt) = each(%$methods)) {
    if ($opt ne 'off') {
      $join_alignments = 1;
      $cacti++ if $key eq 'CACTUS_HAL_PW';
    } 
  }

  ## CACTUS_HAL alignments use a _lot_ of memory, so warn the user
  $self->hub->session->delete_records({'type' => 'message', 'code' => 'too_many_cacti'});
  my $cactus_limit = 8;
  if ($cacti && $max > $cactus_limit) {
    $hub->session->set_record_data({
          'type'      => 'message',
          'function'  => '_warning',
          'code'      => "too_many_cacti",
          'message'   => "You have attached more than $cactus_limit CACTUS_HAL pairwise alignments. Owing to memory limits on this machine, some of these alignments might not be drawn.",
    });
  } 

  my $connect_genes   = $self->param('opt_join_genes_bottom') eq 'on';

  my $compara_db      = $connect_genes ? EnsEMBL::Web::DBSQL::DBConnection->new($primary_species)->_get_compara_database : undef;
  my $i               = 1;
  my $primary_image_config;
  my @images;

  foreach (@$slices) {
    my $image_config   = $hub->get_imageconfig({type => 'MultiBottom', cache_code => "contigview_bottom_$i", species => $_->{'species'}});
    my $highlight_gene = $hub->param('g' . ($i - 1));
    
    $image_config->set_parameters({
      container_width   => $_->{'slice'}->length,
      image_width       => $image_width,
      slice_number      => "$i|3",
      multi             => 1,
      more_slices       => 1,
      compara           => $i == 1 ? 'primary' : $_->{'species'} eq $primary_species ? 'paralogue' : 'secondary',
      base_url          => $base_url,
      connection_types  => $gene_connection_types
    });
    # allows the 'set as primary' sprite to be shown on an single species view
    if ($image_config->get_parameter('can_set_as_primary') && $i != 1) {
      $image_config->set_parameters({
           compara => 'secondary'
         });
    }

    $image_config->get_node('scalebar')->set('caption', $_->{'short_name'} =~ s/^[^\s]+\s+//r);
    $image_config->get_node('scalebar')->set('name', $_->{'short_name'});
    $image_config->get_node('scalebar')->set('caption_img',"f:24\@-6:".$hub->species_defs->get_config($_->{'species'}, 'SPECIES_IMAGE');
    $_->{'slice'}->adaptor->db->set_adaptor('compara', $compara_db) if $compara_db;
    
    if ($i == 1) {
      $image_config->multi($methods, $seq_region_name, $i, $max, $slices, $slices->[$i]) if $join_alignments && $max == 2 && $slices->[$i]{'species_check'} ne $primary_species;

      $image_config->connect_genes($i, $max, $slices->[$i]) if $connect_genes && $max == 2;
      
      push @images, $primary_slice, $image_config if $max < 3;
      
      $primary_image_config = $image_config;
    } else {
      $image_config->multi($methods, $_->{'target'} || $seq_region_name, $i, $max, $slices, $slices->[0]) if $join_alignments && $_->{'species_check'} ne $primary_species;
      $image_config->connect_genes($i, $max, $slices->[0]) if $connect_genes;
      $image_config->highlight($highlight_gene) if $highlight_gene;
      
      push @images, $_->{'slice'}, $image_config;
      
      if ($max > 2 && $i < $max) {
        # Make new versions of the primary image config because the alignments required will be different each time
        if ($join_alignments || $connect_genes) {
          $primary_image_config = $hub->get_imageconfig({type => 'MultiBottom', cache_code => "contigview_bottom_1_$i", species => $primary_species});
          
          $primary_image_config->set_parameters({
            container_width   => $primary_slice->length,
            image_width       => $image_width,
            slice_number      => '1|3',
            multi             => 1,
            more_slices       => 1,
            compara           => 'primary',
            base_url          => $base_url,
            connection_types  => $gene_connection_types
          });
        }
        
        if ($join_alignments) {
          $primary_image_config->get_node('scalebar')->set('caption', $short_name =~ s/^[^\s]+\s+//r);
          $primary_image_config->get_node('scalebar')->set('name', $short_name);
          $primary_image_config->get_node('scalebar')->set('caption_img',"f:24\@-11:".$hub->species_defs->get_config($slices->[0]->{'species'}, 'SPECIES_NAME');
          $primary_image_config->multi($methods, $seq_region_name, 1, $max, $slices, map { $slices->[$_] } ($i - 1,$i));
        }
        
        $primary_image_config->connect_genes(1, $max, map $slices->[$_], $i - 1, $i) if $connect_genes;
        
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
  $image->{'export_params'} = [];
  foreach ($hub->param) {
    push @{$image->{'export_params'}}, [$_, $self->param($_)] if ($_ =~ /^(r|s)\d/ || $_ =~ /^opt/);
  } 
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'bottom';
  
  return $image->render;
}

1;
