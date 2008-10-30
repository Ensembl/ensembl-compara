package EnsEMBL::Web::Component::CommandMessage;

### Module to create generic message page

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Tools::Encryption;

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
  my $message = $self->object->param('command_message');
  if (EnsEMBL::Web::Tools::Encryption::validate_checksum($message, $checksum)) {
    $html = $message;
  }
  return $html;
}

1;
