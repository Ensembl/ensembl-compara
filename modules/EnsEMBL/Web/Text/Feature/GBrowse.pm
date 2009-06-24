package EnsEMBL::Web::Text::Feature::GBrowse;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $hash_ref ) = @_;

  my $extra      = {};
  $extra->{'type'} = [$hash_ref->[6]] if defined $hash_ref->[6];
  $extra->{'note'} = [$hash_ref->[7]] if defined $hash_ref->[7];
  $extra->{'link'} = [$hash_ref->[8]] if defined $hash_ref->[8];

  return bless { '__raw__' => $hash_ref, '__extra__' => $extra }, $class;
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
