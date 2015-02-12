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

package EnsEMBL::Web::File::Utils::IO;

### Non-OO wrapper around the core API file-handling code
### Transparently handles file compression (if desired), or for efficiency you
### can explicitly pass a compression type (e.g. 'gz'), or 0 for no compression, 
### to any appropriate method to bypass internal checking

### For web interfaces, it is recommended that you set the 'nice' flag in the
### argument hash in order to return user-friendly error messages and turn off
### exceptions. The method will return a hashref containing either error messages,
### a 'success' flag, or some kind of content.

### The "non-nice" mode returns less structured data for capture by the calling 
### script and will also throw exceptions unless the 'no_exception' flag is passed.

### Examples:

### use EnsEMBL::Web::File::Utils::IO qw/:all/;

### Read file contents into a variable
### my $file_content = read_file('/path/to/my/file.txt', {'no_exception' => 1});

### Fetch API features and output data about each one to a gzipped file
### my $output_file = '/path/to/my/output.gz';
### my @features = $adaptor->fetch_Features();
### foreach (@features) {
###   # Write one line per feature
###   append_lines($output_file, {
###                                'lines'              => [$_->stable_id],
###                                'write_compression'  => 'gz',
###                                'nice'               => 0,
###                              };                                         
### }

use strict;

use Bio::EnsEMBL::Utils::IO qw(:all);
use EnsEMBL::Web::File::Utils qw(get_filename get_compression);
use EnsEMBL::Web::File::Utils::FileSystem qw(create_path);
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_exists fetch_file read_file read_lines preview_file write_file write_lines append_lines);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

sub file_exists {
### Check if a file of this name exists
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction
###                     no_exception Boolean - whether to throw an exception
### @return Hashref (nice mode) or Boolean
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_read_path : $file;
  if ($args->{'nice'}) {
    if (-e $path && -f $path) {
      return {'success' => 1};
    }
    else {
      my $filename = get_filename($file);
      return {'error' => ["Could not find file $filename."]};
    }
  }
  else {
    if (-e $path && -f $path) {
      return 1;
    }
    else {
      throw exception('FileIOException', "File $path could not be found: $!") unless $args->{'no_exception'};
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
  my $path = ref($file) ? $file->absolute_write_path : $file;
  if ($args->{'nice'}) {
    if (unlink $path) {
      return {'success' => 1};
    }
    else {
      my $filename = get_filename($file);
      return {'error' => ["Could not delete file $filename: $!"]};
    }
  }
  else {
    if (unlink $path) {
      return 1;
    }
    else {
      throw exception('FileIOException', "Error occurred when deleting file $path: $!") unless $args->{'no_exception'};
      return 0;
    }
  }
}

sub fetch_file {
### Get raw content of file (e.g. for download, hence ignoring compression)
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
### @return Hashref (in nice mode) or String - entire file
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_read_path : $file;
  my $content;
  eval { $content = slurp($path) }; 
  if ($args->{'nice'}) {
    if ($@) {
      warn "!!! COULDN'T FETCH FILE $path: $@";
      my $filename = get_filename($file);
      return {'error' => ["Could not fetch file $filename for downloading."]};
    }
    else {
      return {'content' => $content};
    }
  }
  else {
    if ($@) {
      throw exception('FileIOException', sprintf qq(Could not fetch contents of file '%s' due to following errors: \n%s), $path, $@) unless $args->{'no_exception'};
      return undef;
    }
    else {
      return $content;
    }
  }
}

sub read_file {
### Get entire content of file, uncompressed
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     compression String - compression type
### @return Hashref (in nice mode) or String - contents of file
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_read_path : $file;
  my $content;

  my $compression = defined($args->{'read_compression'}) || get_compression($path);
  my $method = $compression ? $compression.'_slurp' : 'slurp';
  eval { 
    no strict 'refs';
    $content = &$method($path) 
  }; 

  if ($args->{'nice'}) {
    if ($@) {
      warn "!!! COULDN'T READ FILE $path: $@";
      my $filename = get_filename($file);
      return {'error' => ["Could not read file $filename."]};
    }
    else {
      return {'content' => $content};
    }
  }
  else {
    if ($@) {
      throw exception('FileIOException', sprintf qq(Could not read file '%s' due to following errors: \n%s), $path, $@) unless $args->{'no_exception'};
      return undef;
    }
    else {
      return $content;
    }
  }
}

sub read_lines {
### Get entire content of file as separate lines
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     compression String - compression type
### @param (optional) String - compression type
### @return Hashref (in nice mode) or Arrayref containing lines of file 
  my ($file, $args) = @_;
  my $content = [];
  my $path = ref($file) ? $file->absolute_read_path : $file;

  my $compression = defined($args->{'read_compression'}) || get_compression($file);
  my $method = $compression ? $compression.'_slurp_to_array' : 'slurp_to_array';
  eval { 
    no strict 'refs';
    $content = &$method($path) 
  }; 

  if ($args->{'nice'}) {
    if ($@) {
      warn "!!! COULDN'T READ LINES FROM FILE $path: $@";
      my $filename = get_filename($file);
      return {'error' => ["Could not read file $filename."]};
    }
    else {
      return {'content' => $content};
    }
  }
  else {
    if ($@) {
      throw exception('FileIOException', sprintf qq(Could not read lines from file '%s' due to following errors: \n%s), $path, $@) unless $args->{'no_exception'};
      return undef;
    }
    else {
      return $content;
    }
  }
}

sub preview_file {
### Get n lines of a file, e.g. for a web preview
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     read_compression String - compression type
###                     limit Integer - number of lines required (defaults to 10)
### @return Hashref (in nice mode) or Arrayref - n lines of file
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_read_path : $file;
  my $limit = $args->{'limit'} || 10;
  my $count = 0;
  my $lines = [];

  my $compression = $args->{'read_compression'} || get_compression($file);
  my $method = $compression ? $compression.'_work_with_file' : 'work_with_file';

  eval { 
    no strict 'refs';
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

  if ($args->{'nice'}) {
    if ($@) {
      warn "!!! COULDN'T READ PREVIEW FROM FILE $path: $@";
      my $filename = get_filename($file);
      return {'error' => ["Could not read file $filename."]};
    }
    else {
      return {'content' => $lines};
    }
  }
  else {
    if ($@) {
      throw exception('FileIOException', sprintf qq(Could not fetch preview of file '%s' due to following errors: \n%s), $path, $@) unless $args->{'no_exception'};
      return undef;
    }
    else {
      return $lines;
    }
  }
}

sub write_file {
### Write an entire file in one chunk
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     write_compression String - compression type
###                     content String - content of file
### @return Hashref (in nice mode) or Boolean 
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_write_path : $file;

  my $content = $args->{'content'};
  my $filename = get_filename($file, 'write');

  if (!$content) {
    if ($args->{'nice'}) {
      return {'error' => ["No content given for file $filename."]};
    }
    else {
      throw exception('FileIOException', sprintf qq(No content given for file '%s'.), $path) unless $args->{'no_exception'};
      return 0;
    }
  }
 
  ## Create the directory path if it doesn't exist
  my $has_path = _check_path($path);
  
  if ($has_path) { 
    $args->{'write_compression'} ||= get_compression($file, 'write');
    eval {
      _write_to_file($path, $args, '>',
        sub {
          my ($fh) = @_;
          print $fh $content;
          return;
        }
      );
    };
    if ($args->{'nice'}) {
      if ($@) {
        return {'error' => ["Could not create path for writing file $filename."]};
      }
      else {
        return {'success' => 1};
      }
    }
    else {
      if ($@) {
        throw exception('FileIOException', sprintf qq(Could not create path '%s'.), $path) unless $args->{'no_exception'};
        return 0;
      }
      else {
        return 1;
      }
    }
  }
  else {
    if ($args->{'nice'}) {
      return {'error' => ["Could not create path for writing file $filename."]};
    }
    else {
      throw exception('FileIOException', sprintf qq(Could not create path '%s'.), $path) unless $args->{'no_exception'};
      return 0;
    }
  }
}

sub write_lines {
### Write one or more lines to a file
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param String - full path to file
### @param Args Hashref 
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     write_compression String - compression type
###                     lines Arrayref - lines of file
### @return Hashref (in nice mode) or Boolean
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_write_path : $file;
  my $lines = $args->{'lines'};

  if (ref($lines) ne 'ARRAY') {
    if ($args->{'nice'}) {
      throw exception('FileIOException', sprintf qq(Input for '%s' must be an arrayref. Use the write_file method to create a file from a single string.), $path) unless $args->{'no_exception'};
      return 0;
    }
    else {
      return {'error' => ["Cannot write lines - input must be an arrayref."]};
    }
  }
  
  ## Create the directory path if it doesn't exist
  my $has_path = _check_path($path);
  
  $args->{'write_compression'} ||= get_compression($path, 'write');
  eval {
      _write_to_file($path, $args, '>',
        sub {
          my $fh = shift;
          foreach (@$lines) {
            print $fh "$_\n";
          }
          return;
        }
      );
  };
  if ($args->{'nice'}) {
    if ($@) {
      my $filename = get_filename($file);
      return {'error' => ["Could not write lines to file $filename."]};
    }
    else {
      return {'success' => 1};
    }
  }
  else {
    if ($@) {
      throw exception('FileIOException', sprintf qq(Could not write lines to file '%s'.), $path) unless $args->{'no_exception'};
      return 0;
    }
    else {
      return 1;
    }
  }
}

sub append_lines {
### Append one or more lines to a file
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###                     nice Boolean - see introduction 
###                     no_exception Boolean - whether to throw an exception
###                     write_compression String - compression type
###                     lines Arrayref - lines of file
### @return Hashref (in nice mode) or Boolean
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->absolute_write_path : $file;
  my $lines = $args->{'lines'};

  if (ref($lines) ne 'ARRAY') {
    if ($args->{'nice'}) {
      return {'error' => ["Cannot write lines - input must be an arrayref."]};
    }
    else {
      throw exception('FileIOException', sprintf qq(Input for '%s' must be an arrayref.), $path) unless $args->{'no_exception'};
      return 0;
    }
  }
  
  ## Create the directory path if it doesn't exist
  my $has_path = _check_path($path);
  
  $args->{'write_compression'} ||= get_compression($file, 'write');
  eval {
    _write_to_file($path, $args, '>>',
      sub {
        my $fh = shift;
        foreach (@$lines) {
          print $fh "$_\n";
        }
        return;
      }
    );
  };

  if ($args->{'nice'}) {
    if ($@) {
      my $filename = get_filename($file, 'write');
      return {'error' => ["Could not append lines to file $filename."]};
    }
    else {
      return {'success' => 1};
    }
  }
  else {
    if ($@) {
      throw exception('FileIOException', sprintf qq(Could not append lines to file '%s'.), $path) unless $args->{'no_exception'};
      return 0;
    }
    else {
      return 1;
    }
  }
}

sub _check_path {
### Check if the path you want to write to exists, and create it if not
  my $path = shift;
  my @path_elements = split('/', $path);
  pop @path_elements;
  my $dir = join ('/', @path_elements);

  if (-e $dir && -d $dir) {
    return scalar @path_elements;
  }
  else {
    my $dirs = create_path($dir, {'no_exception' => 1});
    return scalar @$dirs;
  }
}

sub _write_to_file {
### Generic method for file-writing
### @private
### @param String - full path to file
### @param Args Hashref 
###         write_compression (optional) String - compression type
###         no_exception (optional) Boolean - whether to throw an exception
### @param write mode String - parameter to pass to API method
### @param Coderef - parameter to pass to API method
### @return Void
  my ($path, $args, @params) = @_;

  my $compression = $args->{'write_compression'} || get_compression($path);
  my $method = $compression ? $compression.'_work_with_file' : 'work_with_file';
  eval { 
    no strict 'refs';
    &$method($path, @params); 
  };

  if ($@) {
    if (!$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Could not write to file '%s' due to following errors: \n%s), $path, $@);
    }
  }
  else {
    return 1;
  }
}

1;

