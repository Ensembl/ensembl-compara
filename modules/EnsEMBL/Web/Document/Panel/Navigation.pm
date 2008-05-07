package EnsEMBL::Web::Document::Panel::Navigation;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_content( $caption, $body );
}

sub add_content {
  my( $self, $content ) =@_;
  $self->print( $content );
}

1;
