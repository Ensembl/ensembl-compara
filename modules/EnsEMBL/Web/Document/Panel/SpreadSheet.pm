package EnsEMBL::Web::Document::Panel::SpreadSheet;

use strict;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::SpreadSheet;
use Exporter;
our @ISA = qw(EnsEMBL::Web::Document::Panel);

sub new { ## All now configured by the component!!
  my $self = shift->SUPER::new(
    @_, '_intro'=>'','_tailnote'=>'',
    '_form_action' => '', '_form_hidden' => {}, '_form_buttons' => {}
  );
  $self->{'_spreadsheet'} = new EnsEMBL::Web::Document::SpreadSheet( [], [], $self->{'_options'} );
  return $self;
}

sub spreadsheet { return $_[0]->{'_spreadsheet'}; }

sub add_form {
  my($self, $action, $hidden_fields, $buttons ) = @_;
  $self->{_form_action } = $action;
  $self->{_form_hidden } = $hidden_fields;
  $self->{_form_buttons} = $buttons;
}
sub intro {
  my $self = shift;
  $self->{_intro} .= join '', @_;
} 

sub tailnote {
  my $self = shift;
  $self->{_tailnote} .= join '', @_;
}

sub content_Text {
  my $self    = shift;
  my $counter = 0;
  foreach my $component ($self->components) {
    foreach my $function_name ( @{$self->{'components'}{$component}} ) {
      my $result;
      (my $module_name = $function_name ) =~s/::\w+$//;
      if( $self->dynamic_use( $module_name ) ) {
        no strict 'refs';
        eval {
          $result = &$function_name( $self, $self->{'object'} );
        };
        if( $@ ) {
          my $error = sprintf( '<pre>%s</pre>', $self->_format_error($@) );
          # if( $@ =~ /^Undefined subroutine / ) {
          #  $error = "<p>This function is not defined</p>";
          # }
          $self->_error( qq(Runtime Error in component "<b>$component</b>"),
            qq(<p>Function <strong>$function_name</strong> fails to execute due to the following error:</p>$error)
          );
          $self->timer_push( "Component $function_name (runtime failure)" );
        } else {
          $self->timer_push( "Component $function_name succeeded" );
        }
      } else {
        $self->_error( qq(Compile error in component "<b>$component</b>"),
          qq(
            <p>Function <strong>$function_name</strong> not executed as unable to use module <strong>$module_name</strong>
               due to syntax error.</p>
            <pre>@{[ $self->_format_error( $self->dynamic_use_failure($module_name) ) ]}</pre>
          )
        );
        $self->timer_push( "Component $function_name (compile failure)" );
      }
      last if $result;
    }
  }
  warn $self->spreadsheet;
  $self->renderer->print( $self->spreadsheet->render_Text() );
}

sub _start {
  $_[0]->{_error_notes_} = '';
}

sub _error {
  my( $self, $caption, $message) = @_;
  $self->{_error_notes_} .= "<h4>$caption</h4>$message";
}

sub _end {
  my $self    = shift;
  my $counter = 0;
  my $data    = $self->spreadsheet->{_data}    || [];
  my $columns = $self->spreadsheet->{_columns}    || [];
  if( exists( $self->{null_data} ) && !@$data) {
    if( $self->{null_data} ) {
      $self->print( $self->{null_data} );
    }
    return;
  }
  return undef unless @$columns;
# Start the table...
  my $T = $self->spreadsheet->render();
  if( $self->{_form_action} ) {
    $self->printf( '<form action="%s" method="get">', $self->{_form_action} );
    foreach my $param_key (  keys %{$self->{_form_hidden}} ) {
      my @values = $self->{_form_hidden}{$param_key};
      if (ref $values[0] eq 'ARRAY') {
	@values = @{$values[0]};
      }
      foreach (@values) {
	$self->printf( '<input type="hidden" name="%s" value="%s" />', $param_key, $_ );
      }
	
    }
  }
  $self->print( qq(
$self->{_intro}
$T
$self->{tailnote}
$self->{_error_notes_}
) );
  if( $self->{_form_action} ) {
    $self->print( '<p class="center">');
    foreach( keys %{$self->{_form_buttons}} ) {
      $self->printf( '<input type="submit" class="red-button" name="%s" value="%s" />', $_, $self->{_form_buttons}{$_} );
    }
    $self->print( '</p></form>' );
  }
  return; 
}

sub clear_options { $_[0]->spreadsheet->{_options} = {};            }
sub clear_option  { delete $_[0]->spreadsheet->{_options}{$_[1]}; }
sub add_option    { $_[0]->spreadsheet->{_options}{$_[1]} = $_[2];  }
sub option        { return $_[0]->spreadsheet->{_options}{$_[1]};   }
sub options       { return keys %{$_[0]->spreadsheet->{_options}};  }

sub add_columns {        
  my $self = shift;     
  push @{$self->spreadsheet->{_columns}}, @_;        
}       
         
sub add_row {   
  my( $self, $data ) = @_;      
  push @{$self->spreadsheet->{_data}}, $data;        
}       
        
1;

