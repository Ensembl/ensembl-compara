=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  
  my $ramp = $self->ramp($min||1e3,$max||1e6,$length);
  return $self->navbar($ramp);
}

sub navbar {
  my ($self, $ramp,$extra_params) = @_;
  
  my $hub          = $self->hub;
  my $img_url      = $self->img_url;
  my $image_width  = $self->image_width . 'px';
  my $url          = $hub->url({ %{$hub->multi_params(0)}, function => undef, r => undef, g => undef }, 1);
  my $psychic      = $hub->url({ type => 'psychic', action => 'Location', __clear => 1 });
  my $extra_inputs = join '', map { sprintf '<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_}) } keys %{$url->[1] || {}};
  my $g            = $hub->param('g');
  my $g_input      = $g ? qq{<input name="g" value="$g" type="hidden" />} : '';
  $extra_params = "?$extra_params" if $extra_params;
  $extra_params ||= '';
  
  return qq(
      <div class="navbar print_hide" style="width:$image_width">
        <input type="hidden" class="panel_type" value="LocationNav" />
        <div class="relocate">
          <form action="$url->[0]" method="get">
            <label for="loc_r">Location:</label>
            $extra_inputs
            $g_input
            <input name="r" id="loc_r" class="location_selector" value="" type="text" />
            <a class="go-button" href="">Go</a>
          </form>
          <div class="js_panel" style="float: left; margin: 0">
            <input type="hidden" class="panel_type" value="AutoComplete" />
            <form action="$psychic" method="get" class="autocomplete">
              <label for="loc_q">Gene:</label>
              $extra_inputs
              <input name="g" value="" type="hidden" />
              <input name="q" id="loc_q" class="autocomplete" value="" type="text" />
              <a class="go-button" href="">Go</a>
            </form>
          </div>
        </div>
        <div class="image_nav">
          <a href="$extra_params" style="display:none" class="extra-params">.</a>
          <a href="#" class="move left_2" title="Back 1Mb"></a>
          <a href="#" class="move left_1" title="Back 1 window"></a>
          <a href="#" class="zoom_in" title="Zoom in"></a>
          <span class="ramp">$ramp</span>
          <span class="slider_wrapper">
            <span class="slider_left"></span>
            <span class="slider"><span class="slider_label floating_popup"></span></span>
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
