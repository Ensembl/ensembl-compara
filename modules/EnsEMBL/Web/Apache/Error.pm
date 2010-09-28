package EnsEMBL::Web::Apache::Error;
       
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
  
  my $controller = new EnsEMBL::Web::Controller($r, { page_type => 'Static', renderer_type => 'Apache' });
  my $page       = $controller->page;

  $r->uri($error_url);
  
  $page->initialize;
  $page->title->set("$error_number error: $error_subject");
  
  $page->content->add_panel(new EnsEMBL::Web::Document::Panel(
    raw => qq{
      <h2>$error_number error: $error_subject</h2>
      <p>$error_text</p>
      <p>
        Please check that you have typed in the correct URL or else use the site search
        facility to try and locate information you require.
      </p>
      <p>
        If you think an error has occurred please send email to the server administrator 
        using the link below.
      </p>
    }
  ));
  
  $controller->render_page;
  
  return 0;
}

1;

