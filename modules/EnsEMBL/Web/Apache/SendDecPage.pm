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

use Apache2::Const qw(:common :methods :http);

use Cache::Memcached;

our $memd =Cache::Memcached->new({
  'servers' => [ 'localhost:11211' ],
  'debug'   => 0,
  'compress_threshold' => 10000,
  'namespace'          => $SiteDefs::ENSEMBL_SERVER."-".($SiteDefs::ENSEMBL_PROXY_PORT||80)
});
$memd->enable_compress(0);

#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my $r = shift;
  ## First of all check that we should be doing something with the page...
  my $pageContent = $memd->get( "SDP::".$r->filename );
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

  if( $pageContent ) {
#    warn "STATIC CONTENT CACHE HIT  SDP::".$r->filename."\n";
  } else {
#    warn "STATIC CONTENT CACHE MISS SDP::".$r->filename."\n";
  
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
    $memd->set( "SDP::".$r->filename, $pageContent );
  }
  return DECLINED if $pageContent =~ /<!--#set var="decor" value="none"-->/;

  $pageContent =~ s/\[\[([A-Z]+)::([^\]]*)\]\]/my $m = "template_$1"; no strict 'refs'; &$m($r, $2);/ge;

  my $renderer = new EnsEMBL::Web::Document::Renderer::Apache( $r );
  my $page     = new EnsEMBL::Web::Document::Static( $renderer, undef, $ENSEMBL_WEB_REGISTRY->species_defs );

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
  my $hr = ($ENV{'SCRIPT_NAME'} eq '/index.html') ? '' : '<hr class="end-of-doc" />'; 
  my $panelContent;
  
  if( $ENV{'SCRIPT_NAME'} =~ m#^/info/#) {
    $panelContent = qq(<div id="nav">);
    $panelContent .= template_SCRIPT($r, 'EnsEMBL::Web::Document::HTML::DocsMenu');
    $panelContent .= qq(</div>
<div id="content">
$html);
    $panelContent .= qq(\n</div>\n$hr);
  }
  else {
    $panelContent = ($html =~ /^\s*<div/) ? "$html\n$hr\n" : qq(\n<div class="onecol">\n$html\n$hr\n</div>\n); 
  }

  $page->content->add_panel(
    new EnsEMBL::Web::Document::Panel( 
      'raw' => $panelContent 
    )
  );
  if($ENV{PERL_SEND_HEADER}) {
    print "Content-type: text/html\n\n";
  } else {
    $r->content_type('text/html');
#    $r->send_http_header;
  }
    
  $page->render();
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
  $r->log->error("Cannot include virtual file: does not exist or permission denied ", $include);
  $content = "[Cannot include virtual file: does not exist or permission denied]";
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
      if( fopen FH, $filename ) {
        local($/) = undef;
        $content = <FH>;
        close FH;
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
