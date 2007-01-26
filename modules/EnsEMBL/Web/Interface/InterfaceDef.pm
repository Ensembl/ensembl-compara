package EnsEMBL::Web::Interface::InterfaceDef;

### Module for auto-creating a database interface. Methods are provided which
### allow the user to configure the behaviour of the interface, without
### having to worry about individual form elements

use strict;
use warnings;

use EnsEMBL::Web::Interface::ElementDef;
use EnsEMBL::Web::DBSQL::StructureDef;

{

my %Structure_of;

my %Data_of;
my %Multi_of;
my %Repeat_of;
my %Tainted_of;
my %PermitDelete_of;

my %Elements_of;
my %ElementOrder_of;
my %OptionColumns_of;
my %OptionOrder_of;
my %Dropdown_of;
my %RecordList_of;
my %RecordFilter_of;
my %ShowHistory_of;
my %Caption_of;

my %OnSuccess_of;
my %OnFailure_of;


sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Structure_of{$self}    = defined $params{structure} ? $params{structure} : {};

  $Data_of{$self}         = defined $params{data} ? $params{data} : {};
  $Multi_of{$self}        = defined $params{multi} ? $params{multi} : undef;
  $Repeat_of{$self}       = defined $params{repeat} ? $params{repeat} : undef;
  $Tainted_of{$self}      = defined $params{tainted} ? $params{tainted} : {};
  $PermitDelete_of{$self} = defined $params{permit_delete} ? $params{permit_delete} : undef;

  $Elements_of{$self}     = defined $params{elements} ? $params{elements} : {};
  $ElementOrder_of{$self} = defined $params{element_order} ? $params{element_order} : [];
  $OptionColumns_of{$self} = defined $params{option_columns} ? $params{option_columns} : [];
  $OptionOrder_of{$self}  = defined $params{option_order} ? $params{option_order} : undef;
  $Dropdown_of{$self}     = defined $params{dropdown} ? $params{dropdown} : undef;
  $RecordList_of{$self}   = defined $params{record_list} ? $params{record_list} : undef;
  $RecordFilter_of{$self} = defined $params{record_filter} ? $params{record_filter} : undef;
  $ShowHistory_of{$self}  = defined $params{show_history} ? $params{show_history} : undef;
  $Caption_of{$self}      = defined $params{caption} ? $params{caption} : {};

  $OnSuccess_of{$self}    = defined $params{on_success} ? $params{on_success} : '';
  $OnFailure_of{$self}    = defined $params{on_failure} ? $params{on_failure} : '';

  return $self;
}


sub structure {
  ### a
  ### Returns: E::W::DBSQL::StructureDef object
  my $self = shift;
  $Structure_of{$self} = shift if @_;
  return $Structure_of{$self};
}

sub data {
  ### a
  ### Returns: hashref (hash of hashes), consisting of one or more data records
  my $self = shift;
  $Data_of{$self} = shift if @_;
  return $Data_of{$self};
}

sub multi {
  ### a
  ### Flag to set whether the interface allows multiple record manipulation. If set to
  ### more than 1, that number of records may be added at once
  ### Returns: integer
  my $self = shift;
  $Multi_of{$self} = shift if @_;
  return $Multi_of{$self};
}

sub repeat {
  ### a
  ### Field used to add several identical records with different foreign key values 
  ### (used in healthchecks for rapid annotation)
  ### Returns: string
  my $self = shift;
  $Repeat_of{$self} = shift if @_;
  return $Repeat_of{$self};
}

sub tainted {
  ### a
  ### Returns: reference to an array of ids of records that have been changed
  my $self = shift;
  $Tainted_of{$self} = shift if @_;
  return $Tainted_of{$self};
}

sub permit_delete {
  ### a
  ### Flag to control whether user is allowed to delete records
  ### Returns: boolean - 1 if set, 0 if set to n/no (case-insensitive) or if not set
  my $self = shift;
  $PermitDelete_of{$self} = shift if @_;
  my $delete = $PermitDelete_of{$self};
  if ($delete && !($delete =~ /^n$/i || $delete =~ /^no$/i)) {
    return 1;
  }
  else {
    return 0;
  }
}

sub elements {
  ### a
  ### Returns: hashref whose values are E::W::Interface::ElementDef objects
  my $self = shift;
  $Elements_of{$self} = shift if @_;
  return $Elements_of{$self};
}

sub element_order {
  ### a
  ### Determines the order in which elements are displayed on the form
  ### Returns: arrayref
  my $self = shift;
  $ElementOrder_of{$self} = shift if @_;
  return $ElementOrder_of{$self};
}

sub option_columns {
  ### a
  ### Determines the database columns used to assemble the record labels 
  ### on the 'Select a Record' page
  ### Returns: arrayref
  my $self = shift;
  $OptionColumns_of{$self} = shift if @_;
  return $OptionColumns_of{$self};
}

sub option_order {
  ### a
  ### Determines the order in which records are displayed on the dropdown list
  ### Returns: string
  my $self = shift;
  $OptionOrder_of{$self} = shift if @_;
  return $OptionOrder_of{$self};
}


sub dropdown {
  ### a
  ### Flag to set whether the interface uses a dropdown box for selecting records,
  ### or radio buttons/checkboxes (none-dropdown style is affected by value of $Multi_of)
  ### Returns: boolean
  my $self = shift;
  $Dropdown_of{$self} = shift if @_;
  return $Dropdown_of{$self};
}


sub record_list {
  ### a
  ### Returns: array of all records, containing only the columns needed for record selection
  my ($self, $parameters) = @_;
  
  if (!$RecordList_of{$self}) {

    my $primary_key = $self->structure->primary_key;
    if (!$primary_key) {
      $self->structure->discover;
      $primary_key = $self->structure->primary_key;
    }
    my $table = $self->structure->data_adaptor->table;
    my @columns = @{$self->option_columns};
    my $order = $self->option_order;

    ## Check for record filters
    if (!$parameters && $self->record_filter) {
      $parameters = $self->record_filter;
    }

    $RecordList_of{$self} = $self->structure->data_adaptor->fetch_list($table, $primary_key, \@columns, $parameters, $order);
  }
  return $RecordList_of{$self};
}

sub record_filter {
  ### a
  ### Field(s) and value(s) on which to filter editable records
  ### Returns: hashref
  my $self = shift;
  $RecordFilter_of{$self} = shift if @_;
  return $RecordFilter_of{$self};
}

sub show_history {
  ### a
  ### Flag to control whether creation and modification details are shown
  ### Returns: boolean - 1 if set, 0 if set to n/no (case-insensitive) or if not set
  my $self = shift;
  $ShowHistory_of{$self} = shift if @_;
  my $show = $ShowHistory_of{$self};
  if ($show && !($show =~ /^n$/i || $show =~ /^no$/i)) {
    return 1;
  }
  else {
    return 0;
  }
}

sub caption {
  ### a
  ### Optional configuration of captions
  ### Returns: hash - keys should correspond to built-in interface methods, e.g. 'add', 'edit'
  my ($self, $input) = @_;
  if ($input) {
    if (ref($input) eq 'HASH') {
      while (my ($view, $caption) = each (%$input)) {
        $Caption_of{$self}{$view} = $caption;
      }
    }
    else {
      return $Caption_of{$self}{$input};
    }
  }
}

sub on_success{
  ### a
  ### Optional - action to be taken on database save success.
  ### Parameter - either a Configuration::[ObjectType]::method name or a URL
  ### Returns - hash reference
  my ($self, $action) = shift;
  if ($action) {
    if ($action =~ /::/) {
      $OnSuccess_of{$self} = {'action' => $action, 'type' => 'module'};
    }
    else {
      $OnSuccess_of{$self} = {'action' => $action, 'type' => 'url'};
    }
  }
  return $OnSuccess_of{$self};
}

sub on_failure {
  ### a
  ### Optional - action to be taken on database save failure.
  ### Parameter - either a Configuration::[ObjectType]::method name or a URL
  ### Returns - hash reference
  my ($self, $action) = shift;
  if ($action) {
    if ($action =~ /::/) {
      $OnFailure_of{$self} = {'action' => $action, 'type' => 'module'};
    }
    else {
      $OnFailure_of{$self} = {'action' => $action, 'type' => 'url'};
    }
  }
  return $OnFailure_of{$self};
}

##--------------------------------------------------------------------------------------

## Additional accessors

sub data_row {
  ### a
  ### Sets or gets a row in the $Data_of{$self} hash
  ### Parameters: record ID, record hash (optional)
  my ($self, $id, $record) = @_;
  if ($id) {
    if ($record) {
      $Data_of{$self}{$id} = $record;
    }
    return $Data_of{$self}{$id};
  }
}

sub data_value {
  ### a
  ### Sets or gets the value of a parameter in a row in the $Data_of{$self} hash
  ### Parameters: record ID, parameter name, parameter value (optional)
  ### Returns: value of parameter
  my ($self, $param) = @_;
  my $name = $param->{'name'};
  if ($name) {
    my $data = $self->data;
    my $id = $param->{'id'}; 
    my $value = $param->{'value'}; 
    my $record;
    if (!$id) {
      my @keys = keys %$data;
      $id = $keys[0];
    }
    $record = $data->{$id};
    if ($value) {
      $record->{$name} = $value;
      $Data_of{$self}{$id} = $record;
      ## Make sure record is saved
      $self->taint($id);
    }
    else {
      $value = $record->{$name};
    }
    return $value;
  }
  return undef;
}


sub element {
  ### a 
  ### Sets or gets an individual form element in the $Elements_of{$self} hash
  ### Parameters: element name, parameter hash (optional)
  my ($self, $name, $param) = @_;
  if ($name) {
    if ($param && ref($param) eq 'HASH') {
      my (%element, $label, $type, %options);
      $element{'name'} = $name;
      while (my ($k, $v) = each (%$param)) {
        if ($k eq 'type' || $k eq 'label') {
          $element{$k} = $v;
        }
        else {
          $options{$k} = $v;
        }
      }
      $element{'options'} = \%options;
      ## append as an ElementDef object
      $Elements_of{$self}{$name} = EnsEMBL::Web::Interface::ElementDef->new(\%element);
    }
    return $Elements_of{$self}{$name};
  }
}

## Other functions

sub discover {
  ### Autogenerate elements based on data structure
  my $self = shift;
  my %columns = %{$self->structure->columns};
  my $relationships = $self->structure->relationships; 
  if (%columns) {

    ## first check for lookups
    my (%lookups, %crossrefs);
    foreach my $r (@$relationships) {
      if ($r->type eq 'lookup') {
        $lookups{$r->foreign_key} = $r;
      }
      elsif ($r->type eq 'has many') {
        $crossrefs{$r->linked_key} = $r;
      }
    }

    my (%elements, @element_order);
    foreach my $key (keys %columns) {
      my ($element_type, $label, $options);
      my $name = $key;
      my $column = $columns{$key}; ## ColumnDef object
      ## set label
      $label = ucfirst($name);
      $label =~ s/_/ /g;
      my $column_type = $column->type;

      ## is it a lookup or crossref key?
      my $linked;
      foreach my $k (keys %lookups) {
        if ($k eq $name) {
          $linked = $lookups{$name};
          last;
        }
      }
      foreach my $k (keys %crossrefs) {
        if ($k eq $name) {
          ## get data from the cross table
          $linked = $crossrefs{$name};
          last;
        }
      }

      ## set widget type and options
      if ($linked ) {
        if ($linked->type eq 'lookup') {
          $element_type = 'DropDown';
          $options->{'select'} = 'select';
        }
        else {
          $element_type = 'MultiSelect';
        }
        my $table = $linked->to;
        my $columns = $linked->option_columns;
        my $order = $linked->option_order;
        my @values;
        my $results = $self->structure->data_adaptor->fetch_list($table, $name, $columns, undef, $order);
        foreach my $row (@$results) {
          my $value = shift(@$row);
          my $text = join(' - ', @$row);
          push @values, {'value'=>$value, 'name'=>$text};
        }
        $options->{'values'} = \@values;
        ## Reset label to table name
        $label = ucfirst($table);
        $label =~ s/_/ /g;
      }
      elsif ($column_type =~ /int/) {
        $element_type = 'Int';
      }
      elsif ($column_type =~ /^varchar/ || $column_type eq 'tinytext') {
        $element_type = 'String';
        if ($column_type =~ /^varchar/) {
          my $size = $column_type;
          $size =~ s/varchar\(//;  
          $size =~ s/\)//;
          $options->{'maxlength'} = $size;
        }
      }
      elsif ($column_type =~ /text/) {
        $element_type= 'Text';
      }
      elsif ($column_type =~ /^enum/ || $column_type =~ /^set/) {

        my @values;
        my $type_text = $column_type;
        if ($type_text  =~ /^enum/) {
          $element_type = 'DropDown';
          $type_text =~ s/enum\(//;
        }
        else {
          $element_type = 'MultiSelect';
          $type_text =~ s/set\(//;
        }
        $type_text =~ s/\)//;
        my @types = split(',', $type_text);
        foreach my $value (@types) {
          $value =~ s/^'//;
          $value =~ s/'$//;
          push @values, {'name'=>$value, 'value'=>$value};
        }
        $options->{'select'} = 'select';
        $options->{'values'} = \@values;
      }

      ## Record management fields should be non-editable, regardless of type
      ## and omitted from the standard widget list
      if ($name =~ /^created_|^modified_/) {
        $element_type = 'NoEdit';
      }
      else {
        push @element_order, $name;
      }
      $elements{$name} = EnsEMBL::Web::Interface::ElementDef->new({
          'name'        => $name,
          'label'       => $label,
          'type'        => $element_type,
          'options'     => $options
        });
    }
    $Elements_of{$self} = \%elements;
    $ElementOrder_of{$self} = \@element_order;
  }
}

sub customize_element {
  ### Sets an individual value of a form element in the $Elements_of{$self} hash
  ### Parameters: element name, parameter, value (optional)
  my ($self, $name, $param, $value) = @_;
  if ($name) {
    my $element = $Elements_of{$self}{$name};
    if ($param eq 'type') {
      $element->type($value);
    }
    elsif ($param eq 'label') {
      $element->label($value);
    }
    else {
      $element->option($param, $value);
    }
  }
}


sub db_populate {
  ### Populate the data hash from the database, using the ID
  ### Also gets user names from the user db, if record includes user IDs
  my ($self, $id) = @_;
  if ($id) {
    my $primary_key = $self->structure->primary_key;
    my $data = $self->structure->data_adaptor->fetch_by($primary_key, {$primary_key => $id});
    my $record = $data->{$id};

    ## Also get user names, where appropriate
    my ($user_id, $user);
    if ($self->structure->column('created_name')) {
      $user_id = $record->{'created_by'};
      $user = $self->structure->user_adaptor->find_user_by_user_id($user_id);
      if (keys %$user) {
        $record->{'created_name'} = $user->{'name'};
      } 
      else {
        $record->{'created_name'} = 'not logged';
      }
    }
    if ($self->structure->column('modified_name')) {
      $user_id = $record->{'modified_by'};
      $user = $self->structure->user_adaptor->find_user_by_user_id($user_id);
      if (keys %$user) {
        $record->{'modified_name'} = $user->{'name'};
      } 
      else {
        $record->{'modified_name'} = 'not logged';
      }
    }
    $self->data_row($id, $record);
  }
}

sub cgi_populate {
  ### Populate the data hash from the CGI parameters
  my ($self, $id, $object) = @_;
  return unless $id;
  my $record = $self->data_row($id) || {};

=pod
  if ($id eq 'NEW') {
    $self->taint($id);
  } 
=cut

  my @parameters = $object->param();
  foreach my $param (@parameters) {
    my $param_name = $param;
    if ($self->multi) {
      ## only include parameters for this record!
      if ($param =~ /_$id$/) {
        $param_name =~ s/_$id//;
      }
      else {
        next;
      } 
    }
=pod
    ## taint the record if it exists and is being updated
    if ($record->{$param_name} && 
            ($record->{$param_name} ne $object->param($param))) {
      $self->taint($id);
    }
=cut
    ## deal with multiple-value parameters!
    my @param_check = $object->param($param);
    if (scalar(@param_check) > 1) {
      $record->{$param_name} = [$object->param($param)];
    }
    else {
      $record->{$param_name} = $object->param($param);
    }
  }
  $self->data_row($id, $record);
}

sub edit_fields {
  ### Returns editable fields as form element parameters
  my ($self, $id) = @_;
  my $parameters = [];
  my $record;
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  if ($id) { ## populate widgets from Data_of{$self}
    $record = $self->data_row($id);
  }
  foreach my $field (@$element_order) {
    my $name = $field;
    my $element = $elements->{$name};
    ## rename if editing multiple elements
    if ($id && $self->multi) {
      $name = $name.'_'.$id;
      $element->name($name);
    }

    my %param = %{$element->widget};
    if ($record && !$param{'value'}) {
      $param{'value'} = $record->{$field};
    }
    push @$parameters, \%param;
    ## pass non-editable elements as additional hidden fields
    if ($element->type eq 'NoEdit') {
      my %hidden = %{$element->hide};
      if ($record) {
        $hidden{'value'} = $param{'value'};
      }
      push @$parameters, \%hidden;
    }
  } 
  return $parameters;
}

sub preview_fields {
  ### Returns fields as non-editable text
  my ($self, $id) = @_;
  my $parameters = [];
  my $record;
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  if ($id) { ## populate widgets from Data_of{$self}
    $record = $self->data_row($id);
  }
  foreach my $field (@$element_order) {
    my $name = $field;
    my $element = $elements->{$name};
    next if $element->type eq 'Information';
    ## rename if editing multiple elements
    if ($id && $self->multi) {
      $element->name($name.'_'.$id);
    }
    my %param = %{$element->preview};
    if ($record) {
      my $var = $record->{$field};
      if ($element->type eq 'DropDown' || $element->type eq 'MultiSelect') {
        my @values = @{$param{'values'}};
        my %lookup;
        foreach my $option (@values) {
          $lookup{$option->{'value'}} = $option->{'name'};
        }
        if (ref($var) eq 'ARRAY') {
          my @readable;
          foreach my $key (@$var) {
            if ($key ne '') {
              push @readable, $lookup{$key};
            }
          }
          $param{'value'} = join(', ', @readable);
        }
        else {
          $param{'value'} = $lookup{$var};
        }
      }
      else {
        $param{'value'} = $var;
      }
    }
    push @$parameters, \%param;
  } 
  return $parameters;
}

sub pass_fields {
  ### Returns editable fields as hidden element parameters
  my ($self, $id) = @_;
  my $parameters = [];
  my $record;
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  if ($id) { ## populate widgets from Data_of{$self}
    $record = $self->data_row($id);
  }
  foreach my $field (@$element_order) {
    my $name = $field;
    my $element = $elements->{$name};
    next if $element->type eq 'Information';
    next if $element->type eq 'SubHeader';
    next if $element->type eq 'Information';
    ## rename if editing multiple elements
    if ($id && $self->multi) {
      $element->name($name.'_'.$id);
    }
    my %param = %{$element->hide};
    if ($record) {
      my $var = $record->{$field};
      if (ref($var) eq 'ARRAY') {
        foreach my $v (@$var) {
          if ($v ne '') {
            my %temp = %param;
            $temp{'value'} = $v;
            push @$parameters, \%temp;
          }
        }
        next;
      }
      else {
        $param{'value'} = $var;
      }
    }
    push @$parameters, \%param;
  } 
  return $parameters;
}

sub history_fields {
  ### Returns a set of standard non-editable fields used to track record modification
  my ($self, $id) = @_;
  my $parameters = [];
  my $record;
  my $elements = $self->elements;
  my @history = ('created_name', 'created_at', 'modified_name', 'modified_at');
  if ($id) { ## populate widgets from Data_of{$self}
    $record = $self->data_row($id);
  }
  foreach my $field (@history) {
    my $name = $field;
    my $element = $elements->{$name};
    ## rename if editing multiple elements
    if ($id && $self->multi) {
      $element->name($name.'_'.$id);
    }
    if ($element) {
      my %param = %{$element->preview};
      if ($record) {
        $param{'value'} = $record->{$field};
      }
      if ($name eq 'created_name') {
        $param{'label'} = 'Created by';
      }
      elsif ($name eq 'modified_name') {
        $param{'label'} = 'Modified by';
      }
      push @$parameters, \%param;
    }
  } 
  return $parameters;
}

sub taint {
  ### Marks a record for an update. Tainted
  ### records are updated in the database when the Record's save method
  ### is called.
  my ($self, $id) = @_;
  $self->tainted->{$id} = 1;
}


sub DESTROY {
  ### d
  my $self = shift;
  delete $Structure_of{$self};

  delete $Data_of{$self};
  delete $Multi_of{$self};
  delete $Tainted_of{$self};
  delete $PermitDelete_of{$self};

  delete $Elements_of{$self};
  delete $ElementOrder_of{$self};
  delete $OptionColumns_of{$self};
  delete $OptionOrder_of{$self};
  delete $Dropdown_of{$self};
  delete $RecordList_of{$self};
  delete $ShowHistory_of{$self};
  delete $Caption_of{$self};

  delete $OnSuccess_of{$self};
  delete $OnFailure_of{$self};

}

}

1;
