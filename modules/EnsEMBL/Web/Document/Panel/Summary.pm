package EnsEMBL::Web::Document::Panel::Summary;

use strict;
use Data::Dumper qw(Dumper);

use base qw(EnsEMBL::Web::Document::Panel);

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_row( $caption, $body );
}

sub add_description {
  my( $self, $description ) = @_;
  $self->printf( qq(
        <p>%s</p>), $description );
}


sub add_row {
  my( $self, $label, $content ) =@_;
  $self->printf( qq(
        <dl class="summary">
          <dt>%s</dt>
          <dd>
            %s
          </dd>
        </dl>),
    $label, $content
  );
}

1;
