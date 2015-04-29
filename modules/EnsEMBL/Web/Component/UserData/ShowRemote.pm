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

package EnsEMBL::Web::Component::UserData::ShowRemote;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return 'Save source information to your account';
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $form     = $self->modal_form('show_remote', $hub->species_path($hub->data_species). '/UserData/ModifyData/save_remote', { wizard => 1 });
  my $fieldset = $form->add_fieldset;
  my $has_data = 0;
  my $das      = $session->get_all_das;
  
  if ($das && keys %$das) {
    $has_data = 1;
    $fieldset->add_notes('Choose the DAS sources you wish to save to your account')->set_attribute('class', 'spaced');
    $fieldset->add_element({'type' => 'DASCheckBox', 'das'  => $_}) for sort { lc $a->label cmp lc $b->label } values %$das;
  }

  my @urls = $session->get_data(type => 'url');
  
  if (@urls) {
    $has_data = 1;
    $fieldset->add_notes("You have the following remote data attached:")->set_attribute('class', 'spaced');
    $fieldset->add_field({'type'=>'checkbox', 'name' => 'code', 'value' => $_->{'code'}, 'label' => $_->{'name'}, 'notes' => $_->{'url'}}) for @urls;
  }

  $fieldset->add_notes("You have no temporary data sources to save. Click on 'Attach DAS' or 'Attach URL' in the left-hand menu to add sources.") unless $has_data;

  return $form->render;
}

1;
