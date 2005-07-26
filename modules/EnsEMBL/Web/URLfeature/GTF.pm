package EnsEMBL::Web::URLfeature::GTF;
use strict;
use EnsEMBL::Web::URLfeature::GFF;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::URLfeature::GFF);

sub id      { my $self = shift; return $self->{'__raw__'}[16]; }
1;
