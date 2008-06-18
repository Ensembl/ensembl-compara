package EnsEMBL::Web::Form::Element::NoEdit;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render { 
  my $self = shift;
  my $value = $self->value || '&nbsp;';
  return sprintf(qq(<label for="%s" class="label-preview">%s</label> <div class="preview">%s</div>), 
    $self->name, $self->label, $value); 
}

1;
