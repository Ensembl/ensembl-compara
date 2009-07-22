package EnsEMBL::Web::Form::Element::ForceReload;

use strict;

use base qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render {
  my $self = shift;
  return '<div class="modal_reload">This window will try and reload when closed</div>';
}

1;
