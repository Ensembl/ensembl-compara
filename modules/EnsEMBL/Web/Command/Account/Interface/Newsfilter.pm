package EnsEMBL::Web::Command::Account::Interface::Newsfilter;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::Release;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $data;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface->new;

  ## TODO: make new constructor accept 'record_type' parameter
  if ($object->param('record_type') && $object->param('record_type') eq 'group') {
    $data = EnsEMBL::Web::Data::Record::NewsFilter::Group->new($object->param('id'));
  } else {
    $data = EnsEMBL::Web::Data::Record::NewsFilter::User->new($object->param('id'));
  }

  $interface->data($data);
  $interface->discover;

  ## Set values for checkboxes
  my $release = EnsEMBL::Web::Data::Release->new($object->species_defs->ENSEMBL_VERSION);
  my @all_species = $release->species('assembly_code'=>{'!='=>''});
  my @species_list;
  my @sorted = sort {$a->common_name cmp $b->common_name} @all_species;
  foreach my $species (@sorted) {
    push @species_list, {'name' => $species->common_name, 'value' => $species->name};
  }
  #my @topic_list = (
  #    {'name' => 'Data updates', 'value' => 'data'},
  #    {'name' => 'Code changes', 'value' => 'code'},
  #    {'name' => 'API changes', 'value' => 'schema'},
  #    {'name' => 'Web features', 'value' => 'feature'},
  #  );

  ## Customization
  $interface->caption({add  => 'Set news filter'});
  $interface->caption({edit => 'Edit news filter'});
  $interface->permit_delete('yes');
  #$interface->element('topic', {'type'=>'MultiSelect', 'label'=>'Topic(s)',
  #                              'values' => \@topic_list, value => ''});
  $interface->element('species', {
                                  type   => 'MultiSelect',
                                  label  => 'Species',
                                  values => \@species_list,
                                  value => ''
                                 }
  );

  $interface->element('owner_type', { type => 'Hidden'});
  $interface->element_order(['species', 'owner_type']);

  ## Render page or munge data, as appropriate
  $interface->configure($self->webpage, $object);
}

}

1;
