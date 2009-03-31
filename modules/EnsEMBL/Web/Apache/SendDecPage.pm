package EnsEMBL::Web::Apache::SendDecPage;
       
use strict;
#use Apache::File ();
# use Apache::Log ();
use SiteDefs qw(:ALL);
use EnsEMBL::Web::Document::Renderer::Apache;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::Static;
use EnsEMBL::Web::RegObj;
use Data::Dumper;
use EnsEMBL::Web::Root;
use Compress::Zlib;

use Apache2::Const qw(:common :methods :http);

use EnsEMBL::Web::Cache;

use Carp qw(cluck);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);


#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my $r = shift;
  my $i = 0;
  ## First of all check that we should be doing something with the page...

  ## Pick up DAS entry points requests and
  ## uncompress them dynamically

  if( -e $r->filename && -r $r->filename && $r->filename =~ /\/entry_points$/) {
    my $gz = gzopen( $r->filename, 'rb' );
    my $buffer = 0;
    my $content = '';
    $content .= $buffer while $gz->gzread( $buffer ) > 0;
    $gz->gzclose(); 
    if($ENV{PERL_SEND_HEADER}) {
      print "Content-type: text/xml; charset=utf-8";
    } else {
      $r->content_type('text/xml; charset=utf-8');
    }
    $r->print($content);
    return OK;
  }

  $r->err_headers_out->{'Ensembl-Error'=>"Problem in module EnsEMBL::Web::Apache::SendDecPage"};
  $r->custom_response(SERVER_ERROR, "/Crash");

  return DECLINED if $r->content_type ne 'text/html';

  my $rc = $r->discard_request_body;
  return $rc unless $rc == OK;
  if ($r->method_number == M_INVALID) {
    $r->log->error("Invalid method in request ", $r->the_request);
    return HTTP_NOT_IMPLEMENTED;
  }
   
  return DECLINED                if $r->method_number == M_OPTIONS;
  return HTTP_METHOD_NOT_ALLOWED if $r->method_number != M_GET;
  return DECLINED                if -d $r->filename;

  $ENV{CACHE_TAGS}{'STATIC'}            = 1;
  $ENV{CACHE_TAGS}{$ENV{'REQUEST_URI'}} = 1;
  $ENV{CACHE_KEY} = $ENV{REQUEST_URI};

  ## User logged in, some content depends on user
  $ENV{CACHE_KEY} .= "::USER[$ENV{ENSEMBL_USER_ID}]" if $ENV{ENSEMBL_USER_ID};

  ## Ajax disabled
  $ENV{CACHE_KEY} .= '::NO_AJAX'  unless $ENSEMBL_WEB_REGISTRY->check_ajax;
  
  if (
      $MEMD && 
      ($r->headers_in->{'Cache-Control'} eq 'max-age=0' || $r->headers_in->{'Pragma'} eq 'no-cache')
     ) {
      $MEMD->delete_by_tags(
        $ENV{'REQUEST_URI'},
        $ENV{ENSEMBL_USER_ID} ? 'user['.$ENV{ENSEMBL_USER_ID}.']' : (),
      );
  }

  my $pageContent = $MEMD ? $MEMD->get($ENV{CACHE_KEY}, keys %{$ENV{CACHE_TAGS}}) : undef;
    
  if ($pageContent) {
    warn "STATIC CONTENT CACHE HIT $ENV{CACHE_KEY}"
      if $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
         $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MEMCACHED;
  } else {
    warn "STATIC CONTENT CACHE MISS $ENV{CACHE_KEY}"
      if $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
         $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MEMCACHED;

    unless (-e $r->filename) {
      $r->log->error("File does not exist: ", $r->filename);
      return NOT_FOUND;
    }
    unless( -r $r->filename) {
      $r->log->error("File permissions deny server access: ", $r->filename);
      return FORBIDDEN;
    }

    ## Is this page under a 'private' folder?

    ## parse path and get first 'private_n_nn' folder above current page
    my @dirs = reverse(split('/', $r->filename));
    my @groups;
    foreach my $d (@dirs) {
      if ($d =~ /^private(_[0-9]+)+/) {
        (my $grouplist = $d) =~ s/private_//;
        @groups = split('_', $grouplist); ## groups permitted to access files 
      }
      last if @groups;
    }
  
    ## Read html file into memory to parse out SSI directives.
    {
      local($/) = undef;
      $pageContent = ${ $r->slurp_filename() }; #<$fh>;
    }

    return DECLINED if $pageContent =~ /<!--#set var="decor" value="none"-->/;

    $pageContent =~ s/\[\[([A-Z]+)::([^\]]*)\]\]/my $m = "template_$1"; no strict 'refs'; &$m($r, $2);/ge;

    my $renderer = new EnsEMBL::Web::Document::Renderer::String( r => $r );
    my $page     = new EnsEMBL::Web::Document::Static($renderer, undef, $ENSEMBL_WEB_REGISTRY->species_defs);
    $page->include_navigation( $ENV{'SCRIPT_NAME'} =~ /^\/info/ );
    $page->_initialize();
  
    $page->title->set( $pageContent =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: '.$r->uri );
  
    my $head = $pageContent =~ /<head>(.*?)<\/head>/sm ? $1 : '';
    while($head=~s/<script(.*?)>(.*?)<\/script>//sm) {
      my($attr,$cont) = ($1,$2);
      next unless $attr =~/text\/javascript/;
      if($attr =~ /src="(.*?)"/ ) {
        $page->javascript->add_source( $1 );
      } else {
        $page->javascript->add_script( $cont );
      }   
    }
    while($head=~s/<style(.*?)>(.*?)<\/style>//sm) {
      my($attr,$cont) = ($1,$2);
      next unless $attr =~/text\/css/;
      my $media = $attr =~/media="(.*?)"/ ? $1 : 'all';
      if($attr =~ /src="(.*?)"/ ) {
        $page->stylesheet->add_sheet( $media, $1 );
      } else {
        $page->stylesheet->add( $media, $cont );
      }
    }
  
    ## Build page content
    my $html = $pageContent =~ /<body.*?>(.*?)<\/body>/sm ? $1 : $pageContent;
    my $hr;
    if ($ENV{'SCRIPT_NAME'} eq '/index.html') {
      $hr = '';
    }
    elsif ($page->include_navigation) {
      $hr = '<hr class="end-of-doc with-nav" />';
    }
    else {
      $hr = '<hr class="end-of-doc" />';
    } 
    my $panelContent;
    if ($page->include_navigation) {
      $panelContent .= qq(<div id="content"><div id="static">\n$html\n</div></div>\n$hr\n);
    }
    elsif ($ENV{'SCRIPT_NAME'} eq '/blog.html') {
      $panelContent = $html;
    }
    else {
      $panelContent = qq(\n<div id="static">\n$html\n$hr\n</div>\n); 
    }

    $page->content->add_panel(
      new EnsEMBL::Web::Document::Panel( 
        'raw' => $panelContent 
      )
    );
    
    $page->render;
    $pageContent = $renderer->value;

    $MEMD->set($ENV{CACHE_KEY}, $pageContent, $ENV{CACHE_TIMEOUT}, keys %{$ENV{CACHE_TAGS}}) if $MEMD;
  }

  if($ENV{PERL_SEND_HEADER}) {
    print "Content-type: text/html; charset=utf-8";
  } else {
    $r->content_type('text/html; charset=utf-8');
    #$r->send_http_header;
  }
    
  $r->print($pageContent);
  return OK;
} # end of handler

sub template_SPECIESINFO {
  my( $r, $code ) = @_;
  my($sp,$code) = split /:/, $code;
  return $ENSEMBL_WEB_REGISTRY->species_defs->other_species($sp,$code);
}
sub template_SPECIESDEFS {
  my( $r, $code ) = @_;
  return $ENSEMBL_WEB_REGISTRY->species_defs->$code;
}

sub template_SPECIES {
  my( $r, $code ) = @_;
  return $ENV{'ENSEMBL_SPECIES'} if $code eq 'code';
  return $ENSEMBL_WEB_REGISTRY->species_defs->SPECIES_COMMON_NAME if $code eq 'name';
  return $ENSEMBL_WEB_REGISTRY->species_defs->SPECIES_RELEASE_VERSION if $code eq 'version';
  return "**$code**";
}

sub template_RELEASE {
  my( $r, $code ) = @_;
  return $ENSEMBL_WEB_REGISTRY->species_defs->VERSION;
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
      if( open FH, $filename ) {
        local($/) = undef;
        $content = <FH>;
        close FH;
        return $content;
      }
    }
  }
  $r->log->error("Cannot include virtual file: does not exist or permission denied ", $include) if $r;
  #$content = "[Cannot include virtual file: does not exist or permission denied]";
  return $content;
}

sub template_SCRIPT {
  my( $r, $include ) = @_;
  my $content;
  eval {
    EnsEMBL::Web::Root->dynamic_use($include);
    $content = $include->render();
  };
  if( $@ ){ warn( "Cannot dynamic_use $include: $@" ) } 
  return "$content";
}

sub template_PAGE {
  my( $r, $rel ) = @_;
  my $root = $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_BASE_URL;
  return "$root/$rel"; 
}

sub template_LINK {
  my( $r, $rel ) = @_;
  my $root = $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_BASE_URL;
  return qq(<a href="$root/$rel">$root/$rel</a>); 
}

#############################################################

1;
