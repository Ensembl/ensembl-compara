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

use EnsEMBL::Web::File::Utils::IO qw/:all/;
use EnsEMBL::Web::File::Utils::FileSystem qw(create_path);

### Replacement for EnsEMBL::Web::TmpFile, using the file-handling
### functionality in EnsEMBL::Web::File::Utils 

### Data can be written to disk or, if enabled and appropriate, memcached

sub new {
### @constructor
### N.B. You need either the path (to an existing file) or
### the name and extension (for new files)
### @param Hash of arguments 
###  - hub - for getting TMP_DIR location, etc
###  - location - full path to file (optional)
###  - prefix - top-level directory (optional)
###  - name (optional) String
###  - extension (optional) String
###  - compression (optional) String
### @return EnsEMBL::Web::File
  my ($class, %args) = @_;

  ## Set default driver (disk only) and include modules
  $args{'drivers'} ||= ['IO'];
  foreach (@{$args{'drivers'}}) {
    my $library = "EnsEMBL::Web::File::Utils::$_";
    require $library;
  }

### ToDo - sort this lot out - might need moving into a subclass 
  my $self = \%args;
  $self->{'error'} = undef;

  if ($self->{'path'}) {
    my @path = split('/', $self->{'path'});
    $self->{'prefix'} = shift @path;
    $self->{'filename'} = pop @path;
    $self->{'random_path'} = join('/', @path);
    ($self->{'extension'} = $self->{'filename'}) =~ s/^\w+//;
    $self->{'compress'} = $self->{'extension'} =~ /gz$/ ? 1 : 0;
  }
  else {
    ## Create a filename if none given (not user-friendly, but...whatever)
    my $name = $self->{'name'} || random_string;
    ## Make sure it's a valid file name!
    ($self->{'name'} = $name) =~ s/[^\w]/_/g;

    ### Web-generated files go into a random directory
    my @random_chars  = split(//, random_ticket);
    my @pattern  = qw(3 1 1 15);
    my $random_path;
    foreach (@pattern) {
      for (my $i = 0; $i < $_; $i++) {
        $random_path .= shift @random_chars;
      }
      $random_path .= '/';
    }
    $self->{'random_path'}  = $random_path;

    ## Sort out filename
    $self->{'extension'} ||= 'txt';
    ## Allow for atypical file extensions such as gff3 or bedGraph
    (my $extension          = $self->{'extension'}) =~ s/^\.?(\w+)(\.gz)?$/$1/;
    $self->{'extension'}    = $extension;
    my $filename            = $self->{'name'}.'.'.$extension;
    $filename               .= '.gz' if $self->{'compress'};
    $self->{'filename'}     = $filename;

    $self->{'path'}         = sprintf('/%s/%s%s', 
                                      $self->{'prefix'}, $self->{'random_path'}, 
                                      $self->{'filename'},
                                    );
    create_path($self->{'hub'}->species_defs->ENSEMBL_TMP_DIR.$self->{'path'});
  }
  $self->{'location'}     = $self->{'hub'}->species_defs->ENSEMBL_TMP_DIR.$self->{'path'}; 
  $self->{'url'}          = $self->{'hub'}->species_defs->ENSEMBL_TMP_URL.$self->{'path'}; 

  bless $self, $class;
  return $self;
}

sub filename {
### a
  my $self = shift;
  return $self->{'filename'};
}

sub random_path {
### a
  my $self = shift;
  return $self->{'random_path'};
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

sub error {
### a
  my $self = shift;
  return $self->{'error'};
}

sub is_compressed {
### a
  my $self = shift;
  return $self->{'compression'} ? 1 : 0;
}

### Wrappers around E::W::File::Utils::IO methods
### N.B. this parent class only includes methods that are supported
### by all drivers

sub exists {
### Check if a file of this name exists
### @return Boolean
  my $self = shift;

  foreach ($self->{'drivers'}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::file_exists'; 
    my $exists = $method();
    return $exists if $exists;
  }
}

sub read {
### Get entire content of file, uncompressed
### @return String (entire file)
  my $self = shift;
  my $content;

  foreach ($self->{'drivers'}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::read_file'; 
    $content = $method();
    last if $content;
  }
  return $content;
}

sub write {
### Write entire file
### @param Arrayref - lines of file
### @return Void
  my ($self, $content) = @_;
 
  foreach ($self->{'drivers'}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::write_file'; 
    my $success = $method();
    return 1 if $success;
  }
}

1;

