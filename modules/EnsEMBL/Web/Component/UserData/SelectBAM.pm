package EnsEMBL::Web::Component::UserData::SelectBAM;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  
  my $current_species = $hub->species_path($hub->data_species);
  my $form = $self->modal_form('select_bam', "$current_species/UserData/AttachBAM", {'wizard' => 1, 'back_button' => 0});
  my $user = $hub->user;
  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;

  # URL-based section
  $form->add_notes({'heading'=>'Tip', 'text'=> qq(
    When attaching a BAM file, both the BAM file and it's index file should be present on your web server and named correctly. The BAM file should have a ".bam" extension, and the index file should have a ".bam.bai" extension, E.g: MyData.bam, MyData.bam.bai
  )});

  $form->add_element('type'  => 'URL',
                     'name'  => 'url',
                     'label' => 'BAM File URL',
                     'size'  => '30',
                     'value' => $hub->param('url'),
                     'notes' => '( e.g. http://www.example.com/MyProject/MyData.bam )');

  $form->add_element('type'  => 'String',
                     'name'  => 'name',
                     'label' => 'Name for this track',
                     'size'  => '30',
                     );

  if ($user && $user->id) {
    $form->add_element('type'    => 'CheckBox',
                       'name'    => 'save',
                       'label'   => 'Save URL to my account',
                       'notes'   => 'N.B. Only the file address will be saved, not the data itself',
                       );
  }

  return $form->render;
}

1;
