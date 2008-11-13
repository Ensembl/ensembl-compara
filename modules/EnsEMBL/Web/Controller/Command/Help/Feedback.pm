package EnsEMBL::Web::Controller::Command::Help::Feedback;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $help;

  my $module = 'EnsEMBL::Web::Data::'.$cgi->param('type');
  if ($self->dynamic_use($module)) {
    $help = $module->new($cgi->param('record_id'));
    foreach my $p ($cgi->param) {
      next unless $p =~ /help_feedback/;
      if ($cgi->param($p) eq 'yes') {
        $help->helpful($help->helpful + 1);
      }
      elsif ($cgi->param($p) eq 'no') {
        $help->not_helpful($help->not_helpful + 1);
      }
    }
  }
  $help->save;

  my $param_hash = {'feedback' => $cgi->param('record_id') };
  my $url = $self->url($cgi->param('return_url'), $param_hash);
  $self->ajax_redirect($self->ajax_url($url));
}

}

1;
