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

package EnsEMBL::Draw::GlyphSet::urlfeature;

### STATUS: Unknown - doesn't seem to be in use any more

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_feature);

sub my_label { 
  my $self = shift;
  return $self->{'extras'}{'name'}||'URL features';
}

sub check { return 'urlfeature'; }

sub bumped { return undef; }

sub managed_name {
  my ($self) = @_;
  return $self->{'extras'}{'name'};
}

sub features {
  my ($self) = @_;
  return $self->{extras}->{_features} if (@{$self->{extras}->{_features} || []});
  my @data =
    map { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map { [ $_->start, $_ ] }
    map { $_->map( $self->{'container'} ) } @{ $self->{'extras'}{'data'} };
  return $self->{extras}->{_features} = \@data;
}

sub colour {
  my( $self, $id ) = @_;
  return $self->{'extras'}{'colour'};
}

sub href {
  my ($self, $id ) = @_;
  (my $T = $self->{'extras'}{'url'}) =~ s/\$\$/$id/g;
  return $T ? $T : undef;
}

sub zmenu {
  my ($self, $id, $f ) = @_;
  my $T = $self->href( $id );
  my $h = {
  	'caption' => $id
	};
  $h->{ 'details...'} = $T  if ($T);
  if ($f) {
  	my $score = $f->score;
	$h->{"SCORE:$score"} = '';
  }

  return $h;
}

1;
