package EnsEMBL::Web::Command::Help::Feedback;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub = $self->hub;
  my $help;

  my $module = 'EnsEMBL::Web::Data::'.$hub->param('type');
  if ($self->dynamic_use($module)) {
    $help = $module->new($hub->param('record_id'));
    foreach my $p ($hub->param) {
      next unless $p =~ /help_feedback/;
      if ($hub->param($p) eq 'yes') {
        $help->helpful($help->helpful + 1);
      }
      elsif ($hub->param($p) eq 'no') {
        $help->not_helpful($help->not_helpful + 1);
      }
    }
  }
  $help->save;

  my $param_hash = {'feedback' => $hub->param('record_id') };
  $self->ajax_redirect($hub->param('return_url'), $param_hash);
}

1;
