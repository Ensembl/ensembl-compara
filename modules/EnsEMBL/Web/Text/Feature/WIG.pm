package EnsEMBL::Web::Text::Feature::WIG;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { return -1;}
sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub score { my $self = shift; return $self->{'__raw__'}[3]; }
sub id { my $self = shift; return $self->{'__raw__'}[4]; }
sub external_data { return undef; }

1;
