package EnsEMBL::Web::Controller::Command;

use strict;
use warnings;

use EnsEMBL::Web::Controller::Command::Filter;
use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Magic;
use Class::Std;
use CGI qw(escape escapeHTML);

use base qw(EnsEMBL::Web::Root);


{

my %Filters       :ATTR(:get<filters> :set<filters>);
my %Action        :ATTR(:get<action> :set<action> :init_arg<action>);
my %Message       :ATTR(:get<message> :set<message>);
my %SpeciesDefs   :ATTR(:get<species_defs> :set<species_defs>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
    $self->set_species_defs($ENSEMBL_WEB_REGISTRY->species_defs);
  }
}

sub action {
  my $self = shift;
  return $self->get_action; 
}

sub render {
  my $self = shift;
  ## Set _referer so we can return to calling page
  unless ($self->action->cgi->param('_referer')) {
    $self->action->cgi->param('_referer', CGI::escape($ENV{'HTTP_REFERER'}));
  }
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process;
  }
}

sub render_message {
  my $self = shift;
  my $type = $ENV{'ENSEMBL_TYPE'} || 'Account';
  my $url = "/$type/Message?command_message=".$self->get_message;
  $self->action->cgi->redirect($url);
}

sub add_filter {
  my ($self, $class, $params) = @_;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    my $parameters = $params || {};
    $parameters->{'action'} = $self->action;
    my $filter = $class->new($parameters);
    my $filters = $self->get_filters || [];
    push @$filters, $filter;
    $self->set_filters($filters);
  } else {
    warn "Failed to add filter.";;
  }
}

sub not_allowed {
  ### Loops through array of filters and returns error message 
  ### for the first one which fails
  my $self = shift;
  my $filters = $self->get_filters || [];
  foreach my $f (@$filters) {
    if (!$f->allow) {
      $self->set_message($f->message);
      return 1;
    }
  }
  return undef;
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
