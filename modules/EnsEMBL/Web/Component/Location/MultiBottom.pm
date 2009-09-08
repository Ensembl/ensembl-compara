package EnsEMBL::Web::Component::Location::MultiBottom;

use strict;
use warnings;
no warnings "uninitialized";

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
  my $i               = 1;
  my $primary_image_config;
  my @images;
  
  my $methods = {
    BLASTZ_NET          => $object->param('pairwise_blastz'),
    TRANSLATED_BLAT_NET => $object->param('pairwise_tblat'),
    OTHER               => $object->param('pairwise_align')
  };
  
  my $multi = grep /yes/, values %$methods;
  my $compara_db = new EnsEMBL::Web::DBSQL::DBConnection($primary_species)->_get_compara_database if $multi;
  
  foreach (@$slices) {
    my $image_config = $object->image_config_hash("contigview_bottom_$i", 'MultiBottom', $_->{'species'});
    my $highlight_gene = $object->param('g' . ($i-1));
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width,
      slice_number    => "$i|3",
      multi           => 1,
      compara         => $i == 1 ? 'primary' : $_->{'species'} eq $primary_species ? 'paralogue' : 'secondary',
      base_url        => $base_url
    });
    
    $image_config->get_node('scalebar')->set('caption', $_->{'short_name'});
    
    $_->{'slice'}->adaptor->db->set_adaptor('compara', $compara_db) if $compara_db;
    
    if ($i == 1) {
      $image_config->multi($methods, $i, $max, { species => $slices->[$i]->{'species'}, ori => $slices->[$i]->{'strand'} }) if $multi && $max == 2;
      
      push @images, $primary_slice, $image_config if $max < 3;
      
      $primary_image_config = $image_config;
    } else {
      $image_config->multi($methods, $i, $max, { species => $primary_species, ori => $primary_strand }) if $multi;
      $image_config->highlight($highlight_gene) if $highlight_gene;
      
      push @images, $_->{'slice'}, $image_config;
      
      if ($max > 2 && $i < $max) {
        # Make new versions of the primary image config because the alignments required will be different each time
        if ($multi) {
          my @sl = map { species => $slices->[$_]->{'species'}, ori => $slices->[$_]->{'strand'} }, $i-1, $i;
          
          $primary_image_config = $object->image_config_hash("contigview_bottom_1_$i", 'MultiBottom', $primary_species);
          
          $primary_image_config->set_parameters({
            container_width => $primary_slice->length,
            image_width     => $image_width,
            slice_number    => '1|3',
            multi           => 1,
            compara         => 'primary',
            base_url        => $base_url
          });
          
          $primary_image_config->get_node('scalebar')->set('caption', $short_name);
          $primary_image_config->multi($methods, 1, $max, @sl);
        }
        
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
