package EnsEMBL::Web::Utils::HoneyPot;

use strict;
use warnings;

use Exporter qw(import);

use EnsEMBL::Web::Utils::SecretForm;

our @EXPORT_OK = qw(spam_protect_form is_form_spam);

sub spam_protect_form {
  my ($hub,$form) = @_;

  my @honeypots;
  foreach my $child (@{$form->child_nodes||[]}) {
    my $hps = [];
    $hps = $child->get_honeypots if $child->can('get_honeypots');
    push @honeypots,@$hps if $hps;
  }

  my $sf = EnsEMBL::Web::Utils::SecretForm->new($hub,"honeypots");
  $sf->set('fields',\@honeypots);
  my $field = $form->dom->create_element('inputhidden',{
    name => "honeypots",
    value => $sf->save()
  }); 
  $form->append_child($field);
}

sub is_form_spam {
  my ($hub) = @_;

  my $sf = EnsEMBL::Web::Utils::SecretForm->new($hub,"honeypots");
  $sf->load($hub->param('honeypots'));
  my $fields = $sf->get('fields');
  return 1 if !$fields;
  foreach my $f (@{$fields}) {
    return 1 if $hub->param($f);
  }
  return 0;
}

1;
