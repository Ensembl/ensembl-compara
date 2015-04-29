=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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