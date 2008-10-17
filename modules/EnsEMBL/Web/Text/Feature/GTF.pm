package Data::Bio::Text::Feature::GTF;
use strict;
use Data::Bio::Text::Feature;
use vars qw(@ISA);
@ISA = qw(Data::Bio::Text::Feature);

sub id      { my $self = shift; return $self->{'__raw__'}[2]; }
sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift; return $self->_strand( $self->{'__raw__'}[6] ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[3]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[4]; }

1;
