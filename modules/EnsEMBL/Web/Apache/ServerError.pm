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

package EnsEMBL::Web::Apache::ServerError;

use strict;
use warnings;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Template::Error;

sub get_template {
  return 'EnsEMBL::Web::Template::Error';
}

sub handler {
  ## Handles 500 errors (via /Crash) and internal exceptions (called by EnsEMBL::Web::Apache::Handlers)
  ## @param Apache2::RequestRec request object
  ## @param EnsEMBL::Web::SpeciesDefs object (only when called by EnsEMBL::Web::Apache::Handlers)
  ## @param EnsEMBL::Web::Exception object (only when called by EnsEMBL::Web::Apache::Handlers)
  my ($r, $species_defs, $exception) = @_;

  my ($content, $content_type);

  my $heading = '500 Server Error';
  my $message = 'An unknown error has occurred';
  my $stack   = '';

  try {

    if ($exception) {
      $heading  = sprintf 'Server Exception: %s', $exception->type;
      $message  = $exception->message;
      $stack    = $exception->stack_trace;
      warn $exception;
    }

    $content_type = 'text/html';
    $content      = get_template->new({
      'species_defs'  => $species_defs,
      'heading'       => $heading,
      'message'       => $message,
      'content'       => $stack,
      'helpdesk'      => 1,
      'back_button'   => 1
    })->render;

  } catch {
    warn $_;
    $content_type = 'text/plain';
    $content      = "$heading\n\n$message\n\n$stack";
  };

  $r->status(Apache2::Const::SERVER_ERROR);
  $r->content_type($content_type) if $content_type;
  $r->print($content);

  return undef;
}

1;
