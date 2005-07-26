package EnsEMBL::Web::Form::Element::Text;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render {
  my $self = shift;
  return sprintf(
    qq(<textarea name="%s" id="%s" rows="%s" cols="%s" onKeyUp="check('text',this,%d)" onChange="check( 'text', this, %d )">%s</textarea>),
    CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
    CGI::escapeHTML( $self->rows ) ? CGI::escapeHTML( $self->rows ) : '10', 
    CGI::escapeHTML( $self->cols ) ? CGI::escapeHTML( $self->rows ) : '40',
    $self->required eq 'yes' ? 1 : 0,
    $self->required eq 'yes' ? 1 : 0,
    CGI::escapeHTML( $self->value )
  );
}

sub validate { return 1; }

1;
