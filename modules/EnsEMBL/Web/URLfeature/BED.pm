package EnsEMBL::Web::URLfeature::BED;
use strict;
use EnsEMBL::Web::URLfeature;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::URLfeature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub hstrand  { my $self = shift; return @{$self->{'__raw__'}}>5 ? $self->_strand( $self->{'__raw__'}[5] ) : -1 ; }
sub rawstart{ my $self = shift; return $self->{'__raw__'}[1] + 1; }
sub rawend  { my $self = shift; return $self->{'__raw__'}[2] + 1; }
sub score   { my $self = shift; return $self->{'__raw__'}[4]; }
sub start{ my $self = shift; return $self->{'__raw__'}[1]; }
sub end  { my $self = shift; return $self->{'__raw__'}[2]; }
sub id      { my $self = shift; return $self->{'__raw__'}[3]; }

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
  if($self->{'__raw__'}[9]) {
    my $strand = $self->hstrand();
    my $cigar;
    my @block_starts  = split /,/,$self->{'__raw__'}[11];
    my @block_lengths = split /,/,$self->{'__raw__'}[10];
    my $end = 0;
    foreach(0..( $self->{'__raw__'}[9]-1) ) {
      my $start =shift @block_starts;
      my $length = shift @block_lengths;
      if($_) {
        if($strand == -1) {
          $cigar =  ( $start - $end - 1)."I$cigar";
        } else {
          $cigar.= ( $start - $end - 1)."I";
        }
      }
      if($strand == -1) {
        $cigar = $length."M$cigar";
      } else {
        $cigar.= $length.'M';
      }
      $end = $start + $length -1;
    }
    return $self->{'_cigar'}=$cigar;
  } else {
    return $self->{'_cigar'}=($self->{'__raw__'}[2]-$self->{'__raw__'}[1]+1)."M";
  }
}
1;
