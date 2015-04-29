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

package EnsEMBL::Web::Apache::Error;

### Serves standard Apache error messages within an Ensembl static page
       
use strict;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Document::Panel;

sub handler {
  my $r              = shift;
  my $error_number   = $ENV{'REDIRECT_STATUS'};
  my $error_url      = $ENV{'REDIRECT_URL'};
  my %error_messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;
  
  my ($error_subject, $error_text) = @{$error_messages{$error_number} || []};
     ($error_subject, $error_text) = (" 'Unrecognised error' ", $ENV{'REDIRECT_ERROR_NOTES'}) unless $error_subject;
  
  warn "$error_number ERROR: $error_subject $error_url\n";
  
  my $controller = EnsEMBL::Web::Controller->new($r, { page_type => 'Static', renderer_type => 'Apache' });
  my $page       = $controller->page;

  $r->uri($error_url);
  
  $page->initialize;
  $page->title->set("$error_number error: $error_subject");
  
  $page->content->add_panel(EnsEMBL::Web::Document::Panel->new(
    raw => qq{<div class="error left-margin right-margin">
      <h3>$error_number error: $error_subject</h3>
      <div class="error-pad">
        <p>$error_text</p>
        <p>Please check that you have typed in the correct URL or else use the
        <a href="/Multi/Search/Results">site search</a>
        facility to try and locate information you require.
        </p>
        <p>
        If you think an error has occurred, please
        <a href="http://www.ensembl.org/Help/Contact">contact our HelpDesk</a>.
        </p>
      </div>
    </div>}
  ));
  
  $controller->render_page;
  
  return 0;
}

1;

