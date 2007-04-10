package EnsEMBL::Web::Commander;

use strict;
use warnings;

use CGI;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Commander::Connection;
use EnsEMBL::Web::Commander::Connection::Option;
use EnsEMBL::Web::Commander::Node;
use EnsEMBL::Web::Commander::Node::Final;


{

my %Data_of;
my %Form_of;
my %Nodes_of;
my %Connections_of;
my %CGI_of;
my %Destination_of;

sub new {
  ### c
  ### Creates a new inside-out Commander object. This object controls
  ### a number of Node objects to create a wizard interface. A
  ### Commander object only controls the flow of the linked wizard nodes, 
  ### and maintains the data associated with a user's movement through 
  ### the nodes. The actual UI for each linked page is controlled by the 
  ### {{EnsEMBL::Web::Commander::Node}} objects.
  ###
  ### The Commander wizard collections information from each node, and 
  ### eventually passes it all on to the page specified by {{destination}}.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Data_of{$self} = {}; 
  $Form_of{$self} = undef; 
  $Connections_of{$self} = []; 
  $Nodes_of{$self} = defined $params{nodes} ? $params{nodes} : [];
  $Destination_of{$self} = defined $params{destination} ? $params{destination} : "";
  $CGI_of{$self} = defined $params{cgi} ? $params{cgi} : new CGI;
  return $self;
}

## accessors

sub destination {
  ### a
  my $self = shift;
  $Destination_of{$self} = shift if @_;
  return $Destination_of{$self};
}

sub cgi {
  ### a
  my $self = shift;
  $CGI_of{$self} = shift if @_;
  return $CGI_of{$self};
}

sub nodes {
  ### a
  my $self = shift;
  $Nodes_of{$self} = shift if @_;
  return $Nodes_of{$self};
}

sub connections {
  ### a
  my $self = shift;
  $Connections_of{$self} = shift if @_;
  return $Connections_of{$self};
}

sub create_node {
  my ($self, %params) = @_;
  my $module = $params{module};
  my $name = $params{name};
  if ($module && $name) {
    if (EnsEMBL::Web::Root::dynamic_use(undef, $module)) {
      my $node = $module->new(( name => $name, object => $params{object}));
      $self->add_node(( node => $node ));
      return $node;
    }
    else {
      warn "Can't use module $module";
    }
  }
  return undef;
}

sub add_node {
  my ($self, %params) = @_;
  my $name = $params{name};
  if (!$name) {
    $name = $params{node}->name;
  }
  push @{ $self->nodes }, { $name => $params{node}, name => $name, node => $params{node} };
}

sub node_with_name {
  my ($self, $name) = @_;
  my $named_node = undef;
  foreach my $node (@{ $self->nodes} ) {
    if ($node->{name} eq $name) {
      $named_node = $node->{node};
    }
  }
  return $named_node;
}

sub current_node {
  my ($self) = @_;
  my @nodes = @{ $self->nodes };
  my $current_node = undef; 
  if ($self->cgi->param('node_name')) {
    $current_node = $self->node_with_name($self->cgi->param('node_name'));
  } else {
    if ($#nodes > -1) {
      $current_node = $nodes[0]->{node};
    }
  }
  return $current_node;
}

sub node_is_connected {
  my ($self, $node) = @_;
  my $is_connected = 0;
  if ($self->forward_connection($node)) {
    $is_connected = 1;
  }
  if ($self->backward_connection($node)) {
    $is_connected = 1;
  }
  return $is_connected;
}

sub forward_connection {
  my ($self, $node) = @_;
  my $forward_connection = undef;
  foreach my $connection (@{ $self->connections }) {
    if ($connection->from->name eq $node->name) {
      $forward_connection = $connection;
    }
  }
  return $forward_connection;
}

sub forward_connections {
  my ($self, $node) = @_;
  my @return_connections = ();
  foreach my $connection (@{ $self->connections }) {
    if ($connection->from->name eq $node->name) {
      push @return_connections, $connection;
    }
  }
  return @return_connections; 
}

sub backward_connection {
  my ($self, $node) = @_;
  my $backward_connection = undef;
  foreach my $connection (@{ $self->connections }) {
    if ($connection->to->name eq $node->name) {
      $backward_connection = $connection;
    }
  }
  return $backward_connection;
}

sub add_connection {
  my ($self, %params) = @_;
  my $connection = undef;
  if ($params{type} eq 'option') {
    $connection = EnsEMBL::Web::Commander::Connection::Option->new();
  } else {
    $connection = EnsEMBL::Web::Commander::Connection->new();
  }
  if ($connection) {
    if ($params{from} && $params{to}) {
      $connection->from($params{from});
      $connection->to($params{to});
      $connection->type($params{type});
    }
    if ($params{conditional} && $params{predicate}) {
      $connection->set_conditional($params{conditional});
      $connection->set_predicate($params{predicate});
    }
    push @{ $self->connections }, $connection;
  }
}

sub render_current_node {
  my ($self) = @_;
  my $current_node = $self->current_node;
  my $render = "";
  if ($current_node) {
    my $name = $current_node->name;
    $current_node->$name;
    $render .= "<h2>".$current_node->title."</h2>\n";
    $render .= $self->render_connection_form_header($current_node);
    $render .= $current_node->render($self->incoming_parameters);
    $render .= $self->render_connection_form($current_node);
  } else {
    $render = $self->render_error_message('No current node has been specified. Check the URL and try again.');
  }
  return $render;
}

sub render_connection_form_header {
  my ($self, $node) = @_;
  my $html = "";
  my @forward_connections = $self->forward_connections($node);
  my $backward_connection = $self->backward_connection($node);
  $html .= "<script language='javascript'>\n";
  $html .= "function next_node() {\n";
  #$html .= "alert('next node');\n";
  if (@forward_connections) {
    my $added = 0;
    foreach my $forward_connection (@forward_connections) {
      if ($forward_connection->type eq 'option') {
        #$html .= "alert('checking conditions: ' + \$('" . $forward_connection->get_conditional . "').value);\n";
        $html .= "  if (\$('" . $forward_connection->get_conditional . "').value == '" . $forward_connection->get_predicate . "') {\n";
        #$html .= "alert('OK - submit');\n";
        $html .= "  \$('node_name').value = '" . $forward_connection->to->name . "';\n";
        #$html .= "  alert('conditional link to: " . $forward_connection->to->name . "');\n";
        $html .= "  \$('connection_form').submit();\n";
        $html .= "  }\n";
        $added = 1;
      }
    }
    if (!$added) {
      $html .= "  \$('connection_form').submit();\n";
    }
  }
  $html .= "}\n";
  $html .= "\n";
  if ($backward_connection) {
    $html .= "function previous_node() {\n";
    $html .= "  \$('node_name').value = '" . $backward_connection->from->name . "';\n";
    $html .= "  \$('connection_form').submit();\n";
    $html .= "}\n";
  }
  $html .= "</script>\n";
  my $action;
  if ($node->is_final) {
    ## redirect to the final destination
    $action = $node->destination; 
  }
  $html .= $node->text_above."\n";

  $self->form(EnsEMBL::Web::Form->new('connection_form', $action));
   
  return $html;
}

sub render_connection_form {
  my ($self, $node) = @_;
  my $html = "";
  if ($self->node_is_connected($node)) {
    $self->add_incoming_parameters;
    my $forward_connection = $self->forward_connection($node);
    my $backward_connection = $self->backward_connection($node);
    if ($node->is_final) {
      $self->form->add_element(type => 'Submit', name => 'finish', value => 'Finish');
    } else {
      if ($backward_connection) {
        $self->form->add_element(type => 'Submit', name => 'go_previous', value => 'Previous', 
                                onclick => 'previous_node();', 'spanning' => 'inline');
      }
      if ($forward_connection) {
        $self->form->add_element(type => 'Hidden', name => 'node_name', id => 'node_name', value => $forward_connection->to->name);
        $self->form->add_element(type => 'Button', name => 'go_next', value => 'Next', 'spanning' => 'inline', on_click => 'next_node();');
      }
    }
    $html .= $self->form->render;
    $html .= "\n".$node->text_below."\n";
  } else {
    ## Node is not connected
  }
  return $html;
}

sub incoming_parameters {
  my $self = shift;
  my %parameters = ();

  my @cgi_params = $self->cgi->param();
  foreach my $name (@cgi_params) {
    next if $name eq 'node_name';
    my @value = $self->cgi->param($name);
    if (@value) {
      $parameters{$name} = wantarray ? \@value : $value[0];
    } 
  }

  return %parameters;
}

sub add_incoming_parameters {
  my ($self) = @_;
  my %parameters = $self->incoming_parameters;
  foreach my $key (keys %parameters) {
    if ($key ne 'node_name') { 
      my $value = $parameters{$key};
      if (ref($value) eq 'ARRAY') {
        foreach my $v (@$value) {
          $self->form->add_element(type => 'Hidden', name => $key, value => $v);
        }
      }
      else {
        $self->form->add_element(type => 'Hidden', name => $key, value => $value);
      }
    }
  }
}

sub render_error_message {
  my ($self, $message) = @_;
  return "<h1>Error from Commander:</h1>$message";
}

sub data {
  ### a
  my $self = shift;
  $Data_of{$self} = shift if @_;
  return $Data_of{$self};
}

sub form {
  ### a
  my $self = shift;
  $Form_of{$self} = shift if @_;
  return $Form_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Data_of{$self};
  delete $Form_of{$self};
  delete $Nodes_of{$self};
  delete $Connections_of{$self};
  delete $CGI_of{$self};
  delete $Destination_of{$self};
}

}

1;
