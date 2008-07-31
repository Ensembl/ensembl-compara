package EnsEMBL::Web::Component::Help::EmailSent;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = qq(<p>Thank you. Your message has been sent to our HelpDesk.</p>);

  return $html;
}

1;
