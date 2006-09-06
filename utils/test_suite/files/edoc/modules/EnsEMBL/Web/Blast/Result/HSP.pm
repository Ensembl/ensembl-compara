package EnsEMBL::Web::Blast::Result::HSP;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Blast::Result;
our @ISA = qw(EnsEMBL::Web::Blast::Result);

sub new {
  #my ($class, $id, $type, $chromosome, $score, $probability, $reading_frame, $ident) = @_;
  my ($class, $properties) = @_;
  my $self = {
              'id' => undef,
              'type' => undef,
              'chromosome' => undef,
              'score' => undef,
              'probability' => undef,
              'reading_frame' => undef,
              'ident' => undef,
              'alignments' => undef,
              'start' => undef,
              'end' => undef,
             };
  bless $self, $class;
  $self->assign_properties($properties);
  return $self;
}

sub new_from_database {
  my ($class, $record) = @_;
  return new ($class, {
              'id'            => $record->[0],
              'job_id'        => $record->[1],
              'ident'         => $record->[2],
              'type'          => $record->[3],
              'chromosome'    => $record->[4],
              'probability'   => $record->[5],
              'score'         => $record->[6],
              'start'         => $record->[7],
              'end'           => $record->[8],
              'length'        => $record->[9],
              'reading_frame' => $record->[10],
             });
}

sub new_from_line {
  my ($class, $line) = @_;
  my ($ident, $type, $info, $reading_frame, $score, $probability, $n) = split(/\s+/, $line);
  my ($info_type, $ncbi, $chromosome) = split(/:/, $info); 
  #return new($class, 'test', $type, $chromosome, $score, $probability, $reading_frame, $ident);
  return new($class, { id => 'undefined',
                       type => $type,
                       chromosome => $chromosome,
                       score => $score,
                       probability => $probability,
                       reading_frame => $reading_frame,
                       ident => $ident 
                       });
}

sub add_alignment {
  my ($self, $alignment) = @_;
  if ($alignment) {
    $self->add_alignments($alignment);
  }
}

sub add_alignments {
  my ($self, @alignments) = @_;
  if (@alignments) {
    push @{ $self->{'alignments'} }, @alignments;
  }
}

sub alignments {
  my ($self, @alignments) = @_;
  if (@alignments) {
    $self->{'alignments'} = \@alignments;
  }
  return $self->{'alignments'}; 
}

1;
