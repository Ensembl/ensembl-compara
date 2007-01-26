package EnsEMBL::Web::Configuration::Interface;

### Module to create generic panels for Document::Interface and its associated modules

use strict;
use EnsEMBL::Web::Configuration;

our @ISA = qw( EnsEMBL::Web::Configuration );


sub select_to_edit {
  ### Creates a panel containing a record selection form
  my ($self, $object, $interface) = @_;
  my $caption = $interface->caption('edit') || 'Select a Record';
  if (my $panel = $self->interface_panel($interface, $caption)) {
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
  my $caption = $interface->caption('add') || 'Add a New Record';
  if (my $panel = $self->interface_panel($interface, $caption)) {
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
  my $caption = $interface->caption('edit') || 'Edit this Record';
  if (my $panel = $self->interface_panel($interface, $caption)) {
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
  my $caption = $interface->caption('delete');
  if (my $panel = $self->interface_panel($interface, $caption)) {
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
  if (my $panel = $self->interface_panel($interface, 'Preview')) {
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
  my $script = $object->script;
  my ($url, $id, @ids);
  ## Convert CGI parameters into normal Perl datastructure
  my $primary_key = $interface->structure->primary_key;
  if ($interface->multi) {
    @ids = $object->param($primary_key);
    foreach $id (@ids) {
      $interface->cgi_populate($id, $object) if $id ne '';
    }
  }
  else {
    $id = $object->param($primary_key);
    $interface->cgi_populate($id, $object);
    @ids = ($id);
  }

  my $save_method = $interface->structure->save_method;
  my $success = 0;
  my $result;
  ## Only insert/update changed records
  foreach $id (@ids) {
    my %record;
    my $parameters = $interface->data_row($id);
    while (my ($k, $v) = each(%$parameters)) {
      $record{$k} = $v;
    }
    if ($id =~ '^NEW') { ## reset ID for new records
      $record{$primary_key} = '';
    }
    if ($interface->repeat) {
      my $repeat = $interface->repeat;
      my @repeat_ids = $record{$repeat};
      foreach my $r (@repeat_ids) {
        $record{$repeat} = $r;
        $result = $object->$save_method(\%record);
        $success++ if $result;
      }
    }
    else {
      $result = $object->$save_method(\%record);
      $success++ if $result;
    }
  }
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
  my $script = $object->script;
  my $url;

  my $delete_method = $interface->structure->delete_method;
  my $success = $object->$delete_method($interface->structure->primary_key);
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
  my $method = $interface->on_success;
  if (!$method) {
    $method = 'EnsEMBL::Web::Configuration::Interface::on_success';
  }
  $self->$method($object, $interface);
}

sub failure {
  ### Wrapper for on_failure method set in interface script
  ### Defaults to local on_failure method if not set
  my ($self, $object, $interface) = @_;
  my $method = $interface->on_failure;
  if (!$method) {
    $method = 'EnsEMBL::Web::Configuration::Interface::on_failure';
  }
  $self->$method($object, $interface);
}

sub on_success {
  ### Creates a panel showing feedback on database success 
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'Database Update Succeeded')) {
    $panel->add_components(qw(success  EnsEMBL::Web::Component::Interface::on_success));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Update Successful");
  }
  return undef;
}

sub on_failure {
  ### Creates a panel showing feedback on database failure
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'Database Update Failed')) {
    $panel->add_components(qw(failure  EnsEMBL::Web::Component::Interface::on_failure));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Ensembl $type Database: Update Failed");
  }
  return undef;
}

sub interface_panel {
  ### Utility to instantiate an interface panel
  my ($self, $interface, $caption) = @_;
  my $panel = $self->new_panel('Image',
        'code'      => 'interface_panel',
        'caption'   => $caption,
        'interface' => $interface,
        'object'    => $self->{object}
    );
  return $panel;
}


1;
