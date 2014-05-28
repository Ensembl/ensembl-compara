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
### functionality in the core API

### N.B. Will probably require subclass for images

sub new {
### @constructor
### @param Hashref of arguments 
###  - hub - for getting TMP_DIR location, etc
###  - prefix - top-level directory
###  - name (optional)
###  - extension - file extension
###  - compress (optional)
### @return EnsEMBL::Web::File
  my ($class, $args) = @_;

  my $self = $args;

  ## Create a filename if none given (not user-friendly, but...whatever)
  my $name = $args->{'name'} || random_string;
  ## Make sure it's a valid file name!
  ($args->{'name'} = $name) =~ s/[^\w]/_/g;

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

  ## Useful paths 
  $self->{'random_path'}  = $random_path;
  $self->{'filename'}     = $name.'.'.$extension;
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


sub read {
### Get entire content of file
### @return Arrayref (lines of file)
  my $self = shift;
  return slurp_to_array($self->location); 
}

sub preview {
### Get n lines of a file, e.g. for a web preview
### @return Arrayref (lines of file)
  my ($self, $limit) = @_;
  $limit ||= 10;
  my $count = 0;
  my $lines = [];

  work_with_file($self->location, 'r',
    sub {
      my $fh = shift;
      while (<$fh>) {
        $count++;
        push @$lines, $_;
        last if $count == $limit;
      }
    }
  );

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



