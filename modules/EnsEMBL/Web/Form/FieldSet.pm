package EnsEMBL::Web::Form::FieldSet;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Root);

use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Tools::RandomString;

sub new {
  my ($class, %option) = @_;
  
  my $name = $option{'name'} || EnsEMBL::Web::Tools::RandomString::random_string;
  
  my $self = {
    '_id'       => $option{'form'}."_$name",
    '_legend'   => $option{'legend'}  || '',
    '_stripes'  => $option{'stripes'} || 0,
    '_elements'       => {},
    '_element_order'  => [],
    '_set_id'   => 1,
    '_required' => 0,
    '_file'     => 0,
    '_extra'    => '',
    '_notes'    => '',
    '_class'    => '',
  };
  
  bless $self, $class;
  
  # Make adding of form elements as bulletproof as possible
  if ($option{'elements'} && ref($option{'elements'}) eq 'ARRAY') {
    foreach my $element (@{$option{'elements'}}) {
      if (ref($element) =~ /EnsEMBL::Web::Form::Element/) {
        $self->_add_element($element);
      } else {
        $self->add_element(%$element);
      }
    }    
  }
  
  return $self;
}

sub elements {
  my $self = shift;
  my $elements = [];
  foreach my $e (@{$self->{'_element_order'}}) {
    next unless $e;
    push @$elements, $self->{'_elements'}{$e} if $self->{'_elements'}{$e};
  }
  return $elements;
}

sub add_element {
  my( $self, %options ) = @_;
  my $module = "EnsEMBL::Web::Form::Element::$options{'type'}";
  
  if( $self->dynamic_use( $module ) ) {
    $self->_add_element( $module->new( 'form' => $self->{'_attributes'}{'id'}, %options ) );
  } else {
    warn "Unable to dynamically use module $module. Have you spelt the element type correctly?";
  }
}

sub _add_element {
  my( $self, $element ) = @_;
  if( $element->type eq 'File' ) { 
    $self->{'_file'} = 1;
  }
  if( $element->required eq 'yes' ) { 
    $self->{'_required'} = 1;
  }
  if (!$element->id) {
    $element->id =  $self->_next_id();
  }
  
  my $key = $element->name || $element->id;
 
  if ($self->{'_elements'}{$key}) {
    push @{$self->{'_elements'}{$key}}, $element;
  }
  else { 
    $self->{'_elements'}{$key} = [$element];
    push @{$self->{'_element_order'}}, $key;
  }
}

sub delete_element {
  my ($self, $name) = @_;
  return unless $name;
  delete $self->{'_elements'}{$name};
  ## Don't forget to remove it from the element order as well!
  my $keepers;
  foreach my $element (@{$self->{'_element_order'}}) {
    push @$keepers, $element unless $element eq $name;
  }
  $self->{'_element_order'} = $keepers;
}

sub modify_element {
### Modify an attribute of an EnsEMBL::Web::Form::Element object
  my ($self, $name, $attribute, $value) = @_;
  return unless ($name && $attribute);
  if ($name eq $attribute) {
    warn "!!! Renaming of elements not permitted! Remove this element and replace with a new one.";
    return;
  }
  my $elements = $self->{'_elements'}{$name};
  if (@$elements > 1) {
    warn "!!! Use modify_elements to change multiple elements";
    return;
  }
  my $element = $elements->[0];
  if ($element && $element->can($attribute)) {
    $element->$attribute = $value;
  }
}

sub modify_elements {
### Modify an attribute of multiple EnsEMBL::Web::Form::Element objects of the same name
  my ($self, $name, $attribute, $value) = @_;
  return unless ($name && $attribute);
  if ($name eq $attribute) {
    warn "!!! Renaming of elements not permitted! Remove this element and replace with a new one.";
    return;
  }
  foreach my $element (@{$self->{'_elements'}{$name}}) {
    if ($element && $element->can($attribute)) {
      $element->$attribute = $value;
    }
  }
}

sub legend {
  my $self = shift;
  $self->{'_legend'} = shift if @_;
  return $self->{'_legend'};
}

sub notes {
  my $self = shift;
  $self->{'_notes'} ||= [];
  push @{$self->{'_notes'}}, shift if @_;
  return $self->{'_notes'};
}

sub extra {
  my $self = shift;
  $self->{'_extra'} = shift if @_;
  return $self->{'_extra'};
}

sub class {
  my $self = shift;
  $self->{'_class'} = shift if @_;
  return $self->{'_class'};
}

sub _next_id {
  my $self = shift;
  return $self->{'_id'}.'_'.($self->{'_set_id'}++);
}

sub _render_element {
  my ($self, $elements, $tint) = @_;
  my $output;
  if (ref($elements) ne 'ARRAY') {
    $elements = [$elements];
  }
  foreach my $element (@$elements) {
    if ($element->type eq 'Submit' || $element->type eq 'Button') {
      my $html = '<tr><td></td><td>';
      $html .= $element->render($tint);
      $html .= '</td></tr>';
      return $html;
    } 
    else {
      return $element->render;
    }
  }
}

sub _render_raw_element {
  my ($self, $element) = @_;
  return $element->render_raw;
}

sub render {
  my $self = shift;
 
  my $output = sprintf qq{<div class="%s"><fieldset%s>\n}, $self->class, $self->extra;
  $output .= sprintf "<h2>%s</h2>\n", encode_entities($self->legend) if $self->legend;

  if ( $self->extra =~/matrix/){ 
    my $html = $self->render_matrix;
    $output .= $html;  
  } else {   
    if ($self->{'_required'}) {
      $self->add_element(
        'type'  => 'Information',
        'value' => 'Fields marked with <strong>*</strong> are required'
     )
    }
  
    foreach my $note (@{$self->notes||[]}) {
      my $class = exists $note->{'class'} && !defined $note->{'class'} ? '' : $note->{'class'} || 'notes';
      $class = qq{ class="$class"} if $class;
    
      $output .= qq{<div$class>};
    
      if ($note->{'heading'}) {
        $output .= "<h4>$note->{'heading'}</h4>";
      }
    
      if ($note->{'list'}) {
        $output .= '<ul>';
        $output .= "<li>$_</li>\n" for @{$note->{'list'}};
        $output .= '</ul>';
      } elsif ($note->{'text'}) {
        $output .= "<p>$note->{'text'}</p>";
      }
    
      $output .= "</div>\n";
    } 
  
    $output .= qq{\n<table style="width:100%"><tbody>\n};
  
    my $hidden_output;
    my $i;
  
    foreach my $name (@{$self->{'_element_order'}}) {
      my $elements = $self->{'_elements'}{$name};
      next unless @$elements;
      foreach my $element (@$elements) {
        if ($element->type eq 'Hidden') {
          $hidden_output .= $self->_render_element($element);
        } 
        else {
          if ($self->{'_stripes'}) {
            $element->bg = $i % 2 == 0 ? 'bg2' : 'bg1';
          }
      
          $output .= $self->_render_element($element);
        }
    
        $i++;
      }
    }
  
    $output .= "\n</tbody></table>\n";
    $output .= $hidden_output;
    $output .= "\n</fieldset></div>\n";
  }
  return $output;
}

sub render_matrix {
  my $self = shift;
  my $html;
  my @data_matrix;
      

  foreach my $name (@{$self->{'_element_order'}}) {
    next if $name =~/select_all/;
    my $elements = $self->{'_elements'}{$name};
    my $element = $elements->[0];
    my $position = $element->layout;
    my ($row, $column) = split (/:/, $position);
    $data_matrix[$row][$column] = $element;
  }

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' =>'1em 0px'});

  my @column_headers = @{$data_matrix[0]};
  my $number_of_variable_width_columns = scalar @column_headers -1;
  my $fixed_column_width = 8;
  my $column_width = (100 - $fixed_column_width) / $number_of_variable_width_columns; 
  
  my $column_count =1;
  my $header_flag;
  # First add table columns 
  foreach (@column_headers){
    my $label = '';
    if ($_){
      $label = $_->label; 
      $table->add_columns( {'key' => $column_count,   'title' => $label, 'align' => 'left', width => $column_width.'%', },);
      $column_count++; 
    } else {
      unless( $header_flag){  
        $table->add_columns( {'key' => 'header',  'title' => '&nbsp'  , 'align' => 'left', 'width' => $fixed_column_width .'%', },);
        $header_flag =1;
      }
    }
  }

  my $number_of_rows = scalar @data_matrix - 1; 
 
  my @table_rows;

  # Now loop through a row at a time
  for( my $i = 1; $i <= $number_of_rows; $i++){
    my $row; 
    my @row_data = @{$data_matrix[$i]};
    my $label_element = shift(@row_data);
    my $row_label = $label_element->label;
    $row_label = '<strong>'.$row_label.'</strong>';
    $row->{'header'} = $row_label; 

    # Add check boxes
    my $column_pos =1;  
    foreach my $element( @row_data){  
      if ($element){
        my $checkbox .= $self->_render_raw_element($element);
        if ($element->label =~/all/){
          $checkbox .= 'Select all ' 
        } 
        $row->{$column_pos} = $checkbox; 
      } else {
        $row->{$column_pos} = '';   
      }
      $column_pos++;        
    }

    push @table_rows, $row;    
  }

  foreach (@table_rows){
    $table->add_row($_);
  }

  $html .= $table->render;
  $html .= "\n</fieldset></div>\n";
  return $html;
}
1;
