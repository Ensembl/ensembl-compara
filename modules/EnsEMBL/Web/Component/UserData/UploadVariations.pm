package EnsEMBL::Web::Component::UserData::UploadVariations;

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
  return 'Select File to Upload';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $object->data_species;
  my $action_url = $object->species_path($current_species)."/UserData/CheckConvert";

  ## Get assembly info
  my $html;

  ## Should default to 5.0MB :)
  my $max_upload_size = sprintf("%.1f", $object->species_defs->CGI_POST_MAX / 1048576).'MB';

  my $form = $self->modal_form('select', $action_url,);
  $form->add_notes({ 
    'heading'=>'IMPORTANT NOTE:',
    'text'=>qq(<p>Data should be uploaded as a list of tab separated values for more information 
              on the expected format see <a href="/info/website/upload/index.html#Consequence">here.</a> 
              There is also a $max_upload_size limit on data uploads.</p>
  )});
  my $subheader = 'Upload file';

   ## Species now set automatically for the page you are on
  my @species;
  foreach my $sp ($object->species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $object->species_defs->species_label($sp, 1)};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;

  $form->add_element( type => 'Hidden', name => 'consequence_mapper', 'value' => 1);
  $form->add_element( type => 'Hidden', name => 'upload_format', 'value' => 'consequence');
  $form->add_element('type' => 'SubHeader', 'value' => $subheader);
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
  );
  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );
  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );
 

  $html .= $form->render;
  return $html;
}


1;
