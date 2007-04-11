package EnsEMBL::Web::Form;

use strict;
use EnsEMBL::Web::Root;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Root );

sub new {
  my( $class, $name, $action, $method ) = @_;
  my $self = {
    '_attributes' => {
        'action'   => $action,
        'method'   => lc($method) || 'get' ,  
        'name'     => $name,
        'id'       => $name,
        'onSubmit' => sprintf( 'return( on_submit( %s_vars ))', $name )
    },
    '_buttons'     => {},
    '_button_order'=> [],
    '_elements'    => [],
    '_form_id'     => 1
  };
  bless $self, $class;
  return $self;
}

sub add_button {
  my( $self, $type, $value ) = @_;
  push @{$self->{'_button_order'}}, $type unless exists $self->{'_button'}{$type};
  $self->{'_buttons'}{$type} = $value;
} 

sub add_attribute {
  my( $self, $type, $value ) = @_;
  $self->{'_attributes'}{$type} = $value;
}

sub add_element {
  my( $self, %options ) = @_;
  my $module = "EnsEMBL::Web::Form::Element::$options{'type'}";
  warn $module;
  #warn $self->dynamic_use( $module );

  if( $self->dynamic_use( $module ) ) {
    warn "ID: " . $options{'id'};
    $self->_add_element( $module->new( 'form' => $self->{'_attributes'}{'name'}, %options ) );
  }
  else {
    warn "Unable to dynamically use module $module. Have you spelt the element type correctly?";
  }
}

sub _add_element {
  my( $self, $element ) = @_;
  if( $element->type eq 'File' ) { # File types must always be multipart Posts 
    $self->add_attribute( 'method',  'post' );
    $self->add_attribute( 'enctype', 'multipart/form-data' );
  }
  if (!$element->id) {
    $element->id =  $self->_next_id();
  }
  $element->{form} = $self->{_form_id};
  $element->{formname} = $self->{_attributes}{name};
  push @{$self->{'_elements'}}, $element;
}

sub _next_id {
  my $self = shift;
  return $self->{'_attributes'}{'name'}.'_'.($self->{'_form_id'}++);
}

sub _render_element {
  my( $self, $element ) = @_;
  my $output;
  return $element->render() if $element->type eq 'Hidden';

  my $style = 'formblock';
  if( $element->spanning eq 'yes' ) {
    $style = 'formwide';
  } elsif( $element->spanning eq 'center' ) { 
    $style = 'formcenter';
  } elsif( $element->spanning eq 'inline' ) { 
    $style = 'forminline';
  }
  if( $element->hidden_label ) {
    $output = sprintf qq(
  <div class="formpadding">
    <div class="hidden"><label for="%s">%s</label</div>
  </div>), $element->id, ( $element->label eq '' ? "&nbsp;" : CGI::escapeHTML($element->label) )
  } elsif( $element->label ne '' ) {
    if( $element->comment ) { 
      $output = sprintf qq(
   <h6><label for="%s">%s<br><span style="color: #333; font-weight: normal;">%s<br /><br /></span></label></h6>),
        $element->id, CGI::escapeHTML($element->label), CGI::escapeHTML($element->comment);
    } else {
      $output = sprintf qq(
   <h6><label for="%s">%s</label></h6>),
        $element->id, CGI::escapeHTML($element->label);
    }
  } elsif( $style eq 'formblock' ) {
    $output = qq(
  <div class=\"formpadding\"></div>);;
  }
  return qq(
  <div class="$style">$output
    <div class="formcontent">
    ).$element->render().qq(
    </div>
  </div>);
}

sub render {
  my $self = shift;
  my $output = "<form";
  foreach my $K ( keys %{$self->{'_attributes'}} ) {
    $output .= sprintf ' %s="%s"', CGI::escapeHTML($K), CGI::escapeHTML($self->{'_attributes'}{$K});
  }
  $output .= ">";
  if( @{$self->{'_button_order'}} ) {
    $self->add_element(
      'type' => 'Information',
      'value' => '<div style="text-align: center">'.
      ( exists( $self->{'_buttons'}{'submit'} ) ? sprintf( '<input type="submit" value="%s" />', $self->{'_buttons'}{'submit'} ) : '' ).
      ( exists( $self->{'_buttons'}{'reset'}  ) ? sprintf( '<input type="reset"  value="%s" />', $self->{'_buttons'}{'reset'}  ) : '' ).
      '</div>'
    );
  }
  my $F = 0;
  foreach my $element ( @{$self->{'_elements'}} ) {
    if( $element->required eq 'yes' ) {
      $F=1;
    }
  }
  $self->add_element( 'type' => 'Information', 
    'value' => '<div style="text-align: right">Fields marked with <b>*</b> are required</div>'
  ) if $F;
  foreach my $element ( @{$self->{'_elements'}} ) {
    $output .= $self->_render_element( $element );
  }
  $output .= "\n</form>\n";
  return $output;
}

sub render_js {
  my $self = shift;
  my @entries;
  foreach my $element ( @{$self->{'_elements'}} ) {
    if($element->validate()) {
      if( $element->type eq 'DropDownAndString' ) {
        (my $T_name = $element->name)=~s/'/\\'/g;
        (my $T_label = $element->label)=~s/'/\\'/g;
        (my $TS_name = $element->string_name)=~s/'/\\'/g;
        (my $TS_label = $element->string_label)=~s/'/\\'/g;
        push @entries, sprintf(
          " new form_obj( '%s', '%s', '%s', '%s', %d )", $self->{_attributes}{'name'},$T_name,
          'DropDown', $T_label, $element->required eq 'yes'?1:0
        );
        push @entries, sprintf(
          " new form_obj( '%s', '%s', '%s', '%s', %d )", $self->{_attributes}{'name'},$TS_name,
          'String', $TS_label, $element->required eq 'yes'?1:0
        );
      } else { 
        (my $T_name = $element->name)=~s/'/\\'/g;
        (my $T_label = $element->label)=~s/'/\\'/g;
        push @entries, sprintf(
          " new form_obj( '%s', '%s', '%s', '%s', %d )", $self->{_attributes}{'name'},$T_name,
          $element->type, $T_label, $element->required eq 'yes'?1:0
        );
      }
    }
  }
  my $vars_array = $self->{'_attributes'}{'name'}."_vars";
  if( @entries ) {
    return {
      'head_vars' => "$vars_array = new Array(\n  ".join(",\n  ",@entries)."\n);\n",
      'body_code' => "on_load( $vars_array );",
      'scripts'   => '/js/forms.js'
    }; 
  } else {
    return {};
  }
}

1;
