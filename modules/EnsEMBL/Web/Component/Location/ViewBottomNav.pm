# $Id$

package EnsEMBL::Web::Component::Location::ViewBottomNav;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1); # Must be ajaxable for slider/button nav stuff to work properly.
}

sub content_region {
  return shift->content([ [4,1e4], [6,5e4], [8,1e5], [10,5e5], [12,1e6], [14,2e6], [16,5e6], [18,1e7] ], 'region')
}

sub content {
  my $self             = shift;
  my $ramp_entries     = shift || [ [4,1e3], [6,5e3], [8,1e4], [10,5e4], [12,1e5], [14,2e5], [16,5e5], [18,1e6] ];
  my $hub              = $self->hub;
  my $object           = $self->object;
  my $image_width      = $self->image_width . 'px';
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;
  my $cp               = int(($seq_region_end + $seq_region_start) / 2);
  my $wd               = $seq_region_end - $seq_region_start + 1;
  my $r                = $hub->param('r');
  
  $self->{'update'} = $hub->param('update_panel');
  
  my $values = [
    $self->ajax_url(shift, 1) . ";r=$r",
    $r,
    $self->nav_url($seq_region_start - 1e6, $seq_region_end - 1e6),
    $self->nav_url($seq_region_start - $wd, $seq_region_end - $wd),
    $self->nav_url($cp - int($wd/4) + 1, $cp + int($wd/4)),
    $self->nav_url($cp - $wd + 1, $cp + $wd),
    $self->nav_url($seq_region_start + $wd, $seq_region_end + $wd),
    $self->nav_url($seq_region_start + 1e6, $seq_region_end + 1e6)
  ];
  
  my $ramp = $self->ramp($ramp_entries, $wd, $cp);
  
  unshift @$values, $ramp if $self->{'update'};
  
  return $self->{'update'} ? $self->jsonify($values) : $self->navbar($ramp, $wd, $values);
}

sub navbar {
  my ($self, $ramp, $wd, $values) = @_;
  
  my $hub          = $self->hub;
  my $image_width  = $self->image_width . 'px';
  my $url          = $hub->url({ %{$hub->multi_params(0)}, r => undef }, 1);
  my $form_action  = $hub->url({ type => 'psychic', action => 'Location', __clear => 1 });
  my $extra_inputs = join '', map { sprintf '<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_}) } keys %{$url->[1]||{}};
  
  return sprintf (qq{
    <div class="autocenter_wrapper">
      <div class="autocenter navbar print_hide js_panel" style="width:$image_width">
        <input type="hidden" class="panel_type" value="LocationNav" />
        <input type="hidden" class="update_url" value="%s" />
        <div class="relocate">
          <form action="$form_action" method="get">
            Location:
              $extra_inputs
              <label class="hidden" for="q">Location</label><input name="q" id="q" class="location_selector" style="width:20em" value="%s" type="text" />
              <input value="Go &gt;" type="submit" class="go-button" />
          </form>
        </div>
        <div class="image_nav">
          <a href="%s" class="move"><img src="/i/nav-l2.gif" class="zoom" alt="1Mb left" /></a>
          <a href="%s" class="move"><img src="/i/nav-l1.gif" class="zoom" alt="window left" /></a>
          <a href="%s" class="zoom_in"><img src="/i/zoom-plus.gif" class="zoom" alt="zoom in" /></a>
          <span class="ramp">$ramp</span>
          <span class="slider_wrapper">
            <span class="slider_left"></span>
            <span class="slider"><span class="slider_label floating_popup">$wd</span></span>
            <span class="slider_right"></span>
          </span>
          <a href="%s" class="zoom_out"><img src="/i/zoom-minus.gif" class="zoom" alt="zoom out" /></a>
          <a href="%s" class="move"><img src="/i/nav-r1.gif" class="zoom" alt="window left" /></a>
          <a href="%s" class="move"><img src="/i/nav-r2.gif" class="zoom" alt="1Mb left" /></a>
        </div>
        <div class="invisible"></div>
      </div>
    </div>},
    @$values
  );
}

sub ramp {
  my ($self, $ramp_entries, $wd, @url_params) = @_;
  
  my $scale = $self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1;
  my $x     = 0;
  my ($ramp, @mp);
  
  foreach (@$ramp_entries) {
    $_->[1] *= $scale;
    push @mp, sqrt($x * $_->[1]);
    $x = $_->[1];
  }
  
  push @mp, 1e30;
  
  my $l = shift @mp;
  
  if ($self->{'update'}) {
    $ramp = 0;
    
    for (0..$#$ramp_entries) {
      my $r = shift @mp;
      
      if ($wd > $l && $wd <= $r) {
        $ramp = $_;
        last;
      }
      
      $l = $r;
    }
  } else {
    foreach (@$ramp_entries) {
      my $r = shift @mp; 
      
      $ramp .= sprintf(
        '<a href="%s" name="%d" class="ramp%s"><img title="%d bp" alt="%s bp" src="/i/blank.gif" style="height:%dpx" /></a>',
        $self->ramp_url($_->[1], @url_params),
        $_->[1], 
        $wd > $l && $wd <= $r ? ' selected' : '',
        $_->[1], 
        $_->[1],
        $_->[0]
      );
      
      $l = $r;
    }
  }
  
  return $ramp;
}

sub ramp_url {
  my ($self, $entry, $cp) = @_;
  return $self->nav_url($cp - ($entry/2) + 1, $cp + $entry/2);
}

sub nav_url {
  my ($self, $s, $e) = @_;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $max    = $object->seq_region_length;
  
  ($s, $e) = (1, $e - $s || 1) if $s < 1;
  ($s, $e) = ($max - ($e - $s), $max) if $e > $max;
  
  $s = $e if $s > $e;
  
  return $object->seq_region_name . ':' . $s . '-' . $e if $self->{'update'};
  
  return $hub->url({ 
    %{$hub->multi_params(0)},
    r => $object->seq_region_name . ':' . $s . '-' . $e
  });
}

1;
