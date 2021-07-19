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

package EnsEMBL::Web::Apache::SSI;

use strict;
use warnings;

use Apache2::Const qw(:common :http :methods);
use File::Spec;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub map_to_file {
  ## Finds out the file that maps to a url and saves it as ENSEMBL_FILENAME entry in subprocess_env
  ## @param Apache2::RequestRec request object
  ## @return URL string if a redirect is needed, undef otherwise, irrespective of whether the file was found or not (If file is not found ENSEMBL_FILENAME is not set)
  my $r     = shift;
  my $path  = $r->subprocess_env('ENSEMBL_PATH');
  my $match = get_htdocs_path($path);

  # we don't have any file corresponding to the path
  return unless $match;

  # if path corresponds to a folder, redirect to it's index.html page
  return "$path/index.html" if $match->{'dir'};

  # file found, save it in subprocess_env
  $r->subprocess_env('ENSEMBL_FILENAME', $match->{'file'});

  return undef;
}

sub get_htdocs_path {
  ## Gets a filesystem path corresponding to the given url path
  ## @param URL path string
  ## @return Hashref with corresponding path saved against key 'dir' or 'file' accordingly
  my $path = shift;

  if ($path =~ /\.html$/ || $path =~ /\/[^\.]+$/) { # path to file with .html extension or without extension (possibly a folder)

    my @path_seg = grep { $_ ne '' } split '/', $path;

    foreach my $dir (@SiteDefs::ENSEMBL_HTDOCS_DIRS) {

      my $filename = File::Spec->catfile($dir, @path_seg);

      return { 'dir'  => $filename } if -d $filename;
      return { 'file' => $filename } if -r $filename;
    }
  }
}

sub get_controller {
  ## Gets the controller class name that should server the given file
  ## @param Absolute path of the file to be served
  ## @return Package name of the required controller
  my $filename = shift;
  return $filename =~ /\/Doxygen\// ? 'EnsEMBL::Web::Controller::Doxygen' : 'EnsEMBL::Web::Controller::SSI';
}

sub handler {
  ## Actual handler called by EnsEMBL::Web::Apache::Handlers for .html files (optionally with 'server side includes')
  ## @param Apache2::RequestRec request object
  ## @param SpeciesDefs object
  ## @return One of the Apache2::Const constants or undef in case this handler can not handle this request
  my ($r, $species_defs) = @_;

  # Populate ENSEMBL_FILENAME or perform redirect if static file location is changed
  if (my $redirect = map_to_file($r)) {
    $r->subprocess_env('ENSEMBL_REDIRECT_PERMANENT', $redirect);
    return;
  }

  # get target filename
  my $filename = $r->subprocess_env('ENSEMBL_FILENAME');

  # we can't do anything with SSI handler if no file is mapped to the URL
  return unless $filename;

  # html files can only be requested via GET
  if ($r->method_number != M_GET) {
    $r->log->error('Invalid method in request ', $r->the_request);
    return HTTP_METHOD_NOT_ALLOWED;
  }

  # get appropriate controller to serve this request
  my $controller = get_controller($filename);

  try {
    $controller = dynamic_require($controller)->new($r, $species_defs, {'filename' => $filename});
    $controller->process;

  } catch {
    throw $_ unless ref $controller && $_->handle($controller);
  };

  return OK;
}

1;
