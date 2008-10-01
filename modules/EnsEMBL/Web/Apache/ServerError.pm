package EnsEMBL::Web::Apache::ServerError;
     
use strict;
use Apache2::Const qw(:common :http);
use CGI qw(:html);
use SiteDefs qw(:WEB);
use Text::Wrap;

use EnsEMBL::Web::Document::Renderer::Apache;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::Static;
use EnsEMBL::Web::SpeciesDefs;

our $SD = EnsEMBL::Web::SpeciesDefs->new();

use Data::Dumper qw(Dumper);

sub handler {
  my $r = shift;
  my $error      = $ENV{'REDIRECT_error_message'}; #$r->err_header_out('Ensembl-Error');
  eval {
    my $exception   = $ENV{'REDIRECT_error_notes'}; #$r->err_header_out('Ensembl-Exception');
    my $nomail      = '';
    unless ($error) {
      $error = 'unknown (no specific information available)';
    } else{
      my $serverroot = $r->server_root_relative();
      $error =~ s!$serverroot!!ig;
    }
    return OK if $r->header_only;
      
    my $renderer = new EnsEMBL::Web::Document::Renderer::Apache( r => $r );
    my $page     = new EnsEMBL::Web::Document::Static( $renderer, undef, $SD );
    $page->_initialize();
    $page->title->set( "500: Internal Server Error" );    
    # unless ($r->err_header_out('ensembl_headers_out')){  
    #  $output->start;
    # }
      
###############################################################
# If ENSEMBL_MAIL_ERRORS is set, then mail out an error report
###############################################################
    if ($ENSEMBL_MAIL_ERRORS and !$nomail){
      my $date = `date +"%Y-%m-%d %H:%M:%S"`;
      chomp $date;
      my $scriptname = $ENV{'REDIRECT_URL'};
      $scriptname =~ s:/perl/::;
      my $url = "http://$ENSEMBL_SERVERNAME:" . 
                ($ENSEMBL_PROXY_PORT||$ENSEMBL_PORT)."/$scriptname";
    
      my $mail_subj="Ensembl Automailed Error :$ENSEMBL_SERVER : $scriptname : $error";
      $mail_subj =~s/['"]/_/g;
      $Text::Wrap::columns = 72;
      # $Text::Wrap::huge = 'wrap';
      my @data = (
        ['Date',         $date],
        ['Error',        $error],
        ['Exception',    $exception],
        ['Server',       $ENSEMBL_SERVER],
        ['URL',          $url],
        ['Query String', $ENV{'REDIRECT_QUERY_STRING'}],
        ['Referer',      $ENV{'REDIRECT_HTTP_REFERER'}],
        ['HTTP Status',  $ENV{'REDIRECT_STATUS'}],
        ['Request',      $ENV{'REDIRECT_REQUEST_METHOD'}],
        ['IP',           $ENV{'REDIRECT_REMOTE_ADDR'}],
        ['Real IP',      $ENV{'REDIRECT_HTTP_X_FORWARDED_FOR'}],
      );
      my $message = '';
      foreach (@data) {
        my ($key,$value) = @$_;
        my $line;
        eval {
          $line = Text::Wrap::wrap( sprintf('%-16.16s',"$key:"), ' 'x16, "$value")."\n";
        };
        if($@) {
          $line = Text::Wrap::wrap( sprintf('%-16.16s',"$key:"), ' 'x16, "******")."\n";
        }
        $message.=$line;
      }    

      # unwrapped URL and referrer
      $message .= "\nUnwrapped URL:\n$url";
      $message .= "?$ENV{'REDIRECT_QUERY_STRING'}" if $ENV{'REDIRECT_QUERY_STRING'};
      $message .= "\nUnwrapped referrer:\n$ENV{'REDIRECT_HTTP_REFERER'}\n";
      
      open(MAILER, "| $ENSEMBL_MAIL_COMMAND '$mail_subj' $ENSEMBL_ERRORS_TO");
      print MAILER "$message\n\n";
      close(MAILER);
    } else {
      print STDERR "$error: \n$exception\n";
    }

  #######################
  # Report error to user
  #######################
    my $admin = $r->server->server_admin;
    
    $page->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'raw' => qq(
<h2>Ensembl Server Error</h2>
<p>Sorry, an error occurred while the Ensembl server was processing your request</p>
<p>Please email a report , quoting any additional information given below, along with the URL, to $admin</p>
<p><strong>The error was:</strong>
<blockquote class="error"><pre>$error</pre></blockquote>
      )
    ));
      
    if($r->err_headers_out->{'ensembl_headers_out'}){  
      $page->content->render();
      $page->render_end();
    } else {
      $page->render();
    }
    return 500;
  };
  if($@) {
    print qq(Content-type: text/html

<p>Sorry, an error occurred while the Ensembl server was processing your request</p>
<p>Please email a report , quoting any additional information given below, along
   with the URL to the website administrator</p>
<p><strong>The error was:</strong>
<blockquote class="error"><pre>$error</pre></blockquote>
<pre>$@</pre>
    );

    warn qq(
********* ERROR PAGE FAILED ****************************
$error
********************************************************
);
  }
  return OK;
}

1;

__END__

