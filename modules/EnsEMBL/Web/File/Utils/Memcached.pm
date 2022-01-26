=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
use EnsEMBL::Web::File::Utils qw(:all);

use Exporter qw(import);
our @EXPORT_OK = qw(file_exists read_file write_file delete_file);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

sub file_exists {
### Check if a file of this name exists
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction
###                     no_exception Boolean - whether to throw an exception
### @return Hashref (nice mode) or Boolean
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->read_url : $file;
  my $cache = $args->{'hub'}->cache;
  if (!$cache) {
    return $args->{'nice'} ? {'error' => ['No cache found!']} : 0;
  }

  my $result = $cache->get($path);
  if ($args->{'nice'}) {
    return $result ? {'success' => 1} : {'error' => ["Could not located cached file $path"]};
  }
  else {
    if (!$result && !$args->{'no_exception'}) {
      throw exception('FileIOException', "File $path could not be found: $!");
    }
    return $result;
  } 
}

sub read_file {
### Get entire content of file, uncompressed
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     read_compression String - compression type
### @return Hashref (in nice mode) or String - contents of file
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->read_url : $file;
  my $cache = $args->{'hub'}->cache;
  if (!$cache) {
    return $args->{'nice'} ? {'error' => ['No cache found!']} : 0;
  }

  $cache->enable_compress($args->{'compression'} || get_compression($path));

  my $result = $cache->get($path);

  if ($args->{'nice'}) {
    if ($result) {
      return {'content' => $result};
    }
    else {
      warn "!!! COULDN'T RETRIEVE FILE $path FROM CACHE";
      my $filename = get_filename($file);
      return {'error' => ["Could not retrieve file $filename."]};
    }
  }
  else {
    if ($result) {
      return $result;
    }
    else {
      throw exception('FileIOException', sprintf qq(Could not retrieve file '%s' from memory), $path, $@) unless $args->{'no_exception'};
      return 0;
    }
  }

}

sub write_file {
### Write an entire file in one chunk
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     compression String - compression type
###                     content String - content of file
### @return Hashref (in nice mode) or Boolean 
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->write_url : $file;
  my $cache = $args->{'hub'}->cache;
  if (!$cache) {
    return $args->{'nice'} ? {'error' => ['No cache found!']} : 0;
  }

  $cache->enable_compress($args->{'write_compression'} || get_compression($file, 'write'));
  my $result = $cache->set(
                      $path,
                      $args->{'content'},
                      0,
                      ('TMP', get_extension($file), values %{$ENV{'CACHE_TAGS'} || {}}),
                    );

  if ($args->{'nice'}) {
    if ($result) {
      return {'success' => 1};
    }
    else {
      my $filename = get_filename($file, 'write');
      return {'error' => ["Could not write file $filename to memory."]};
    }
  }
  else {
    if ($result) {
      return 1;
    }
    else {
      throw exception('FileIOException', sprintf qq(Could not write file '%s' to memcached.), $path) unless $args->{'no_exception'};
      return 0;
    }
  }
}

sub delete_file {
### Delete a file 
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
### @return Hashref (in nice mode) or Boolean
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->write_url : $file;
  my $cache = $args->{'hub'}->cache;
  if (!$cache) {
    return $args->{'nice'} ? {'error' => ['No cache found!']} : 0;
  }

  my $result = $cache->delete($path);

  if ($args->{'nice'}) {
    if ($result) {
      return {'success' => 1};
    }
    else {
      my $filename = get_filename($file, 'write');
      return {'error' => ["Could not delete file $filename from memory."]};
    }
  }
  else {
    if ($result) {
      return 1;
    }
    else {
      throw exception('FileIOException', "Error occurred when deleting file $path: $!") unless $args->{'no_exception'};
      return 0;
    }
  }
}

1;

