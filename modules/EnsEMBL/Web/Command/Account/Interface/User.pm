package EnsEMBL::Web::Command::Account::Interface::User;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $sitetype = $sd->ENSEMBL_SITETYPE;

  ## Create interface object, which controls the forms
  my $interface = new EnsEMBL::Web::Interface;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  $user = new EnsEMBL::Web::Data::User unless $user;
  $interface->data($user);
  $interface->discover;

  ## Customization
  $interface->caption({
    'add'     => 'Register with '.$sitetype, 
    'display' => 'Your details',
    'edit'    => 'Update your account',
  });

## Form elements
  $interface->element('name', {'label' => 'Your name', 'required' => 'yes'});
  $interface->element('email', {'label' => 'Your email address', 'required' => 'yes', 
                      'notes' => "You'll use this to log in to Ensembl"});
  $interface->extra_data('record_id');
  ## Honeypot fields, hidden from user
  $interface->element('surname', {'type' => 'Honeypot'});
  $interface->element('address', {'type' => 'Honeypot'});
  $interface->element_order(['name', 'surname', 'address', 'email', 'organisation']);

  ## Render page or munge data, as appropriate
  $interface->configure($self->webpage, $object);
}

}

1;
