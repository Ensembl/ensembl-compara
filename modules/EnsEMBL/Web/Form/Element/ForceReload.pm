package EnsEMBL::Web::Form::Element::ForceReload;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render {
  my $self = shift;
  return '<div id="modal_reload">This window will try and reload when closed</div>';
}

1;
