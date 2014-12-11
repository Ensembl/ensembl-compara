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

### Non-OO wrapper around the core API file-handling code
### Transparently handles file compression (if desired), or for efficiency you
### can explicitly pass a compression type (e.g. 'gz'), or 0 for no compression, 
### to any appropriate method to bypass internal checking

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
###                                'lines'       => [$_->stable_id],
###                                'compression' => 'gz',
###                              };                                         
### }

use strict;

use Bio::EnsEMBL::Utils::IO qw(:all);
use EnsEMBL::Web::File::Utils qw(check_compression);
use EnsEMBL::Web::File::Utils::FileSystem qw(create_path);
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_exists fetch_file read_file read_lines preview_file write_file write_lines append_lines);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

sub file_exists {
### Check if a file of this name exists
### @param File - EnsEMBL::Web::File object or path to file (String)
### @return Boolean
  my $file = shift;
  my $path = ref($file) ? $file->location : $file;
  return -e $path && -f $path;
}

sub delete_file {
### Delete a file 
### @param File - EnsEMBL::Web::File object or path to file (String)
### @return Boolean
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;
  return unlink $path;
}

sub fetch_file {
### Get raw content of file (e.g. for download, hence ignoring compression)
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###         no_exception Boolean - whether to throw an exception
### @return String (entire file)
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;
  my $content;
  eval { $content = slurp($path) }; 

  if ($@ && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Could not fetch contents of file '%s' due to following errors: \n%s), $path, $@);
  }
  return $content;
}

sub read_file {
### Get entire content of file, uncompressed
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###         compression String - compression type
###         no_exception Boolean - whether to throw an exception
### @return String (entire file)
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;
  my $content;

  my $compression = defined($args->{'compression'}) || check_compression($path);
  my $method = $compression ? $compression.'_slurp' : 'slurp';
  eval { 
    no strict 'refs';
    $content = &$method($path) 
  }; 

  if ($@ && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Could not read file '%s' due to following errors: \n%s), $path, $@);
  }
  return $content;
}

sub read_lines {
### Get entire content of file as separate lines
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###         compression String - compression type
###         no_exception Boolean - whether to throw an exception
### @param (optional) String - compression type
### @return Arrayref
  my ($file, $args) = @_;
  my $content = [];
  my $path = ref($file) ? $file->location : $file;

  my $compression = defined($args->{'compression'}) || check_compression($path);
  my $method = $compression ? $compression.'_slurp_to_array' : 'slurp_to_array';
  eval { 
    no strict 'refs';
    $content = &$method($path) 
  }; 

  if ($@ && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Could not read lines from  file '%s' due to following errors: \n%s), $path, $@);
  }
  return $content;
}

sub preview_file {
### Get n lines of a file, e.g. for a web preview
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args (optional) Hashref 
###         compression String - compression type
###         no_exception Boolean - whether to throw an exception
###         limit Integer - number of lines required (defaults to 10)
### @return Arrayref (n lines of file)
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;
  my $limit = $args->{'limit'} || 10;
  my $count = 0;
  my $lines = [];

  my $compression = $args->{'compression'} || check_compression($path);
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

  if ($@ && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Could not fetch preview of file '%s' due to following errors: \n%s), $path, $@);
    ## Throw exception 
  }
  return $lines; 
}

sub write_file {
### Write an entire file in one chunk
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         content String - content of file
###         compression (optional) String - compression type
###         no_exception (optional) Boolean - whether to throw an exception
### @return Void 
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;

  my $content = $args->{'content'};

  if (!$content && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(No content given for file '%s'.), $path);
    return;
  }
 
  ## Create the directory path if it doesn't exist
  my $has_path = _check_path($path);
  
  if ($has_path) { 
    $args->{'compression'} ||= check_compression($path);
    _write_to_file($path, $args, '>',
        sub {
          my ($fh) = @_;
          print $fh $content;
          return;
        }
    );
  }
  else {
    warn "!!! COULD NOT CREATE PATH $path for writing.";
  }
}

sub write_lines {
### Write one or more lines to a file
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param String - full path to file
### @param Args Hashref 
###         lines Arrayref - lines of file
###         compression (optional) String - compression type
###         no_exception (optional) Boolean - whether to throw an exception
### @return Void
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;
  my $lines = $args->{'lines'};

  if (ref($lines) ne 'ARRAY' && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Input for '%s' must be an arrayref. Use the write_file method to create a file from a single string.), $path);
    return;
  }
  
  $args->{'compression'} ||= check_compression($path);
  _write_to_file($path, $args, '>',
      sub {
        my $fh = shift;
        foreach (@$lines) {
          print $fh "$_\n";
        }
        return;
      }
  );
}

sub append_lines {
### Append one or more lines to a file
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         lines Arrayref - lines of file
###         compression (optional) String - compression type
###         no_exception (optional) Boolean - whether to throw an exception
### @return Void
  my ($file, $args) = @_;
  my $path = ref($file) ? $file->location : $file;
  my $lines = $args->{'lines'};

  if (ref($lines) ne 'ARRAY' && !$args->{'no_exception'}) {
    throw exception('FileIOException', sprintf qq(Input for '%s' must be an arrayref. Use the write_file method to create a file from a single string.), $path);
    return;
  }
  
  $args->{'compression'} ||= check_compression($path);
  _write_to_file($path, $args, '>>',
      sub {
        my $fh = shift;
        foreach (@$lines) {
          print $fh "$_\n";
        }
        return;
      }
  );
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
###         compression (optional) String - compression type
###         no_exception (optional) Boolean - whether to throw an exception
### @param write mode String - parameter to pass to API method
### @param Coderef - parameter to pass to API method
### @return Void
  my ($path, $args, @params) = @_;

  my $compression = $args->{'compression'} || check_compression($path);
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

