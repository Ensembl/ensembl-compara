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

package EnsEMBL::Web::Controller::Json;

use strict;
use warnings;

use Apache2::RequestUtil;
use JSON qw(to_json);

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Exceptions;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class     = shift;
  my $r         = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args      = shift || {};
  my $hub       = EnsEMBL::Web::Hub->new({
    apache_handle  => $r,
    session_cookie => $args->{'session_cookie'},
    user_cookie    => $args->{'user_cookie'},
  });

  my $self      = bless {
    r             => $r,
    hub           => $hub,
    cache         => $hub->cache,
    type          => $hub->type,
    action        => $hub->action,
    function      => $hub->function,
  }, $class;

  $CGI::POST_MAX = $self->upload_size_limit; # Set max upload size

  $hub->{'_input'} = $self->{'input'} = CGI->new; # Hack to force the new upload limit! FIXME!

  my ($json, $chunked);

  try {

    if (($hub->input->cgi_error || '') =~ /413/) {
      throw exception('InputError', sprintf 'File exceeds the size limit of %d MB', $CGI::POST_MAX / (1024 * 1024));
    }

    my @path      = ($hub->type, $hub->action || (), $hub->function || ());
    my $method    = sprintf 'json_%s', pop @path;
    my $on_update = ($hub->param('X-Comet-Request') || '') eq 'true' || undef;
    my $json_page = 'EnsEMBL::Web::JSONServer';
       $json_page = $self->dynamic_use_fallback(reverse map {$json_page = "${json_page}::$_"} @path);

    if ($on_update && $json_page) {
      $chunked = 1;
      my $js_update_method = $hub->param('_cupdate');
      $r->content_type('text/html');
      print "<!DOCTYPE HTML><html><head>";

      $on_update = sub {
        my $obj = shift;
        print sprintf '<script>%s(%s);</script>', $js_update_method, to_json($obj);
        $r->rflush;
      };
    }

    $json = $json_page && ($json_page = $json_page->new($hub)) && $json_page->can($method) ? $json_page->$method($on_update) : {'header' => {'status' => '404'}};
    $json->{'header'}{'status'} ||= 200;

  } catch {
    warn $_;
    $json = {'header' => {'status' => 500}, 'exception' => {'type' => $_->type, 'message' => $_->message, 'stack' => $_->stack_trace}};
  };

  print sprintf $chunked ? '</head><body>%s</body></html>' : '%s', to_json($json);

  return $self;
}

1;
