=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::RandomString qw(random_string);
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

  my $to_logs = $species_defs && $species_defs->SERVER_ERRORS_TO_LOGS;
  my $heading = '500 Server Error';
  my $message = !$to_logs && $exception && "$exception" || 'An unknown error has occurred';

  try {

    if ($exception) {
      my $error_id  = random_string(8);
      $heading      = sprintf 'Server Exception: %s', $exception->type;
      $message      = $to_logs
        ? sprintf(q(There was a problem with our website. Please report this issue to %s, quoting error reference '%s'.), $species_defs->ENSEMBL_HELPDESK_EMAIL, $error_id)
        : "$exception";

      warn "ERROR: $error_id (Server Exception)\n" if $to_logs;
      warn $exception;
    }

    my $template = dynamic_require(get_template($r))->new({
      'species_defs'  => $species_defs,
      'heading'       => $heading,
      'message'       => $message,
      'helpdesk'      => 1,
      'back_button'   => 1
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
