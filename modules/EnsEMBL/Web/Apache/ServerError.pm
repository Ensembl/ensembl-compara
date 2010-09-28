package EnsEMBL::Web::Apache::ServerError;
     
use strict;

use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Document::Panel;

sub handler {
  my $r          = shift;
  my $controller = new EnsEMBL::Web::Controller($r, { page_type => 'Static', renderer_type => 'Apache' });
  my $page       = $controller->page;
  my $admin      = $controller->species_defs->ENSEMBL_HELPDESK_EMAIL;
  
  $page->initialize;
  $page->title->set('500: Internal Server Error');
  
  $page->content->add_panel(new EnsEMBL::Web::Document::Panel(
    raw => qq{
      <div style="padding:0 5px;">
        <h2>Internal Server Error</h2>
        <div class="error" style="padding:0 5px;">
          <p>Sorry, an error occurred while the Ensembl server was processing your request</p>
          <p>Please email a report giving the URL and details on how to replicate the error (for example, how you got here), to $admin</p>
        </div>
      </div>
    }
  ));
  
  $controller->render_page;
}

1;
