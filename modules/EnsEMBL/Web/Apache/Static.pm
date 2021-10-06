=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Apache::Static;

#############################################################
## mod_perl static files handler
#############################################################

use strict;

use MIME::Types;
use Compress::Zlib;
use HTTP::Date;

use Apache2::Const qw(:common :methods :http);
use Apache2::Util;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Cache;

our $MEMD = EnsEMBL::Web::Cache->new;
our $MIME = MIME::Types->new;

our @HTDOCS_TRANS_DIRS;

BEGIN {
  foreach my $dir (@SiteDefs::ENSEMBL_HTDOCS_DIRS) {
    if (-d $dir) {
      if (-r $dir) {
        push @HTDOCS_TRANS_DIRS, "$dir/%s";
      } else {
        warn "ENSEMBL_HTDOCS_DIR $dir is not readable\n";
      }
    } else {
      # warn "ENSEMBL_HTDOCS_DIR $dir does not exist\n";
    }
  }
};

## TODO:
## cahrset + utf8
## Not modified!
## restrictions
## error pages!
## PLUGINS!!!!!!!!!!!!

sub static_cache_hook {} # Overridden in plugins (eg nginx)

sub handler {
  my $r       = shift;
  my $uri     = $r->uri;

  my $content = undef;
  if($MEMD) {
    $content //= $MEMD->get("$SiteDefs::ENSEMBL_STATIC_BASE_URL$uri");
    $content //= $MEMD->get("$SiteDefs::ENSEMBL_STATIC_SERVER$uri");
  }

  # don't pollute logs with static file requests
  $r->subprocess_env('LOG_REQUEST_IGNORE', 1);

  if ($content) {
    $r->headers_out->set('X-MEMCACHED'    => 'yes');
    $r->headers_out->set('Accept-Ranges'  => 'bytes');
    $r->headers_out->set('Content-Length' => length $content);
    $r->content_type(mime_type($uri));
    add_caching_headers($r);
    $r->print($content);
    static_cache_hook($uri,$content);
    return OK;
  } else {
    my $file = $uri;
    
    return FORBIDDEN if $file =~ /\.\./;

    ## Map robots.txt URL
    if ($file eq '/robots.txt' && !$SiteDefs::ENSEMBL_CUSTOM_ROBOTS_TXT) { # if ENSEMBL_CUSTOM_ROBOTS_TXT is set, it uses one from plugin's htdocs
      $file = $SiteDefs::ENSEMBL_ROBOTS_TXT_DIR.'/robots.txt';
    }

    ## Map URLs for temporary files that are stored outside the htdocs directory
    ## Note that we can't guarantee that URLs are unique, so use an array rather than a hash
    my @tmp_paths = (
                    $SiteDefs::ENSEMBL_TMP_URL        => $SiteDefs::ENSEMBL_TMP_DIR, 
                    $SiteDefs::ENSEMBL_TMP_URL_IMG    => $SiteDefs::ENSEMBL_TMP_DIR_IMG,
                    $SiteDefs::ENSEMBL_USERDATA_URL   => $SiteDefs::ENSEMBL_USERDATA_DIR, 
                    $SiteDefs::ENSEMBL_MINIFIED_URL   => $SiteDefs::ENSEMBL_MINIFIED_FILES_PATH,
                    $SiteDefs::ENSEMBL_OPENSEARCH_URL => $SiteDefs::ENSEMBL_OPENSEARCH_PATH,
                    $SiteDefs::GOOGLE_SITEMAPS_URL    => $SiteDefs::GOOGLE_SITEMAPS_PATH,
                    );
    my $is_tmp;
    
    while (my($url, $dir) = splice @tmp_paths, 0, 2) {
      if ($file =~ /^$url/) {
        (my $filecheck = $file) =~ s/$url/$dir/;
        if (-e $filecheck) {
          $file = $filecheck;
          $is_tmp = 1;
          last;
        }
      }
    }
    
    ## Non-temporary static files are pluggable:
    unless ($is_tmp) {
      ## walk through plugins tree and search for the file in all htdocs dirs
      $file = htdoc_dir($file, $r);
    }

    return DECLINED if $file eq $uri; # absolute file path provided via url

    if (-e $file) {
      ## Send 2MB+ files without caching them
      add_caching_headers($r);
      $r->content_type(mime_type($uri));
      return $r->sendfile($file) if -s $file > 2*1024*1024;

      $content = get_file_content($file, $r);

      $MEMD->set("$SiteDefs::ENSEMBL_STATIC_BASE_URL$uri", $content, undef, 'STATIC') if $MEMD;
      static_cache_hook($uri,$content);
      
      my @file_info = stat($file);
      $r->headers_out->set('Last-Modified'  => HTTP::Date::time2str($file_info[9]));
      $r->headers_out->set('Accept-Ranges'  => 'bytes');
      $r->headers_out->set('Content-Length' => length($content));
      
      $r->print($content);
      return OK;
    }
  }

  return DECLINED;

} # end of handler

sub get_file_content {
  my ($file, $r) = @_;
  local $/ = undef;
  open FILE, $file or die "Couldn't open file: $!";
  my $content = <FILE>;
  close FILE;
  return $content;
}

sub mime_type {
  my $file    = shift;
  my $mimeobj = $MIME->mimeTypeOf($file);
  return $mimeobj ? $mimeobj->type : 'text/plain';
}

#overwritten in mobile plugin
sub htdoc_dir { 
  my ($file, $r) = @_;
  
  foreach my $dir (@HTDOCS_TRANS_DIRS) {
    my $f = sprintf $dir, $file;
    if (-d $f or -r $f) {
      $file = $f;
      last;
    }
  }
  return $file;
}

sub add_caching_headers {
  my $r = shift;
  if (should_skip_caching($r)) {
    $r->headers_out->set('Cache-Control'  => 'no-store, max-age=0');
  } else {
    my $thirty_days = 60 * 60 * 24 * 30;
    $r->headers_out->set('Cache-Control'  => 'max-age=' . $thirty_days);
    $r->headers_out->set('Expires'        => HTTP::Date::time2str(time + $thirty_days));
  }
}

#overwritten in public plugins
sub should_skip_caching {
  return 0;
}

1;
