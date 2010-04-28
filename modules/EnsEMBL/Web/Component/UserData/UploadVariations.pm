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
  my $variation_limit = 750;

  my $html;
  my $form = $self->modal_form('select', $action_url,);
  $form->add_notes({ 
    'heading'=>'IMPORTANT NOTE:',
    'text'=>qq(<p class="space-below">Data should be uploaded as a list of tab separated values for more information 
              on the expected format see <a href="/info/website/upload/index.html#Consequence">here.</a></p>
              <p>There is a limit of $variation_limit variations that can be processed at any one time. 
              You can upload a file that contains more entries, however anything after the $variation_limit 
              line will be ignored. If your file contains more than $variation_limit variations you can split 
              your file into smaller chunks and process them one at a time, or you may wish to use the 
              <a href="/info/docs/api/variation/variation_tutorial.html#Consequence">variation API</a> or a standalone 
              <a href="ftp://ftp.ensembl.org/pub/misc-scripts/SNP_effect_predictor_1.0/">perl script</a> which you 
              can run on your own machine to generate the same results as this web tool. </p>
  )});
  my $subheader = 'Upload file';

   ## Species now set automatically for the page you are on
  my @species;
  foreach my $sp ($object->species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $object->species_defs->species_label($sp, 1)};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;

  $form->add_element( type => 'Hidden', name => 'consequence_mapper', 'value' => 1);
  $form->add_element( type => 'Hidden', name => 'upload_format', 'value' => 'snp');
  $form->add_element('type' => 'SubHeader', 'value' => $subheader);
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
  );
  $form->add_element( type => 'Hidden', name => 'variation_limit', 'value' => $variation_limit);
  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );
  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );
 

  $html .= $form->render;
  return $html;
}


1;
