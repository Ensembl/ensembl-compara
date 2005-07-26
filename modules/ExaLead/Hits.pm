package ExaLead::Hits;
use strict;

sub new {
  my( $class, $nmatches, $nhits, $last, $estimated, $start, $end ) = @_;
  my $self = {
    'nmatches'  => $nmatches  ||0,
    'nhits'     => $nhits     ||0,
    'start'     => $start     ||0,
    'end'       => $end       ||0,
    'last'      => $last      ||0,
    'estimated' => $estimated ||0,
    'hits'      => [],
  };
  bless $self, $class;
  return $self;
}

sub nmatches  :lvalue { $_[0]->{'nmatches'};  } # get/set int
sub nhits     :lvalue { $_[0]->{'nhits'};     } # get/set int
sub start     :lvalue { $_[0]->{'start'};     } # get/set int
sub end       :lvalue { $_[0]->{'end'};       } # get/set int
sub last      :lvalue { $_[0]->{'last'};      } # get/set int
sub estimated :lvalue { $_[0]->{'estimated'}; } # get/set int

sub addHit  { push @{$_[0]{'hits'}},  $_[1]; }
sub getHits { return $_[0]{'hits'}; }

1;
