package EnsEMBL::Web::Controller::Command;

use strict;
use warnings;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::SpeciesDefs;

use EnsEMBL::Web::Controller::Command::Filter;
use EnsEMBL::Web::Controller::Command::Filter::Logging;
use EnsEMBL::Web::Controller::Command::Filter::LoggedIn;
use EnsEMBL::Web::Controller::Command::Filter::Authentication;
use EnsEMBL::Web::Controller::Command::Filter::Ajax;
use EnsEMBL::Web::Controller::Command::Filter::DataUser;
use EnsEMBL::Web::Controller::Command::Filter::Redirect;

use Class::Std;

{

my %Filter :ATTR(:get<filter> :set<filter>);
my %Action :ATTR(:get<action> :set<action>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_filter(EnsEMBL::Web::Controller::Command::Filter->new);
}

sub filters {
  my $self = shift;
  return $self->get_filter;
}

sub add_filter {
  my ($self, $filter) = @_;
  if ($filter->isa('EnsEMBL::Web::Controller::Command::Filter')) {
    $filter->inherit($self->get_filter);
    $self->set_filter($filter);
  } else {
    warn "Failed to add filter: must be of class Filter.";;
  }
}

sub add_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);

  unless (defined *{ "$class\::$name" }) {
    *{ "$class\::$name" } = $self->initialize_accessor($name);
  }
}

sub initialize_accessor {
  no strict;
  my ($self, $attribute) = @_;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_value($attribute);
  };
}

}

1;
