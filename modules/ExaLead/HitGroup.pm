package ExaLead::HitGroup;
use strict;

sub new {
  my( $class, $name ) = @_;
  my $self = { 'name' => $name, 'children' => [], 'links' => {} };
  bless $self, $class;
  return $self;
}

sub name   :lvalue { $_[0]->{'name'};     } # get/set string
sub children       { @{$_[0]->{'children'}}; } # get arrayref
sub links          { %{$_[0]->{'links'}};    } # get hashref
sub addLink        { $_[0]->{'links'}{$_[1]} = $_[2]; } # set string,string
sub link   :lvalue { $_[0]->{'links'}{$_[1]}; }
sub addChildren    { $_[0]->{'children'}     = $_[1]; } # set arrayref of E::C

1;
