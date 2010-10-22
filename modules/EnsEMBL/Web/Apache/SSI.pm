package EnsEMBL::Web::Apache::SSI;

use strict;

use Apache2::Const qw(:common :methods :http);

use SiteDefs qw(:APACHE);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Cookie;

#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my $r = shift;
  my $i = 0;
  ## First of all check that we should be doing something with the page...

  ## Pick up DAS entry points requests and
  ## uncompress them dynamically
  
  if (-e $r->filename && -r $r->filename && $r->filename =~ /\/entry_points$/) {
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
  
  my $cookies = {
    session_cookie => new EnsEMBL::Web::Cookie({
      host    => $ENSEMBL_COOKIEHOST,
      name    => $ENSEMBL_SESSION_COOKIE,
      value   => '',
      env     => 'ENSEMBL_SESSION_ID',
      hash    => {
        offset  => $ENSEMBL_ENCRYPT_0,
        key1    => $ENSEMBL_ENCRYPT_1,
        key2    => $ENSEMBL_ENCRYPT_2,
        key3    => $ENSEMBL_ENCRYPT_3,
        expiry  => $ENSEMBL_ENCRYPT_EXPIRY,
        refresh => $ENSEMBL_ENCRYPT_REFRESH
      }
    }),
    user_cookie => new EnsEMBL::Web::Cookie({
      host    => $ENSEMBL_COOKIEHOST,
      name    => $ENSEMBL_USER_COOKIE,
      value   => '',
      env     => 'ENSEMBL_USER_ID',
      hash    => {
        offset  => $ENSEMBL_ENCRYPT_0,
        key1    => $ENSEMBL_ENCRYPT_1,
        key2    => $ENSEMBL_ENCRYPT_2,
        key3    => $ENSEMBL_ENCRYPT_3,
        expiry  => $ENSEMBL_ENCRYPT_EXPIRY,
        refresh => $ENSEMBL_ENCRYPT_REFRESH
      }
    })
  };
  
  return new EnsEMBL::Web::Controller::SSI($r, $cookies)->status;
}

1;
