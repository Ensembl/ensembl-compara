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
use CGI qw(escapeHTML);

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
  unless ($object->get_action->get_cgi->param('_referer')) {
    $self->get_action->get_cgi->param('_referer', $ENV{'HTTP_REFERER'});
  }
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process;
  }
}

sub render_message {
  warn "Rendering error message";
  my $self = shift;
  my $type = shift || 'Account';
  EnsEMBL::Web::Magic::stuff($type, 'Message', $self, 'Popup');
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
      ## Set the message in the CGI object so it accessible via the proxy object
      $self->action->cgi->param('command_message', $f->message);
      #$self->set_message($f->message);
      return $f->message;
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
