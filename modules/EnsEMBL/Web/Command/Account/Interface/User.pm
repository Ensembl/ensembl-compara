package EnsEMBL::Web::Command::Account::Interface::User;

use strict;

use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $object    = $self->object;
  my $interface = $self->interface; ## Create interface object, which controls the forms
  my $user      = $object->user || EnsEMBL::Web::Data::User->new;
  
  $interface->data($user);
  $interface->discover;

  ## Customization
  $interface->caption({
    add     => 'Register with ' . $object->species_defs->ENSEMBL_SITETYPE, 
    display => 'Your details',
    edit    => 'Update your account'
  });
        
  ## Form elements
  $interface->modify_element('name',  { label => 'Your name',          required => 'yes' });
  $interface->modify_element('email', { label => 'Your email address', required => 'yes', notes => "You'll use this to log in to Ensembl", type => 'Email' });
  if ($object->function =~ /add/i) {
    $interface->modify_element('subscription', { label => 'Ensembl Newsletters Subscription', name => 'subscription', value => 'Yes', notes => 'Tick the box if you wish to receive emails from Ensembl.', type => 'CheckBox' });
  }
  else {
    $interface->modify_element('subscription', { name => 'subscription', value => 'Yes', type => 'Hidden' });
  }
  $interface->extra_data('record_id');
  ## Honeypot fields, hidden from user
  $interface->element('surname', { type => 'Honeypot'});
  $interface->element('address', { type => 'Honeypot'});
  $interface->element_order([ 'name', 'surname', 'address', 'email', 'organisation', 'subscription' ]);
  
  ## Render page or munge data, as appropriate
  return $interface->configure($self);
}
1;
