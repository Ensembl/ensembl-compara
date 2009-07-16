package EnsEMBL::Web::Interface;

### Module for auto-creating a database interface. Methods are provided which
### allow the user to configure the behaviour of the interface, without
### having to worry about individual form elements

use strict;
use warnings;

use Class::Std;
use Data::Dumper;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data;
use EnsEMBL::Web::Interface::Element;

{

my %Data              :ATTR(:get<data> :set<data>);
my %ExtraData         :ATTR(:get<extra_data> :set<extra_data>);
my %Repeat            :ATTR(:get<repeat> :set<repeat>);
my %NoPreview         :ATTR(:get<no_preview> :set<no_preview>);
my %PermitDelete      :ATTR(:get<permit_delete> :set<permit_delete>);
my %ScriptName        :ATTR(:get<script_name> :set<script_name>);

my %Caption           :ATTR(:get<caption> :set<caption>);
my %Elements          :ATTR(:get<elements> :set<elements>);
my %ElementOrder      :ATTR(:get<element_order> :set<element_order>);
my %ShowHistory       :ATTR(:get<show_history> :set<show_history>);
my %LandingPage       :ATTR(:get<landing_page> :set<landing_page>);

my %RecordFilter      :ATTR(:get<record_filter> :set<record_filter>);
my %OptionColumns     :ATTR(:get<option_columns> :set<option_columns>);
my %OptionOrder       :ATTR(:get<option_order> :set<option_order>);
my %Dropdown          :ATTR(:get<dropdown> :set<dropdown>);


sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_script_name($ENV{'ENSEMBL_TYPE'}.'/'.$ENV{'ENSEMBL_ACTION'});
}

sub script_name {
  ### a
  my $self = shift;
  $self->set_script_name(shift) if @_;
  return $self->get_script_name;
}

sub data {
  ### a
  ### Returns: An Object::Data::[record or table name] object
  my $self = shift;
  $self->set_data(shift) if @_;
  return $self->get_data;
}

sub extra_data {
  ### a 
  my ($self, $name, $value) = @_;
  if ($name) {
    my $hashref = $self->get_extra_data;
    if ($value) {
      $hashref->{$name} = $value;
    }
    else {
      $hashref->{$name} = '';
    }
    $self->set_extra_data($hashref);
    return $hashref->{$name};
  }
  return $self->get_extra_data;
}

sub repeat {
  ### a
  ### Field used to add several identical records with different foreign key values
  ### (used in healthchecks for rapid annotation)
  ### Returns: string
  my $self = shift;
  $self->set_repeat(shift) if @_;
  return $self->get_repeat;
}

sub permit_delete {
  ### a
  ### Flag to control whether user is allowed to delete records
  my $self = shift;
  $self->set_permit_delete(shift) if @_;
  return $self->get_permit_delete;
}

sub no_preview {
  ### a
  ### Flag to control whether interface offers record preview
  my $self = shift;
  $self->set_no_preview(shift) if @_;
  return $self->get_no_preview;
}

sub caption {
  ### a
  ### Optional configuration of captions
  ### Returns: hash - keys should correspond to built-in interface methods, e.g. 'add', 'edit'
  my ($self, $input) = @_;
  if ($input) {
    if (ref($input) eq 'HASH') {
      my $hashref = $self->get_caption;
      while (my ($view, $caption) = each (%$input)) {
        $hashref->{$view} = $caption;
      }
      $self->set_caption($hashref);
    }
    else {
      #return $self->get_caption->{$input};
    }
  }
}

sub elements {
  ### a
  ### Returns: hashref whose values are E::W::Interface::Element objects
  my $self = shift;
  return $self->get_elements;
}

sub named_element {
  my ($self, $name, $element) = @_;
  return unless $name;
  my $elements = $self->get_elements;
  if ($element) {
    $elements->{$name} = $element;
    $self->set_elements($elements);
  }
  else {
    $element = $elements->{$name};
  }
  return $element;
}

sub element_order {
  ### a
  ### Determines the order in which elements are displayed on the form
  ### Returns: array
  my $self = shift;
  $self->set_element_order(shift) if @_;
  return $self->get_element_order;
}

sub show_history {
  ### a
  ### Flag to control whether creation and modification details are shown
  ### Returns: boolean - 1 if set, 0 if set to n/no (case-insensitive) or if not set
  my $self = shift;
  $self->set_show_history(shift) if @_;
  return $self->get_show_history;
}

sub record_filter {
  ### a
  ### Field(s) and value(s) on which to filter editable records
  ### Returns: hash
  my $self = shift;
  $self->set_record_filter(shift) if @_;
  return $self->get_record_filter;
}

sub option_columns {
  ### a
  ### Determines the database columns used to assemble the record labels
  ### on the 'Select a Record' page
  ### Returns: array
  my $self = shift;
  $self->set_option_columns(shift) if @_;
  return $self->get_option_columns;
}

sub option_order {
  ### a
  ### Determines the order in which records are displayed on the dropdown list
  ### Returns: arrayref
  my $self = shift;
  $self->set_option_order(shift) if @_;
  return $self->get_option_order;
}

sub dropdown {
  ### a
  ### Flag to set whether the interface uses a dropdown box for selecting records,
  ### or radio buttons/checkboxes
  ### Returns: boolean
  my $self = shift;
  $self->set_dropdown(shift) if @_;
  return $self->get_dropdown;
}

##--------------------------------------------------------------------------------------

sub element {
  ### a 
  my ($self, $name, $param) = @_;
  return unless $name;
  my $element;
  if ($param && ref($param) eq 'HASH') {
    $element = EnsEMBL::Web::Interface::Element->new;
    while (my ($k, $v) = each (%$param)) {
      if ($k eq 'name' || $k eq 'type' || $k eq 'label') {
        $element->$k($v);
      }
      else {
        $element->option($k,$v);
      }
    }
    ## Set mandatory fields if still empty
    unless ($element->type) {
      $element->type('String');
    }
    unless ($element->label) {
      my $label = ucfirst($name);
      $label =~ s/_/ /g;
      $element->label($label);
    }
    $self->named_element($name, $element);
  }
  else {
    $element = $self->named_element($name);
  }
  return $element;
}

sub modify_element {
  my ($self, $name, $param) = @_;
  return unless $name;
  return unless $param && ref($param) eq 'HASH';
  my $element = $self->named_element($name);
  return unless $element;
  while (my ($k, $v) = each (%$param)) {

    if ($k eq 'name' || $k eq 'type' || $k eq 'label') {
      $element->$k($v);
    }
    else {
      $element->option($k,$v);
    }
  }
}



## Other functions

sub discover {
  ### Autogenerate elements based on data structure
  ### N.B. this sets up some default values that can be customised later
  my $self = shift;
  
  my %fields = %{ $self->data->get_all_fields };
  $fields{'id'} = 'int';
  my %hasa_fields = %{ $self->data->hasa_relations };

  my (%elements, @element_order);
  foreach my $field (keys %fields) {
    
    my ($element_type, $param);
    $param->{'name'} = $field;
    ## set label
    my $label = ucfirst($field);
    $label =~ s/_/ /g;
    $param->{'label'} = $label;
    my $data_type = $fields{$field};

    if ($field =~ /password/) {
      $element_type = 'Password';
    } 
    elsif ($data_type =~ /^int/) {
      $element_type = 'Int';
    } 
    elsif ($data_type eq 'text' || $data_type eq 'mediumtext') {
      $element_type= 'Text';
    } 
    elsif ($data_type =~ /^(enum|set)\((.*)\)/) {

      if ($1 eq 'enum') {
        $element_type = 'DropDown';
      } else {
        $element_type = 'MultiSelect';
      }

      my @values = map {
        $_ =~ s/'//g;
        { 'name' => $_, 'value' => $_ };
      } split ',', $2;

      $param->{'select'} = 'select';
      $param->{'values'} = \@values;
    } else {
      $element_type = 'String';
      if ($data_type =~ /^varchar/) {
        my $size = $data_type;
        $size =~ s/varchar\(//;
        $size =~ s/\)//;
        $param->{'maxlength'} = $size;
      }
    }

    ## Do any has_a fields, which are added as queriable fields by Data.pm
    if (my $class = $hasa_fields{$field}) {
      $element_type = 'DropDown';
      $param->{'select'} = 'select';
      my $lookup = $class->get_lookup_values;
      if ($lookup && ref($lookup) eq 'ARRAY') {
        $param->{'values'} = $self->create_select_values($lookup);
      }
      else {
        $param->{'values'} = [];
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
    $param->{'type'} = $element_type;
    $self->element($field, $param);
  }

  my %has_many = %{ $self->data->hasmany_relations };
  while (my ($field, $classes) = each (%has_many)) {
    my $rel_class = $classes->[1];
    if ($rel_class) {
      my $lookup = $rel_class->get_lookup_values;
      my $select = scalar(@$lookup) > 20 ? 'select' : '';
      my $param = {
        'name'    => $field,
        'label'   => ucfirst($field),
        'type'    => 'MultiSelect',
        'select'  => $select,
        'values'  => $self->create_select_values($lookup),
      };
      if ($select) {
        $param->{'size'} = 10;
        $param->{'notes'} = 'Use the CTL button to select multiple items';
      }
      $self->element($field, $param);
      push @element_order, $field;
    }
  }

  $self->elements(\%elements);
  $self->element_order(@element_order);
}

sub create_select_values {
  my ($self, $lookup) = @_;
  my $values = [];
  foreach my $record (@$lookup) {
    my $order = $record->{'order'};
    my $field;
    if ($order) {
      $field = $order->[0];
    }
    else {
      my @fields = keys %{$record->{'lookups'}};
      $field = $fields[0];
    }
    push @$values, {'value' => $record->{'id'}, 'name' => $record->{'lookups'}{$field}}; 
  }
  return $values;
}

sub configure {
  ### Determines which interface component/command is required by this step
  my ($self, $webpage, $object) = @_;

  ## Make interface available from components, by attaching to Object
  $object->interface($self);
  my $type      = $ENV{'ENSEMBL_TYPE'};
  my $data      = $ENV{'ENSEMBL_ACTION'};
  my $function  = $ENV{'ENSEMBL_FUNCTION'} || 'Display';
  #warn "@@@ $type / $data / $function";

  if ($function eq 'Save' || $function eq 'Delete') { ## Process database command
    ## Do we have a custom interface module, or shall we use the generic one?
    my $class = 'EnsEMBL::Web::Command::'.$type.'::Interface::'.$data.$function;
    if (!EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
      $class = 'EnsEMBL::Web::Command::Interface::'.$function;
    }
    if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
      my $command = $class->new({'object' => $object, 'webpage' => $webpage});
      $command->process;
    }
    else {
      warn "CANNOT USE COMMAND MODULE $class";
    }
  }
  else {
    ## Do we have a custom interface module, or shall we use the generic one?
    my $class   = 'EnsEMBL::Web::Component::'.$type.'::Interface::'.$data.$function;
    if (!EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
      $class = 'EnsEMBL::Web::Component::Interface::'.$function;
    }
    my $key     = lc($type);
    my $panel = $webpage->page->content->panel('main');
    $panel->add_components($key, $class);
    $webpage->render;
  }
}


sub record_list {
  ### a
  ### Returns: array of data objects of the same type as the parent
  my ($self, $criteria) = @_;
  my @records;

  ## Get data
  if (ref($self->data) =~ /User/) {
    my $method = lc($ENV{'ENSEMBL_ACTION'}).'s';
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
    @records = $user->$method;
  }
  else {
    if ($criteria) {
      @records = $self->data->search($criteria);
    }
    else {
      @records = $self->data->find_all;
    }
  }

  ## Now sort it (can't do this in MySQL owing to 'data' field)
  my @sort = $self->option_order;
  ## Build a default sort order if there isn't one configured
  unless (@sort && $sort[0]) {
    foreach my $col (@{$self->option_columns}) {
      push @sort, [$col, 'ASC'];
    }
  }
  if (@sort) {
    sort {
      ## Funky custom sort function!
      foreach my $option (@sort) {
        my $field = $option->[0];
        next unless $field;
        my $dir = $option->[1] || 'ASC';
        if ($dir eq 'DESC') {
          my $result = lc($b->$field) cmp lc($a->$field);
          return $result if $result; 
        }
        else {
          my $result = lc($a->$field) cmp lc($b->$field);
          return $result if $result; 
        }
      }
      ## End custom sort function
    } @records;
  }
  else {
    return @records;
  }
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
  my $extras = $self->extra_data;
  if ($extras) {
    foreach my $key (keys %$extras) {
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

sub relational_element {
}


sub edit_fields {
  ### Returns editable fields as form element parameters
  my ($self, $object) = @_;
  my $parameters = [];
  my $data = $self->data;
  my $dataview = $ENV{'ENSEMBL_FUNCTION'};
  my $element_order = $self->element_order;
  my %has_many = %{ $self->data->hasmany_relations };

  ## populate widgets from Data_of{$self}
  foreach my $field (@$element_order) {
    my $element;
    $element = $self->element($field);
    next unless $element;

    my %param = %{$element->widget};
    ## File widgets behave differently depending on user action
    if ($element->type eq 'File' && $dataview ne 'Add') {
      $param{'type'} = 'NoEdit';
    }

    ## Catch 'has_many' fields before doing normal ones
    if ($has_many{$field}) {
      my $value = [];
      foreach my $many ($data->$field) {
        push @$value, $many->id;
      }
      $param{'value'} = $value;
    }

    my $extra_data = $self->extra_data;
    ## Set field values
    if (ref($data) && !$param{'value'}) {
      ## Set value from data object, if possible 
      $param{'value'} = $data->$field unless exists $extra_data->{$field};
      ## Make sure checkboxes are checked
      if ($param{'type'} eq 'CheckBox' && $param{'value'}) {
        $param{'checked'} = 'yes';
      }
      ## Fall-back - set default value if there is one
      if (!$param{'value'} && $param{'default'}) {
        $param{'value'} = $param{'default'};
      }
    }
    push @$parameters, \%param;

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
  my $extras = $self->extra_data;
  if ($extras) {
    while (my($k, $v) = each (%$extras)) {
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
  my $extra_data = $self->extra_data;
  my $element_order = $self->element_order;
  my %has_many = %{ $self->data->hasmany_relations };

  foreach my $field (@$element_order) {
    my $element = $self->element($field);
    next unless $element;
    next if $element->type eq 'Information';
    next if $element->type eq 'Hidden';
    next if $element->type eq 'Honeypot';
    my %param = %{$element->preview};
    if (ref $data) {
      my $var;
      if (exists $extra_data->{$field}) {
        $var = $object->param($field);
      }
      else {
        $var = $data->$field;
      }
  
      ## Catch 'has_many' fields before doing normal ones
      if (my $classes = $has_many{$field}) {
        warn ">>> HAS MANY $field";
        my $class = $classes->[1];
        my $lookup = $class->get_lookup_values;
        my $order = $lookup->[0]{'order'};
        my $label;
        if ($order) {
          $label = $order->[0];
        }
        else {
          my @labels = keys %{$lookup->{'lookups'}};
          $label = $labels[0];
        }
        my @readable;
        foreach my $many ($data->$field) {
          my $obj = $class->new($many->id);
          push @readable, $obj->$label;
        }
        #warn Dumper($data->$field);
        $param{'value'} = join(', ', @readable);
      }
      elsif ($element->type eq 'DropDown' || $element->type eq 'MultiSelect') {
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
  my $extras = $self->extra_data;
  if ($extras) {
    while (my($k, $v) = each (%$extras)) {
      my %ex = ('name'=>$k, 'type'=>'Hidden', 'value'=>$v);
      push @$parameters, \%ex;  
    }
  }

  return $parameters;
}

sub pass_fields {
  ### Returns editable fields as hidden element parameters
  my ($self, $id, $object) = @_;
  my $parameters = [];
  my $data = $self->data;
  my $extra_data = $self->extra_data;
  my $elements = $self->elements;
  my $element_order = $self->element_order;
  foreach my $field (@$element_order) {
    my $name = $field;
    my $element = $elements->{$name};
    next unless $element;
    next if $element->type eq 'Information';
    next if $element->type eq 'SubHeader';
    next if $element->type eq 'Information';
    my %param = %{$element->hide};
    if (ref $data) {
      my $var;
      if (exists $extra_data->{$field}) {
        $var = $object->param($field);
      }
      else {
        $var = $data->$field;
      }
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

sub honeypots {
### Identifies fields of type Honeypot and returns an arrayref of names
  my $self = shift;
  my $elements = $self->elements;
  my $honeypots;
  while (my ($name, $element) = each (%$elements)) {
    push @$honeypots, $name if $element->type eq 'Honeypot';
  }
  return $honeypots;
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

}

1;
