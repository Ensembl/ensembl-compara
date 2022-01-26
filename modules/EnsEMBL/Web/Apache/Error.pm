=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Apache::Error;

use strict;
use warnings;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub get_template {
  my $r       = shift;
  my $request = $r->headers_in->get('X-Requested-With') || '';

 return $request eq 'XMLHttpRequest' ? 'EnsEMBL::Web::Template::AjaxError' : 'EnsEMBL::Web::Template::Error';
}

sub handler {
  ## Handles 4** errors (via /Error)
  ## @param Apache2::RequestRec request object
  my $r = shift;

  my ($content, $content_type);

  my $heading = '404 Not Found'; # TODO - not always 404
  my $message = 'Please check that you have typed in the correct URL or else use the <a href="/Multi/Search/Results">site search</a> facility to try and locate information you require.<br />If you think an error has occurred, please <a href="//www.ensembl.org/Help/Contact">contact our HelpDesk</a>';

  try {

    my $template = dynamic_require(get_template($r))->new({
      'title'           => $heading,
      'heading'         => 'Page not found',
      'message'         => $message,
      'message_is_html' => 1,
      'helpdesk'        => 1,
      'back_button'     => 1
    });

    $content_type = $template->content_type;
    $content      = $template->render;

  } catch {
    warn $_;
    $content_type = 'text/plain; charset=utf-8';
    $content      = "$heading\n\n$message";
  };

  $r->content_type($content_type) if $content_type;
  $r->print($content);

  return undef;
}

1;
