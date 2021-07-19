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

package EnsEMBL::Web::Apache::SpeciesHandler;

use strict;
use warnings;

use Apache2::Const qw(:common :http :methods);

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::OldLinks qw(get_redirect);
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub get_controller {
  ## Gets the required controller package name needed for the request and modifies the passed path array to remove any segments related to the Controller
  ## @param Species name
  ## @param Arrayref of path segments
  ## @param URI query part
  ## @return Package name for controller (string) if controller is found for the request, undef otherwise
  my ($species, $path_segments, $query) = @_;

  # extract Controller if it's present among the ones allowed to be passed via URL
  my %allowed     = map { $_ => 1} @{$SiteDefs::ALLOWED_URL_CONTROLLERS};
  my $controller  = @$path_segments && $allowed{$path_segments->[0]} ? shift @$path_segments : undef;

  # if not, get controller from OBJECT_TO_CONTROLLER_MAP
  $controller ||= $SiteDefs::OBJECT_TO_CONTROLLER_MAP->{$path_segments->[0]} if @$path_segments && $path_segments->[0];

  return $controller && "EnsEMBL::Web::Controller::$controller";
}

sub get_redirect_uri {
  ## Gets a new URI if redirect needs to be performed for the given species and URI path
  ## @param Species name
  ## @param Arrayref of path segments
  ## @param URI query part
  ## @return URI string if http redirect is required, undef otherwise
  my ($species, $path_segments, $query) = @_;

  # old species home page redirect
  return $species eq 'Multi' ? '/index.html' : "/$species/Info/Index" if !@$path_segments || $path_segments->[0] eq 'index.html';

  # other old redirects
  if (my $redirect = get_redirect($path_segments->[0])) {
    $redirect = join('?', join('/', '', $species, $redirect), $query || ());

    warn "OLD LINK REDIRECT: $path_segments->[0] $redirect\n" if $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;

    return $redirect;
  }

  return undef;
}

sub handler {
  ## Actual handler called by EnsEMBL::Web::Apache::Handlers
  ## @param Apache2::RequestRec request object
  ## @param SpeciesDefs object
  ## @return One of the Apache2::Const constants or undef in case this handler can not handle this request
  my ($r, $species_defs) = @_;

  my $species         = $r->subprocess_env('ENSEMBL_SPECIES');
  my $path            = $r->subprocess_env('ENSEMBL_PATH');
  my $query           = $r->subprocess_env('ENSEMBL_QUERY');
  my @path_segments   = grep $_, split '/', $path;

  # handle redirects
  if (my $redirect = get_redirect_uri($species, \@path_segments, $query)) {
    $r->subprocess_env('ENSEMBL_REDIRECT_PERMANENT', $redirect);
    return;
  }

  # get controller
  my $controller = get_controller($species, \@path_segments, $query);

  # let the next handler handle it if the URL does not map to any Controller
  return unless $controller;

  try {
    $controller = dynamic_require($controller)->new($r, $species_defs, {
      'species'       => $species,
      'path_segments' => \@path_segments,
      'query'         => $query
    });
    $controller->process;

  } catch {
    throw $_ unless ref $controller && $_->handle($controller);
  };

  return OK;
}

1;
