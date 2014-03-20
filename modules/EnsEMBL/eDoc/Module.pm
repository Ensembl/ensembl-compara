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

package EnsEMBL::eDoc::Module;


use strict;
use warnings;

sub new {
  my ($class, %params) = @_;
  my $default_keywords = "a accessor c constructor d destructor x deprecated i initialiser";
  my $self = {
    'methods'     => $params{'methods'}     || [],
    'name'        => $params{'name'}        || '',
    'inheritance' => $params{'inheritance'} || [],
    'subclasses'  => $params{'subclasses'}  || [],
    'location'    => $params{'location'}    || '',
    'lines'       => $params{'lines'}       || '',
    'overview'    => $params{'overview'}    || '',
    'identifier'  => $params{'identifier'}  || '###',
    'keywords'    => $params{'keywords'}    || $default_keywords,
  };
  bless $self, $class;
  return $self;
}

sub get_location {
  my $self = shift;
  return $self->{'location'};
}

sub get_base {
  my $self = shift;
  return $self->{'base'};
}

sub get_serverroot {
  my $self = shift;
  return $self->{'serverroot'};
}

sub set_serverroot {
  my $self = shift;
  $self->{'serverroot'} = shift;
}

sub get_support {
  my $self = shift;
  return $self->{'support'};
}

1;
