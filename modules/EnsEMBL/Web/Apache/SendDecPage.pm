package EnsEMBL::Web::Apache::SendDecPage;
       
use strict;
use Apache::File ();
use Apache::Log ();
use SiteDefs qw(:ALL);
use EnsEMBL::Web::Document::Renderer::Apache;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::Static;
use EnsEMBL::Web::SpeciesDefs;
use Data::Dumper;
# use EnsEMBL::Web::Root;

our $SD = EnsEMBL::Web::SpeciesDefs->new();

use Apache::Constants qw(:response :methods :http);
#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my $r = shift;
## First of all check that we should be doing something with the page...
  $r->err_header_out('Ensembl-Error'=>"Problem in module EnsEMBL::Web::Apache::SendDecPage");
  $r->custom_response(SERVER_ERROR, "/Crash");
    
  return DECLINED if $r->content_type ne 'text/html';
  my $rc = $r->discard_request_body;
  return $rc unless $rc == OK;

  if ($r->method_number == M_INVALID) {
    $r->log->error("Invalid method in request ", $r->the_request);
    return NOT_IMPLEMENTED;
  }

  return DECLINED                if $r->method_number == M_OPTIONS;
  return HTTP_METHOD_NOT_ALLOWED if $r->method_number == M_PUT;
  return DECLINED                if -d $r->finfo;
  unless (-e $r->finfo) {
    $r->log->error("File does not exist: ", $r->filename);
    return NOT_FOUND;
  }
  return HTTP_METHOD_NOT_ALLOWED if $r->method_number != M_GET;

  my $fh = Apache::File->new($r->filename);
  unless ($fh) {
    $r->log->error("File permissions deny server access: ", $r->filename);
    return FORBIDDEN;
  }

## Read html file into memory to parse out SSI directives.
  my $pageContent;
  {
    local($/) = undef;
    $pageContent = <$fh>;
  }

  return DECLINED if $pageContent =~ /<!--#set var="decor" value="none"-->/;

  $pageContent =~ s/\[\[([A-Z]+)::([^\]]*)\]\]/my $m = "template_$1"; no strict 'refs'; &$m($r, $2);/ge;

  $pageContent =~ s/<h2>/'<h2 class="breadcrumbs">'.breadcrumbs( $r );/ge;

  # do SSI includes
  #  $pageContent =~ s/<!--#include\s+virtual\s*=\s*\"(.*)\"\s*-->/template_INCLUDE($r, $1)/eg;

  my $renderer = new EnsEMBL::Web::Document::Renderer::Apache( $r );
  my $page     = new EnsEMBL::Web::Document::Static( $renderer, undef, $SD );

  $page->_initialize();

  $page->title->set( $pageContent =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: '.$r->uri );
  # warn $ENV{'ENSEMBL_SPECIES'};
  $page->masthead->species = $SD->SPECIES_COMMON_NAME if $ENV{'ENSEMBL_SPECIES'};

  $page->content->add_panel(
    new EnsEMBL::Web::Document::Panel( 
      'raw' => $pageContent =~ /<body.*?>(.*?)<\/body>/sm ? $1 : $pageContent
    )
  );
  if($ENV{PERL_SEND_HEADER}) {
    print "Content-type: text/html\n\n";
  } else {
    $r->content_type('text/html');
    $r->send_http_header;
  }
    
  $page->render();
  return OK;
} # end of handler

sub breadcrumbs {
  my $r = shift;
  my $filename = $r->uri;
  my $pointer = qq(<img src="/img/red_bullet.gif" width="4" height="8" alt="&gt;" class="breadcrumb" />);
  my $DIR = '';
  my $out = '';
  my @DATA = split '/', $filename;
  my $file = pop @DATA;
  pop @DATA if $file eq 'index.html';
  foreach my $part ( @DATA ) {
    $DIR.=$part.'/';
    if( $DIR ne '/' && $SD->ENSEMBL_BREADCRUMBS->{$DIR} ) {
      $out .= sprintf qq(<a href="%s" title="%s" class="breadcrumb">%s</a> $pointer ), $DIR, $SD->ENSEMBL_BREADCRUMBS->{$DIR}[1], $SD->ENSEMBL_BREADCRUMBS->{$DIR}[0];
    }
  }
  return $out;
}

sub template_SPECIESDEFS {
  my( $r, $code ) = @_;
  return $SD->$code;
}

sub template_SPECIES {
  my( $r, $code ) = @_;
  return $ENV{'ENSEMBL_SPECIES'} if $code eq 'code';
  return $SD->SPECIES_COMMON_NAME if $code eq 'name';
  return $SD->SPECIES_RELEASE_VERSION if $code eq 'version';
  return "**$code**";
}

sub template_RELEASE {
  my( $r, $code ) = @_;
  return $SD->VERSION;
}

sub template_INCLUDE {
  my( $r, $include ) = @_;
  $include =~ s/\{\{([A-Z]+)::([^\}]+)\}\}/my $m = "template_$1"; no strict 'refs'; &$m($r,$2);/ge;
  my $content = "";
  #warn $filename;
    # Doh! Test file isn't a directory
  foreach my $root (  @ENSEMBL_HTDOCS_DIRS ) {
    my $filename = "$root/$include";
    if( -f $filename && -e $filename) {
      my $fh = Apache::File->new($filename);
      if( $fh ) {
        local($/) = undef;
        $content = <$fh>;
        return $content;
      }
    }
  }
  $r->log->error("Cannot include virtual file: does not exist or permission denied ", $include);
  $content = "[Cannot include virtual file: does not exist or permission denied]";
  return $content;
}

sub template_PAGE {
  my( $r, $rel ) = @_;
  my $root = $SD->ENSEMBL_PROTOCOL."://".$SD->ENSEMBL_SERVERNAME.(
    $SD->ENSEMBL_PROTOCOL eq 'http' ? ( $SD->ENSEMBL_PROXY_PORT == 80 ? '' : ":".$SD->ENSEMBL_PROXY_PORT ) :
                                      ( $SD->ENSEMBL_PROXY_PORT == 443 ? '' : ":".$SD->ENSEMBL_PROXY_PORT ) )."/";
  return "$root$rel"; 
}

sub template_LINK {
  my( $r, $rel ) = @_;
  my $root = $SD->ENSEMBL_PROTOCOL."://".$SD->ENSEMBL_SERVERNAME.(
    $SD->ENSEMBL_PROTOCOL eq 'http' ? ( $SD->ENSEMBL_PROXY_PORT == 80 ? '' : ":".$SD->ENSEMBL_PROXY_PORT ) :
                                      ( $SD->ENSEMBL_PROXY_PORT == 443 ? '' : ":".$SD->ENSEMBL_PROXY_PORT ) )."/";
  return qq(<a href="$root$rel">$root$rel</a>); 
}

sub template_RANDOM {
  my ($r, $include) = @_;
  $include =~ s/\{\{([A-Z]+)::([^\}]+)\}\}/my $m = "template_$1"; no strict 'refs'; &$m($r,$2);/ge;
  my $content = "";

  my $directory = $r->document_root . "/" .$include;
  $directory.="/" unless $directory=~/\/$/;
  my $error = undef;
       if( ! -d $directory) {                     # Doh! Test file isn't a directory
    $error = "Must link to a directory: $include";
  } elsif( ! -e $directory) {                     # Doh! Test file exists
    $error = "Directory does not exist: $include";
  } elsif( !opendir( DIR_HANDLE, $directory ) ) { # Tried to open directory but failedt
    $error = "Cannot read directory: $include";
  } else {
    my @files = ();
    while(my $Q = readdir(DIR_HANDLE)) {
      next unless $Q=~/\.html?$/i;
      push @files, $Q;
    }
    closedir( DIR_HANDLE );
    if( !@files) {                                # Directory is empty...
      $error = "No HTML files in directory: $include"; 
    } else {
      srand(time()^($$+($$<<15)));
      my $index = int(rand() * scalar(@files));
      my $filename = $directory.$files[$index];
      my $fh = Apache::File->new($filename);
      if( $fh  ) {
        local($/) = undef;
        $content = <$fh>;
        return $content;
      }                                           # No permission to read file! 
      $error = "No permission to access file: $include/$files[$index]";
    }
  }
  $r->log->error( $error );
  return "<div>Cannot include random file: $error</div>";
}

#############################################################

1;
