package EnsEMBL::Web::Component::Transcript;

use strict;

use base qw(EnsEMBL::Web::Component);

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub non_coding_error {
  my $self = shift;
  return $self->_error('No protein product', '<p>This transcript does not have a protein product</p>');
}

sub _flip_URL {
  my ($transcript, $code) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $transcript->species, $transcript->script, $transcript->stable_id, $transcript->get_db, $code;
}

1;

