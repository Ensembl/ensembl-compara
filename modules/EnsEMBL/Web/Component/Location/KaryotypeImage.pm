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

  ## Do we have feature "tracks" to display?
  my $pointers;
  my %pointer_defaults = (
        'Gene'      => ['blue', 'lharrow'],
        'OligoProbe' => ['red', 'rharrow'],
  );
  if ($object->param('id')) {
    $image->cacheable  = 'no';
    $image->image_name = "feature-$species";
    $image->imagemap = 'yes';
    my $features = $self->_get_features;
    my @pointers = ();
    my $i = 0;
    my $zmenu_config;
    foreach my $ftype  (keys %$features) {
      my $pointer_ref = $image->add_pointers(
			    $object,
			    {'config_name'  => 'Vkaryotype',
			    'zmenu_config' => $zmenu_config,
			    'feature_type' => $ftype,
			    'color'        => $object->param("col_$i")
			                         || $pointer_defaults{$ftype}[0],
			    'style'        => $object->param("style_$i")
			                         || $pointer_defaults{$ftype}[1]}
			 );
      push(@pointers, $pointer_ref);
      $i++;
    }
  }
  else {
    $image->cacheable  = 'yes';
    $image->image_name = "karyotype-$species";
    $image->imagemap = 'no';
    $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
    $image->caption = 'Click on the image above to jump to an overview of the chromosome';
  }
  
  $image->karyotype( $object, $pointers, 'Vkaryotype' );

  return $image->render;
}

sub _get_features {
### Creates some raw API objects of the selected type(s), 
### and returns a ref to hash whose keys are the types
  my $self = shift;
  my $object = $self->object;
  my $features = {};
  return $features;
}

1;
