package Bio::EnsEMBL::GlyphSet::urlfeature;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_feature);

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
