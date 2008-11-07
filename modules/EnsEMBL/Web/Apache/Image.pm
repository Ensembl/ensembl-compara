package EnsEMBL::Web::Apache::Image;

use strict;
# use Apache::File ();
# use Apache::Log ();

use SiteDefs qw(:ALL);
use EnsEMBL::Web::RegObj;
use Data::Dumper;

use EnsEMBL::Web::Root;

use Apache2::Const qw(:common :methods :http);
use Apache2::Util ();

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Cache;

our $MEMD = EnsEMBL::Web::Cache->new;

#############################################################
# Mod_perl request handler all /img-tmp and /img-cache images
#############################################################
sub handler {
  my $r = shift;

  $r->err_headers_out->{ 'Ensembl-Error' => 'Problem in module EnsEMBL::Web::Apache::Image' };
  $r->custom_response(SERVER_ERROR, '/Crash');

  my $path = $ENSEMBL_SERVERROOT . $r->parsed_uri->path;
  my $replace = $ENSEMBL_SERVERROOT . $ENSEMBL_TMP_URL_IMG;
  $path =~ s/$replace/$ENSEMBL_TMP_DIR_IMG/g;
  return DECLINED if $path !~ /png$/;
  return DECLINED if $path =~ /\.\./;

  if( $MEMD && (my $data = $MEMD->get($path)) ) {
    
      $r->headers_out->set('Accept-Ranges'  => 'bytes');
      $r->headers_out->set('Content-Length' => $data->{'size'});
      $r->headers_out->set('Expires'        => Apache2::Util::ht_time($r->pool, $r->request_time + 60*60*24*30*12) );
      $r->set_last_modified($data->{'mtime'});
      
      $r->content_type('image/png');

      my $rc = $r->print($data->{'image'});
      return OK;

  } elsif( -e $path ) {

      $r->headers_out->set('Accept-Ranges'  => 'bytes');
      $r->headers_out->set('Expires'        => Apache2::Util::ht_time($r->pool, $r->request_time + 60*60*24*30*12) );
      my $rc = $r->sendfile($path);
      return OK;
      
  }


  ## Nothing found: delete all related content if MEMD 
  if ($MEMD) {
      my $session_id = $ENSEMBL_WEB_REGISTRY->get_session->get_session_id;
      $MEMD->delete_by_tags(
        $ENV{'HTTP_REFERER'},
        $session_id ? "session_id[$session_id]" : (),
      );
  }
  
  return NOT_FOUND;
} # end of handler

1;
