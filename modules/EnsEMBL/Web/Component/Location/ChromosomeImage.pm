package EnsEMBL::Web::Component::Location::ChromosomeImage;

### Module to replace part of the former MapView, in this case displaying 
### an overview image of an individual chromosome 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $config_name = 'Vmapview';
  my $species   = $object->species;
  my $chr_name  = $object->seq_region_name;

  my $config = $object->image_config_hash($config_name);
     $config->set_parameters({
       'container_width', $object->Obj->{'slice'}->seq_region_length,
       'slice_number'    => '2|1'
     });
  my $ideo_height = $config->get_parameter('image_height');
  my $top_margin  = $config->get_parameter('top_margin');
  my $hidden = {
    'seq_region_name'   => $chr_name,
    'seq_region_width'  => '100000',
    'seq_region_left'   => '1',
    'seq_region_right'  => $object->Obj->{'slice'}->seq_region_length,
    'click_right'       => $ideo_height+$top_margin,
    'click_left'        => $top_margin,
  };

  $config->get_node('Videogram')->set('label',   ucfirst($object->seq_region_type) );
  $config->get_node('Videogram')->set('label_2', $chr_name );
  my $image    = $object->new_karyotype_image();
    $image->image_type         = 'chromosome';
    $image->image_name         = $species.'-'.$chr_name;
    $image->set_button('drag', 'title' => 'Click or drag to jump to a region' );
    $image->imagemap         = 'yes';
    $image->{'panel_number'} = 'chrom';

  my $script = $object->species_defs->NO_SEQUENCE ? 'Overview' : 'View';
  $image->add_tracks($object, $config_name);
  $image->karyotype($object, undef, $config_name);
  $image->caption = 'Click on the image above to zoom into that point';
  return $image->render;
}

1;
