package EnsEMBL::Web::Command::Account::Interface::Annotation;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $data;

  ## Create interface object, which controls the forms
  my $interface = $self->interface;
  ## TODO: make new constructor accept 'record_type' parameter
  if ($object->param('record_type') && $object->param('record_type') eq 'group') {
    $data = new EnsEMBL::Web::Data::Record::Annotation::Group($object->param('id'));
  } else {
    $data = new EnsEMBL::Web::Data::Record::Annotation::User($object->param('id'));
  }
  $interface->data($data);
  $interface->discover;

  ## Customization
  $interface->caption({add  => 'Create annotation'});
  $interface->caption({edit => 'Edit annotation'});
  $interface->permit_delete('yes');
  $interface->option_columns([qw/stable_id title/]);
  $interface->modify_element('title',       {type => 'String', label =>'Title'});
  $interface->modify_element('annotation',  {type =>'Text'   , label =>'Annotation notes'});
  $interface->modify_element('stable_id',   {type =>'NoEdit' , label =>'Stable ID'});
  $interface->modify_element('ftype',       {type =>'Hidden'});
  $interface->modify_element('species',     {type =>'Hidden'});
  $interface->modify_element('owner_type',  {type => 'Hidden'});
  $interface->element_order([qw/stable_id title annotation ftype species owner_type/]);

  ## Render page or munge data, as appropriate
  $interface->configure($self->page, $object);
}

1;
