package EnsEMBL::Web::Wizard::Connection;

### Package to define a connection between nodes in a wizard

use strict;
use warnings;

use Class::Std;

{

my %From :ATTR(:set<from> :get<from>);
my %To :ATTR(:set<to> :get<to>);
my %Label :ATTR(:set<label> :get<label>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_from($args->{from});
  $self->set_to($args->{to});
  $self->set_label($args->{label});
}

sub from {
  ### a
  my $self = shift;
  $self->set_from(shift) if @_;
  return $self->get_from;
}

sub to {
  ### a
  my $self = shift;
  $self->set_to(shift) if @_;
  return $self->get_to;
}

sub label {
  ### a
  my $self = shift;
  $self->set_label(shift) if @_;
  return $self->get_label;
}


}

1;
