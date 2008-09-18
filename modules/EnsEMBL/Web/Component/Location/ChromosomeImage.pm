package EnsEMBL::Web::Component::Location::ChromosomeImage;

### Module to replace part of the former MapView, in this case displaying 
### an overview image of an individual chromosome 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
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

  my $config = $object->get_imageconfig($config_name);
  my $ideo_height = $config->{'_image_height'};
  my $top_margin  = $config->{'_top_margin'};
  my $hidden = {
            'seq_region_name'   => $chr_name,
            'seq_region_width'  => '100000',
            'seq_region_left'   => '1',
            'seq_region_right'  => $object->Obj->{'slice'}->seq_region_length,
            'click_right'       => $ideo_height+$top_margin,
            'click_left'        => $top_margin,
    };

  my $image    = $object->new_karyotype_image();
  $image->cacheable          = 'no';
  $image->image_type         = 'chromosome';
  $image->image_name         = $species.'-'.$chr_name;
  $image->imagemap           = 'no';

  ## Check if there is userdata in session
  my $userdata = $object->get_session->get_tmp_data;
  use Data::Dumper;
  my $pointers = [];

  if ($userdata && $userdata->{'filename'}) {
    ## Set some basic image parameters
    $image->imagemap = 'no';
    $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
    $image->caption = 'Click on the image above to jump to an overview of the chromosome';

    ## Create pointers from user data
    my $pointer_set = $self->create_userdata_pointers($image, $userdata);
    push(@$pointers, $pointer_set);
  }

  my $script = $object->species_defs->NO_SEQUENCE ? 'Overview' : 'View';
  $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
  $image->add_tracks($object, $config_name);
  $image->karyotype($object, $pointers, $config_name);
  $image->caption = 'Click on the image above to zoom into that point';
  return $image->render;
}

1;
