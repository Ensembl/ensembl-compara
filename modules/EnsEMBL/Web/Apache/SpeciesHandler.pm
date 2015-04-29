=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Apache::SpeciesHandler;

use strict;

use Apache2::Const qw(:common :http :methods);

use SiteDefs;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::OldLinks qw(get_redirect);

our $MEMD = EnsEMBL::Web::Cache->new;

sub handler_species {
  my ($r, $cookies, $species, $raw_path_segments, $querystring, $file, $flag) = @_;
  
  my $redirect_if_different = 1;
  my @path_segments         = @$raw_path_segments;
  my ($plugin, $type, $action, $function);
  
  s/\W//g for @path_segments; # clean up dodgy characters
  
  # Parse the initial path segments, looking for valid ENSEMBL_TYPE values
  my $seg    = shift @path_segments;
  my $script = $SiteDefs::OBJECT_TO_SCRIPT->{$seg};
  
  if ($seg eq 'Component' || $seg eq 'ZMenu' || $seg eq 'Config' || $seg eq 'Json' || $seg eq 'Download') {
    $type   = shift @path_segments if $SiteDefs::OBJECT_TO_SCRIPT->{$path_segments[0]} || $seg eq 'ZMenu' || $seg eq 'Json' || $seg eq 'Download';
    $plugin = shift @path_segments if $seg eq 'Component';
  } else {
    $type = $seg;
  }
  
  $action   = shift @path_segments;
  $function = shift @path_segments;
  
  $r->custom_response($_, "/$species/Info/Error/$_") for (NOT_FOUND, HTTP_BAD_REQUEST, FORBIDDEN, AUTH_REQUIRED);

  if ($flag && $script) {
    $ENV{'ENSEMBL_FACTORY'}   = 'MultipleLocation' if $type eq 'Location' && $action =~ /^Multi(Ideogram.*|Top|Bottom)?$/;
    $ENV{'ENSEMBL_COMPONENT'} = join  '::', 'EnsEMBL', $plugin, 'Component', $type, $action =~ s/__/::/gr if $script eq 'Component';  
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
  
  # Path is changed: HTTP_TEMPORARY_REDIRECT
  if (!$flag || ($redirect_if_different && $newfile ne $file)) {
    $r->uri($newfile);
    $r->headers_out->add('Location' => join '?', $newfile, $querystring || ());
    $r->child_terminate;
    
    return HTTP_TEMPORARY_REDIRECT;
  }
  
  my $redirect = get_redirect($script);
  
  if ($redirect) {
    my $newfile = join '/', '', $species, $redirect;
    warn "OLD LINK REDIRECT: $script $newfile" if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
    
    $r->headers_out->add('Location' => join '?', $newfile, $querystring || ());
    $r->child_terminate;
    
    return HTTP_TEMPORARY_REDIRECT;
  }
 
  my $controller = "EnsEMBL::Web::Controller::$script";  
  
  eval "use $controller";
  
  if (!$@) {
    $controller->new($r, $cookies);
    return OK;
  }
  
  # Search the perl directories for a script to run if it wasn't one of the functions from EnsEMBL::Web::Magic
  my $to_execute = $MEMD ? $MEMD->get("::SCRIPT::$script") : '';
  
  if (!$to_execute) {
    my @dirs;
    
    foreach (grep { -d $_ && -r $_ } @SiteDefs::ENSEMBL_PERL_DIRS) {
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
