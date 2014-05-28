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

use Bio::EnsEMBL::Utils::IO qw/:all/;
use EnsEMBL::Web::Tools::RandomString qw(random_ticket random_string);

### Replacement for EnsEMBL::Web::TmpFile, using the file-handling
### functionality in the core API to provide error reporting

### STATUS: Under development

### N.B. Will probably require subclass for images

sub new {
### @constructor
### @param Hash of arguments 
###  - hub - for getting TMP_DIR location, etc
###  - prefix - top-level directory
###  - name (optional)
###  - extension - file extension
###  - compress (optional) Boolean
### @return EnsEMBL::Web::File
  my ($class, %args) = @_;

  my $self = \%args;
  $self->{'error'} = undef;

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

  ## Sort out filename
  $self->{'extension'} ||= 'txt';
  (my $ext = $self->{'extension'}) =~ s/\.gz//;
  $self->{'extension'}    = $ext;
  my $filename            = $name.'.'.$extension;
  $filename               .= '.gz' if $self->{'compress'};
  $self->{'filename'}     = $filename;

  ## Useful paths 
  $self->{'random_path'}  = $random_path;
  $self->{'location'}     = sprintf('%s/%s/%s%s', 
                                      $hub->species_defs->ENSEMBL_TMP_DIR, 
                                      $prefix, $random_path, $filename,
                                    );
  $self->{'url'}          = sprintf('%s/%s/%s%s', 
                                      $hub->species_defs->ENSEMBL_TMP_URL, 
                                      $prefix, $random_path, $filename,
                                    ); 

  bless $self, $class;
  return $self;
}

sub filename {
### a
  my $self = shift;
  return $self->{'filename'};
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
  return $self->{'compress'} ? 1 : 0;
}

sub read {
### Get entire content of file, uncompressed
### @return String (entire file)
  my $self = shift;
  my $content;
  if ($self->is_compressed) {
    eval { $content = gz_slurp($self->location) }; 
  }
  else {
    eval { $content = slurp($self->location) }; 
  }
  if ($@) {
    $self->{'error'} = $@;
  }
  return $content;
}

sub fetch {
### Get entire content of file for download (e.g. not uncompressed)
### @return String (entire file)
  my $self = shift;
  my $content;
  eval { $content = slurp($self->location) }; 
  if ($@) {
    $self->{'error'} = $@;
  }
  return $content;
}

sub read_lines {
### Get entire content of file
### @return Arrayref (lines of file)
  my $self = shift;
  my $content = [];
  if ($self->is_compressed) {
    eval { $content = gz_slurp_to_array($self->location) }; 
  }
  else {
    eval { $content = slurp_to_array($self->location) }; 
  }
  if ($@) {
    $self->{'error'} = $@;
  }
  return $content;
}

sub preview {
### Get n lines of a file, e.g. for a web preview
### @param Integer - number of lines required (default is 10)
### @return Arrayref (n lines of file)
  my ($self, $limit) = @_;
  $limit ||= 10;
  my $count = 0;
  my $lines = [];
  my $method = $self->is_compressed ? 'gz_work_with_file' : 'work_with_file';

  eval { 
    &$method($self->location, 'r',
      sub {
        my $fh = shift;
        while (<$fh>) {
          $count++;
          push @$lines, $_;
          last if $count == $limit;
        }
      }
    );
  };

  if ($@) {
    $self->{'error'} = $@;
  }
  return $lines; 
}

sub exists {
### Check if a file of this name exists
### @return Boolean
}

sub write {
### Write entire file
### @return String (error message) or undef
}

sub write_line {
### Write a single line to an open file
### @return String (error message) or undef
}



