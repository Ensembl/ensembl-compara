package Bio::EnsEMBL::GlyphSet::urlfeature;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { 
  my $self = shift;
  return $self->{'extras'}{'name'}||'URL features';
}

sub check { return 'urlfeature'; }

sub managed_name {
  my ($self) = @_;
  return $self->{'extras'}{'name'};
}

sub features {
  my ($self) = @_;
  my @data = map { $_->map( $self->{'container'} ) } @{ $self->{'extras'}{'data'} };
  return \@data;
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
  my ($self, $id ) = @_;
  my $T = $self->href( $id );
  return { 'caption' => $id, 'details...' => $T } if $T;
  return { 'caption' => $id };
}
1;
