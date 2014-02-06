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

package EnsEMBL::Web::Controller::Json;

use strict;
use warnings;

use Apache2::RequestUtil;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Exceptions;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class     = shift;
  my $r         = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args      = shift || {};
  my $self      = bless {}, $class;

  my $json;

  try {
    my $hub = EnsEMBL::Web::Hub->new({
      apache_handle  => $r,
      session_cookie => $args->{'session_cookie'},
      user_cookie    => $args->{'user_cookie'},
    });

    my @path      = ($hub->type, $hub->action || (), $hub->function || ());
    my $method    = sprintf 'json_%s', pop @path;
    my $json_page = 'EnsEMBL::Web::JSONServer';
       $json_page = $self->dynamic_use_fallback(reverse map {$json_page = "${json_page}::$_"} @path);

    $json         = $json_page && ($json_page = $json_page->new($hub)) && $json_page->can($method) ? $json_page->$method : {'header' => {'status' => '404'}};
    $json->{'header'}{'status'} ||= 200;

  } catch {
    warn $_;
    $json         = {'header' => {'status' => 500}, 'exception' => {'type' => $_->type, 'message' => $_->message, 'stack' => $_->stack_trace}};
  };

  print $self->jsonify($json);

  return $self;
}

1;