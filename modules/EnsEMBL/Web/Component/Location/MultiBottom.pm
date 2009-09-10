package EnsEMBL::Web::Component::Location::MultiBottom;

use strict;

use EnsEMBL::Web::DBSQL::DBConnection;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $threshold = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $image_width     = $self->image_width;
  my $primary_slice   = $object->slice;
  my $primary_species = $object->species;
  my $primary_strand  = $primary_slice->strand;
  my $slices          = $object->multi_locations;
  my $short_name      = $slices->[0]->{'short_name'};
  my $max             = scalar @$slices;
  my $base_url        = $object->_url($object->multi_params);
  my $s               = $object->param('panel_top') eq 'yes' ? 3 : 2;
  my $i               = 1;
  my $methods         = {};
  my $join_genes;
  my $join_alignments;
  my $compara_db;
  my $primary_image_config;
  my @images;
  
  foreach (@$slices) {
    my $image_config = $object->image_config_hash("contigview_bottom_$i", 'MultiBottom', $_->{'species'});
    my $highlight_gene = $object->param('g' . ($i-1));
    
    if (!defined $join_alignments) {
      $methods->{'BLASTZ_NET'}          = $image_config->get_option('opt_pairwise_blastz', 'values');
      $methods->{'TRANSLATED_BLAT_NET'} = $image_config->get_option('opt_pairwise_tblat', 'values');
      
      $join_alignments = grep $_, values %$methods;
    }
    
    if (!defined $join_genes) {
      $join_genes = $image_config->get_option('opt_join_genes', 'values');
      $compara_db = new EnsEMBL::Web::DBSQL::DBConnection($primary_species)->_get_compara_database if $join_genes
    }
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width,
      slice_number    => "$i|$s",
      multi           => 1,
      compara         => $i == 1 ? 'primary' : $_->{'species'} eq $primary_species ? 'paralogue' : 'secondary',
      base_url        => $base_url
    });
    
    $image_config->get_node('scalebar')->set('caption', $_->{'short_name'});
    
    $_->{'slice'}->adaptor->db->set_adaptor('compara', $compara_db) if $compara_db;
    
    if ($i == 1) {
      $image_config->multi($methods, $i, $max, { species => $slices->[$i]->{'species'}, ori => $slices->[$i]->{'strand'} }) if $join_alignments && $max == 2 && $slices->[$i]->{'species'} ne $primary_species;
      $image_config->join_genes($i, $max, $slices->[$i]->{'species'}) if $join_genes && $max == 2;
      
      push @images, $primary_slice, $image_config if $max < 3;
      
      $primary_image_config = $image_config;
    } else {
      $image_config->multi($methods, $i, $max, { species => $primary_species, ori => $primary_strand }) if $join_alignments && $_->{'species'} ne $primary_species;
      $image_config->join_genes($i, $max, $primary_species) if $join_genes;
      $image_config->highlight($highlight_gene) if $highlight_gene;
      
      push @images, $_->{'slice'}, $image_config;
      
      if ($max > 2 && $i < $max) {
        # Make new versions of the primary image config because the alignments required will be different each time
        if ($join_alignments) {
          my @sl = map { $slices->[$_]->{'species'} eq $primary_species ? {} : { species => $slices->[$_]->{'species'}, ori => $slices->[$_]->{'strand'} }} $i-1, $i;
          
          $primary_image_config = $object->image_config_hash("contigview_bottom_1_$i", 'MultiBottom', $primary_species);
          
          $primary_image_config->set_parameters({
            container_width => $primary_slice->length,
            image_width     => $image_width,
            slice_number    => "1|$s",
            multi           => 1,
            compara         => 'primary',
            base_url        => $base_url
          });
          
          $primary_image_config->get_node('scalebar')->set('caption', $short_name);
          $primary_image_config->multi($methods, 1, $max, @sl);
        }
        
        $primary_image_config->join_genes(1, $max, map $slices->[$_]->{'species'}, $i-1, $i) if $join_genes;
        
        push @images, $primary_slice, $primary_image_config;
      }
    }
    
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'bottom';
  
  my $html = $image->render;
  
  $html .= $self->_info(
    'Configuring the display',
    '<p>To change the tracks you are displaying, use the "<strong>Configure this page</strong>" link on the left.</p>'
  );
  
  return $html;
}

1;
