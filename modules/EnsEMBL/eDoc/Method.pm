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

package EnsEMBL::eDoc::Method;


use strict;
use warnings;

sub new {
  my ($class, %params) = @_;
  my $default_keywords = "a accessor c constructor d destructor x deprecated i initialiser";
  my $self = {
    'name'          => $params{'name'} || '',
    'module'        => $params{'module'} || '',
    'documentation' => $params{'documentation'} || '',
    'table'         => $params{'table'} || {},
    'type'          => $params{'type'} || 'unknown',
    'result'        => $params{'result'} || '',
  };
  bless $self, $class;
  return $self;
}

sub get_name {
  my $self = shift;
  return $self->{'name'};
}

sub get_module {
  my $self = shift;
  return $self->{'module'};
}

sub get_documentation {
  my $self = shift;
  return $self->{'documentation'};
}

sub get_table {
  my $self = shift;
  return $self->{'table'};
}

sub set_table {
  my $self = shift;
  $self->{'table'} = shift;
}

sub get_type {
  my $self = shift;
  return $self->{'type'};
}

sub get_result {
  my $self = shift;
  return $self->{'result'};
}


1;
