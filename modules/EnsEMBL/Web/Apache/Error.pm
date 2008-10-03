package EnsEMBL::Web::Apache::Error;
       
use strict;
use Apache2::Const qw(:common :http);
use EnsEMBL::Web::Document::Renderer::Apache;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::Static;

use EnsEMBL::Web::SpeciesDefs;
our $SD = EnsEMBL::Web::SpeciesDefs->new();

my %error_messages = (
  404 => [
    'Page not found' ,
    'Sorry, the page you requested was not found on this server.',
  ], 
  400 => [
    'Bad method' ,
    'Sorry, the way you were asking for the file was not recognised',
  ], 
  403 => [
    'No permission',
    'The webserver does not have permission to view that file'
  ], 
  401 => [
    'Not authorised',
    'You were not authorised to view that page, an username and password is required',
  ], 
);

sub handler {
  my $r = shift;
  my $error_number = $ENV{'REDIRECT_STATUS' };
  my $error_URL    = $ENV{'REDIRECT_URL' };
  my ($error_subject, $error_text) = @{$error_messages{ $error_number }||[]};
  ($error_subject, $error_text) = (
    qq( 'Unrecognised error' ),
    $ENV{'REDIRECT_ERROR_NOTES'}
  ) unless $error_subject;
  $r->content_type('text/html; charset=utf-8');
  $r->uri( $error_URL );
  return OK if $r->header_only;
  
  my $admin = $r->server->server_admin;
  warn "$error_number ERROR: $error_subject $error_URL\n";
  
  my $renderer = new EnsEMBL::Web::Document::Renderer::Apache( r => $r );
  my $page     = new EnsEMBL::Web::Document::Static( $renderer, undef, $SD );

  $page->_initialize();

  $page->title->set( "$error_number error: $error_subject" );
  $page->content->add_panel( new EnsEMBL::Web::Document::Panel(
      'raw' => qq(<h2>$error_number error: $error_subject</h2 >
  <p>$error_text</p>
  <p>
    Please check that you have typed in the correct URL or else use the site search
    facility to try and locate information you require.
  </p>
  <p>
    If you think an error has occurred please send email to the server administrator 
    using the link below.
  </p>)
  ));  
  $page->render;
  return OK;
}

1;

__END__
