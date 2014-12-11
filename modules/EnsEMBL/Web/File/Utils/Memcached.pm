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

package EnsEMBL::Web::File::Utils::Memcached;

### Non-OO library package for reading and writing data to memcached
### Data is automatically compressed for memory efficiency

use strict;

use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_exists read_file write_file delete_file);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

sub file_exists {
### Check if a file of this name exists
### @param File - EnsEMBL::Web::File object
### @param Args (optional) Hashref 
###         compression String - compression type
  my ($file, $args) = @_;
  my $cache = $args->{'hub'}->cache;
  return 1 if $cache->get($file->url);
}

sub read_file {
### Get entire content of file, uncompressed
### @param File - EnsEMBL::Web::File object
### @param Args (optional) Hashref 
###         compression String - compression type
### @return String (entire file)
  my ($file, $args) = @_;
  my $cache = $args->{'hub'}->cache;

  $cache->enable_compress($args->{'compression'} || $file->check_compression);
  return $cache->get($file->URL);
}

sub write_file {
### Write an entire file in one chunk
### @param File - EnsEMBL::Web::File object
### @param Args Hashref 
###         content String - content of file
###         compression (optional) String - compression type
### @return Void 
  my ($file, $args) = @_;
  my $cache = $args->{'hub'}->cache;

  $cache->enable_compress($args->{'compression'} || $file->check_compression);
  return $cache->set(
                      $file->url,
                      $args->{'content'},
                      0,
                      ('TMP', $file->extension, values %{$ENV{'CACHE_TAGS'} || {}}),
                    );
}

1;

