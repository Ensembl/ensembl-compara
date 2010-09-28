package EnsEMBL::Web::Command::Account::Interface::Configuration;

use strict;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $object    = $self->object;
  my $interface = $self->interface; ## Create interface object, which controls the forms
  my $data;
  
  if ($object->param('record_type') && $object->param('record_type') eq 'group') {
    $data = new EnsEMBL::Web::Data::Record::Configuration::Group($object->param('id'));
  } else {
    $data = new EnsEMBL::Web::Data::Record::Configuration::User($object->param('id'));
  }
  $interface->data($data);
  $interface->discover;

  ## Customization
  $interface->caption({
    add  => 'Save configuration', 
    edit => 'Edit configuration'
  });
  
  $interface->permit_delete('yes');
  $interface->modify_element('name',        { type => 'String', label => 'Configuration name' });
  $interface->modify_element('description', { type => 'Text',   label => 'A brief description of your configuration' });
  $interface->modify_element('url',         { type => 'Hidden' });
  $interface->modify_element('viewconfig',  { type => 'Hidden' });
  $interface->modify_element('owner_type',  { type => 'Hidden' });
  $interface->extra_data('rename');
  $interface->element_order([qw(name description url viewconfig owner_type)]);

  ## Render page or munge data, as appropriate
  return $interface->configure($self);
}

1;
