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
  my $error_text     = $error_messages{$self->hub->function};

  return sprintf '<div class="error"><h3>%s</h3><div class="error-pad"><p>%s</p>%s</div></div>',
    $error_text->[0],
    $error_text->[1],
    EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, '/ssi/species/ERROR_4xx.html')
  ;
}

1;
