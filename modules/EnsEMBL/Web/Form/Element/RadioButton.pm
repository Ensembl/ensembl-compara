package EnsEMBL::Web::Form::Element::RadioButton;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}
                                                                                
sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new(
    %params,
  );
  $self->checked  = $params{'checked'};
  $self->disabled = $params{'disabled'};
  return $self;
}

sub checked  :lvalue { $_[0]->{'checked'};  }
sub disabled :lvalue { $_[0]->{'disabled'}; }

sub render {
  my $self = shift;
  return sprintf(
   qq(<tr>
  <th><label class="label-radio"></th>
  <td><input type="radio" name="%s" id="%s" value="%s" class="input-radio"%s%s/> %s %s</label></td>
  </tr>),
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $self->id ),
    $self->value || 'yes', 
    $self->checked ? ' checked="checked" ' : '',
    $self->disabled ? ' disabled="disabled" ' : '',
    CGI::escapeHTML( $self->label ),
    $self->notes
  );
}
                                                                                
sub validate { return 1; }


1;
