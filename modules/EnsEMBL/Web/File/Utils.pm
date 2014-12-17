=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
our @EXPORT_OK = qw(get_filename get_extension get_compression uncompress);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);


sub get_filename {
### Get filename from an object or parse it from a path, depending on input
  my $file = shift;
  my $filename = '';
  if (ref($file)) {
    $filename = $file->file_name;
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
  my $file = shift;
  my $extension = '';
  if (ref($file)) {
    $extension = $file->extension;
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
### @param String - full path to file
### @return String - compression type 
  my $path = shift;
  return 'gz'   if $path =~ /\.gz$/;
  return 'zip'  if $path =~ /\.zip$/;
  return 'bz'   if $path =~ /\.bz2?$/;
  return undef;
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

