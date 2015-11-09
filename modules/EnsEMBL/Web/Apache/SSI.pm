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

package EnsEMBL::Web::Apache::SSI;

use strict;
use warnings;

use Apache2::Const qw(:common :http :methods);
use File::Spec;

use EnsEMBL::Web::Controller::Doxygen;
use EnsEMBL::Web::Controller::SSI;

sub map_to_file {
  ## Finds out the file that maps to a url and saves it as ENSEMBL_FILENAME entry in subprocess_env
  ## @param Apache2::RequestRec request object
  ## @return URL string if a redirect is needed, undef otherwise, irrespective of whether the file was found or not (If file is not found ENSEMBL_FILENAME is not set)
  my $r     = shift;
  my $path  = $r->subprocess_env('ENSEMBL_PATH');

  if ($path =~ /\.html$/ || $path =~ /\/[^\.]+$/) { # path to file with .html extension or without extension (possibly a folder)

    my @path_seg = grep { $_ ne '' } split '/', $path;

    foreach my $dir (@SiteDefs::ENSEMBL_HTDOCS_DIRS) {

      my $filename = File::Spec->catfile($dir, @path_seg);

      return "$path/index.html" if -d $filename; # if path corresponds to a folder, redirect to it's index.html page

      if (-r $filename) {
        $r->subprocess_env('ENSEMBL_FILENAME', $filename);
        last;
      }
    }
  }

  return undef;
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
    $r->subprocess_env('ENSEMBL_REDIRECT', $redirect);
    return OK;
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
  get_controller($filename)->new($r, $species_defs, {'filename' => $filename})->process;

  return OK;
}

1;
