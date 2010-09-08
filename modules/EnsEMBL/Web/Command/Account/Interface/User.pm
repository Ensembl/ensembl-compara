package EnsEMBL::Web::Command::Account::Interface::User;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  ## Create interface object, which controls the forms
  my $interface = $self->interface;
  my $user = $object->user;
  $user = new EnsEMBL::Web::Data::User unless $user;
  $interface->data($user);
  $interface->discover;

  ## Customization
  $interface->caption({
    'add'     => 'Register with ' . $object->species_defs->ENSEMBL_SITETYPE, 
    'display' => 'Your details',
    'edit'    => 'Update your account',
  });

## Form elements
  $interface->modify_element('name', {'label' => 'Your name', 'required' => 'yes'});
  $interface->modify_element('email', {'label' => 'Your email address', 'required' => 'yes', 'notes' => "You'll use this to log in to Ensembl", 'type' => 'Email' });
  $interface->element('subscription', {'name' => 'subscription', 'label' => 'Ensembl Newsletters Subscription', 'type' => 'CheckBox', 'value'=>'Yes','notes' => 'Tick the box if you wish to receive email from Ensembl.'});
  $interface->extra_data('record_id');
  ## Honeypot fields, hidden from user
  $interface->element('surname', {'type' => 'Honeypot'});
  $interface->element('address', {'type' => 'Honeypot'});
  $interface->element_order(['name', 'surname', 'address', 'email', 'organisation', 'subscription']);

  ## Render page or munge data, as appropriate
  $interface->configure($self->page, $object);
}

1;
