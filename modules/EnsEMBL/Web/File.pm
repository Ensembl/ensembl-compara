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
###  - hub - for getting TMP_DIR location, etc
###  - file_path - full path to file (optional)
###  - name (optional) String - not including file extension
###  - extension (optional) String
###  - compression (optional) String
### @return EnsEMBL::Web::File
  my ($class, %args) = @_;
  my $self = \%args;

  ## Set base locations
  $args{'base_dir'} ||= $self->{'hub'}->species_defs->ENSEMBL_TMP_DIR;
  $args{'base_url'} ||= $self->{'hub'}->species_defs->ENSEMBL_TMP_URL;

  if ($args{'cgi'}) { 
    ## We need to read the data from the system's CGI location
    ## but otherwise treat this as a new file
    my @cgi_path = split('/', $args{'file_path'});
    delete $args{'file_path'};
    $self->{'read_name'}        = pop @cgi_path;
    $self->{'read_ext'}         = '';
    $self->{'read_compression'} = '';
    $self->{'base_read_path'}   = join('/', @cgi_path);
    $self->{'read_location'}    = $self->{'base_read_path'}.'/'.$self->{'read_name'}; 
  }

  ## Set default drivers (disk only)
  $args{'input_drivers'} ||= ['IO'];
  $args{'output_drivers'} ||= ['IO'];

  $self->{'error'} = undef;
  bless $self, $class;

  my $read_path   = $self->{'read_path'} || $self->{'file_path'};

  if ($read_path && !$args{'cgi'}) {
    ## DEALING WITH AN EXISTING FILE
   
    ## Clean up the path
    $read_path  =~ s/^\s+//;
    $read_path  =~ s/\s+$//;
    my $tmp     = $self->{'hub'}->species_defs->ENSEMBL_TMP_DIR;
    $read_path  =~ s/$tmp//;
    $tmp        = $self->{'hub'}->species_defs->ENSEMBL_TMP_URL;
    $read_path  =~ s/$tmp//;
    $self->{'read_path'} = $read_path;

    my @path = grep length, split('/', $read_path);

    ## Parse filename
    my $read_name = sanitise_filename(pop @path);
    my ($name, $extension, $compression) = split(/\./, $read_name);
    $compression =~ s/2$//; ## We use 'bz' internally, not 'bz2'
    $self->{'read_name'}        = $read_name;
    $self->{'read_ext'}         = $extension;
    $self->{'read_compression'} = $compression;
    $self->{'read_compress'}    = $self->{'read_compression'} ? 1 : 0;

    ## Parse rest of path
    $self->{'read_dir_path'}    = join('/', @path); 
    
    ## Backwards compatibility with TmpFile paths
    ## TODO Remove after TmpFile modules are removed
    if ($self->{'prefix'}) {
      ## These values are slightly bogus, but will work with old filepaths
      $self->{'read_path'} = $self->{'prefix'}.'/'.$self->{'read_path'};
      delete $self->{'prefix'};
      $self->{'read_datestamp'}   = $self->{'prefix'};
      $self->{'user_identifier'}  = shift @path if scalar @path;
      $self->{'read_sub_dir'}     = join('/', @path) if scalar @path;
    }
    elsif ($self->{'read_dir_path'}) { 
      $self->{'read_datestamp'}   = shift @path;
      $self->{'user_identifier'}  = shift @path;
      $self->{'read_sub_dir'}     = shift @path if scalar @path;
    }
    $self->{'base_read_path'}    = $self->{'base_dir'}.'/'.$self->{'read_dir_path'}; 
    $self->{'read_location'}     = $self->{'base_dir'}.'/'.$self->{'read_path'}; 
    $self->{'read_url'}          = $self->{'base_url'}.'/'.$self->{'read_path'}; 
  }
  else {
    ## CREATING A NEW FILE (or trying to...)
    ## Note that we allow generic parameter names here

    if (my $name = $self->{'name'} || $self->{'write_name'}) {
      $self->{'write_name'} = sanitise_filename($name);
      ## Set a random path in case we have multiple files with this name
      $self->{'write_sub_dir'} ||= $self->{'sub_dir'};
      $self->{'write_sub_dir'} ||= random_string;
    }
    else {
      ## Create a file name if none given
      $self->{'write_name'} = $self->set_timestamp if $args{'name_timestamp'};
      $self->{'write_name'} .= random_string;
    }

    if ($self->{'extension'}) {
      $self->{'write_ext'} = $self->{'extension'};
      delete $self->{'extension'};
    }
    $self->{'write_ext'} ||= 'txt';
    ## Allow for atypical file extensions such as gff3 or bedGraph
    (my $extension  = $self->{'write_ext'}) =~ s/^\.?(\w+)(\.gz)?$/$1/;
    $self->{'write_ext'}    = $extension;

    my $file_name           = $self->{'write_name'}.'.'.$extension;

    if ($self->{'compress'} || $self->{'compression'} || $self->{'write_compression'}) {
      $self->{'write_compression'} ||= $self->{'compression'};
      ## Default to gzip
      unless ($self->{'write_compression'} && $self->{'write_compression'} =~ /gz|bz|zip/) {
        $self->{'write_compression'} = 'gz';
      }
      $file_name .= '.'.$self->{'write_compression'};
    }

    $self->{'write_name'} = $file_name;

    my @path_elements = ($self->set_datestamp, $self->set_user_identifier);
    $self->{'write_sub_dir'} ||= $self->{'sub_dir'};
    push @path_elements, $self->{'write_sub_dir'} if $self->{'write_sub_dir'};
    $self->{'write_dir_path'} = join('/', @path_elements); 

    push @path_elements, $file_name;
    $self->{'write_path'} = join('/', @path_elements); 

    $self->{'base_write_path'}   = $self->{'base_dir'}.'/'.$self->{'write_dir_path'}; 
    $self->{'write_location'}    = $self->{'base_dir'}.'/'.$self->{'write_path'}; 
    $self->{'write_url'}         = $self->{'base_url'}.'/'.$self->{'write_path'}; 
  }
  warn ">>> FILE OBJECT:";
  while (my($k, $v) = each (%$self)) {
    warn "... $k = $v";
  }

  return $self;
}

sub read_name {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_name'} || $self->{'write_name'};
}

sub write_name {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
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

sub read_datestamp {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_datestamp'} || $self->{'write_datestamp'};
}

sub write_datestamp {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'write_datestamp'} || $self->{'read_datestamp'};
}

sub user_identifier {
### a
### This should be the same for both reading and writing
  my $self = shift;
  return $self->{'user_identifier'};
}

sub read_path {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_path'} || $self->{'write_path'};
}

sub write_path {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'write_path'} || $self->{'read_path'};
}

sub read_sub_dir {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'read_sub_dir'} || $self->{'read_sub_dir'};
}

sub write_sub_dir {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'write_sub_dir'} || $self->{'read_sub_dir'};
}

sub base_read_path {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'base_read_path'} || $self->{'base_write_path'};
}

sub base_write_path {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'base_write_path'} || $self->{'base_read_path'};
}

sub base_read_dir {
### a
### Assume that we read back from the same file we wrote to
### unless read parameters were set separately
  my $self = shift;
  return $self->{'base_read_dir'} || $self->{'base_write_dir'};
}

sub base_write_dir {
### a
### Assume that we write back to the same file unless 
### write parameters have been set
  my $self = shift;
  return $self->{'base_write_dir'} || $self->{'base_read_dir'};
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

  $self->{'write_name'} = sprintf('%s%s%s', $hour, $min, $sec);
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

  $self->{'read_datestamp'} = sprintf('%s_%s_%s', $year, $month, $day);
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

