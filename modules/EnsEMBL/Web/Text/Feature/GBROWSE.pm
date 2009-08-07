package EnsEMBL::Web::Text::Feature::GBROWSE;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $args ) = @_;

  my $extra      = {};
  $extra->{'type'} = [$args->[6]] if defined $args->[6];
  $extra->{'note'} = [$args->[7]] if defined $args->[7];
  $extra->{'link'} = [$args->[8]] if defined $args->[8];

  return bless { '__raw__' => $args, '__extra__' => $extra }, $class;
}


sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub strand   { my $self = shift; return $self->{'__raw__'}[3]; }
sub id { my $self = shift; return $self->{'__raw__'}[4]; }
sub score { my $self = shift; return $self->{'__raw__'}[5]; }
sub type { my $self = shift; return $self->{'__raw__'}[6]; }
sub note { my $self = shift; return $self->{'__raw__'}[7]; }
sub link { my $self = shift; return $self->{'__raw__'}[8]; }
sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }

1;
