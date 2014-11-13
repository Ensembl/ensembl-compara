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

package EnsEMBL::Web::File::Utils::IO;

### Wrapper around the core API file-handling code

use strict;

use Bio::EnsEMBL::Utils::IO qw/:all/;
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_exists fetch_content read_file read_lines preview_file write_lines append_lines);

sub exists {
### Check if a file of this name exists
### @param String - full path to file
### @return Boolean
  my $path = shift;
  return -e $path && -f $path;
}

sub fetch_content {
### Get raw content of file (e.g. for download, hence ignoring compression)
### @param Path string
### @return String (entire file)
  my $path = shift;
  my $content;
  eval { $content = slurp($path) }; 
  if ($@) {
    ## Throw exception 
  }
  return $content;
}

sub read_file {
### Get entire content of file, uncompressed
### @param String - full path to file
### @param (optional) String - compression type
### @return String (entire file)
  my ($path, $compression) = @_;
  my $content;
  if (($compression && $compression eq 'gz') || _compression($path) eq 'gz') {
    eval { $content = gz_slurp($path) }; 
  }
  else {
    eval { $content = slurp($path) }; 
  }
  if ($@) {
    ## Throw exception 
  }
  return $content;
}

sub read_lines {
### Get entire content of file as separate lines
### @param String - full path to file
### @param (optional) String - compression type
### @return Arrayref
  my ($path, $compression) = @_;
  my $content = [];
  if (($compression && $compression eq 'gz') || _compression($path) eq 'gz') {
    eval { $content = gz_slurp_to_array($path) }; 
  }
  else {
    eval { $content = slurp_to_array($path) }; 
  }
  if ($@) {
    ## Throw exception 
  }
  return $content;
}

sub preview_file {
### Get n lines of a file, e.g. for a web preview
### @param String - full path to file
### @param (optional) String - compression type
### @param (optional) Integer - number of lines required (default is 10)
### @return Arrayref (n lines of file)
  my ($path, $compression, $limit) = @_;
  $limit ||= 10;
  my $count = 0;
  my $lines = [];
  my $method = (($compression && $compression eq 'gz') || _compression($path) eq 'gz') 
                    ? 'gz_work_with_file' : 'work_with_file';

  eval { 
    &$method($path, 'r',
      sub {
        my $fh = shift;
        while (<$fh>) {
          $count++;
          push @$lines, $_;
          last if $count == $limit;
        }
        return;
      }
    );
  };

  if ($@) {
    ## Throw exception 
  }
  return $lines; 
}

sub write_lines {
### Write one or more lines to a file
### @param String - full path to file
### @param Arrayref - lines of file
### @param (optional) String - compression type
### @return Void
  my ($path, $lines, $compression) = @_;
  $compression ||= _compression($path);

  unless (ref($lines) eq 'ARRAY') {
    # Throw exception
    #$self->{'error'} = 'Input must be an arrayref!';
    return;
  }
  
  $self->_write_to_file($path, $compression, '>',
      sub {
        my $fh = shift;
        foreach (@$lines) {
          print $fh, $_;
        }
        return;
      }
  );
}

sub append_lines {
### Append one or more lines to a file
### @param String - full path to file
### @param Arrayref - lines of file
### @param (optional) String - compression type
### @return Void
  my ($path, $lines, $compression) = @_;
  $compression ||= _compression($path);

  unless (ref($lines) eq 'ARRAY') {
    # Throw exception
    #$self->{'error'} = 'Input must be an arrayref!';
    return;
  }
  
  $self->_write_to_file($path, $compression, '>>',
      sub {
        my $fh = shift;
        foreach (@$lines) {
          print $fh, $_;
        }
        return;
      }
  );
}

sub _write_to_file {
  my ($self, $compression, @params) = @_;

  if ($compression && $compression eq 'gz') {
    eval { gz_work_with_file(@params); }
  }
  else {
    eval { work_with_file(@params); }
  }

  if ($@) {
    ## Throw exception
  }
}


sub _compression {
### Helper method to check if file is compressed and, if so,
### what kind of compression appears to have been used.
### Currently only supports gzip, but should be extended to
### zip and bzip
  my $path = shift;
  return $path =~ /\.gz$/ ? 'gz' : undef;
}

1;

