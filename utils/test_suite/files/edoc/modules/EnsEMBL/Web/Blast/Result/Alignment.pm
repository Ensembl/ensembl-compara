package EnsEMBL::Web::Blast::Result::Alignment;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw(EnsEMBL::Web::Blast::Result);

sub new {
  my ($class, $properties) = @_;
  my $self = {
	      'hsp' => undef,
              'score' => undef,
              'probability' => undef,
              'reading_frame' => undef,
              'identities' => undef,
              'positives' => undef,
              'length' => undef,
              'query_start' => undef,
              'query_end' => undef,
              'subject_start' => undef,
              'subject_end' => undef,
              'display' => undef,
              'cigar_string' => '',
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
              'hsp_id'        => $record->[2],
              'chromosome'    => $record->[3],
              'probability'   => $record->[4],
              'score'         => $record->[5],
              'query_start'   => $record->[6],
              'query_end'     => $record->[7],
              'subject_start' => $record->[8],
              'subject_end'   => $record->[9],
              'identities'    => $record->[10],
              'positives'     => $record->[11],
              'length'        => $record->[12],
              'reading_frame' => $record->[13],
              'display'       => $record->[14],
              'cigar_string'  => $record->[15],
             });
}

sub display {
  my ($self, $value) = @_;    
  return $self->param('display', $value);
}

sub hsp_id {
  my ($self, $value) = @_;    
  return $self->param('hsp_id', $value);
}

sub query_start {
  my ($self, $value) = @_;    
  return $self->param('query_start', $value);
}

sub query_end {
  my ($self, $value) = @_;    
  return $self->param('query_end', $value);
}

sub subject_start {
  my ($self, $value) = @_;    
  return $self->param('subject_start', $value);
}

sub subject_end {
  my ($self, $value) = @_;    
  return $self->param('subject_end', $value);
}

sub cigar_string {
  my ($self, $value) = @_;    
  return $self->param('cigar_string', $value);
}

1;
