package EnsEMBL::Web::URLfeature::WIG;
use strict;
use EnsEMBL::Web::URLfeature;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::URLfeature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub hstrand  { my $self = shift; return @{$self->{'__raw__'}}>5 ? $self->_strand( $self->{'__raw__'}[5] ) : -1 ; }
sub rawstart{ my $self = shift; return $self->{'__raw__'}[1] + 1; }
sub rawend  { my $self = shift; return $self->{'__raw__'}[2] + 1; }
sub score   { my $self = shift; return $self->{'__raw__'}[3]; }
#sub start{ my $self = shift; return $self->{'__raw__'}[1]; }
#sub end  { my $self = shift; return $self->{'__raw__'}[2]; }
sub id      { my $self = shift; return $self->{'__raw__'}[4]; }

sub slide   {
  my $self = shift;
  my $offset = shift;
  my $extra = $self->hstrand >= 0 ? 1 : 0;
  $self->{'start'} = $self->{'__raw__'}[1]+ $offset + $extra;
  $self->{'end'}   = $self->{'__raw__'}[2]+ $offset + $extra;
}

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'} if $self->{'_cigar'};
  return $self->{'_cigar'}=($self->{'__raw__'}[2]-$self->{'__raw__'}[1]+1)."M";
}
1;
