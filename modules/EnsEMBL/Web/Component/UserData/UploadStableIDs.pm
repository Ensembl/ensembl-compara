=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::UserData::UploadStableIDs;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->data_species;
  my $version      = $species_defs->ENSEMBL_VERSION;
  my $id_limit     = 30;
  my $form         = $self->modal_form('select', $hub->url({ action => 'CheckConvert', __clear => 1 }));
  
  $form->add_notes({
    heading => 'IMPORTANT NOTE:', 
    text    => qq{
      <p>Please note that we limit the number of ID's processed to $id_limit. If the uploaded file contains more entries than this only the first $id_limit will be mapped.</p>
      <p>If you would like to convert more IDs, please use our <a href="https://github.com/Ensembl/ensembl-tools/tree/release/$version/scripts/id_history_converter" rel="external">api script</a>.</p>
    }
  });

  $form->add_element(
    type   => 'DropDown',
    name   => 'species',
    label  => 'Species',
    values => [ sort { $a->{'name'} cmp $b->{'name'} } map { value => $_, name => $species_defs->species_label($_, 1) }, $species_defs->valid_species ],
    value  => $species,
    select => 'select',
  );

  $form->add_element(type => 'Hidden', name => 'id_mapper',     value => 1);
  $form->add_element(type => 'Hidden', name => 'id_limit',      value => $id_limit);
  $form->add_element(type => 'Hidden', name => 'filetype',      value => 'ID History Converter');
  $form->add_element(type => 'Hidden', name => 'nonpositional', value => 1);
  $form->add_element(type => 'SubHeader',                       value => 'Upload file');
  $form->add_element(type => 'String', name => 'name', label => 'Name for this data (optional)');
  $form->add_element(type => 'Text',   name => 'text', label => 'Paste data');
  $form->add_element(type => 'File',   name => 'file', label => 'Upload file');
  $form->add_element(type => 'URL',    name => 'url',  label => 'or provide file URL', size => 30);
 
  return $form->render;
}


1;
