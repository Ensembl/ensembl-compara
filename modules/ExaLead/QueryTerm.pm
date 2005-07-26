package ExaLead::QueryTerm;
use strict;

sub new {
  my( $class, $regexp, $level ) = @_;
  my $self = {
    'regexp'   => $regexp,
    'level'    => $level
  };
  bless $self, $class;
  return $self;
}

sub regexp :lvalue { $_[0]->{'regexp'};   } # get/set string
sub level  :lvalue { $_[0]->{'level'};    } # get/set int

1;
