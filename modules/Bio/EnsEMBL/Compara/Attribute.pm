package Bio::EnsEMBL::Compara::Attribute;

use strict;
use Carp;

our ($AUTOLOAD, %ok_field);

%ok_field = ('member_id' => 1,
             'family_id' => 1,
             'cigar_line' => 1,
             'domain_id' => 1,
             'member_start' => 1,
             'member_end' => 1,
             'homology_id' => 1,
             'perc_cov' => 1,
             'perc_id' => 1,
             'perc_pos' => 1,
             'exon_count' => 1,
             'flag' => 1);

sub new {
  my ($class) = @_;

  return bless {}, $class;
}

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype : 
  Exceptions : none
  Caller     : 

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}

sub AUTOLOAD {
  my $self = shift;
  my $method = $AUTOLOAD;
  $method =~ s/.*:://;
  croak "invalid method: ->$method()" unless $ok_field{$method};
  $self->{lc $method} = shift if(@_);
  return $self->{lc $method};
}


sub DESTROY {}

1;
