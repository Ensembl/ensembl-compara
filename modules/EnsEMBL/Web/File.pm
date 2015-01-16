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

package EnsEMBL::Web::File;

use strict;

use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::Utils::RandomString qw(random_string);
use EnsEMBL::Web::File::Utils qw/sanitise_filename/;
use EnsEMBL::Web::File::Utils::IO qw/:all/;
use EnsEMBL::Web::File::Utils::URL qw/:all/;
use EnsEMBL::Web::File::Utils::Memcached qw/:all/;

### Replacement for EnsEMBL::Web::TmpFile, using the file-handling
### functionality in EnsEMBL::Web::File::Utils 

### Data can be written to disk or, if enabled and appropriate, memcached
### Note that to aid cleanup, all files written to disk should use a common
### path pattern, as follows:
### /base_dir/datestamp/user_identifier/sub_dir/file_name.ext
###  - base_dir is set in subclasses - this is the main temporary file location
###  - datestamp aids in cleaning up older files by date
###  - user_identifier is either session id or user id, and 
###    helps to ensure that users only see their own data
###  - sub_dir is optional - it's used by a few pages to separate content further
###  - file_name may be auto-generated, or set by the user

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
  #while (my($k, $v) = each(%args)) {
  #warn "@@@ ARG $k = $v";
  #}
  my $hub = $args{'hub'};
  my $self = {
              'hub'             => $args{'hub'},
              'base_dir'        => $args{'base_dir'} || $hub->species_defs->ENSEMBL_TMP_DIR,
              'base_url'        => $args{'base_url'} || $hub->species_defs->ENSEMBL_TMP_URL,
              'input_drivers'   => $args{'input_drivers'} || ['IO'], 
              'output_drivers'  => $args{'output_drivers'} || ['IO'], 
              'error'           => undef,
              };

  bless $self, $class;

  my $read_path = $args{'file'};
  my $bare_name;

  ## Existing file or user upload
  if ($read_path) {
    $self->{'read_location'} = $read_path;

    ## Clean up the path before processing further
    $read_path  =~ s/^\s+//;
    $read_path  =~ s/\s+$//;
    my $tmp     = $self->{'hub'}->species_defs->ENSEMBL_TMP_DIR;
    $read_path  =~ s/$tmp//;
    $tmp        = $self->{'hub'}->species_defs->ENSEMBL_TMP_URL;
    $read_path  =~ s/$tmp//;

    my $read_name;
    if ($args{'upload'} && $args{'upload'} eq 'cgi') {
      $read_name = $args{'name'};
    }
    else {
      ## Backwards compatibility with previously uploaded TmpFile paths
      ## TODO Remove if block, once TmpFile modules are removed
      if ($args{'prefix'}) {
        $self->{'read_location'} = join('/', $self->{'base_dir'}, $args{'prefix'}, $read_path);
        $read_name = $read_path;
      }
      else {
        my @path = grep length, split('/', $read_path);
        $read_name = sanitise_filename(pop @path);
      }
    }

    my ($name, $extension, $compression) = split(/\./, $read_name);
    $compression =~ s/2$//; ## We use 'bz' internally, not 'bz2'

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

  ## Prepare to write new local file
  ## N.B. We need to allow for user-supplied names with and without extensions
  my ($name, $extension, $compression);
  my $sub_dir = $args{'sub_dir'};

  if ($args{'upload'} || !$read_path) {
    my $filename = $args{'name'};
    if ($filename) {
      $filename = sanitise_filename($filename);
      ($name, $extension, $compression) = split(/\./, $filename);
      $compression =~ s/2$//; ## We use 'bz' internally, not 'bz2'

      ## Set a random path in case we have multiple files with this name
      $sub_dir ||= random_string;
    }
    elsif ($self->{'read_name'}) { 
      ## Uploaded file, so keep original name but save uncompressed
      $name = $bare_name;
      $extension = $self->{'read_ext'};
      $compression = 0;
      ## Set a random path in case we have multiple files with this name
      $sub_dir ||= random_string;
    }
    else {
      ## Create a file name if none given
      $name = $self->set_timestamp if $args{'timestamp_name'};
      $name .= random_string;
    }

    if (!$extension) {
      $extension = $args{'extension'} || 'txt';
    }
    if (!$compression) {
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
    my $datestamp = $args{'datestamp'} || $self->set_datestamp;
    my $user_id   = $args{'user_identifier'} || $self->set_user_identifier;

    my @path_elements = ($datestamp, $user_id);
    push @path_elements, $sub_dir if $sub_dir;
    push @path_elements, $self->{'write_name'};

    $self->{'write_location'} = join('/', $self->{'base_dir'}, @path_elements); 
    $self->{'write_url'}      = join('/', $self->{'base_url'}, @path_elements); 
  } 

  #warn ">>> FILE OBJECT:";
  #while (my($k, $v) = each (%$self)) {
  #  warn "... SET $k = $v";
  #}

  return $self;
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
  return $self->{'write_compression'} || $self->{'read_compression'};
}

sub compress {
### a
### N.B. this only applies to writing files
  my $self = shift;
  return $self->{'compress'};
}


sub read_location {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_location'} || $self->{'write_location'};
}

sub write_location {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'write_location'} || $self->{'read_location'};
}

sub read_url {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_url'} || $self->{'write_url'};
}

sub write_url {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
### N.B. whilst we don't literally write to a url, memcached
### uses this method to create a virtual path to a saved file
  my $self = shift;
  return $self->{'write_url'} || $self->{'read_url'};
}

sub hub {
### a
  my $self = shift;
  return $self->{'hub'};
}

sub error {
### a
  my $self = shift;
  return $self->{'error'};
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

sub set_user_identifier {
  ### a
  my $self = shift;
  my $hub = $self->hub;
 
  if ($hub->user) {
    $self->{'user_identifier'} = 'user_'.$hub->user->id;
  }
  else {
    $self->{'user_identifier'} = 'session_'.$hub->session->session_id;
  } 

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
  my $self = shift;

  ## Don't access source again if we've already fetched the contents
  my $content = $self->{'content'};
  return {'content' => $content} if $content;

  my $result = {};
  foreach (@{$self->{'input_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::read_file'; 
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

1;

