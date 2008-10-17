package EnsEMBL::Web::Text::Feature::GFF;
use strict;
use EnsEMBL::Web::Text::Feature;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::Text::Feature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[12] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[6]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[8]; }
sub id       { my $self = shift; return $self->{'__raw__'}[16]; }

sub slide   {
  my $self = shift; my $offset = shift;
  $self->{'start'} = $self->{'__raw__'}[6]+ $offset;
  $self->{'end'}   = $self->{'__raw__'}[8]+ $offset;
}

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'}||=($self->{'__raw__'}[8]-$self->{'__raw__'}[6]+1)."M";
}

1;
