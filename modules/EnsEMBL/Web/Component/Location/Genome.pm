package EnsEMBL::Web::Component::Location::Genome;

### Module to replace Karyoview

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
use Data::Dumper;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::Text;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;

  return unless $object->species_defs->ENSEMBL_CHROMOSOMES;

  ## Form with hidden elements for click-through
  my $config = $object->image_config_hash('Vkaryotype');
     $config->set_parameter(
       'container_width',
       $object->species_defs->MAX_CHR_LENGTH
     );

  my $ideo_height = $config->get_parameter('image_height');
  my $top_margin  = $config->get_parameter('top_margin');

  my $image    = $object->new_karyotype_image();

  my $pointers = [];
  my %pointer_defaults = (
    'DnaAlignFeature'     => ['blue', 'lharrow'],
    'ProteinAlignFeature' => ['blue', 'lharrow'],
    'RegulatoryFactor'    => ['blue', 'lharrow'],
    'Gene'                => ['blue', 'lharrow'],
    'OligoProbe'          => ['red', 'rharrow'],
    'XRef'                => ['red', 'rharrow'],
    'UserData'            => ['darkgreen', 'lharrow'],
  );
  
  ## Check if there is userdata in session
  my $userdata = $object->get_session->get_tmp_data;

  #warn keys %$userdata; 
  ## Do we have feature "tracks" to display?
  my $hidden = {
    'karyotype'   => 'yes',
    'max_chr'     => $ideo_height,
    'margin'      => $top_margin,
    'chr'         => $object->seq_region_name,
    'start'       => $object->seq_region_start,
    'end'         => $object->seq_region_end,
  };

  if( $userdata && $userdata->{'filename'} ) {
    ## Set some basic image parameters
    $image->imagemap = 'no';
    $image->caption = 'Click on the image above to jump to an overview of the chromosome';
   
    ## Create pointers from user data
    my $pointer_set = $self->create_userdata_pointers($image, $userdata, $pointer_defaults{'UserData'});
    push(@$pointers, $pointer_set);
  } 
  if ($object->param('id')) { ## "FeatureView"
    $image->image_name = "feature-$species";
    $image->imagemap = 'yes';
    my $features = $object->create_features; ## Now that there's no Feature factory, we create these on the fly
    ## TODO: Should there be some generic object->hash functionality for use with drawing code?
    my @f_hashes = @{$object->retrieve_features($features)};
    my $i = 0;
    my $zmenu_config;
    foreach my $ftype  (@f_hashes) {
      my $pointer_ref = $image->add_pointers( $object, {
        'config_name'  => 'Vkaryotype',
        'features'      => \@f_hashes,
        'zmenu_config'  => $zmenu_config,
        'feature_type'  => $ftype,
        'color'         => $object->param("col_$i")   || $pointer_defaults{$ftype}[0],
        'style'         => $object->param("style_$i") || $pointer_defaults{$ftype}[1]}
      );
      push(@$pointers, $pointer_ref);
      $i++;
    }
  } 
  if (!@$pointers) { ## Ordinary "KaryoView"
    $image->image_name = "karyotype-$species";
    $image->imagemap = 'no';
    $image->caption = 'Click on the image above to jump to an overview of the chromosome';
  }
  
  $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
  $image->karyotype( $object, $pointers, 'Vkaryotype' );
  my $html = $image->render;

  if ($object->param('id')) { ## FeatureView
    $html .= $self->feature_table;
  }
  elsif (@$pointers) {
    ## User data - do nothing at the moment
  }
  else {
    my $file = '/ssi/species/stats_'.$object->species.'.html';
    $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file);
  }

  return $html;
}

sub feature_table {
  my $self = shift;
  my $object = $self->object;
  my $table;
  return $table;
}


1;
