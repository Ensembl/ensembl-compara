=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

#########
# helper class for compatibilising Bioperl
# Bio::Search:::Result::ResultI objects with DrawableContainers

package EnsEMBL::Web::Container::HSPContainer;
use strict;

sub new {
  my $class = shift;
  my $result = shift;
  my $aligns = shift || undef;

  ( $result && $result->isa("Bio::Search::Result::ResultI" ) ) or
    die( "Need a Bio::Search:::Result::ResultI object" );
  my $self = {'result' => $result };

  my @hsps;
  if( $aligns ){ @hsps = map{$_->[1]} @$aligns }
  else{ @hsps = map{$_->hsps} $result->hits }
  $self->{hsps} = [@hsps];

  return bless($self, $class);
}

sub start {
  my ($self) = @_;
  return 0;
}

sub end {
  my ($self) = @_;
  return $self->length;
}

sub length {
  my ($self) = @_;
  return $self->{result}->query_length();
}

sub name {
  my ($self) = shift;
  return $self->{result}->query_name();
}

sub database{
  my ($self) = @_;
  return $self->{result}->database_name();
}

sub hits {
  my ($self) = @_;
  return $self->{result}->hits();
}

sub hsps{
  my ($self) = @_;
  return @{$self->{hsps}};
}

1;
