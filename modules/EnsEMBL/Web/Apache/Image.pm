package EnsEMBL::Web::Apache::Image;

use strict;
# use Apache::File ();
# use Apache::Log ();

use SiteDefs qw(:ALL);
use EnsEMBL::Web::RegObj;
use Data::Dumper;

use EnsEMBL::Web::Root;

use Apache2::Const qw(:common :methods :http);

use EnsEMBL::Web::Cache;

our $memd = EnsEMBL::Web::Cache->new;

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

  if ($memd) {

      ##return DECLINED if $r->$r-> ne 'image/png';
      return DECLINED if $path !~ /png$/;
      return DECLINED if $path =~ /\.\./;
    
      my $data = $memd->get($path);
      $r->headers_out->set('Accept-Ranges'  => 'bytes');
      $r->headers_out->set('Content-Length' => $data->{'size'});
      $r->set_last_modified($data->{'mtime'});
      
      $r->content_type('image/png');

      my $rc = $r->print($data->{'image'});
      return OK;

  } else {

      ##return DECLINED if $r->content_type ne 'image/png';
      return DECLINED if $path !~ /png$/;
      return DECLINED if $path =~ /\.\./;
    
      ## TODO: Lookup and check file, error exception!
      my $rc = $r->sendfile($path);
      return OK;

  }
} # end of handler

1;