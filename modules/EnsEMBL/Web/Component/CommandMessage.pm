package EnsEMBL::Web::Component::CommandMessage;

### Module to create generic message page

use strict;
use warnings;
no warnings "uninitialized";

use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::Tools::Encryption;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $html = '';
  ## Check this is genuinely from the web code, not injection of arbitrary HTML
  my $checksum = $self->object->param('checksum');
  my $message = uri_unescape($self->object->param('command_message'));
  if (EnsEMBL::Web::Tools::Encryption::checksum($message) eq $checksum) {
    $html = $message;
  }
  else {
    warn '+++ Checksums do not match - suspected HTML injection!';
  }
  return $html;
}

1;
