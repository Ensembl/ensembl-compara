package EnsEMBL::Web::Component::Location::KaryotypeImage;

### Module to replace Karyoview

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;

  ## Form with hidden elements for click-through
  my $config = $object->get_userconfig('Vkaryotype');
  my $ideo_height = $config->{'_image_height'};
  my $top_margin  = $config->{'_top_margin'};
  my $hidden = {
            'karyotype'   => 'yes',
            'max_chr'     => $ideo_height,
            'margin'      => $top_margin,
            'chr'         => $object->seq_region_name,
            'start'       => $object->seq_region_start,
            'end'         => $object->seq_region_end,
    };

  my $image    = $object->new_karyotype_image();
  $image->cacheable  = 'yes';
  $image->image_name = "karyotype-$species";
  $image->imagemap = 'no';
  $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
  $image->caption = 'Click on the image above to jump to an overview of the chromosome';
  $image->karyotype( $object, '', 'Vkaryotype' );

  return $image->render;
}

1;
