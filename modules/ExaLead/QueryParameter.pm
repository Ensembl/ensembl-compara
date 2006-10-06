package ExaLead::QueryParameter;
use strict;

### Encapsulates the exalead XML <QueryParameter /> element
sub new {
### c
  my( $class, $name, $value ) = @_;
  my $self = {
    'name'   => $name,
    'value'  => $value
  };
  bless $self, $class;
  return $self;
}

sub name  :lvalue {
### a
  $_[0]->{'name'};
}
sub value :lvalue {
### a
  $_[0]->{'value'};
}

1;
