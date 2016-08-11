=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::Config;

### Prints the configuration modal dialog and accepts config change request when the same dialog form us submitted

use strict;
use warnings;

use JSON;

use EnsEMBL::Web::Exceptions qw(WebException);

use parent qw(EnsEMBL::Web::Controller::Modal);

sub init {
  ## @override
  my $self  = shift;
  my $hub   = $self->hub;

  if ($hub->param('submit')) {
    $self->update_configuration;
  } else {
    $self->SUPER::init(@_);
  }
}

sub page_type {
  ## @override
  return 'Configurator';
}

sub _create_objects {
  ## @override
}

sub update_configuration {
  ## Handles the request to make changes to the configs (when the config modal form is submitted)
  my $self        = shift;
  my $r           = $self->r;
  my $hub         = $self->hub;
  my $view_config = $hub->get_viewconfig($hub->action);
  my $response    = {};

  throw WebException('ViewConfig missing') unless $view_config;

  my $params = { map { my $val = $hub->param($_); ($_ => $hub->param($_)) } $hub->param }; # update_from_input doesn't expect multiple values for a single param

  $params->{$_} = from_json($params->{$_} || '{}') for qw(image_config view_config);

  if ($view_config->update_from_input($params)) {
    $hub->session->store_records;
    $response->{'updated'} = 1;
  }

  $r->content_type('text/plain');
  $r->print(to_json($response));
}

1;
