package EnsEMBL::Web::Form::Element::CheckBox;

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
    qq(<input type="checkbox" name="%s" id="%s" />),
    CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
  );
}
                                                                                
sub validate { return 1; }


1;
