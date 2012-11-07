package EnsEMBL::Web::Apache::SSI;

use strict;

use Apache2::Const qw(:common :methods :http);
use Compress::Zlib;

use SiteDefs qw(:APACHE);

use EnsEMBL::Web::Controller::Doxygen;
use EnsEMBL::Web::Controller::SSI;

#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my ($r, $cookies) = @_;
  my $i = 0;
  ## First of all check that we should be doing something with the page...

  ## Pick up DAS entry points requests and
  ## uncompress them dynamically
  
  if (-e $r->filename && -r $r->filename) {
    if ($r->filename =~ /\/entry_points$/) {
      my $gz      = gzopen($r->filename, 'rb');
      my $buffer  = 0;
      my $content = '';
      $content   .= $buffer while $gz->gzread($buffer) > 0;
      
      $gz->gzclose; 
      
      if ($ENV{'PERL_SEND_HEADER'}) {
        print "Content-type: text/xml; charset=utf-8";
      } else {
        $r->content_type('text/xml; charset=utf-8');
      }
      
      $r->print($content);
      
      return OK;
    } elsif ($r->filename =~ /\/Doxygen\/(?!index.html)/ || $r->filename =~ /\/edoc\/index.html/) {
      return EnsEMBL::Web::Controller::Doxygen->new($r, $cookies)->status;
    }
  }

  $r->err_headers_out->{'Ensembl-Error' => 'Problem in module EnsEMBL::Web::Apache::SSI'};
  $r->custom_response(SERVER_ERROR, '/Crash');

  return DECLINED if $r->content_type ne 'text/html';

  my $rc = $r->discard_request_body;
  
  return $rc unless $rc == OK;
  
  if ($r->method_number == M_INVALID) {
    $r->log->error('Invalid method in request ', $r->the_request);
    return HTTP_NOT_IMPLEMENTED;
  }
   
  return DECLINED                if $r->method_number == M_OPTIONS;
  return HTTP_METHOD_NOT_ALLOWED if $r->method_number != M_GET;
  return DECLINED                if -d $r->filename;
  return EnsEMBL::Web::Controller::SSI->new($r, $cookies)->status;
}

1;
