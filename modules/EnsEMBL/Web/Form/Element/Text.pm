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
  my ($style, @styles);
  if ( CGI::escapeHTML( $self->rows ) ) {
    my $height = CGI::escapeHTML( $self->rows ) * 1.2;
    push @styles, 'height:'.$height.'em';
  }
  
  if (@styles) {
    $style = 'style="'.join(';', @styles).'"';
  }

  return sprintf(
    qq(<label for="%s" style="vertical-align:top;">%s: </label><textarea name="%s" id="%s" rows="%s" cols="%s" class="input-textarea" %s>%s</textarea>),
    CGI::escapeHTML( $self->name ), 
    CGI::escapeHTML( $self->label ), 
    CGI::escapeHTML( $self->name ), 
    CGI::escapeHTML( $self->id ),
    CGI::escapeHTML( $self->rows ) ? CGI::escapeHTML( $self->rows ) : '10', 
    CGI::escapeHTML( $self->cols ) ? CGI::escapeHTML( $self->cols ) : '40',
    $style,
    CGI::escapeHTML( $self->value )
  );
}

sub validate { return 1; }

1;
