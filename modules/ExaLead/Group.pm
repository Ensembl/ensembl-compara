package ExaLead::Group;
use strict;

sub new {
  my( $class, $name, $count ) = @_;
  my $self = { 'name' => $name, 'count' => $count, 'children' => [], 'links' => {} };
  bless $self, $class;
  return $self;
}

sub name   :lvalue { $_[0]->{'name'};     } # get/set string
sub count  :lvalue { $_[0]->{'count'};    } # get/set int
sub children       { @{$_[0]->{'children'}}; } # get arrayref
sub links          { %{$_[0]->{'links'}};    } # get hashref
sub addLink        { $_[0]->{'links'}{$_[1]} = $_[2]; } # set string,string
sub link   :lvalue { $_[0]->{'links'}{$_[1]}; }
sub addChildren    { $_[0]->{'children'}     = $_[1]; } # set arrayref of E::C

1;
