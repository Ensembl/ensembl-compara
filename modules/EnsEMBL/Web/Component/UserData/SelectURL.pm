package EnsEMBL::Web::Component::UserData::SelectURL;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::RegObj;

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
  my $object = $self->object;

  my $form = $self->modal_form('select_url', '/'.$object->data_species.'/UserData/AttachURL', {'wizard' => 1, 'back_button' => 0});

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $object->data_species;

  # URL-based section
  $form->add_notes({'heading'=>'Tip', 'text'=>qq(Accessing data via a URL can be slow if the file is large, but the data you see is always the same as the file on your server. For faster access, you can <a href="/$current_species/UserData/Upload?$referer" class="modal_link">upload files</a> to $sitename (only suitable for small, single-species datasets).)});

  $form->add_element('type'  => 'String',
                     'name'  => 'url',
                     'label' => 'File URL',
                     'size'   => '30',
                     'value' => $object->param('url'),
                     'notes' => '( e.g. http://www.example.com/MyProject/mydata.gff )');

  $form->add_element('type'  => 'String',
                     'name'  => 'name',
                     'label' => 'Name for this track',
                     'size'   => '30',
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
