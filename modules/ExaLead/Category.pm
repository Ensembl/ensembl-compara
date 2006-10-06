package ExaLead::Category;
use strict;

sub new {
### c
  my( $class, $name, $count, $gcount, $state ) = @_;
  my $self = {
    'name'     => $name,
    'count'    => $count,
    'gcount'   => $gcount,
    'children' => [],
    'links'    => {},
    'state'    => qw(normal refined excluded)[$state]
  };
  bless $self, $class;
  return $self;
}

sub name   :lvalue {
### a
  $_[0]->{'name'};
}
sub count  :lvalue {
### a
  $_[0]->{'count'};
}
sub gcount :lvalue {
### a
  $_[0]->{'gcount'};
}
sub children       {
### a
### returns the child arrayref as an array of {{Exalead::Category}} objects
  @{$_[0]->{'children'}};
} # get arrayref
sub links          {
### a
  %{$_[0]->{'links'}};
} # get hashref

sub addLink        {
### adds a link to the links hash
  $_[0]->{'links'}{$_[1]} = $_[2];
}
sub link   :lvalue {
### a
  $_[0]->{'links'}{$_[1]};
}
sub addChildren    {
### a
### Sets the childrens arrayref to an arrayref of {{Exalead::Category}} objects
  $_[0]->{'children'}    = $_[1];
}

1;
