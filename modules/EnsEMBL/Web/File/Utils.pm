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

package EnsEMBL::Web::File::Utils;

### Library for location-independent file functions such as compression support

use strict;

use Compress::Zlib qw//;
use Compress::Bzip2;
use IO::Uncompress::Bunzip2;

use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(sanitise_path sanitise_filename get_filename get_extension get_compression uncompress);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

sub sanitise_path {
### Clean up a given file path to prevent access to non-permitted files
### @param path String - the path you want to sanitise
### @param species_defs EnsEMBL::Web::SpeciesDefs (optional) - allows you 
###        to remove the SERVERROOT and TMP directories from an absolute path
### @return path String
  my ($path, $species_defs) = @_;

  ## Tread carefully with absolute paths!
  if ($path =~ /\//) {
    if ($species_defs) {
      foreach ($species_defs->ENSEMBL_TMP_DIR, 
                $species_defs->ENSEMBL_TMP_DIR_IMG, 
                $species_defs->ENSEMBL_TMP_DIR_TOOLS) {
        $path =~ s/$_//;
      }
    }
    else {
      return undef;
    }
  }

  ## Strip double dots to prevent downloading of files outside permitted directories
  $path =~ s/\.\.//g;
  ## Strip beginning dots to prevent downloading of hidden files
  $path =~ s/^\.//g;
  ## Remove any remaining illegal characters
  $path =~ s/[^\w|-|\.|\/]//g;

  return $path;
}

sub sanitise_filename {
### Users often break the rules for safe, Unix-friendly filenames
### so clean up input
  my $file_name = shift;
  $file_name =~ s/[^\w\.]/_/g;
  return $file_name;
}

sub get_filename {
### Get filename from an object or parse it from a path, depending on input
### @param file - EnsEMBL::Web::File object or string
### @param mode (optional) - String, either 'read' or 'write' 
  my ($file, $mode) = @_;
  my $filename = '';
  if (ref($file)) {
    $filename = $mode eq 'write' ? $file->write_name : $file->read_name;
  }
  else {
    my @path = split('/', $file);
    $filename = $path[-1];
  }
  return $filename;
}

sub get_extension {
### Get file extension from an object or parse it from a path, depending on input
### Note that the returned string does not include any compression extension
### @param file - EnsEMBL::Web::File object or string
### @param mode (optional) - String, either 'read' or 'write' 
  my ($file, $mode) = @_;
  my $extension = '';

  if (ref($file)) {
    $extension = $mode eq 'write' ? $file->write_ext : $file->read_ext;
  }
  else {
    my $filename = get_filename($file);
    my @parts = split(/\./, $filename);
    $extension = pop @parts;
    if ($extension =~ /zip|gz|bz/) {
      $extension = pop @parts;
    }
  }
  return $extension;
}

sub get_compression {
### Helper method to check if file is compressed and, if so,
### what kind of compression appears to have been used.
### @param file - EnsEMBL::Web::File object or string
### @param mode (optional) - String, either 'read' or 'write' 
### @return compression type - String
  my ($file, $mode) = @_;
  my $compression;

  if (ref($file)) {
    $compression = $mode eq 'write' ? $file->write_compression : $file->read_compression;
    return $compression;
  }
  else {
    return 'gz'   if $file =~ /\.gz$/;
    return 'zip'  if $file =~ /\.zip$/;
    return 'bz'   if $file =~ /\.bz2?$/;
    return undef;
  }
}

sub uncompress {
### Compression support for remote files, which cannot use the built-in support
### in Bio::EnsEMBL::Utils::IO. If not passed an explicit compression type, will
### attempt to work out compression type based on the file content
### @param content_ref - reference to file content
### @param compression (optional) - compression type
### @return Void
  my ($content_ref, $compression) = @_;
  $compression ||= ''; ## avoid undef, so we don't have to keep checking it exists!
  my $temp;

  if ($compression eq 'zip' || 
      ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 157 ) { ## ZIP...
    $temp = Compress::Zlib::uncompress($$content_ref);
    $$content_ref = $temp;
  } 
  elsif ($compression eq 'gz' || 
      ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 139 ) { ## GZIP...
    $temp = Compress::Zlib::memGunzip($$content_ref);
    $$content_ref = $temp;
  } 
  elsif ($compression eq 'bz' || $$content_ref =~ /^BZh([1-9])1AY&SY/ ) {                            ## GZIP2
    my $temp = Compress::Bzip2::decompress($content_ref); ## Try to uncompress a 1.02 stream!
    unless($temp) {
      my $T = $$content_ref;
      my $status = IO::Uncompress::Bunzip2::bunzip2 \$T,\$temp;            ## If this fails try a 1.03 stream!
    }
    $$content_ref = $temp;
  }

  return;
}


1;

