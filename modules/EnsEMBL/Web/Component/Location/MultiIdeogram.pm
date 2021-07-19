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

package EnsEMBL::Web::Component::Location::MultiIdeogram;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $image_width = $self->image_width;
  my $object      = $self->object || $self->hub->core_object('location');
  my $i           = 1;
  my @images;
  
  foreach (@{$object->multi_locations}) {
    my $image_config      = $hub->get_imageconfig({type => 'chromosome', cache_code => "chromosome_$i", species => $_->{'species'}});
    my $chromosome        = $_->{'slice'}->adaptor->fetch_by_region(undef, $_->{'name'});
    my $annotation_status = $image_config->get_node('annotation_status');
    
    $image_config->set_parameters({
      container_width => $chromosome->seq_region_length,
      image_width     => $image_width,
      slice_number    => "$i|1",
      multi           => 1
    });
    
    if ($annotation_status) {
      $annotation_status->set('caption', '');
      $annotation_status->set('menu', 'no');
    };

    $image_config->get_node('ideogram')->set('caption', $_->{'short_name'});
    
    push @images, $chromosome, $image_config;
    $i++;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'ideogram';
  
  return $image->render;
}

1;
