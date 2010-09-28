package EnsEMBL::Web::Command::Account::Interface::Newsfilter;

use strict;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self         = shift;
  my $object       = $self->object;
  my $species_defs = $object->species_defs;
  my $interface    = $self->interface; ## Create interface object, which controls the forms
  my $data;

  ## TODO: make new constructor accept 'record_type' parameter
  if ($object->param('record_type') && $object->param('record_type') eq 'group') {
    $data = new EnsEMBL::Web::Data::Record::NewsFilter::Group($object->param('id'));
  } else {
    $data = new EnsEMBL::Web::Data::Record::NewsFilter::User($object->param('id'));
  }

  $interface->data($data);
  $interface->discover;
  
  ## Set values for checkboxes
  my @species_list = sort { $a->{'name'} cmp $b->{'name'} } map {{ name => $species_defs->get_config($_, 'SPECIES_COMMON_NAME', 1), value => $_ }} $species_defs->valid_species;
  
  ## Customization
  $interface->caption({ add  => 'Set news filter'  });
  $interface->caption({ edit => 'Edit news filter' });
  $interface->permit_delete('yes');
  
  $interface->element('species', {
    name   => 'species',
    type   => 'MultiSelect',
    label  => 'Species',
    values => \@species_list,
  });

  $interface->modify_element('owner_type', { type => 'Hidden' });
  $interface->element_order([ 'species', 'owner_type' ]);

  ## Render page or munge data, as appropriate
  return $interface->configure($self);
}

1;
