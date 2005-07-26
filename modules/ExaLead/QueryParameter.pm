package ExaLead::QueryParameter;
use strict;

sub new {
  my( $class, $name, $value ) = @_;
  my $self = {
    'name'   => $name,
    'value'  => $value
  };
  bless $self, $class;
  return $self;
}

sub name  :lvalue { $_[0]->{'name'};    } # get/set string
sub value :lvalue { $_[0]->{'value'};   } # get/set string

1;
