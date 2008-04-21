package EnsEMBL::Web::Configuration::Interface;

### Module to create generic panels for Document::Interface and its associated modules

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );


sub select_to_edit {
  ### Creates a panel containing a record selection form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'select_to_edit', 'Select a Record')) {
    $panel->add_components(qw(select    EnsEMBL::Web::Component::Interface::select_to_edit));
    $self->add_form($panel, qw(select   EnsEMBL::Web::Component::Interface::select_to_edit_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Select a Record to Edit");
  }
  return undef;
}

sub add {
  ### Creates a panel containing an empty record form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'add', 'Add a New Record')) {
    $panel->add_components(qw(add     EnsEMBL::Web::Component::Interface::add));
    $self->add_form($panel, qw(add    EnsEMBL::Web::Component::Interface::add_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Add a Record");
  }
  return undef;
}

sub edit {
  ### Creates a panel containing a record form populated with data
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'edit', 'Edit this Record')) {
    $panel->add_components(qw(edit    EnsEMBL::Web::Component::Interface::edit));
    $self->add_form($panel, qw(edit   EnsEMBL::Web::Component::Interface::edit_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Edit a Record");
  }
  return undef;
}

sub select_to_delete {
  ### Creates a panel containing a record selection form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'select_to_delete', 'Select a Record to Delete')) {
    $panel->add_components(qw(select   EnsEMBL::Web::Component::Interface::select_to_delete));
    $self->add_form($panel, qw(select   EnsEMBL::Web::Component::Interface::select_to_delete_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Select a Record to Delete");
  }
  return undef;
}

sub preview {
  ### Creates a panel showing a non-editable record
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'preview', 'Preview')) {
    $panel->add_components(qw(preview     EnsEMBL::Web::Component::Interface::preview));
    $self->add_form($panel, qw(preview    EnsEMBL::Web::Component::Interface::preview_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Preview");
  }
  return undef;
}

sub save {
  ### Saves changes to the record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  $interface->cgi_populate($object);

  my $success = $interface->data->save;
  my $script = $interface->script_name || $object->script;
  my $url;
  if ($success) {
    $url = "/common/$script?dataview=success";
  }
  else {
    $url = "/common/$script?dataview=failure";
  }
  return $url;
}

sub delete {
  ### Deletes record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  
  #$interface->data->populate($object->param('id'));

  my $success = $interface->data->destroy;
  my $script = $interface->script_name || $object->script;
  my $url;
  if ($success) {
    $url = "/common/$script?dataview=success";
  }
  else {
    $url = "/common/$script?dataview=failure";
  }
  return $url;
}


sub success {
  ### Wrapper for on_success method set in interface script
  ### Defaults to local on_success method if not set
  my ($self, $object, $interface) = @_;
  my $option = $interface->on_success;
  my $method;
  if ($option) {
    if ($option->{'type'} eq 'url') {
      my $url = $option->{'action'};

      ## pass any additional CGI parameters
      my @parameters = $object->param();
      if (scalar(@parameters) > 0) {
        $url .= '?';
        my @params;
        foreach my $key (@parameters) {
          next if $key eq 'dataview'; ## skip this, or it will break the destination script!
          ## deal with multiple-value parameters!
          my @param_check = $object->param($key);
          my $value;
          if (scalar(@param_check) > 1) {
            foreach my $p (@param_check) {
              push(@params, $key.'='.$p);
            }
          }
          else {
            my $param = $object->param($key);
            if ($key eq 'url') {
              $param = CGI::escape($param);
            }
            push(@params, "$key=$param");
          }
        }
        $url .= join(';', @params);
      }
      return $url;
    }
    else {
      $method = $option->{'action'};
      my $module = $method;
      $module =~ s/::[\w]+$//;
      $method = undef unless $self->dynamic_use($module);
    }
  }
  $self->on_success($object, $interface, $method);
}

sub failure {
  ### Wrapper for on_failure method set in interface script
  ### Defaults to local on_failure method if not set
  my ($self, $object, $interface) = @_;
  my $option = $interface->on_failure;
  my $method;
  if ($option) {
    if ($option->{'type'} eq 'url') {
      return $option->{'action'};
    }
    else {
      $method = $option->{'action'};
      my $module = $method;
      $module =~ s/::[\w]+$//;
      $method = undef unless $self->dynamic_use($module);
    }
  }
  $self->on_failure($object, $interface, $method);
}

sub on_success {
  ### Creates a panel showing feedback on database success 
  my ($self, $object, $interface, $component) = @_;
  if (my $panel = $self->interface_panel($interface, 'on_success', 'Database Update Succeeded')) {
    unless ($component) {
      $component = 'EnsEMBL::Web::Component::Interface::on_success';
    }
    $panel->add_components('success', $component);
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Update Successful");
  }
  return undef;
}

sub on_failure {
  ### Creates a panel showing feedback on database failure
  my ($self, $object, $interface, $component) = @_;
  if (my $panel = $self->interface_panel($interface, 'on_failure', 'Database Update Failed')) {
    unless ($component) {
      $component = 'EnsEMBL::Web::Component::Interface::on_success';
    }
    $panel->add_components('failure', $component);
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Update Failed");
  }
  return undef;
}

sub interface_panel {
  ### Utility to instantiate an interface panel
  my ($self, $interface, $action, $caption) = @_;
  if ($interface->caption($action)) {
    $caption = $interface->caption($action);
  }
  my $panel = $self->new_panel('Image',
        'code'      => 'interface_panel',
        'caption'   => $caption,
        'interface' => $interface,
        'object'    => $self->{object}
    );
  return $panel;
}


1;
