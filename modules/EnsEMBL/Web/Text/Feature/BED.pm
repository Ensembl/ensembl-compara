package EnsEMBL::Web::Text::Feature::BED;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $args ) = @_;
  
  my $extra     = {
    'thick_start' => [ $args->[6] ],
    'thick_end'   => [ $args->[7] ],
    'item_colour' => [ $args->[8] ],
    'BlockCount'  => [ $args->[9] ],
    'BlockSizes'  => [ $args->[10] ],
    'BlockStart'  => [ $args->[11] ]
  };

  return bless { '__raw__' => $args, '__extra__' => $extra }, $class;
}

sub coords {
  ## BED start coord needs +1 
  my ($self, $data) = @_;
  (my $chr = $data->[0]) =~ s/chr//;
  return ($chr, $data->[1]+1, $data->[2]);
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift;
  my $T = ( 0+@{$self->{'__raw__'}}) > 5 
        ? $self->_strand( $self->{'__raw__'}[5] )
        : -1
        ;
}
# Note rawstart has +1 because BED is 'semi-open' coordinates
sub rawstart { my $self = shift; return $self->{'__raw__'}[1]+1; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub id       { my $self = shift; return $self->{'__raw__'}[3]; }

sub _raw_score    { 
  my $self = shift;

  my $score = 0;
  if ( exists($self->{'__raw__'}[4]) && $self->{'__raw__'}[4] =~ /^-*\d+\.?\d*$/) {
    $score = $self->{'__raw__'}[4];
  }
  elsif ($self->{'__raw__'}[3] =~ /^-*\d+\.?\d*$/) { ## Possible bedGraph format
    $score = $self->{'__raw__'}[3];
  } 
  return $score;
}

sub score {
  my $self = shift;

  $self->{'score'} = $_[0] if @_;
  $self->{'score'} = $self->_raw_score unless exists $self->{'score'};
  return $self->{'score'};
}

sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'} if $self->{'_cigar'};
  if($self->{'__raw__'}[9]>0) {
    my $strand = $self->strand();
    my $cigar;
    my @block_starts  = split /,/,$self->{'__raw__'}[11];
    my @block_lengths = split /,/,$self->{'__raw__'}[10];
    my $end = 0;
    foreach(0..( $self->{'__raw__'}[9]-1) ) {
      last unless @block_starts and @block_lengths;
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
    # Length of Cigar must not have +1 
    return $self->{'_cigar'}=($self->{'__raw__'}[2]-$self->{'__raw__'}[1])."M";
  }
}

1;
