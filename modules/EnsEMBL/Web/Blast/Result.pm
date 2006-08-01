package EnsEMBL::Web::Blast::Result;

use strict;
use warnings;
no warnings "uninitialized";

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub assign_properties {
  my ($self, $properties) = @_;
  while ( my ($key, $value) = each(%$properties) ) {
    $self->$key($value);
  }
}

sub id {
  my ($self, $value) = @_;    
  return $self->param('id', $value);
}

sub type {
  my ($self, $value) = @_;    
  return $self->param('type', $value);
}

sub chromosome {
  my ($self, $value) = @_;    
  return $self->param('chromosome', $value);
}

sub score {
  my ($self, $value) = @_;    
  return $self->param('score', $value);
}

sub probability {
  my ($self, $value) = @_;    
  return $self->param('probability', $value);
}

sub reading_frame {
  my ($self, $value) = @_;    
  return $self->param('reading_frame', $value);
}

sub ident {
  my ($self, $value) = @_;    
  return $self->param('ident', $value);
}

sub hsp {
  my ($self, $value) = @_;    
  return $self->param('hsp', $value);
}

sub identities {
  my ($self, $value) = @_;    
  return $self->param('identifies', $value);
}

sub positives {
  my ($self, $value) = @_;    
  return $self->param('positives', $value);
}

sub length {
  my ($self, $value) = @_;    
  return $self->param('length', $value);
}

sub start {
  my ($self, $value) = @_;    
  return $self->param('start', $value);
}

sub end {
  my ($self, $value) = @_;    
  return $self->param('end', $value);
}

sub param {
  my ($self, $key, $param) = @_;
  if ($param) {
    $self->{$key} = $param;
  }
  return $self->{$key};
}

1;
