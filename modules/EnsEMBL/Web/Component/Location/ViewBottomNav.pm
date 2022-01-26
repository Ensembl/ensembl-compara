=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::ViewBottomNav;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->ajaxable(1);  # Must be ajaxable for slider/button nav stuff to work properly.
  $self->has_image(2); # Cache key and tags depend on image width, so lie about having images so that they are correct. Setting has_image to something other than 1 stops the image_panel class being added
}

sub set_cache_key {
  my $self = shift;
  $self->SUPER::set_cache_key;
}

sub content_region {
  return $_[0]->content(1e4,1e7);
}

sub content {
  my ($self,$min,$max) = @_;

  my $length = -1;
  my $object = $self->hub->core_object('Location');
  $length = $object->seq_region_length if $object;
  
  my $ramp = $self->ramp($min||1e2,$max||1e6,$length);
  return $self->navbar($ramp);
}

sub navbar {
  my ($self, $ramp) = @_;
  
  my $hub          = $self->hub;
  my $img_url      = $self->img_url;
  my $image_width  = $self->image_width . 'px';
  my $url          = $hub->url({ r => undef, g => undef, __clear => 1 });

  return qq(
      <div class="navbar print_hide" style="width:$image_width">
        <input type="hidden" class="panel_type" value="LocationNav" />
        <div class="relocate">
          <form action="$url" method="get" class="_nav_loc">
            <label for="loc_r">Location:</label>
            <input name="r" id="loc_r" value="" type="text" />
            <a class="go-button" href="">Go</a>
          </form>
          <div class="navgene">
            <form action="$url" method="get" class="_nav_gene">
              <label for="loc_g">Gene:</label>
              <input name="q" id="loc_q" type="text" />
              <a class="go-button" href="">Go</a>
            </form>
          </div>
        </div>
        <div class="image_nav">
          <a href="#" class="move left_2" title="Back 1Mb"></a>
          <a href="#" class="move left_1" title="Back 1 window"></a>
          <a href="#" class="zoom_in" title="Zoom in"></a>
          <span class="ramp hidden">$ramp</span>
          <span class="slider_wrapper">
            <span class="slider_left"></span>
            <span class="slider"><span class="slider_label helptip"></span></span>
            <span class="slider_right"></span>
          </span>
          <a href="#" class="zoom_out" title="Zoom out"></a>
          <a href="#" class="move right_1" title="Forward 1 window"></a>
          <a href="#" class="move right_2" title="Forward 1Mb"></a>
        </div>
        <div class="invisible"></div>
      </div>);
}

sub ramp {
  my ($self,$min,$max,$length) = @_;
  
  my $scale = $self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1;
  $length = 0+$length;
  $max *= $scale;
  $min *= $scale;
  $max = $length if $length > 0 and $length < $max;
  my $json = $self->jsonify({
    min => $min,
    max => $max,
    'length' => 0+$length,
  });
  return $json;
}

1;
