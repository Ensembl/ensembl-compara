package EnsEMBL::Web::Form::Element::CheckBox;
use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new( %params );
  $self->checked = $params{'checked'};
  return $self;
}

sub checked  :lvalue { $_[0]->{'checked'};  }

sub render {
  my $self = shift;
  return sprintf(
    qq(<label class="label-checkbox">
<input type="checkbox" name="%s" id="%s" value="%s" class="input-checkbox" %s/> %s %s</label>),
    CGI::escapeHTML( $self->name ), 
    CGI::escapeHTML( $self->id ),
    $self->value || 'yes', $self->checked ? 'checked="checked" ' : '',
    CGI::escapeHTML( $self->label ), 
    $self->notes
  );
}
                                                                                
sub validate { return 1; }
1;
