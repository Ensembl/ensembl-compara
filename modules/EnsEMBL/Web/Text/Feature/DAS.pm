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

package EnsEMBL::Web::Text::Feature::DAS;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $args ) = @_;

  my $extra      = {};

  return bless { '__raw__' => $args, '__extra__' => $extra }, $class;
}

sub coords {
  my ($self, $data) = @_;
  return ($data->[4], $data->[5], $data->[6]);
}


sub id      { my $self = shift; return $self->{'__raw__'}[1]; }
sub _seqname { my $self = shift; return $self->{'__raw__'}[4]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[7] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[5]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[6]; }
sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }

1;
