package ExaLead::QueryTerm;
use strict;

### Encapsulates the exalead XML <QueryTerm /> element

sub new {
### c
  my( $class, $regexp, $level ) = @_;
  my $self = {
    'regexp'   => $regexp,
    'level'    => $level
  };
  bless $self, $class;
  return $self;
}

sub regexp :lvalue {
### a
  $_[0]->{'regexp'};
}
sub level  :lvalue {
### a
  $_[0]->{'level'};
}

1;
