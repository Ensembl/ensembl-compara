package EnsEMBL::Web::Configuration::Interface;

### Module to create generic panels for Document::Interface and its associated modules

use strict;
use base qw( EnsEMBL::Web::Configuration );

#sub populate_tree {}
#sub set_default_action {}

sub select_to_edit {
  ### Creates a panel containing a record selection form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'select_to_edit')) {
    $panel->add_components(qw(select    EnsEMBL::Web::Component::Interface::SelectToEdit));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Select a Record to Edit");
  }
  return undef;
}

sub add {
  ### Creates a panel containing an empty record form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'add')) {
    $panel->add_components(qw(add     EnsEMBL::Web::Component::Interface::Add));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Add a New Record");
  }
  return undef;
}

sub edit {
  ### Creates a panel containing a record form populated with data
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'edit')) {
    $panel->add_components(qw(edit    EnsEMBL::Web::Component::Interface::Edit));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Edit a Record");
  }
  return undef;
}

sub select_to_delete {
  ### Creates a panel containing a record selection form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'select_to_delete')) {
    $panel->add_components(qw(select   EnsEMBL::Web::Component::Interface::SelectToDelete));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Select a Record to Delete");
  }
  return undef;
}

sub confirm_delete {
  ### Creates a panel asking the user to confirm deletion
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'confirm_delete')) {
    $panel->add_components(qw(select   EnsEMBL::Web::Component::Interface::ConfirmDelete));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Confirm Deletion");
  }
  return undef;
}

sub preview {
  ### Creates a panel showing a non-editable record
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'preview')) {
    $panel->add_components(qw(preview     EnsEMBL::Web::Component::Interface::Preview));
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
  my $script = $interface->script_name;
  my $url;
  if ($success) {
    $url = "/$script?dataview=success";
  }
  else {
    $url = "/$script?dataview=failure";
  }
  $url .= ';_referer='.CGI::escape($object->param('_referer'));
  return $url;
}

sub delete {
  ### Deletes record(s) and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  
  my $success = $interface->data->destroy;
  my $script = $interface->script_name;
  my $url;
  if ($success) {
    $url = "/$script?dataview=success;_referer=".CGI::escape($object->param('_referer'));
  }
  else {
    $url = "/$script?dataview=failure;_referer=".CGI::escape($object->param('_referer'));
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
      my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
      $dir = '' if $dir !~ /_/; 
      my $url = $dir.$option->{'action'};
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
  $self->on_failure($object, $interface, $method);
}

sub on_success {
  ### Creates a panel showing feedback on database success 
  my ($self, $object, $interface, $component) = @_;
  if (my $panel = $self->interface_panel($interface, 'on_success')) {
    unless ($component) {
      $component = 'EnsEMBL::Web::Component::Interface::OnSuccess';
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
  if (my $panel = $self->interface_panel($interface, 'on_failure')) {
    unless ($component) {
      $component = 'EnsEMBL::Web::Component::Interface::OnFailure';
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
  my ($self, $interface, $action) = @_;
  $self->{object}->interface($interface);
  my $panel = $self->new_panel('Image',
        'code'      => 'interface_panel',
        'object'    => $self->{object}
    );
  return $panel;
}


1;
