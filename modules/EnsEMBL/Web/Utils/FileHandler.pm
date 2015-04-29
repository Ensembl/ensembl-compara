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

package EnsEMBL::Web::Utils::FileHandler;

use strict;
use warnings;

use FileHandle;
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_get_contents file_put_contents file_append_contents);

sub file_get_contents {
  ## Reads a file from memory location
  ## @param File location
  ## @return List of lines of files
  my $filename    = shift;

  throw exception('FileHandlerException', "File $filename could not be found") if !-e $filename || -d $filename;

  my $file_handle = get_file_handle($filename, 'r');
  my @lines       = $file_handle->getlines;
  $file_handle->close;
  return @lines;
}

sub file_put_contents {
  ## Write the content to the file
  ## Creates a new file if not existing one
  ## Overwrites any existing content if file existing
  ## @param  File location
  ## @params List of text to be written
  ## @return 1 if successful
  my $file_handle = get_file_handle(shift, 'w');
  my $return      = $file_handle->print(@_);
  $file_handle->close;

  return $return;
}

sub file_append_contents {
  ## Appends the content to the file
  ## Creates a new file if not existing one
  ## @param  File location
  ## @params List of lines of text to be appended
  ## @return 1 if successful
  my $file_handle = get_file_handle(shift, 'a');
  my $return      = $file_handle->print(@_);
  $file_handle->close;

  return $return;
}

sub get_file_handle {
  ## Gets a file handle object and open the given file
  ## Private method not exported
  my ($file, $arg) = @_;

  my $file_handle = FileHandle->new;
  $file_handle->open($file, $arg) or throw exception('FileHandlerException', "File $file could not be opened");
  return $file_handle;
}

1;
