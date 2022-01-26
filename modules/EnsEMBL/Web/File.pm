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

package EnsEMBL::Web::File;

use strict;

use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::Utils::RandomString qw(random_ticket);
use EnsEMBL::Web::File::Utils qw/sanitise_filename get_extension get_compression check_compression/;
use EnsEMBL::Web::File::Utils::IO qw/:all/;
use EnsEMBL::Web::File::Utils::URL qw/:all/;
use EnsEMBL::Web::File::Utils::Memcached qw/:all/;
use EnsEMBL::Web::Utils::Encryption qw/encrypt_value/;

### Replacement for EnsEMBL::Web::TmpFile, using the file-handling
### functionality in EnsEMBL::Web::File::Utils 

### Data can be written to disk or, if enabled and appropriate, memcached
### Note that to aid cleanup, all files written to disk should use a common
### path pattern, as follows:
### base_dir/subcategory/datestamp/user_identifier/sub_dir/file_name.ext
###  - base_dir can be set in subclasses - this is the main temporary file location
###    N.B. we store a key to the path_map and look up the actual path only when
###    needed, so as to avoid exposing actual file locations to the user
###  - category - e.g. is this temporary or "saved" data 
###  - subcategory - optional (mostly used by tools)
###  - datestamp aids in cleaning up older files by date
###  - user_identifier (optional) is either session id or user id, and 
###    helps to ensure that users only see their own data
###  - sub_dir is optional - it's used by a few pages to separate content further
###  - file_name may be auto-generated, or set by the user

our %path_map = (
                'user'  => ['ENSEMBL_USERDATA_DIR', 'ENSEMBL_USERDATA_URL'],
                'image' => ['ENSEMBL_TMP_DIR_IMG', 'ENSEMBL_TMP_URL_IMG'],
                'tools' => ['ENSEMBL_TMP_DIR_TOOLS'],
                );

sub new {
### @constructor
### N.B. You need either the path (to an existing file) or
### the name and extension (for new files)
### @param Hash of arguments 
###  - hub Object - for getting TMP_DIR location, etc
###  - file String - full path to file (optional)
###  - name String (optional) String - not including file extension
###  - extension String (optional) String
###  - compression String (optional) String
### @return EnsEMBL::Web::File
  my ($class, %args) = @_;
  #use Carp qw(cluck); cluck 'CREATING NEW FILE OBJECT';
  #warn '!!! CREATING NEW FILE OBJECT';
  #foreach (sort keys %args) {
  #  warn "@@@ ARG $_ = ".$args{$_};
  #}

  my $input_drivers = ['IO'];
  my $absolute = 0;
  my $source = 'file';
  if ($args{'file'} && $args{'file'} =~ /^(http|ftp)/) {
    $absolute = 1;
    $source = 'url';
    $input_drivers = ['URL'];
  }
  elsif ($args{'upload'}) {
    $absolute = 1;
  }

  my $self = {
              'hub'             => $args{'hub'},
              'format'          => $args{'format'},
              'absolute'        => $absolute,
              'source'          => $source,
              'base_dir'        => $args{'base_dir'} || 'user',
              'category'        => $args{'category'} || 'temporary',
              'subcategory'     => $args{'subcategory'},
              'input_drivers'   => scalar @{$args{'input_drivers'}||[]} ? $args{'input_drivers'} : $input_drivers, 
              'output_drivers'  => $args{'output_drivers'} || ['IO'], 
              'error'           => undef,
              };

  bless $self, $class;

  ## Option to create an "empty" object with minimal information 
  $self->init(%args) unless $args{'empty'};

  return $self;
}

sub init {
  my ($self, %args) = @_;
  my $read_path = $args{'file'};
  my $bare_name;

  ## size limit
  $self->{'size_limit'} = $args{'size_limit'} || 0;

  ## Override default input drivers if reading from URL
  if ($read_path =~ /^(http|ftp)/) {
    $self->{'input_drivers'} = ['URL'];
  }

  ## Existing file or user upload
  if ($read_path) {
    $self->{'read_location'} = $read_path;

    ## Clean up the path before processing further
    $read_path  =~ s/^\s+//;
    $read_path  =~ s/\s+$//;

    my $read_name;
    if ($args{'upload'} && $args{'upload'} eq 'cgi') {
      $read_name = $args{'name'};
    }
    else {
      ## Backwards compatibility with previously uploaded TmpFile paths
      ## TODO Remove if block, once TmpFile modules are removed
      if ($args{'prefix'}) {
        $self->{'read_location'} = join('/', $args{'prefix'}, $read_path);
        $read_name = $read_path;
      }
      else {
        my @path = grep length, split('/', $read_path);
        $read_name = sanitise_filename(pop @path);
      }
    }

    my ($name, $extension, $compression) = _parse_filename($read_name);

    ## If being really paranoid about input, e.g. for user uploads
    if ($args{'check_compression'}) {
      my $fetched = $self->fetch;      
      if ($fetched->{'content'}) {
        my $content = $fetched->{'content'};
        $compression = check_compression(\$content);
      }
    }

    $bare_name                  = $name;
    $self->{'read_name'}        = $read_name;
    $self->{'read_ext'}         = $extension;
    $self->{'read_compression'} = $compression;
    $self->{'read_compress'}    = $self->{'read_compression'} ? 1 : 0;
  }
  elsif ($args{'content'}) {
    ## Creating a new file from form input
    $self->{'content'} = $args{'content'};
  }

  $self->{'format'} ||= $args{'format'};

  ## Prepare to write new local file
  ## N.B. We need to allow for user-supplied names with and without extensions
  my ($name, $extension, $compression);
  my $sub_dir = $args{'sub_dir'};

  if ($args{'write_location'}) {
    ## Refreshing a previous upload
    $self->{'write_location'} = $args{'write_location'};
    my @path = split('/', $args{'write_location'});
    ($name, $extension, $compression) = _parse_filename($path[-1]);
    $self->{'write_ext'} = $extension;
    $self->{'write_name'} = $name.'.'.$extension;

    $self->{'write_compression'} = $compression;
    $self->{'write_name'} .= '.'.$compression if $compression;
  }
  elsif ($args{'upload'} || !$read_path) {
    my $filename = $args{'name'};
    if ($filename) {

      ($name, $extension, $compression) = _parse_filename(sanitise_filename($filename));

      ## Set a random path in case we have multiple files with this name
      $sub_dir ||= random_ticket;
    }
    elsif ($self->{'read_name'}) { 
      ## Uploaded file, so keep original name but save uncompressed
      $name = $bare_name;
      $extension = $self->{'read_ext'};
      $compression = 0;
      ## Set a random path in case we have multiple files with this name
      $sub_dir ||= random_ticket;
    }
    else {
      ## Create a file name if none given
      $name = random_ticket;
    }

    if (!$extension) {
      $extension = $args{'extension'} || 'txt';
    }

    if ($args{'uncompress'}) {
      $compression = 0;
    }
    elsif (!$compression) {
      $compression = $args{'compression'} || 0;
      ## Default to gzip
      if (($args{'compress'} && !$compression) || ($compression && $compression !~ /gz|bz|zip/)) {
        $compression = 'gz';
      }
    }

    $self->{'write_ext'} = $extension;
    $self->{'write_name'} = $name.'.'.$extension;

    $self->{'write_compression'} = $compression;
    $self->{'write_name'} .= '.'.$compression if $compression;

    ## Now determine where to write the file to
    my $category    = $args{'category'} || $self->set_category;
    my $subcategory = $args{'subcategory'} || $self->get_subcategory;
    my $datestamp   = $args{'datestamp'} || $self->set_datestamp;
    my $user_id     = $args{'user_identifier'} || $self->set_user_identifier;

    my @path_elements = ($category);
    push @path_elements, $subcategory if $subcategory;
    push @path_elements, $datestamp;
    push @path_elements, $user_id if $user_id;
    push @path_elements, $sub_dir if $sub_dir;
    push @path_elements, $self->{'write_name'};

    $self->{'write_location'} = join('/', @path_elements); 
  } 

  ## Is this a temporary or "saved" file?
  $self->{'status'} = $args{'status'};

  #warn ">>> FILE OBJECT:";
  #while (my($k, $v) = each (%$self)) {
  #  warn "... SET $k = $v";
  #}

}

sub read_name {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
### N.B. This is the full name with extensions
  my $self = shift;
  return $self->{'read_name'} || $self->{'write_name'};
}

sub write_name {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
### N.B. This is the full name with extensions
  my $self = shift;
  return $self->{'write_name'} || $self->{'read_name'};
}

sub read_ext {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_ext'} || $self->{'write_ext'};
}

sub write_ext {
### a
### Assume extension is same unless set otherwise
  my $self = shift;
  return $self->{'write_ext'} || $self->{'read_ext'};
}

sub read_compression {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_compression'} || $self->{'write_compression'};
}

sub write_compression {
### a
  my $self = shift;
  return $self->{'write_compression'};
}

sub compress {
### a
### N.B. this only applies to writing files
  my $self = shift;
  return $self->{'compress'};
}


sub read_location {
### a
### Relative path to directory we want to read from
### N.B. Use this method anywhere that URLs might be exposed to the browser
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_location'} || $self->{'write_location'};
}

sub write_location {
### a
### Relative path to directory we want to write to 
### N.B. Use this method anywhere that URLs might be exposed to the browser
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'write_location'} || $self->{'read_location'};
}

sub base_read_path {
### a
### Full standard path to file, omitting file-specific subdirectory
  my $self = shift;
  my $dir_key     = $path_map{$self->{'base_dir'}}->[0];
  my @path        = ($self->hub->species_defs->$dir_key, $self->get_category);
  my $subcategory = $self->get_subcategory;
  my $user_id     = $self->get_user_identifier;
  push @path, $subcategory if $subcategory;
  push @path, $self->get_datestamp;
  push @path, $user_id if $user_id;
  return join('/', @path); 
}

sub absolute_read_path {
### a
### Absolute path to a file we want to read from
### IMPORTANT: For local files, do not use this value anywhere that might be exposed to the browser!
  my $self = shift;
  if ($self->{'absolute'}) {
    return $self->read_location;
  }
  else {
    my $dir_key = $path_map{$self->{'base_dir'}}->[0];
    my $absolute_path = $self->hub->species_defs->$dir_key;
    return join('/', $absolute_path, $self->read_location);
  }
}

sub absolute_write_path {
### a
### Absolute path to a file we want to write to
### IMPORTANT: Do not use this value anywhere that might be exposed to the browser!
  my $self = shift;
  my $dir_key = $path_map{$self->{'base_dir'}}->[0];
  my $absolute_path = $self->hub->species_defs->$dir_key;
  return join('/', $absolute_path, $self->write_location);
}

sub read_url {
### a
### Absolute path to a file we want to read from
### IMPORTANT: Do not use this value anywhere that might be exposed to the browser!
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  if ($self->{'absolute'}) {
    return $self->read_location;
  }
  else {
    my $dir_key = $path_map{$self->{'base_dir'}}->[1];
    my $base_url = $self->hub->species_defs->$dir_key;
    return join('/', $base_url, $self->read_location);
  }
}

sub write_url {
### a
### Absolute path to a file we want to write to 
### IMPORTANT: Do not use this value anywhere that might be exposed to the browser!
### Assume that we write back to the same file unless 
### write parameters have been set
### N.B. whilst we don't literally write to a url, memcached
### uses this method to create a virtual path to a saved file
  my $self = shift;
  my $dir_key = $path_map{$self->{'base_dir'}}->[1];
  my $base_url = $self->hub->species_defs->$dir_key;
  return join('/', $base_url, $self->write_location);
}

sub hub {
### a
  my $self = shift;
  return $self->{'hub'};
}

sub code {
### a
### Session code for fetching this file
  my $self = shift;
  return $self->{'code'};
}

sub source {
### a
  my $self = shift;
  return $self->{'source'};
}

sub error {
### a
  my $self = shift;
  return $self->{'error'};
}

sub set_format {
### a
  my ($self, $format) = @_;
  $self->{'format'} = $format;
  return $self->{'format'};
}

sub get_format {
### a
  my $self = shift;
  return lc($self->{'format'});
}

sub set_category {
### Set the category of file: defaults to temporary 
  my ($self, $category) = @_;
  $category ||= 'temporary';
  $self->{'category'} = $category;
  return $self->{'category'};
}

sub get_category {
### Get the category of file: typically either temporary or persistent
  my $self = shift;
  my $category = $self->{'category'};
  return $category;
}

sub set_subcategory {
### Set the subcategory of file (optional)
  my ($self, $subcategory) = @_;

  $self->{'subcategory'} = $subcategory;
  return $self->{'subcategory'};
}

sub get_subcategory {
### Get the (optional) subcategory of file
  my $self = shift;
  my $subcategory = $self->{'subcategory'};
  return $subcategory;
}

sub set_timestamp {
### Create a timestamp as part of a filename
  my $self = shift;

  my @time  = localtime;
  my $hour  = $time[2];
  my $min   = $time[1];
  my $sec   = $time[0];

  $self->{'write_name'} = sprintf('%02d%02d%02d', $hour, $min, $sec);
  return $self->{'write_name'};
}

sub set_datestamp {
  ### a
  my $self = shift;
  return $self->{'read_datestamp'} if $self->{'read_datestamp'};
  
  my @time  = localtime;
  my $day   = $time[3];
  my $month = $time[4] + 1;
  my $year  = $time[5] + 1900;

  $self->{'read_datestamp'} = sprintf('%s_%02d_%02d', $year, $month, $day);
  return $self->{'read_datestamp'};
}

sub get_datestamp {
  ### a
  my $self = shift;
  return $self->{'read_datestamp'};
}

sub set_user_identifier {
  ### a
  my $self = shift;
  my $hub = $self->hub;
 
  if ($hub->user) {
    $self->{'user_identifier'} = 'user_'.encrypt_value($hub->user->id);
  }
  else {
    $self->{'user_identifier'} = 'session_'.$hub->session->session_id;
  } 

  return $self->{'user_identifier'};
}

sub get_user_identifier {
  ### a
  my $self = shift;
  return $self->{'user_identifier'};
}

sub md5 {
  my ($self, $content) = @_;
  unless ($content) {
    my $result = $self->read;
    $content = $result->{'content'};
  }
  if ($content) {
    $self->{'md5'} ||= md5_hex($self->read_name . $content);
    return $self->{'md5'};
  }
  else {
    return undef;
  }
}


### Wrappers around E::W::File::Utils::* methods

sub exists {
### Check if a file of this name exists
### @return Boolean
  my $self = shift;
  my $result = {};

  foreach (@{$self->{'input_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::file_exists'; 
    my $args = {
                'hub'   => $self->hub,
                'nice'  => 1,
                };
    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last unless $result->{'error'}; 
  }
  return $result->{'error'} ? 0 : 1;
}

sub fetch {
### Get file uncompressed, e.g. for downloading
### @return Hashref 
  my $self = shift;
  my $result = {};

  foreach (@{$self->{'input_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::fetch_file';
    my $args = {
                'hub'   => $self->hub,
                'nice'  => 1,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last if $result->{'content'};
  }
  return $result;
}

sub read {
### Get entire content of file, uncompressed
### @return Hashref 
  my ($self, $mode) = @_;
  $mode ||= 'read_file';

  ## Don't access source again if we've already fetched the contents
  my $content = $self->{'content'};
  return {'content' => $content} if $content;

  my $result = {};
  foreach (@{$self->{'input_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::'.$mode; 
    my $args = {
                'hub'         => $self->hub,
                'nice'        => 1,
                'size_limit'  => $self->{'size_limit'} || 0,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last if $result->{'content'};
  }
  return $result;
}

sub read_lines {
### Get entire content of file, uncompressed and in an arrayref
### @return Hashref 
  my $self = shift;
  return $self->read('read_lines');
}

sub write {
### Write entire file
### @param Arrayref - lines of file
### @return Hashref 
  my ($self, $content) = @_;
  my $result = {};
 
  foreach (@{$self->{'output_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::write_file'; 
    my $args = {
                'hub'     => $self->hub,
                'nice'    => 1,
                'content' => $content,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last unless $result->{'error'};
  }
  return $result;
}

sub write_line {
### Write content to a new file, or append single line to an existing file  
### @param String
### @return Hashref 
  my ($self, $content) = @_;
  my $result = {};
  $content = [$content] unless ref($content) eq 'ARRAY';
 
  foreach (@{$self->{'output_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::append_lines'; 
    my $args = {
                'hub'     => $self->hub,
                'nice'    => 1,
                'lines'   => $content,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last unless $result->{'error'};
  }
  return $result;
}

sub touch {
### Touch file, i.e. create it (empty) if it doesn't exist
### @return Hashref
  my $self = shift;
  my $result = {};
 
  foreach (@{$self->{'output_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::touch_file'; 
    my $args = {
                'hub'     => $self->hub,
                'nice'    => 1,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last unless $result->{'error'};
  }
  return $result;
}

sub delete {
### Delete file
### @return Hashref
  my $self = shift;
  my $result = {};
 
  foreach (@{$self->{'output_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::delete_file'; 
    my $args = {
                'hub'     => $self->hub,
                'nice'    => 1,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    last unless $result->{'error'};
  }
  return $result;
}

sub _parse_filename {
  ## @private
  my $filename = shift;

  my $compression = get_compression($filename);
  my $extension   = get_extension($filename);
  my $name        = scalar reverse [ reverse split /\./, (scalar reverse $filename), 2 + (!!$compression || 0) ]->[0];

  return $name, $extension, $compression;
}

1;
