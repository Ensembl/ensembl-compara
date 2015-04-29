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

package EnsEMBL::Web::Apache::ServerError;
     
use strict;

use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Document::Panel;

sub handler {
  my $r          = shift;
  my $controller = EnsEMBL::Web::Controller->new($r, { page_type => 'Static', renderer_type => 'Apache' });
  my $page       = $controller->page;
  my $admin      = $controller->species_defs->ENSEMBL_HELPDESK_EMAIL;
  
  $page->initialize;
  $page->title->set('500: Internal Server Error');
  
  $page->content->add_panel(EnsEMBL::Web::Document::Panel->new(
    raw => qq{
      <div class="error left-margin right-margin">
        <h3>Internal Server Error</h3>
        <div class="message-pad">
          <p>Sorry, an error occurred while the Ensembl server was processing your request</p>
          <p>Please email a report giving the URL and details on how to replicate the error (for example, how you got here), to $admin</p>
        </div>
      </div>
    }
  ));
  
  $controller->render_page;
}

1;
