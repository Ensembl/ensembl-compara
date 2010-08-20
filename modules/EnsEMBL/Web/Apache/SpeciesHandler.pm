package EnsEMBL::Web::Apache::SpeciesHandler;

use strict;

use Apache2::Const qw(:common :http :methods);

use SiteDefs qw(:APACHE);

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Magic qw(stuff modal_stuff ingredient configurator menu export);
use EnsEMBL::Web::OldLinks qw(get_redirect);
use EnsEMBL::Web::Registry;
use EnsEMBL::Web::RegObj;

our $MEMD = new EnsEMBL::Web::Cache;

sub handler_species {
  my ($r, $session_cookie, $species, $raw_path_segments, $querystring, $file, $flag) = @_;
  
  my $redirect_if_different = 1;
  my @path_segments         = @$raw_path_segments;
  my ($ajax, $plugin, $type, $action, $function);
  
  s/\W//g for @path_segments; # clean up dodgy characters
  
  # Parse the initial path segments, looking for valid ENSEMBL_TYPE values
  my $seg    = shift @path_segments;
  my $script = $OBJECT_TO_SCRIPT->{$seg};
  
  if ($seg eq 'Component' || $seg eq 'Zmenu' || $seg eq 'Config') {
    $ajax   = $seg;
    $type   = shift @path_segments if $OBJECT_TO_SCRIPT->{$path_segments[0]} || $seg eq 'Zmenu';
    $plugin = shift @path_segments if $ajax eq 'Component';
  } else {
    $type = $seg;
  }
  
  $action   = shift @path_segments;
  $function = shift @path_segments;
  
  $r->custom_response($_, "/$species/Info/Error/$_") for (NOT_FOUND, HTTP_BAD_REQUEST, FORBIDDEN, AUTH_REQUIRED);
  
  if ($flag && $script) {
    if ($script eq 'action' || $script eq 'modal') {
      $ENV{'ENSEMBL_FACTORY'}   = 'MultipleLocation' if $type eq 'Location' && $action eq 'Multi';
    } elsif ($script eq 'component') {
      $ENV{'ENSEMBL_COMPONENT'} = join  '::', 'EnsEMBL', $plugin, 'Component', $type, $action;
      $ENV{'ENSEMBL_FACTORY'}   = 'MultipleLocation' if $type eq 'Location' && $action =~ /^Multi(Ideogram|Top|Bottom)$/;
      
      @path_segments = ();
    }
    
    # Make an ENV flag for custom pages
    $ENV{'ENSEMBL_CUSTOM_PAGE'} = 1 if $action eq 'Custom' || $script =~ /^(config|component)$/ && $ENV{'HTTP_REFERER'} =~ /\/Custom(\?|(?!.))/;
    
    $redirect_if_different = 0;
  } else {
    $script = $seg;
  }
  
  return undef unless $script;
  
  # Mess with the environment
  $ENV{'ENSEMBL_TYPE'}     = $type;
  $ENV{'ENSEMBL_ACTION'}   = $action;
  $ENV{'ENSEMBL_FUNCTION'} = $function;
  $ENV{'ENSEMBL_SPECIES'}  = $species;
  $ENV{'ENSEMBL_SCRIPT'}   = $script;
 
  my $path_info = join '/', @path_segments;
  
  unshift @$raw_path_segments, '', $species;
  
  my $newfile = join '/', @$raw_path_segments;
  
  # Path is changed; HTTP_TEMPORARY_REDIRECT
  
  if (!$flag || ($redirect_if_different && $newfile ne $file)) {
    $r->uri($newfile);
    $r->headers_out->add('Location' => join '?', $newfile, $querystring || ());
    $r->child_terminate;
    
    return HTTP_TEMPORARY_REDIRECT;
  }
  
  my $redirect = get_redirect($script);
  
  if ($redirect) {
    my $newfile = join '/', '', $species, $redirect;
    warn "OLD LINK REDIRECT: $script $newfile" if $ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
    
    $r->headers_out->add('Location' => join '?', $newfile, $querystring || ());
    $r->child_terminate;
    
    return HTTP_TEMPORARY_REDIRECT;
  }
  
  $ENSEMBL_WEB_REGISTRY->initialize_session({
    r       => $r,
    cookie  => $session_cookie,
    species => $species,
    script  => $script,
    type    => $type,
    action  => $action,
  });

  my %web_functions = (
    action    => \&stuff,
    component => \&ingredient,
    config    => \&configurator,
    export    => \&export,
    modal     => \&modal_stuff,
    zmenu     => \&menu
  );
  
  $script = 'export' if $action eq 'Export';
  
  if ($web_functions{$script}) {    
    $web_functions{$script}($r);
    
    return OK;
  }
  
  $script = join '/', map $_ || (), $action, $function if $script eq 'private';
  
  # Search the perl directories for a script to run if it wasn't one of the functions from EnsEMBL::Web::Magic
  my $to_execute = $MEMD ? $MEMD->get("::SCRIPT::$script") : '';
  
  if (!$to_execute) {
    my @dirs;
    
    foreach (grep { -d $_ && -r $_ } @ENSEMBL_PERL_DIRS) {
      push @dirs, "$_/%s";
      push @dirs, "$_/multi"   if -d "$_/multi"   && -r "$_/multi";
      push @dirs, "$_/private" if -d "$_/private" && -r "$_/private";
      push @dirs, "$_/default" if -d "$_/default" && -r "$_/default";
      push @dirs, "$_/common"  if -d "$_/common"  && -r "$_/common";
    }
    
    foreach my $dir (reverse @dirs) {
      my $filename = sprintf($dir, $species) . "/$script";
      
      next unless -r $filename;
      
      $to_execute = $filename;
    }
    
    $MEMD->set("::SCRIPT::$script", $to_execute, undef, 'SCRIPT') if $MEMD;
  }
  
  if ($to_execute && -e $to_execute) {    
    $ENV{'PATH_INFO'} = "/$path_info" if $path_info;
    
    eval 'do $to_execute;';
    
    if ($@) {
      warn $@;
    } else {
      return OK;
    }
  }
  
  return undef;
}

1;
