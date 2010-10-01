# $Id$

package EnsEMBL::Web::Component::Location::MultiBottomNav;

use strict;

use base qw(EnsEMBL::Web::Component::Location::ViewBottomNav);

sub content {
  my $self         = shift;
  my $ramp_entries = shift || [ [4,1e3], [6,5e3], [8,1e4], [10,5e4], [12,1e5], [14,2e5], [16,5e5], [18,1e6] ];
  my $hub          = $self->hub;
  
  return if $hub->param('show_panels') eq 'top';
  
  my $object           = $self->object;
  my $image_width      = $self->image_width . 'px';
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;
  my $wd               = $seq_region_end - $seq_region_start + 1;
  
  my $values = [
    $self->ajax_url,
    $object->seq_region_name,
    $seq_region_start,
    $seq_region_end,
    $self->nav_url(-1e6),
    $self->nav_url(-$wd),
    $self->nav_url($wd/2, 'resize'),
    $self->nav_url($wd*2, 'resize'),
    $self->nav_url($wd),
    $self->nav_url(1e6)
  ];
  
  return $hub->param('update_panel') ? $self->jsonify($values) : $self->navbar($self->ramp($ramp_entries, $wd), $wd, $values);
}

sub ramp_url { return shift->nav_url(shift, 'resize'); }

sub nav_url {
  my ($self, $p, $resize) = @_;
  
  my $hub    = $self->hub;
  my %params = ( multi_action => 'all' );
  $params{$resize ? 'all_w' : 'all_s'} = $p;
  
  return $hub->url({
    %{$hub->multi_params},
    %params
  });
}

1;
