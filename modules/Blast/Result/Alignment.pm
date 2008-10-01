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

sub display {
  my ($self, $value) = @_;    
  return $self->param('display', $value);
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
