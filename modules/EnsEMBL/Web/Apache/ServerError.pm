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
