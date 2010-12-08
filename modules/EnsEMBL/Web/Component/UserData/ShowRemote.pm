# $Id$;

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
  my $form     = $self->modal_form('show_remote', $hub->species_path($hub->data_species). '/UserData/SaveRemote', { wizard => 1 });
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
    $fieldset->add_notes("You have the following URL data attached:")->set_attribute('class', 'spaced');
    $fieldset->add_field({'type'=>'checkbox', 'name' => 'code', 'value' => $_->{'code'}, 'label' => $_->{'name'}, 'notes' => $_->{'url'}}) for @urls;
  }

  my @bams = $session->get_data(type => 'bam');
  if (@bams) {
    $has_data = 1;
    $fieldset->add_notes("You have the following BAM sources attached:")->set_attribute('class', 'spaced');
    $fieldset->add_field({'type'=>'checkBbx', 'name' => 'code', 'value' => $_->{'code'}, 'label' => $_->{'name'}, 'notes' => $_->{'url'}}) for @bams;
  }

  $fielset->add_notes("You have no temporary data sources to save. Click on 'Attach DAS' or 'Attach URL' in the left-hand menu to add sources.") unless $has_data;

  return $form->render;
}

1;
