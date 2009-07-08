package EnsEMBL::Web::Component::UserData::UploadStableIDs;

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
  return 'Select File to Upload';
}

sub content {
  my $self = shift;
  my $object = $self->object;

 my $referer = '_referer='.$object->param('_referer').';x_requested_with='.$object->param('x_requested_with');
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $object->data_species;

  ## Get assembly info
  my $html;

  my $form = $self->modal_form('select', "/$current_species/UserData/CheckConvert");
  my $subheader = 'Upload file';

   ## Species now set automatically for the page you are on
  $form->add_element( type => 'NoEdit', name => 'show_species', label => 'Species', 'value' => $self->object->species_defs->species_label($current_species));
  $form->add_element( type => 'Hidden', name => 'species', 'value' => $current_species);
  $form->add_element( type => 'Hidden', name => 'id_mapper', 'value' => 1);
  $form->add_element('type' => 'SubHeader', 'value' => $subheader);

  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'String', name => 'url', label => 'or provide file URL', size => 30 );
 

  $html .= $form->render;
  return $html;
}


1;
