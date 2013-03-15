package EnsEMBL::Web::Component::ViewNav;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->ajaxable(0);
}

sub content {
  my $self             = shift;

  my $hub              = $self->hub;
  my $image_width      = $self->image_width . 'px';
  my $url              = $hub->url({'type' => 'Location', 'action' => 'View'});

  return qq{
      <div class="navbar print_hide" style="width:$image_width">
        <a href="$url"><img src="/i/48/region_thumb.png" title="Go to Region in Detail for more options" style="border:1px solid #ccc;margin:0 16px;vertical-align:middle" /></a> Go to <a href="$url" class="no-visit">Region in Detail</a> for more tracks and navigation options (e.g. zooming)
      </div>};
}

1;
