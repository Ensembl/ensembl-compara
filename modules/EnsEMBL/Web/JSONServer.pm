package EnsEMBL::Web::JSONServer;

## Abstract parent class for all pages that return JSON

use strict;
use warnings;

use base qw(EnsEMBL::Web::Root);
use EnsEMBL::Web::Exceptions;

sub new {
  my ($class, $hub) = @_;
  return bless {'_hub' => $hub}, $class;
}

sub object {
  my $self = shift;
  return $self->new_object($self->object_type, {}, {'_hub' => $self->hub});
}

sub object_type {
  ## @abstract
  throw exception('NotImplimented', 'Abstract method not implemented.');
}

sub hub {
  return shift->{'_hub'};
}

sub redirect {
  my ($self, $url, $json)       = @_;
  $json                       ||= {};
  $json->{'header'}           ||= {};
  $json->{'header'}{'status'}   = 302;
  $json->{'header'}{'location'} = $self->hub->url($url);

  return $json;
}

sub call_js_panel_method {
  my ($self, $method_name, $method_args) = @_;
  return {'panelMethod' => [ $method_name, @{$method_args || []} ]};
}

1;