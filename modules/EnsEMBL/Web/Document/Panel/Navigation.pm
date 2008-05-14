package EnsEMBL::Web::Document::Panel::Navigation;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->print( qq(
  <h3>$caption</h3>
$body ));
}

sub add_content {
  my( $self, $content ) =@_;
  $self->print( $content );
}

1;
