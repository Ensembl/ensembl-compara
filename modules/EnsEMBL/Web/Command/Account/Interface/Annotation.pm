package EnsEMBL::Web::Command::Account::Interface::Annotation;

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
    $data = EnsEMBL::Web::Data::Record::Annotation::Group->new($object->param('id'));
  } else {
    $data = EnsEMBL::Web::Data::Record::Annotation::User->new($object->param('id'));
  }
  $interface->data($data);
  $interface->discover;

  ## Customization
  $interface->caption({add  => 'Create annotation'});
  $interface->caption({edit => 'Edit annotation'});
  $interface->permit_delete('yes');
  $interface->option_columns([qw/stable_id title/]);
  $interface->modify_element('title',      {type => 'String', label =>'Title'});
  $interface->modify_element('annotation', {type =>'Text'   , label =>'Annotation notes'});
  $interface->modify_element('stable_id',  {type =>'NoEdit' , label =>'Stable ID'});
  $interface->modify_element('url',        {type =>'Hidden'});
  $interface->modify_element('owner_type', {type => 'Hidden'});
  $interface->element_order([qw/stable_id title annotation url owner_type/]);

  ## Render page or munge data, as appropriate
  $interface->configure($self->webpage, $object);
}

}

1;
