package EnsEMBL::Web::Apache::TmpFile;

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
# Mod_perl request handler for tmp files
#############################################################
sub handler {
  my $r = shift;

  $r->err_headers_out->{ 'Ensembl-Error' => 'Problem in module EnsEMBL::Web::Apache::TmpFile' };
  $r->custom_response(SERVER_ERROR, '/Crash');

  my $uri = $r->uri;
  return FORBIDDEN if $uri =~ /\.\./;
  $uri =~ s/^$ENSEMBL_TMP_URL_IMG/$ENSEMBL_TMP_DIR_IMG/g;
  $uri =~ s/^$ENSEMBL_TMP_URL/$ENSEMBL_TMP_DIR/g;

  if( $MEMD && (my $data = $MEMD->get($uri)) ) {

      $r->headers_out->set('Accept-Ranges'  => 'bytes');
      $r->headers_out->set('Content-Length' => $data->{'size'}) if $data->{'size'};
      $r->headers_out->set('Expires'        => Apache2::Util::ht_time($r->pool, $r->request_time + 60*60*24*30*12) );
      $r->set_last_modified($data->{'mtime'}) if $data->{'mtime'};
      
      $r->content_type($data->{'content_type'});

      my $rc = $r->print($data->{'content'});
      return OK;

  } else {
      ## Not found in cache, give up (returns to apache handler)
      return DECLINED;
  }


} # end of handler

1;
