package EnsEMBL::Web::Form::Element::Range;

use EnsEMBL::Web::Form::Element;
use CGI qq(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

## TODO -  Needs updating - probably doesn't work with current JavaScript

sub render {
  my $self = shift;
  my( $min, $max ) = $self->value ? ( 1, $self->value ) : ( '','' );
  if( $self->value =~ /^(.*):(.*)$/ ) {
    $min = $1;
    $max = $2;
  }
  my $extra = sprintf qq(class="%s" onKeyUp="os_check('%s',this,%s)" onChange="os_check( '%s', this, %s )" ),
    'range' , 'range', $self->required eq 'yes' ? 1 : 0 , 'range', $self->required eq 'yes' ? 1 : 0;
  return sprintf
    '%s<input type="text" name="%s_min" value="%s" id="%s_min" %s /> - <input type="text" name="%s_max" value="%s" id="%s_max" %s />%s%s',
    $self->introduction,
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $min ),
    CGI::escapeHTML( $self->id ),
    $extra,
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $max ),
    CGI::escapeHTML( $self->id ),
    $extra,
    $self->required eq 'yes' ? $self->required_string : '',
    $self->notes;
}

1;
