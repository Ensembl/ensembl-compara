package EnsEMBL::Web::Apache::Static;

#############################################################
## mod_perl static files handler
#############################################################

use strict;
# use Apache::File ();
# use Apache::Log ();

use MIME::Types ();
use Compress::Zlib ();
use HTTP::Date ();
use Data::Dumper;

use Apache2::Const qw(:common :methods :http);
use Apache2::Util ();

use SiteDefs qw(:ALL);
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Cache;

our $MEMD = EnsEMBL::Web::Cache->new;
our $MIME = MIME::Types->new();

our @HTDOCS_TRANS_DIRS;

BEGIN {
  foreach my $dir( @SiteDefs::ENSEMBL_HTDOCS_DIRS ){
    if( -d $dir ) {
      if( -r $dir ) {
        push( @HTDOCS_TRANS_DIRS, "$dir/%s" );
      } else {
        warn "ENSEMBL_HTDOCS_DIR $dir is not readable\n";
      }
    } else {
       warn "ENSEMBL_HTDOCS_DIR $dir does not exist\n";
    }
  }
};

## TODO:
## cahrset + utf8
## Not modified!
## restrictions
## error pages!
## PLUGINS!!!!!!!!!!!!

sub handler {
  my $r = shift;


  my $uri  = $r->uri;
  my $content = $MEMD && $MEMD->get($uri) || undef;

  if ($content) {

    $r->headers_out->set('X-MEMCACHED'  => 'yes');
    $r->headers_out->set('Accept-Ranges'  => 'bytes');
    $r->headers_out->set('Content-Length' => length($content));
    $r->headers_out->set('Cache-Control'  => 'max-age=' . 60*60*24*30);
    $r->headers_out->set('Expires'        => HTTP::Date::time2str( time + 60*60*24*30 ));
    $r->content_type(mime_type($uri));
    $r->print($content);
    return OK;

  } else {
    
      my $file = $uri;
      return FORBIDDEN if $file =~ /\.\./;
      ## Not temporary static files are pluggable:
      unless ($file =~ s/^$ENSEMBL_TMP_URL_IMG/$ENSEMBL_TMP_DIR_IMG/g + $file =~ s/^$ENSEMBL_TMP_URL/$ENSEMBL_TMP_DIR/g) {
          ## walk through plugins tree and search for the file in all htdocs dirs
          foreach my $dir (@HTDOCS_TRANS_DIRS) {
            my $f = sprintf( $dir, $file );
            if (-d $f or -r $f) {
              $file = $f;
              last;
            }
          }
      }
      ## /
  
      if (-e $file) {
        {
          local $/=undef;
          open FILE, $file or die "Couldn't open file: $!";
          $content = <FILE>;
          close FILE;
        }
        $MEMD->set($uri, $content) if $MEMD;
        my @file_info = stat($file);
        $r->headers_out->set('Last-Modified'  => HTTP::Date::time2str( $file_info[9] ));
        $r->headers_out->set('Accept-Ranges'  => 'bytes');
        $r->headers_out->set('Content-Length' => length($content));
        $r->headers_out->set('Cache-Control'  => 'max-age=' . 60*60*24*30);
        $r->headers_out->set('Expires'        => HTTP::Date::time2str( time + 60*60*24*30 ));
        $r->content_type(mime_type($uri));
        
        $r->print($content);
        return OK;
      }

  }

  return DECLINED;

} # end of handler


sub mime_type {
    my $file = shift;

    my $mimeobj = $MIME->mimeTypeOf($file);
    return $mimeobj ? $mimeobj->type : 'text/plain';
}

1;
