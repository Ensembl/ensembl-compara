package ExaLead::SpellingSuggestion;
use strict;

sub new {
  my( $class, $query, $display ) = @_;
  my $self = {
    'query'    => $query   ||'',
    'display'  => $display ||'',
  };
  bless $self, $class;
  return $self;
}

sub query       :lvalue { $_[0]->{'query'};    } # get/set string
sub display     :lvalue { $_[0]->{'display'};  } # get/set int

1;
