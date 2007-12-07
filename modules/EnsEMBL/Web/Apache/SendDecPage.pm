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

warn $ENSEMBL_WEB_REGISTRY;

use Apache2::Const qw(:common :methods :http);
#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my $r = shift;
  ## First of all check that we should be doing something with the page...
  my $pageContent;# = $ENSEMBL_WEB_REGISTRY->get_memcache->get( "SDP:".$r->filename );
  unless( $pageContent ) {
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
    return HTTP_METHOD_NOT_ALLOWED if $r->method_number == M_PUT;
    return DECLINED                if -d $r->filename;
    unless (-e $r->filename) {
      $r->log->error("File does not exist: ", $r->filename);
      return NOT_FOUND;
    }
    return HTTP_METHOD_NOT_ALLOWED if $r->method_number != M_GET;
  
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
  
=pod
    if (@groups) {
      ## TODO: Not sure what this block does, as $user is not defined - mw4
      ## Probably best to get the user from the registry.
  
      my $user;
      my @user_groups = $user->groups;
  
      ## cross-reference user's groups against permitted groups
      my $access = 0;
      foreach my $g (@groups) {
        foreach my $u (@user_groups) {
          $access = 1 if $u == $g;
        }
        last if $access;
      }
      if (!$access) {
        my $URL = '/common/access_denied';
        $r->headers_out->add( "Location" => $URL );
        $r->err_headers_out->add( "Location" => $URL );
        $r->status( REDIRECT );
      }
    }
  
=cut
## Read html file into memory to parse out SSI directives.
    {
      local($/) = undef;
      $pageContent = ${ $r->slurp_filename() }; #<$fh>;
    }
#    $ENSEMBL_WEB_REGISTRY->get_memcache->set( "SDP:".$r->filename, $pageContent );
  }
  return DECLINED if $pageContent =~ /<!--#set var="decor" value="none"-->/;

  $pageContent =~ s/\[\[([A-Z]+)::([^\]]*)\]\]/my $m = "template_$1"; no strict 'refs'; &$m($r, $2);/ge;

  $pageContent =~ s/<h2.*?>/'<h2 class="breadcrumbs">'.breadcrumbs( $r->uri, $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_TREE );/ge;

  # do SSI includes
  #  $pageContent =~ s/<!--#include\s+virtual\s*=\s*\"(.*)\"\s*-->/template_INCLUDE($r, $1)/eg;

  my $renderer = new EnsEMBL::Web::Document::Renderer::Apache( $r );
  my $page     = new EnsEMBL::Web::Document::Static( $renderer, undef, $ENSEMBL_WEB_REGISTRY->species_defs );

  $page->_initialize();

  $page->title->set( $pageContent =~ /<title>(.*?)<\/title>/sm ? $1 : 'Untitled: '.$r->uri );
  # warn $ENV{'ENSEMBL_SPECIES'};
  #$page->masthead->ies = $ENSEMBL_WEB_REGISTRY->species_defs->SPECIES_COMMON_NAME if $ENV{'ENSEMBL_SPECIES'};

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

  $page->content->add_panel(
    new EnsEMBL::Web::Document::Panel( 
      'raw' => $pageContent =~ /<body.*?>(.*?)<\/body>/sm ? $1 : $pageContent
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

sub breadcrumbs {
  my ($path, $branch) = @_;
  
  my $out = '';
  my $pointer = qq(<img src="/img/red_bullet.gif" width="4" height="8" alt="&gt;" class="breadcrumb" />);

  my ($step, $rest) = $path =~ m!/(.*?)(/.*)?$!; 

  if (defined $branch->{$step} && $step !~ /\.html/ && $rest ne '/index.html') {
    $out = sprintf qq(<a href="%s" title="%s" class="breadcrumb">%s</a> $pointer ), $branch->{$step}->{_path}, $branch->{$step}->{_nav}, $branch->{$step}->{_title};
    $out .= breadcrumbs($rest, $branch->{$step}) if $rest;
  }
  
  return $out;
}

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
