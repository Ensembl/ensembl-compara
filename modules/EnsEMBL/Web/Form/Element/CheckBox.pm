package EnsEMBL::Web::Form::Element::CheckBox;
use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new( %params );
  $self->checked = $params{'checked'};
  $self->{'class'} = $params{'long_label'} ? 'checkbox-long' : '';
  return $self;
}

sub checked  :lvalue { $_[0]->{'checked'};  }

sub render {
  my $self = shift;
  return sprintf(
    qq(
  <dl>
    <dt%s>
      <label>%s %s</label>
    </dt>
    <dd%s>
      <input type="checkbox" name="%s" id="%s" value="%s" class="input-checkbox" %s/>
    </dd>
  </dl>),
    $self->{'class'} ? ' class="'.$self->{'class'}.'"' : '',
    $self->{'raw'} ? $self->label : CGI::escapeHTML( $self->label ), 
    $self->notes,
    $self->{'class'} ? ' class="'.$self->{'class'}.'"' : '',
    CGI::escapeHTML( $self->name ), 
    CGI::escapeHTML( $self->id ),
    $self->value || 'yes', $self->checked ? 'checked="checked" ' : '',
  );
}
                                                                                
sub validate { return 1; }
1;
