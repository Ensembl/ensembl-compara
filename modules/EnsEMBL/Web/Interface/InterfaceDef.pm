package EnsEMBL::Web::Interface::InterfaceDef;

### Module for auto-creating a database interface. Methods are provided which
### allow the user to configure the behaviour of the interface, without
### having to worry about individual form elements

use strict;
use warnings;

use EnsEMBL::Web::Data;
use EnsEMBL::Web::Interface::ElementDef;

{

my %Data_of;
my %ExtraData_of;
my %Repeat_of;
my %PermitDelete_of;
my %ScriptName_of;

my %Elements_of;
my %ElementOrder_of;
my %OptionColumns_of;
my %OptionOrder_of;
my %Dropdown_of;
my %RecordFilter_of;
my %ShowHistory_of;

my %PanelStyle_of;
my %Caption_of;
my %PanelHeader_of;
my %PanelContent_of;
my %PanelFooter_of;

my %OnSuccess_of;
my %OnFailure_of;
my %DefaultView_of;


sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Data_of{$self}         = defined $params{data} ? $params{data} : {};
  $ExtraData_of{$self}    = defined $params{extra_data} ? $params{extra_data} : {};
  $Repeat_of{$self}       = defined $params{repeat} ? $params{repeat} : undef;
  $PermitDelete_of{$self} = defined $params{permit_delete} ? $params{permit_delete} : undef;

  $Elements_of{$self}      = defined $params{elements} ? $params{elements} : {};
  $ElementOrder_of{$self}  = defined $params{element_order} ? $params{element_order} : [];
  $OptionColumns_of{$self} = defined $params{option_columns} ? $params{option_columns} : [];
  $OptionOrder_of{$self}   = defined $params{option_order} ? $params{option_order} : undef;
  $Dropdown_of{$self}      = defined $params{dropdown} ? $params{dropdown} : undef;
  $RecordFilter_of{$self}  = defined $params{record_filter} ? $params{record_filter} : undef;
  $ShowHistory_of{$self}   = defined $params{show_history} ? $params{show_history} : undef;

  $PanelStyle_of{$self}   = defined $params{panel_style} ? $params{panel_style} : '';
  $Caption_of{$self}      = defined $params{caption} ? $params{caption} : {};
  $PanelHeader_of{$self}  = defined $params{panel_header} ? $params{panel_header} : {};
  $PanelContent_of{$self} = defined $params{panel_content} ? $params{panel_content} : {};
  $PanelFooter_of{$self}  = defined $params{panel_footer} ? $params{panel_footer} : {};

  $OnSuccess_of{$self}    = defined $params{on_success} ? $params{on_success} : '';
  $OnFailure_of{$self}    = defined $params{on_failure} ? $params{on_failure} : '';
  $DefaultView_of{$self}  = defined $params{default_view} ? $params{default_view} : '';

  $ScriptName_of{$self}   = defined $params{script_name} ? $params{script_name} : '';

  return $self;
}

sub script_name {
  ### a
  my $self = shift;
  $ScriptName_of{$self} = shift if @_;
  return $ScriptName_of{$self};
}

sub data {
  ### a
  ### Returns: An Object::Data::[record or table name] object
  my $self = shift;
  $Data_of{$self} = shift if @_;
  return $Data_of{$self};
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
  $ElementOrder_of{$self} = \@_ if @_;
  return $ElementOrder_of{$self};
}

sub option_columns {
  ### a
  ### Determines the database columns used to assemble the record labels 
  ### on the 'Select a Record' page
  ### Returns: arrayref
  my $self = shift;
  $OptionColumns_of{$self} = \@_ if @_;
  return $OptionColumns_of{$self};
}

sub option_order {
  ### a
  ### Determines the order in which records are displayed on the dropdown list
  ### Returns: string
  my $self = shift;
  $OptionOrder_of{$self} = \@_ if @_;
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

sub record_filter {
  ### a
  ### Field(s) and value(s) on which to filter editable records
  ### Returns: hashref
  my $self = shift;
  $RecordFilter_of{$self} = \@_ if @_;
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

sub panel_style {
  ### a
  ### Returns: string
  my $self = shift;
  $PanelStyle_of{$self} = shift if @_;
  return $PanelStyle_of{$self};
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

sub panel_header {
  ### a
  ### Optional configuration of panel headers
  ### Returns: hash - keys should correspond to available interface methods, e.g. 'add', 'edit'
  my ($self, $input) = @_;
  if ($input) {
    if (ref($input) eq 'HASH') {
      while (my ($view, $header) = each (%$input)) {
        $PanelHeader_of{$self}{$view} = $header;
      }
    }
    else {
      return $PanelHeader_of{$self}{$input};
    }
  }
}

sub panel_content {
  ### a
  ### Optional configuration of panel content (normally only needed for success/failure
  ### Returns: hash - keys should correspond to available interface methods, e.g. 'on_success'
  my ($self, $input) = @_;
  if ($input) {
    if (ref($input) eq 'HASH') {
      while (my ($view, $content) = each (%$input)) {
        warn "VIEW $view = $content";
        $PanelContent_of{$self}{$view} = $content;
      }
    }
    else {
      return $PanelContent_of{$self}{$input};
    }
  }
}

sub panel_footer {
  ### a
  ### Optional configuration of panel footers
  ### Returns: hash - keys should correspond to available interface methods, e.g. 'add', 'edit'
  my ($self, $input) = @_;
  if ($input) {
    if (ref($input) eq 'HASH') {
      while (my ($view, $footer) = each (%$input)) {
        $PanelFooter_of{$self}{$view} = $footer;
      }
    }
    else {
      return $PanelFooter_of{$self}{$input};
    }
  }
}

sub on_success{
  ### a
  ### Optional - action to be taken on database save success.
  ### Parameter - either a Configuration::[ObjectType]::method name or a URL
  ### Returns - hash reference
  my ($self, $action) = @_;
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
  my ($self, $action) = @_;
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

sub default_view {
  ### a
  ### Returns: string
  my $self = shift;
  $DefaultView_of{$self} = shift if @_;
  return $DefaultView_of{$self};
}

##--------------------------------------------------------------------------------------

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

sub extra_data {
  ### a 
  my ($self, $name, $value) = @_;
  if ($name) {
    my $extras = $ExtraData_of{$self};
    if ($value) {
      $extras->{$name} = $value;
    }
    else {
      $extras->{$name} = '';
    }
    $ExtraData_of{$self} = $extras;
    return $ExtraData_of{$self}{$name};
  }
  return $ExtraData_of{$self};
}

## Other functions

sub discover {
  ### Autogenerate elements based on data structure
  my $self = shift;
  my %fields = %{ $self->data->get_all_fields };

  my (%elements, @element_order);
  foreach my $field (keys %fields) {
    my ($element_type, $options);
    ## set label
    my $label = ucfirst($field);
    $label =~ s/_/ /g;
    my $data_type = $fields{$field};

    if ($data_type =~ /^int/) {
      $element_type = 'Int';
    } elsif ($data_type eq 'text' || $data_type eq 'mediumtext') {
      $element_type= 'Text';
    } elsif ($data_type =~ /^(enum|set)\((.*)\)/) {

      if ($1 eq 'enum') {
        $element_type = 'DropDown';
      } else {
        $element_type = 'MultiSelect';
      }

      my @values = map {
        $_ =~ s/'//g;
        { 'name' => $_, 'value' => $_ };
      } split ',', $2;

      $options->{'select'} = 'select';
      $options->{'values'} = \@values;
    } else {
      $element_type = 'String';
      if ($data_type =~ /^varchar/) {
        my $size = $data_type;
        $size =~ s/varchar\(//;
        $size =~ s/\)//;
        $options->{'maxlength'} = $size;
      }
    }
    ## Record management fields should be non-editable, regardless of type,
    ## and omitted from the standard widget list
    if ($field =~ /^created_|^modified_/) {
      $element_type = 'NoEdit';
    }
    else {
      push @element_order, $field;
    }
    $elements{$field} = EnsEMBL::Web::Interface::ElementDef->new({
      'name'        => $field,
      'label'       => $label,
      'type'        => $element_type,
      'options'     => $options
    });
  }

=pod

  ## Also get possible 'belongs to' and 'has many' fields as well
  ## 'Belongs to' are dropdown by default
  my $belongs_to = $self->data->get_belongs_to;
  if ($belongs_to) {
    foreach my $class (@$belongs_to) {
      my ($key, $element) = $self->_create_relational_element('DropDown', $class);
      if ($element) {
        $elements{$element->name} = $element;
        push @element_order, $element->name;
        $self->data->add_queriable_field({ name => $key, type => 'int'});
      }
    }
  }
  ## 'Has many' are multiple checkboxes by default

  my $has_many = $self->data->get_has_many;
  if ($has_many) {
    foreach my $class (@$has_many) {
      my ($key, $element) = $self->_create_relational_element('MultiSelect', $class);
      if ($element) {
        $elements{$element->name} = $element;
        push @element_order, $element->name;
        $self->data->add_queriable_field({ name => $key, type => 'int'});
      }
    }
  }
=cut
  $Elements_of{$self} = \%elements;
  $ElementOrder_of{$self} = \@element_order;
}

sub _create_relational_element {
  my ($self, $type, $class) = @_;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    my $object = $class->new();
    my $name = $object->get_primary_key;
    my @namespace = split(/::/, $class);
    my $label = $namespace[-1];
    $label =~ s/([a-z])([A-Z])/$1 $2/g; ## insert spaces into camel-case names
  
    my ($options, @option_values);    
    if ($type eq 'DropDown') {
      $options->{'select'} = 'select';
      @option_values = ({'name'=> '--- Select ---', 'value' => ''});
    }
    else {
      @option_values = ();
    }

    ## Get default values
    my $primary_key;
    my $objects = EnsEMBL::Web::Data::find_all($class);
    foreach my $obj (@$objects) {
      push @option_values, {'name'=> $obj->id, 'value' => $obj->id};
      $primary_key = $obj->get_primary_key;
    }
    $options->{'values'} = \@option_values;

    my $element = EnsEMBL::Web::Interface::ElementDef->new({
    'name'        => $name,
    'label'       => $label,
    'type'        => $type,
    'relational'  => 1,
    'options'     => $options
    });
    return ($primary_key, $element);
  }
  else {
    return undef;
  }
}

sub customize_element {
  ### Sets one or more parameters of a form element in the $Elements_of{$self} hash
  ### Parameters: element name, hash of parameters to update
  my ($self, $name, %params) = @_;
  if ($name) {
    my $element = $Elements_of{$self}{$name};
    while (my ($param, $value) = each (%params)) {
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
}

sub record_list {
  ### a
  ### Returns: array of data objects of the same type as the parent
  my $self = shift;
  my $records = [];

  ## Get data
  my $request = EnsEMBL::Web::DBSQL::SQL::Request->new();
  $request->set_action('select');
  $request->set_table($self->data->get_adaptor->get_table);
  if ($self->record_filter) {
    $request->add_where(@{$self->record_filter});
  }
  if ($self->data->get_data_field_name) {
    $request->add_where('type', $self->data->__type);
  }
  $request->set_index_by($self->data->get_primary_key);
  my $result = $self->data->get_adaptor->find_many($request);

  foreach my $id (keys %{$result->get_result_hash}) {
    my $class = ref($self->data);
    my $record = $class->new({id=>$id});
    push @$records, $record;
  }

  return $records;
}

sub cgi_populate {
  ### Utility function to populate a data object from CGI parameters
  ### instead of from the database
  my ($self, $object) = @_;
  my $data = $self->data;
  ## restrict ourselves to defined fields
  foreach my $field (keys %{ $data->get_all_fields }) {
    next unless grep {$_ eq $field} $object->param();
    my $value = (scalar(@{[$object->param($field)]}) > 1)
                ? [$object->param($field)]
                : $object->param($field);
    $data->$field($value);
  }

  ## Check for extra arbitrary data fields
  my %extras = %{$self->extra_data};
  if (keys %extras) {
    foreach my $key (keys %extras) {
      my @extra_check = $object->param($key);
      if (scalar(@extra_check) > 1) {
        $self->extra_data($key, [$object->param($key)]);
      }
      else {
        $self->extra_data($key, $object->param($key));
      }
    }
  }
}


sub edit_fields {
  ### Returns editable fields as form element parameters
  my ($self, $object) = @_;
  my $parameters = [];
  my $data = $self->data;
  my $dataview = $object->param('dataview');
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  ## populate widgets from Data_of{$self}
  foreach my $field (@$element_order) {
    my $element = $elements->{$field};
    my %param = %{$element->widget};
    ## File widgets behave differently depending on user action
    if ($element->type eq 'File' && $dataview ne 'add') {
      $param{'type'} = 'NoEdit';
    }
    ## Set field values
    if (ref($data) && !$param{'value'}) {
      ## Set value from data object, if possible
      $param{'value'} = $data->$field;
      ## Make sure checkboxes are checked
      if ($param{'type'} eq 'CheckBox' && $param{'value'}) {
        $param{'checked'} = 'yes';
      }
      ## Fall-back - set default value if there is one
      if (!$param{'value'} && $param{'default'}) {
        $param{'value'} = $param{'default'};
      }
    }
    ## deal with multi-value fields
    #if ($param{'value'} && ref($param{'value'}) eq 'ARRAY') {
    #  foreach my $v (@{$param{'value'}}) {
    #    warn "VALUE $v";
    #    my %multi_param = %param;
    #    $multi_param{'value'} = $v;
    #    push @$parameters, \%multi_param;
    #  }
    #}
    #else {
      push @$parameters, \%param;
    #}
    ## pass non-editable elements as additional hidden fields
    if ($element->type eq 'NoEdit') {
      my %hidden = %{$element->hide};
      if (ref $data) {
        $hidden{'value'} = $param{'value'};
      }
      ## deal with multi-value fields
      if ($hidden{'value'} && ref($hidden{'value'}) eq 'ARRAY') {
        foreach my $v (@{$param{'value'}}) {
          my %multi_hidden = %hidden;
          $multi_hidden{'value'} = $v;
          push @$parameters, \%multi_hidden;
        }
      }
      else {
        push @$parameters, \%hidden;
      }
      if ($param{'value'} =~ m#\<#) {
        $param{'value'} = '<pre>'.$param{'value'}.'</pre>';
      }
    }
  } 
  ## Add extra data
  my %extras = %{$self->extra_data};
  if (keys %extras) {
    while (my($k, $v) = each (%extras)) {
      if ($v && ref($v) eq 'ARRAY') {
        foreach my $m (@$v) {
          my %multi_ex = ('name'=>$k, 'type'=>'Hidden', 'value'=>$m);
          push @$parameters, \%multi_ex;
        }
      }
      else {
        my %ex = ('name'=>$k, 'type'=>'Hidden', 'value'=>$v);
        push @$parameters, \%ex;
      }   
    }
  }

  ## Force passing of _referer parameter
  if ($object->param('_referer')) {
    push @$parameters, {'type'=>'Hidden', 'name'=>'_referer', 'value'=> $object->param('_referer')};
  }

  return $parameters;
}

sub preview_fields {
  ### Returns fields as non-editable text
  my ($self, $id, $object) = @_;
  my $parameters = [];

  my $data = $self->data;
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  foreach my $field (@$element_order) {
    my $element = $elements->{$field};
    next if $element->type eq 'Information';
    next if $element->type eq 'Hidden';
    my %param = %{$element->preview};
    if (ref $data) {
      my $var = $data->$field;
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
      elsif ($element->type eq 'Text' && $var =~ m#</|/>#) {
        $param{'value'} = '<pre>'.$var.'</pre>';
      }
      else {
        $param{'value'} = $var;
      }
    }
    push @$parameters, \%param;
  } 
  ## Add extra data
  my %extras = %{$self->extra_data};
  if (keys %extras) {
    while (my($k, $v) = each (%extras)) {
      my %ex = ('name'=>$k, 'type'=>'Hidden', 'value'=>$v);
      push @$parameters, \%ex;  
    }
  }

  return $parameters;
}

sub pass_fields {
  ### Returns editable fields as hidden element parameters
  my ($self, $id) = @_;
  my $parameters = [];
  my $data = $self->data;
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  foreach my $field (@$element_order) {
    my $name = $field;
    my $element = $elements->{$name};
    next if $element->type eq 'Information';
    next if $element->type eq 'SubHeader';
    next if $element->type eq 'Information';
    my %param = %{$element->hide};
    if (ref $data) {
      my $var = $data->$field;
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
  my $data = $self->data;
  my $elements = $self->elements;
  my $belongs_to = $self->data->get_belongs_to;

  my @actions = ('created', 'modified');
  my ($name, $element);
  foreach my $action (@actions) {
    ## do user
    $name = $action.'_by';
    $element = $elements->{$name};
    if ($element) {
      my %param;
      %param = %{$element->preview};
      $param{'label'} = ucfirst($action).' by';
      push @$parameters, \%param;
    }

    ## do date
    $name = $action.'_at';
    my $element = $elements->{$name};
    if ($element) {
      my %param;
      %param = %{$element->preview};
      if (ref $data) {
        $param{'value'} = $data->$name;
      }
      push @$parameters, \%param;
    }
  } 

  return $parameters;
}

sub format_date {
  ## Utility function to return dates in various formats
  my ($self, $date, $style) = @_;
  my ($formatted, $year, $month, $day, $hour, $min, $sec);

  if ($date eq 'now') {
    my @time = localtime();
    $year = $time[5] + 1900;
    $month = sprintf('%02d', $time[4] + 1);
    $day = sprintf('%02d', $time[3]);
  }
  else {
  }

  if ($style && $style eq 'calendar') {
    $formatted = "$day/$month/$year";
  }
  else {
    $formatted = "$year-$month-$day";
  }

  return $formatted;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Data_of{$self};
  delete $ExtraData_of{$self};
  delete $Repeat_of{$self};
  delete $PermitDelete_of{$self};

  delete $Elements_of{$self};
  delete $ElementOrder_of{$self};
  delete $OptionColumns_of{$self};
  delete $OptionOrder_of{$self};
  delete $Dropdown_of{$self};
  delete $ShowHistory_of{$self};

  delete $PanelStyle_of{$self};
  delete $Caption_of{$self};
  delete $PanelHeader_of{$self};
  delete $PanelContent_of{$self};
  delete $PanelFooter_of{$self};

  delete $OnSuccess_of{$self};
  delete $OnFailure_of{$self};
  delete $ScriptName_of{$self};

}

}

1;
