package Data::Bio::Text::Feature::GBrowse;
use strict;
use Data::Bio::Text::Feature;
use vars qw(@ISA);
@ISA = qw(Data::Bio::Text::Feature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub strand   { my $self = shift; return $self->{'__raw__'}[3]; }
sub id { my $self = shift; return $self->{'__raw__'}[4]; }
sub score { my $self = shift; return $self->{'__raw__'}[5]; }
sub type { my $self = shift; return $self->{'__raw__'}[6]; }
sub note { my $self = shift; return $self->{'__raw__'}[7]; }
sub link { my $self = shift; return $self->{'__raw__'}[8]; }

1;
