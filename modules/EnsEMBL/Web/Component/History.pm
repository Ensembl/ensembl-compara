package EnsEMBL::Web::Component::History;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::RegObj;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw(EnsEMBL::Web::Component);

sub stage1 {
  my ($panel, $object) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form('stage1_form')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub stage1_form {
  my ($panel, $object) = @_;
  my $error;
  if ($panel->params('error')) { my $error = $panel->params->{'error'};}
  my $form = EnsEMBL::Web::Form->new( 'stage1_form', "/@{[$object->species]}/historyview", 'get' );
  if ($panel->params('error')) {
    my $error_text = $panel->params->{'error'};
    $form->add_element('type' => 'Information',
      'value' => '<p class="error">'.$error_text.' If you continue to have a problem, please contact <a href="mailto:helpdesk@ensembl.org">helpdesk@ensembl.org</a>.</strong></p>'
    );
  }
  $form->add_element(
        'type' => 'Information',
        'value' => qq(<p>
        IDHistoryView now allows you to upload a list of up to 30 stable IDs so you can retrieve the equivalent IDs in the current and previous releases. Data files should be uploaded in a plain text format 
 	    </p>));

  my $species = $object->species;  
  my $adaptor = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->newsAdaptor;
  my %id_to_species = %{$adaptor->fetch_species($SiteDefs::ENSEMBL_VERSION)};
  my @spp;
  foreach my $id (sort (values %id_to_species)){
	 push @spp, {'value' => $id, 'name' => $id} ;
  }
  $form->add_element( 
    'type'   => 'DropDown',
    'select' => 'select',
    'name'   => 'species',
    'label'  => 'Select species to retrieve IDs for ',
    'values' => \@spp,
    'value'  => $object->species,
  );
 $form->add_element(
    'type'  => 'Text',
    'name'  => 'paste_file',
    'label' => 'Paste file content',
    'rows'  => 10,
    'cols'  => '',
    'value' => '',
    'form'  => 1,
 ); 
 $form->add_element(
    'type'  => 'File',
    'name'  => 'upload_file',
    'value' => '',
    'label' => 'or upload file'
 );
# $form->add_element(
#    'type'  => 'String',
#    'name'  => 'url_file',
#    'label' => 'or use file URL',
#    'value' => ''
# );
 my @optout =(
	['html' => 'HTML'],
	['text' => 'Text'] 
 );
 my %checked = ('html' => 'yes'); 
 $form->add_element(
   'type'   => 'RadioGroup',
   'class'  => 'radiocheck',
   'name'   => 'output',
   'label'  => 'Select output format',
   'values' => [ map {{ 'value' => $_->[0], 'name' => $_->[1], 'checked' => $checked{$_->[0]} }} @optout ]
   
 );
 $form->add_element(
  'type'  => 'Submit',
  'value' => 'Upload >>',
  'name'  => 'submit',
  'class' => 'red-button'
 );
  return $form;
}

sub stage2 {
  	
}

1;
