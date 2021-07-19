=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Apache::ServerError;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub get_template {
  my $r       = shift;
  my $request = $r->headers_in->get('X-Requested-With') || '';

 return $request eq 'XMLHttpRequest' ? 'EnsEMBL::Web::Template::AjaxError' : 'EnsEMBL::Web::Template::Error';
}

sub handler {
  ## Handles 500 errors (via /Crash) and internal exceptions (called by EnsEMBL::Web::Apache::Handlers)
  ## @param Apache2::RequestRec request object
  ## @param EnsEMBL::Web::SpeciesDefs object (only when called by EnsEMBL::Web::Apache::Handlers)
  ## @param EnsEMBL::Web::Exception object (only when called by EnsEMBL::Web::Apache::Handlers)
  my ($r, $species_defs, $exception) = @_;

  my ($content, $content_type);

  my $to_logs = $SiteDefs::SERVER_ERRORS_TO_LOGS;
  my $heading = '500 Server Error';
  my $message = !$to_logs && $exception && "$exception" || 'An unknown error has occurred';
  my $is_html = 0;

  try {

    my $message_pre = '';

    if ($exception) {
      my $error_id  = substr(md5_hex($exception->message), 0, 10); # in most cases, will generate same code for same errors
      my $uri       = $r->unparsed_uri;
      $is_html      = $to_logs;
      $heading      = sprintf 'Server Exception: %s', $exception->type;
      $message      = sprintf("Request: %s\nReference: %s\nError: %s ...", $uri, $error_id, substr($exception->message, 0, 50) =~ s/\R//gr);
      $message_pre  = $to_logs ? encode_entities($message) : "$exception";
      $message      = $to_logs
        ? sprintf(q(There was a problem with our website.
                      Please report this issue to <a href="mailto:%s?subject=%s&body=%s">%1$s</a>
                      with the details below.),
                      $SiteDefs::ENSEMBL_HELPDESK_EMAIL, encode_entities(uri_escape($heading)), encode_entities(uri_escape($message)))
        : $exception->type;

      warn "ERROR: $error_id ($uri) (Server Exception)\n" if $to_logs;
      warn $exception;
    }

    my $template = dynamic_require(get_template($r))->new({
      'species_defs'    => $species_defs,
      'heading'         => $heading,
      'message'         => $message,
      'content'         => $message_pre,
      'helpdesk'        => 1,
      'back_button'     => 1,
      'message_is_html' => $is_html
    });

    $content_type = $template->content_type;
    $content      = $template->render;

  } catch {
    warn $_;
    $content_type = 'text/plain; charset=utf-8';
    $content      = "$heading\n\n$message";
  };

  $r->status(Apache2::Const::SERVER_ERROR);
  $r->content_type($content_type) if $content_type;
  $r->print($content);

  return undef;
}

1;
