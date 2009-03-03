package EnsEMBL::Web::Command::Help::Feedback;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  my $object = $self->object;
  my $help;

  my $module = 'EnsEMBL::Web::Data::'.$object->param('type');
  if ($self->dynamic_use($module)) {
    $help = $module->new($object->param('record_id'));
    foreach my $p ($object->param) {
      next unless $p =~ /help_feedback/;
      if ($object->param($p) eq 'yes') {
        $help->helpful($help->helpful + 1);
      }
      elsif ($object->param($p) eq 'no') {
        $help->not_helpful($help->not_helpful + 1);
      }
    }
  }
  $help->save;

  my $param_hash = {'feedback' => $object->param('record_id') };
  $self->ajax_redirect($object->param('return_url'), $param_hash);
}

}

1;
