package EnsEMBL::Web::Wizard;

### Package to assemble a wizard from its component nodes, render page nodes
### and redirect to next node in process


use strict;
use warnings;

use Class::Std;
use Data::Dumper;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Wizard::Connection;
use EnsEMBL::Web::Wizard::Node;


{

my %Object :ATTR(:set<object> :get<object>);
my %ScriptName :ATTR(:set<scriptname> :get<scriptname> :init_arg<scriptname>);
my %Form :ATTR(:set<form> :get<form>);
my %Nodes :ATTR(:set<nodes> :get<nodes> :init_arg<nodes>);
my %Default_Node :ATTR(:set<default_node> :get<default_node>);
my %Connections :ATTR(:set<connections> :get<connections> :init_arg<connections>);
my %Destination :ATTR(:set<destination>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_nodes({});
  $self->set_connections([]);
}


sub form {
  ### a
  my $self = shift;
  $self->set_form(shift) if @_;
  return $self->get_form;
}


sub create_node {
### Creates a node and adds it to the wizard
  my ($self, %params) = @_;
  my $module = $params{module};
  my $name = $params{name};
  my $type = $params{type} || 'page';
  if ($module && $name) {
    if (EnsEMBL::Web::Root::dynamic_use(undef, $module)) {
      my $node = $module->new({ 
          name      => $name, 
          type      => $type, 
          object    => $params{object},
          backtrack => $params{backtrack}, 
      });
      $self->add_node($name, $node);
      return $node;
    }
    else {
      warn "Can't use module $module";
    }
  }
  else {
    warn "Insufficient parameters - did you supply a module and name?";
  }
  return undef;
}

sub add_node {
### Adds a node to the nodes hash and sets default node if none exists
  my ($self, $name, $node) = @_;
  my $nodes = $self->get_nodes;
  if (!keys %$nodes) {
    $self->set_default_node($name);
  }
  $nodes->{$name} = $node;
  $self->set_nodes($nodes);
}

sub current_node {
### Determines the current node - either as passed in CGI, or default
  my ($self) = @_;
  my $nodes = $self->get_nodes;
  my $current_node = undef; 
  my $submit = $self->get_object->param('wizard_submit');
  if ($submit && $submit =~ /Back/) {
    my $previous = $self->find_previous;
    $current_node = $nodes->{$self->find_previous};
  } 
  elsif ($self->get_object->param('wizard_next')){
    $current_node = $nodes->{$self->get_object->param('wizard_next')};
  }
  else {
    $current_node = $nodes->{$self->get_default_node};
  }
  return $current_node;
}

sub forward_connection {
### Gets the forward connection required to generate 'Next'-type buttons
  my ($self, $node) = @_;
  my $forward_connection = undef;
  foreach my $connection (@{ $self->get_connections }) {
    if ($connection->from->name eq $node->name) {
      $forward_connection = $connection;
    }
  }
  ## Add in any dynamically-created links
  my $next_name = $self->get_object->param('wizard_next');
  if (!$forward_connection && $next_name && $next_name ne $self->current_node->name) {
    $forward_connection = EnsEMBL::Web::Wizard::Connection->new({ 
                    from => $node, to => $self->get_nodes->{$next_name} });
  }
  return $forward_connection;
}


sub add_connection {
### Creates and adds a Wizard::Connection object to the array of connections
  my ($self, %params) = @_;
  return unless $params{from} && $params{to};
  my @connections = @{$self->get_connections};
  my $connection = EnsEMBL::Web::Wizard::Connection->new({ from => $params{from}, to => $params{to}});
  if ($connection) {
    push @connections, $connection;
  }
  $self->set_connections(\@connections);
}

sub update_parameters {
### Updates node with new parameters, then cleans them up so they can be used to redirect the wizard
  my $self = shift;
  my $node = $self->current_node;
  my $init_method = $node->name;
  $node->$init_method; ## Call the method with the same name as the current node
  my $parameter = $node->get_parameter;

  ## Add in any unpassed parameters
  foreach my $param ($self->get_object->param) {
    next if $param =~ /^wizard_/ && $param ne 'wizard_steps'; ## Don't automatically pass built-in parameters
    my @value = $self->get_object->param($param);
    if (@value) {
      $parameter->{$param} = \@value unless $parameter->{$param};
    }
  }

  return $parameter;
}

sub render_current_node {
### Renders a form for the current node
  my $self = shift;
  my $object = $self->get_object;
  my $node = $self->current_node;
  my $html;
  if ($node) {
    my $action = $self->get_scriptname;
    my $form = EnsEMBL::Web::Form->new('connection_form', $action);
    $self->set_form($form);
    my $init_method = $node->name;
    $node->$init_method; 
    my $fieldset = $form->add_fieldset;
    $fieldset->notes($node->notes);
    $html .= "<h2>".$node->title."</h2>\n";

    if ($object->param('error_message')) {
      $html .= '<div class="alert-box">'.$object->param('error_message').'</div>';
    }

    $html .= $node->text_above."\n" if $node->text_above;
    $html .= $self->render_connection_form($node);
    $html .= "\n".$node->text_below."\n" if $node->text_below;
  } else {
    $html = $self->render_error_message($object, 'Either no current node has been specified, or there is a syntax error in the wizard code. Please check your URL and try again.');
  }
  return $html;
}

sub render_connection_form {
### helper function to render the form itself
  my ($self, $node) = @_;
  my $html = '';

  ## Main form widgets
  foreach my $element (@{ $node->get_elements }) {
    $self->form->add_element(%$element);
  }

  ## Passed parameters
  $self->add_incoming_parameters;

  ## Control elements
  my $forward_connection = $self->forward_connection($node);
  if ($node->name ne $self->get_default_node && $node->get_backtrack) {
    $self->form->add_button('type' => 'Submit', 'name' => 'wizard_submit', 'value' => '< Back');
  }
  if ($forward_connection && !$self->get_object->param('fatal_error')) {
    my $label = $forward_connection->label || 'Next >';
    $self->form->add_element('type' => 'Hidden', 'name' => 'wizard_next', 'value' => $forward_connection->to->name);
    $self->form->add_button('type' => 'Submit', 'name' => 'wizard_submit', 'value' => $label);
  }
  $html .= $self->form->render;
  return $html;
}

sub find_previous {
### Returns penultimate element from wizard_steps array
  my $self = shift;
  my @steps = $self->get_object->param('wizard_steps');
  pop(@steps);
  return pop(@steps);
}

sub incoming_parameters {
### Munges CGI parameters
  my $self = shift;
  my %parameter = ();

  my @cgi_params = $self->get_object->param();
  foreach my $name (@cgi_params) {
    my @value = $self->get_object->param($name);
    if (@value) {
      $parameter{$name} = \@value;
    } 
  }
  return %parameter;
}

sub add_incoming_parameters {
### Passes CGI parameters as hidden fields in the form, including munging
### the wizard_steps array to keep track of where we are
  my ($self) = @_;
  my %parameter = $self->incoming_parameters;

  ## Make sure we don't duplicate fields already in this form (via 'Back' actions)
  ## Mainly a fix for stupid HTML checkboxes
  if (keys %parameter) {
    foreach my $element (@{ $self->current_node->get_elements }) {
      delete($parameter{$element->{'name'}}) if $element->{'name'};
    }
  }

  ## Add in valid CGI parameters as hidden fields
  foreach my $name (keys %parameter) {
    next if $name =~ /^wizard_/ && $name ne 'wizard_steps';
    my $value = $parameter{$name};
    ## Deal with step array
    if ($name eq 'wizard_steps') {
      my $submit = $parameter{'wizard_submit'};
      if ($submit && $submit->[0] =~ /Back/) {
        pop(@$value) if ref($value) eq 'ARRAY';
      }
      else {
        push(@$value, $self->current_node->name) if ref($value) eq 'ARRAY';
      }
    }

    foreach my $v (@$value) {
      $self->form->add_element(type => 'Hidden', name => $name, value => $v);
    }
  }
  if (!$parameter{'wizard_steps'}) {
    $self->form->add_element(('type'=>'Hidden', 'name'=>'wizard_steps', 'value'=>$self->current_node->name));
  }

}

sub render_error_message {
### Outputs an error message; also uses a form to keep track of where we were in the wizard
  my ($self, $object, $message) = @_;

  my $form = $self->get_form;
  if (!$form) {
    my $action = $self->get_scriptname;
    $form = EnsEMBL::Web::Form->new('connection_form', $action);
    $form->add_attribute('class', 'wizard');
  }
  if (!$message) {
    $message = $object->param('error_message');
  }

  $form->add_element(( type => 'Information', value => $message ));
  my @steps = ($object->param('wizard_steps'));
  foreach my $value (@steps) {
    $form->add_element(type => 'Hidden', name => 'wizard_steps', value => $value);
  }
  $form->add_element('type' => 'Submit', 'name' => 'wizard_submit', 'value' => '< Back');

  return $form->render;
}

}

1;
