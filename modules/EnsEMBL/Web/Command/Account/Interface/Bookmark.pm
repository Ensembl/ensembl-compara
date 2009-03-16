package EnsEMBL::Web::Command::Account::Interface::Bookmark;

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
  my $interface = EnsEMBL::Web::Interface->new();

  ## TODO: make new constructor accept 'record_type' parameter 
  if ($object->param('record_type') && $object->param('record_type') eq 'group') {
    $data = EnsEMBL::Web::Data::Record::Bookmark::Group->new($object->param('id'));
  } else {
    $data = EnsEMBL::Web::Data::Record::Bookmark::User->new($object->param('id'));
  }
  
  $interface->data($data);
  $interface->discover;

  ## Customization
  $interface->caption({'add'=>'Create bookmark'});
  $interface->caption({'edit'=>'Edit bookmark'});
  $interface->permit_delete('yes');
  $interface->option_columns([qw/name description url/]);
  $interface->element('url', {'type'=>'String', 'label'=>'The URL of your bookmark'});
  $interface->element('name', {'type'=>'String', 'label'=>'Bookmark name'});
  $interface->element('description', {'type'=>'String', 'label'=>'Short description'});
  $interface->element('click', {'type'=>'Hidden'});
  $interface->element('owner_type',  { type => 'Hidden'});
  $interface->element_order([qw/name description url owner_type click/]);

  ## Render page or munge data, as appropriate
  $interface->configure($self->webpage, $object);
}

}

1;
