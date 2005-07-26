package EnsEMBL::Web::URLfeature::PSL;
use strict;
use EnsEMBL::Web::URLfeature;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::URLfeature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[13]; }
sub hstrand  { my $self = shift; return $self->_strand( substr($self->{'__raw__'}[8],-1) ); }
sub rawstart{ my $self = shift; return $self->{'__raw__'}[15]; }
sub rawend  { my $self = shift; return $self->{'__raw__'}[16]; }
sub id      { my $self = shift; return $self->{'__raw__'}[9]; }

sub slide   {
  my $self = shift; my $offset = shift;
  $self->{'start'} = $self->{'__raw__'}[15]+ $offset;
  $self->{'end'}   = $self->{'__raw__'}[16]+ $offset;
}

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'} if $self->{'_cigar'};
  my $strand = $self->strand();
  my $hstrand = $self->hstrand();
  my $cigar;
  my @block_starts  = split /,/,$self->{'__raw__'}[20];
  my @block_lengths = split /,/,$self->{'__raw__'}[18];
  my $end = 0;
  foreach(0..( $self->{'__raw__'}[17]-1) ) {
    my $start =shift @block_starts;
    my $length = shift @block_lengths;
    if($_) {
      if( $hstrand == -1 ) {
        $cigar= ( $start - $end - 1)."I".$cigar;
      } else {
        $cigar.= ( $start - $end - 1)."I";
      }
    }
    if( $hstrand == -1 ) {
      $cigar = $length.'M'.$cigar;
    } else {
      $cigar.= $length.'M';
    }
    $end = $start + $length -1;
  }
  return $self->{'_cigar'}=$cigar;
}

1;
