package EnsEMBL::Web::Command::Account::Interface::Configuration;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $data;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface->new;
  if ($object->param('record_type') && $object->param('record_type') eq 'group') {
    $data = EnsEMBL::Web::Data::Record::Configuration::Group->new($object->param('id'));
  } else {
    $data = EnsEMBL::Web::Data::Record::Configuration::User->new($object->param('id'));
  }
  $interface->data($data);
  $interface->discover;

  ## Customization
  $interface->caption({add  => 'Save configuration'});
  $interface->caption({edit => 'Edit configuration'});
  $interface->permit_delete('yes');
  $interface->modify_element('name',         { type => 'String', label => 'Configuration name'});
  $interface->modify_element('description',  { type => 'Text',   label => 'A brief description of your configuration'});
  $interface->modify_element('url',          { type => 'Hidden'});
  $interface->modify_element('viewconfig', { type => 'Hidden'});
  $interface->modify_element('owner_type',   { type => 'Hidden'});
  $interface->extra_data('rename');
  $interface->element_order([qw/name description url viewconfig owner_type/]);

  ## Render page or munge data, as appropriate
  $interface->configure($self->webpage, $object);
}

}

1;
