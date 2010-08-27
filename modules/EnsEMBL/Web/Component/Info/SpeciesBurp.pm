package EnsEMBL::Web::Component::Info::SpeciesBurp;

use strict;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Apache::SendDecPage;

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
  
  return "<p>$error_text</p><br>" . EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, '/ssi/species/ERROR_4xx.html');
}

1;
