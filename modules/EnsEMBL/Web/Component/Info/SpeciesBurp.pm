package EnsEMBL::Web::Component::Info::SpeciesBurp;

use strict;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self           = shift;
  my %error_messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;
  my $error_text     = $error_messages{$self->hub->function}->[1];
  
  return "<p>$error_text</p><br>" . EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, '/ssi/species/ERROR_4xx.html');
}

1;
