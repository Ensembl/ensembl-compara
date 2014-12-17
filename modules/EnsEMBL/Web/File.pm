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

use EnsEMBL::Web::Utils::RandomString qw(random_string);

use EnsEMBL::Web::File::Utils::IO qw/:all/;
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

  ## Set default drivers (disk only)
  $args{'input_drivers'} ||= ['IO'];
  $args{'output_drivers'} ||= ['IO'];

  $self->{'error'} = undef;
  bless $self, $class;

  my $file_path = $self->{'file_path'};

  if ($file_path) {
    ## DEALING WITH AN EXISTING FILE
   
    ## Clean up the path
    my $tmp = $self->{'hub'}->species_defs->ENSEMBL_TMP_DIR;
    $file_path =~ s/$tmp//;
    $tmp = $self->{'hub'}->species_defs->ENSEMBL_TMP_URL;
    $file_path =~ s/$tmp//;
    $self->{'file_path'} = $file_path;

    my @path = grep length, split('/', $file_path);

    ## Parse filename
    $self->{'file_name'}     = pop @path;
    my ($name, $extension, $compression) = split(/\./, $self->{'file_name'});
    $compression =~ s/2$//; ## We use 'bz' internally, not 'bz2'
    $self->{'name'}         = $name;
    $self->{'extension'}    = $extension;
    $self->{'compression'}  = $compression;
    $self->{'compress'}     = $self->{'compression'} ? 1 : 0;

    ## Parse rest of path
    $self->{'dir_path'}         = join('/', @path); 
    $self->{'datestamp'}        = shift @path;
    $self->{'user_identifier'}  = shift @path;
    $self->{'sub_dir'}          = shift @path if scalar @path;
  }
  else {
    ## CREATING A NEW FILE (or trying to...)
    if ($self->{'name'}) {
      ## Make sure it's a valid file name!
      $self->{'name'} =~ s/[^\w]/_/g;
      ## Set a random path in case we have multiple files with this name
      $self->{'sub_dir'} ||= random_string;
    }
    else {
      ## Create a file name if none given
      $self->{'name'} = $self->set_timestamp if $args{'name_timestamp'};
      $self->{'name'} .= random_string;
    }

    $self->{'extension'} ||= 'txt';
    ## Allow for atypical file extensions such as gff3 or bedGraph
    (my $extension          = $self->{'extension'}) =~ s/^\.?(\w+)(\.gz)?$/$1/;
    $self->{'extension'}    = $extension;

    my $file_name            = $self->{'name'}.'.'.$extension;

    if ($self->{'compress'}) {
      unless ($self->{'compression'}) {
        ## Default to gzip
        $self->{'compression'} = 'gz';
      }
      $file_name .= '.'.$self->{'compression'};
    }

    $self->{'file_name'} = $file_name;

    my @path_elements = ($self->set_datestamp, $self->set_user_identifier);
    push @path_elements, $self->{'sub_dir'} if $self->{'sub_dir'};
    $self->{'dir_path'} = join('/', @path_elements); 

    push @path_elements, $file_name;
    $self->{'file_path'} = join('/', @path_elements); 
  }
  $self->{'base_path'}    = $self->{'base_dir'}.'/'.$self->{'dir_path'}; 
  $self->{'location'}     = $self->{'base_dir'}.'/'.$self->{'file_path'}; 
  $self->{'url'}          = $self->{'base_url'}.'/'.$self->{'file_path'}; 

  return $self;
}

sub file_name {
### a
  my $self = shift;
  return $self->{'file_name'};
}

sub extension {
### a
  my $self = shift;
  return $self->{'extension'};
}

sub compression {
### a
  my $self = shift;
  return $self->{'compression'};
}

sub compress {
### a
  my $self = shift;
  return $self->{'compress'};
}

sub datestamp {
### a
  my $self = shift;
  return $self->{'datestamp'};
}

sub user_identifier {
### a
  my $self = shift;
  return $self->{'user_identifier'};
}

sub file_path {
### a
  my $self = shift;
  return $self->{'file_path'};
}

sub sub_dir {
### a
  my $self = shift;
  return $self->{'sub_dir'};
}

sub base_path {
### a
  my $self = shift;
  return $self->{'base_path'};
}

sub base_dir {
### a
  my $self = shift;
  return $self->{'base_dir'};
}

sub location {
### a
  my $self = shift;
  return $self->{'location'};
}

sub url {
### a
  my $self = shift;
  return $self->{'url'};
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

  $self->{'name'} = sprintf('%s%s%s', $hour, $min, $sec);
  return $self->{'name'};
}

sub set_datestamp {
  ### a
  my $self = shift;
  
  my @time  = localtime;
  my $day   = $time[3];
  my $month = $time[4] + 1;
  my $year  = $time[5] + 1900;

  $self->{'datestamp'} = sprintf('%s_%s_%s', $year, $month, $day);
  return $self->{'datestamp'};
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
    warn "!!! ".$result->{'error'} if $result->{'error'};
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

