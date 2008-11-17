package EnsEMBL::Web::Text::Feature::DAS;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $hash_ref ) = @_;

  my $extra      = {};

  return bless { '__raw__' => $hash_ref, '__extra__' => $extra }, $class;
}

sub id      { my $self = shift; return $self->{'__raw__'}[2]; }
sub _seqname { my $self = shift; return $self->{'__raw__'}[8]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[14] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[10]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[12]; }

1;
