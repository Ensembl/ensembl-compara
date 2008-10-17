package Data::Bio::Text::Feature::DAS;
use strict;
use Data::Bio::Text::Feature;
use vars qw(@ISA);
@ISA = qw(Data::Bio::Text::Feature);

sub id      { my $self = shift; return $self->{'__raw__'}[2]; }
sub _seqname { my $self = shift; return $self->{'__raw__'}[8]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[14] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[10]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[12]; }

1;
