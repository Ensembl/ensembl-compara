package EnsEMBL::Web::Component::Interface;

### Module to create generic forms for Document::Interface and its associated modules

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

sub add_form {
  ### Builds an empty HTML form for a new record
  my($panel, $object) = @_;

  ## Make sure we use any passed values
  if ($panel->interface->multi > 1) {
    my $repeat = $panel->interface->multi;
    for (my $i = 0; $i < $repeat; $i++) {
      $panel->interface->cgi_populate('NEW_'.$i, $object);
    }
  }
  else {
    $panel->interface->cgi_populate('NEW', $object);
  }
  
  my $form = _data_form($panel, $object, 'add');

  ## navigation elements
  my $primary_key = $panel->interface->structure->primary_key;
  $form->add_element( 'type' => 'Hidden', 'name' => $primary_key, 'value' => 'NEW');
  $form->add_element( 'type' => 'Hidden', 'name' => 'prev_action', 'value' => 'Save Record');
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'save');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'preview');
  $form->add_element( 'type' => 'Submit', 'value' => 'Preview');

  return $form ;
}

sub select_to_edit_form {
  ### Builds a form consisting of a dropdown widget that lists all records
  ### Sends the user to a second form where the record can be edited
  my($panel, $object) = @_;

  my $form = _record_select($panel, $object, 'select');

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'edit');
  $form->add_element( 'type' => 'Submit', 'value' => 'View Record');
  return $form ;
}

sub edit_form {
  ### Builds an HTML form populated with a database record
  my($panel, $object) = @_;

  my $primary_key = $panel->interface->structure->primary_key;
  my ($id, @ok_ids);
  if ($panel->interface->multi) {
    my @ids = $object->param($primary_key);
    foreach $id (@ids) {
      if ($id ne '') {
        $panel->interface->db_populate($id);
        push @ok_ids, $id;
      }
    }
  }
  else {
    $id = $object->param($primary_key);
    if ($id ne '') {
      $panel->interface->db_populate($id);
      @ok_ids = ($id);
    }
  }
  
  my $form = _data_form($panel, $object, 'edit');
  foreach $id (@ok_ids) {
    $form->add_element(
            'type'  => 'Hidden',
            'name'  => $primary_key,
            'value' => $id,  
        );

    ## Show creation/modification details?
    if ($panel->interface->show_history) {
      my $history = $panel->interface->history_fields($id);
      foreach my $field (@$history) {
        $form->add_element(%$field);
      }
    }
  }

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'save');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'preview');
  $form->add_element( 'type' => 'Submit', 'value' => 'Preview');
  return $form ;
}

sub select_to_delete_form {
  ### Builds a form consisting of a dropdown widget that lists all records
  ### Sends the user to a page where the record can be previewed before deletion
  my($panel, $object) = @_;
  
  my $form = _record_select($panel, $object, 'select');

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'db_action', 'value' => 'delete');
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => 'preview');
  $form->add_element( 'type' => 'Submit', 'value' => 'View Record');
  return $form ;
}

sub preview_form {
  ### Displays a record or form input as non-editable text, 
  ### and also passes the data as hidden form elements
  my($panel, $object) = @_;
  
  ## Create form  
  my $script = $object->script;
  my $form = EnsEMBL::Web::Form->new('preview', "/common/$script", 'post');

  ## get data and assemble form
  my $primary_key = $panel->interface->structure->primary_key;
  my $db_action = $object->param('db_action');
  my ($id, @ids);
  if ($panel->interface->multi) {
    @ids = $object->param($primary_key);
    foreach $id (@ids) {
      ## get data
      if ($db_action eq 'delete') { ## get record from database
        $panel->interface->db_populate($id) if $id ne '';
      }
      else { ## populate with form contents
        $panel->interface->cgi_populate($id, $object) if $id ne '';
      }
      ## add form elements
      $form->add_element(
            'type'  => 'Hidden',
            'name'  => $primary_key,
            'value' => $id,  
        );
      my $preview_fields = $panel->interface->preview_fields($id);
      my $element;
      foreach $element (@$preview_fields) {
        $form->add_element(%$element);
      }
      my $pass_fields = $panel->interface->pass_fields($id);
      foreach $element (@$pass_fields) {
        $form->add_element(%$element);
      }
    }
  }
  else {
    $id = $object->param($primary_key);
    ## get data
    if ($db_action eq 'delete') { ## get record from database
      $panel->interface->db_populate($id);
    }
    else { ## populate with form contents
      $panel->interface->cgi_populate($id, $object);
    }
    ## add form elements
    $form->add_element(
            'type'  => 'Hidden',
            'name'  => $primary_key,
            'value' => $id,  
        );
    my $preview_fields = $panel->interface->preview_fields($id);
    my $element;
    foreach $element (@$preview_fields) {
      $form->add_element(%$element);
    }
    my $pass_fields = $panel->interface->pass_fields($id);
    foreach $element (@$pass_fields) {
      $form->add_element(%$element);
    }
  }

  ## navigation elements
  $form->add_element( 'type' => 'Hidden', 'name' => 'dataview', 'value' => $db_action);
  $form->add_element( 'type' => 'Submit', 'value' => ucfirst($db_action));
  return $form ;
}

sub _data_form {
  ### Function to build a record editing form
  my($panel, $object, $name) = @_;
  
  my $script = $object->script;
  my $form = EnsEMBL::Web::Form->new('add', "/common/$script", 'post');

  ## form widgets
  my $key = $panel->interface->structure->primary_key;
  my (@widgets, $id);
  if ($name eq 'edit') {
    if ($panel->interface->multi) {
      my @ids = $object->param($key);
      foreach $id (@ids) {
        if ($id ne '') {
          push @widgets, @{$panel->interface->edit_fields($id)};
        }
      }
    }
    else {
      $id = $object->param($key);
      @widgets = @{$panel->interface->edit_fields($id)};
    }
  }
  elsif ($name eq 'add') {
    if ($panel->interface->multi > 1) {
      my $repeat = $panel->interface->multi;
      for (my $i = 0; $i < $repeat; $i++) {
        $id = 'NEW_'.$i;
        push @widgets, @{$panel->interface->edit_fields($id)};
      }
    } 
    else {
      $id = 'NEW';
      @widgets = @{$panel->interface->edit_fields($id)};
    }
  }

  foreach my $element (@widgets) {
    $form->add_element(%$element);
  }
  return $form;
}

sub _record_select {
  ### Function to build a record selection form
  my($panel, $object, $name) = @_;
  
  my $script = $object->script;
  my $form = EnsEMBL::Web::Form->new($name, "/common/$script", 'post');

  ## Format record selection
  my $multi   = $panel->interface->multi;
  my ($type, $title);
  if ($multi) {
    $type  = 'MultiSelect';
    $title = 'Select Records';
  }
  else {
    $type  = 'DropDown';
    $title = 'Select a Record';
  }
  my $select  = $panel->interface->dropdown ? 'select' : '';

  ## Get record index
  my @list = @{$panel->interface->record_list()};
  my @options;
  if ($select) {
    push @options, {'name'=>'--- Choose ---', 'value'=>''};
  }
  foreach my $entry (@list) {
    my $value = shift(@$entry);
    my $text = join(' - ', @$entry);
    push @options, {'name'=>$text, 'value'=>$value};
  }
  
  $form->add_element( 
            'type'    => $type, 
            'select'  => $select,
            'title'   => $title, 
            'name'    => $panel->interface->structure->primary_key, 
            'values'  => \@options,
          
          );
  
  return $form;
}

sub select_to_edit {
  ### Panel rendering for select_form
  my($panel, $object) = @_;
  my $html = _wrap_form($panel, 'select');
  $panel->print($html);
}

sub select_to_delete {
  ### Panel rendering for select_form
  my($panel, $object) = @_;
  my $html = _wrap_form($panel, 'select');
  $panel->print($html);
}

sub add {
  ### Panel rendering for add_form
  my($panel, $object) = @_;
  my $html = _wrap_form($panel, 'add');
  $panel->print($html);
}

sub edit {
  ### Panel rendering for edit_form
  my($panel, $object) = @_;
  my $html = _wrap_form($panel, 'edit');
  $panel->print($html);
}

sub preview {
  ### Panel rendering for preview_form
  my($panel, $object) = @_;
  my $html = _wrap_form($panel, 'preview');
  $panel->print($html);
}

sub _wrap_form {
  ### Wrapper for form rendering - adds a bordered DIV
  my ( $panel, $form ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($form)->render();
  $html .= '</div>';
  return $html;
}

sub on_success {
  ### Static panel displaying database feedback on success
  my($panel, $object) = @_;
  my $script = $object->script;
  my $html = qq(<p>Your changes were saved to the database. 
<ul>
<li><a href="/common/$script?dataview=add">Add another record</a></li>
<li><a href="/common/$script?dataview=select_to_edit">Select a record to edit</a></li>
);
  if ($panel->interface->permit_delete) {
    $html .= qq(<li><a href="/common/$script?dataview=select_to_delete">Select a record to delete</a></li>
);
  }
  $html .= '</ul>';
  $panel->print($html);
}

sub on_failure {
  ### Static panel displaying database feedback on failure
  my($panel, $object) = @_;
  my $html = qq(<p>Sorry, there was a problem saving your changes.</p>);
  $panel->print($html);
}

1;
