package EnsEMBL::Web::Wizard;

use strict;
use warnings;

use Class::Std;
use Data::Dumper;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Wizard::Connection;
use EnsEMBL::Web::Wizard::Node;


{

my %CGI :ATTR(:set<cgi> :get<cgi> :init_arg<cgi>);
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


## accessors

sub form {
  ### a
  my $self = shift;
  $self->set_form(shift) if @_;
  return $self->get_form;
}


sub create_node {
  my ($self, %params) = @_;
  my $module = $params{module};
  my $name = $params{name};
  my $type = $params{type} || 'page';
  if ($module && $name) {
    if (EnsEMBL::Web::Root::dynamic_use(undef, $module)) {
      my $node = $module->new({ name => $name, type => $type, object => $params{object} });
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
  my ($self, $name, $node) = @_;
  my $nodes = $self->get_nodes;
  if (!keys %$nodes) {
    $self->set_default_node($name);
  }
  $nodes->{$name} = $node;
  $self->set_nodes($nodes);
}

sub current_node {
  my ($self) = @_;
  my $nodes = $self->get_nodes;
  my $current_node = undef; 
  my $submit = $self->get_cgi->param('wizard_submit');
  if ($submit && $submit =~ /Back/) {
    $current_node = $nodes->{$self->find_previous};
  } 
  elsif ($self->get_cgi->param('wizard_next')){
    $current_node = $nodes->{$self->get_cgi->param('wizard_next')};
  }
  else {
    $current_node = $nodes->{$self->get_default_node};
  }
  return $current_node;
}

sub forward_connection {
  my ($self, $node) = @_;
  my $forward_connection = undef;
  foreach my $connection (@{ $self->get_connections }) {
    if ($connection->from->name eq $node->name) {
      $forward_connection = $connection;
    }
  }
  ## Add in any dynamically-created links
  my $next_name = $self->get_cgi->param('wizard_next');
  if (!$forward_connection && $next_name) {
    $forward_connection = EnsEMBL::Web::Wizard::Connection->new({ 
                    from => $node, to => $self->get_nodes->{$next_name} });
  }
  return $forward_connection;
}

=pod

## Not currently in use!

sub forward_connections {
my ($self, $node) = @_;
  my @return_connections = ();
  foreach my $connection (@{ $self->get_connections }) {
    if ($connection->from->name eq $node->name) {
      push @return_connections, $connection;
      $count++;
    }
  }
  return @return_connections; 
}


=cut

sub add_connection {
  my ($self, %params) = @_;
  return unless $params{from} && $params{to};
  my @connections = @{$self->get_connections};
  my $connection = EnsEMBL::Web::Wizard::Connection->new({ from => $params{from}, to => $params{to}});
  if ($connection) {
    push @connections, $connection;
  }
  $self->set_connections(\@connections);
}

sub redirect_current_node {
  my $self = shift;
  my $node = $self->current_node;
  my $init_method = $node->name;
  my $parameter = $node->$init_method || {};
  $parameter = {} if ref($parameter) ne 'HASH'; ## sanity check

  ## Add in any unpassed parameters
  foreach my $param ($self->get_cgi->param) {
    next if $param =~ /^wizard_/ && $param ne 'wizard_steps'; ## Don't automatically pass built-in parameters
    my @value = $self->get_cgi->param($param);
    if (@value) {
      $parameter->{$param} = \@value unless $parameter->{$param};
    }
  }

  return $parameter;
}

sub render_current_node {
  my $self = shift;
  my $node = $self->current_node;
  my $html;
  my $action = '/common/'.$node->object->script;
  $self->set_form(EnsEMBL::Web::Form->new('connection_form', $action));
  if ($node) {
    my $init_method = $node->name;
    $node->$init_method; 
    $html .= "<h2>".$node->title."</h2>\n";
    $html .= $node->text_above."\n" if $node->text_above;
    #if ($current_node->is_final) {
      ## redirect to the final destination
      #$action = $current_node->get_destination;
    #}
    $html .= $self->render_connection_form($node);
    $html .= "\n".$node->text_below."\n" if $node->text_below;
  } else {
    $html = $self->render_error_message('No current node has been specified. Check the URL and try again.');
  }
  return $html;
}

sub render_connection_form {
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
  if ($node->name ne $self->get_default_node) {
    $self->form->add_element('type' => 'Submit', 'name' => 'wizard_submit', 'value' => '< Back', 
                            'multibutton' => 'yes');
  }
  if ($forward_connection) {
    my $label = $forward_connection->label || 'Next >';
    $self->form->add_element('type' => 'Hidden', 'name' => 'wizard_next', 'value' => $forward_connection->to->name);
    $self->form->add_element('type' => 'Submit', 'name' => 'wizard_submit', 'value' => $label, 
                            'multibutton' => 'yes' );
  }
  $html .= $self->form->render;
  return $html;
}

sub find_previous {
### Returns penultimate element from wizard_steps array
  my $self = shift;
  my @steps = $self->get_cgi->param('wizard_steps');
  pop(@steps);
  return pop(@steps);
}

sub incoming_parameters {
  my $self = shift;
  my %parameter = ();

  my @cgi_params = $self->get_cgi->param();
  foreach my $name (@cgi_params) {
    my @value = $self->get_cgi->param($name);
    if (@value) {
      $parameter{$name} = \@value;
    } 
  }
  return %parameter;
}

sub add_incoming_parameters {
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
  my $self = shift;
  my $html;

  $self->form->add_element(( type => 'Information', value => $self->get_cgi->param('error_message') ));
  foreach my $value (@{$self->get_cgi->param('wizard_steps')}) {
    $self->form->add_element(type => 'Hidden', name => 'wizard_steps', value => $value);
  }
  $self->form->add_element('type' => 'Submit', 'name' => 'wizard_submit', 'value' => '< Back');

  $html .= $self->form->render;
  return $html;
}

}

1;
