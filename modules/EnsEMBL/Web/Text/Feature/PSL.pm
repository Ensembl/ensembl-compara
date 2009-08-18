package EnsEMBL::Web::Text::Feature::PSL;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $args ) = @_;

  my $extra      = {
    'matches'        => [$args->[0]],
    'miss_matches'   => [$args->[1]],
    'rep_matches'    => [$args->[2]],
    'n_matches'      => [$args->[3]],
    'q_num_inserts'  => [$args->[4]],
    'q_base_inserts' => [$args->[5]],
    't_num_inserts'  => [$args->[6]],
    'q_base_inserts' => [$args->[7]],
    'q_size'         => [$args->[10]],

  };

  return bless { '__raw__' => $args, '__extra__' => $extra }, $class;
}

sub coords {
  my ($self, $data) = @_;
  return ($data->[9], $data->[11], $data->[12]);
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[13]; }
sub strand   { my $self = shift; return $self->_strand( substr($self->{'__raw__'}[8],-1) ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[15]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[16]; }
sub id       { my $self = shift; return $self->{'__raw__'}[9]; }

sub hstart   { my $self = shift; return $self->{'__raw__'}[11]; }
sub hend     { my $self = shift; return $self->{'__raw__'}[12]; }
sub hstrand  { my $self = shift; return $self->_strand( substr($self->{'__raw__'}[8],0,1)); }
sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'} if $self->{'_cigar'};
  my $strand = $self->strand();
  my $cigar;
  my @block_starts  = split /,/,$self->{'__raw__'}[19];
  my @block_lengths = split /,/,$self->{'__raw__'}[18];
  my $end = 0;
  foreach(0..( $self->{'__raw__'}[17]-1) ) {
    my $start =shift @block_starts;
    my $length = shift @block_lengths;
    if($_) {
      $cigar.= ( $start - $end - 1)."I";
    }
    $cigar.= $length.'M';
    $end = $start + $length -1;
  }
  return $self->{'_cigar'}=$cigar;
}

1;
