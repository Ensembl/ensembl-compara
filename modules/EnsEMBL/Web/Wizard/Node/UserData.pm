package EnsEMBL::Web::Wizard::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Wizard::Node;

our @ISA = qw(EnsEMBL::Web::Wizard::Node);

our @formats = (
    {name => '-- Please Select --', value => ''},
    {name => 'generic', value => 'Generic'},
    {name => 'BED', value => 'BED'},
    {name => 'GBrowse', value => 'GBrowse'},
    {name => 'GFF', value => 'GFF'},
    {name => 'GTF', value => 'GTF'},
    {name => 'LDAS', value => 'LDAS'},
    {name => 'PSL', value => 'PSL'},
);

sub start {
  my $self = shift;

  my $tips = ['If your data is distributed across the genome and you wish to view small selections in detail, we recommend uploading it rather than attaching a URL.','You can also save uploaded data in your Ensembl account and reuse it later.'];

  $self->title('Upload your data');

  $self->add_notes(('heading'=>'Tips', 'list'=>$tips));
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  $self->add_element(( type => 'String', name => 'track_name', label => 'Track name', 'notes'=>'(optional)'));
  $self->add_element(( type => 'File', name => 'file', label => 'Upload file' ));
  $self->add_element(( type => 'Text', name => 'paste', label => 'or paste file content' ));
  $self->add_element(( type => 'String', name => 'url', label => 'or provide file URL' ));
  $self->add_element(( type => 'CheckBox', name => 'save', label => 'Save to my user account', 'checked'=>'checked' ));
}

sub upload {
### Node to store uploaded data
  my $self = shift;
  my $parameter = {};

  if ($self->object->param('file') || $self->object->param('paste') || $self->object->param('url')) {
    $parameter->{'wizard_next'} = 'feedback';
  }
  else {
    $parameter->{'wizard_next'} = 'start';
    $parameter->{'error_message'} = 'No data was uploaded. Please try again.';
  }

  return $parameter;
}

sub feedback {
### Node to confirm data upload
  my $self = shift;
  $self->title('File Uploaded');
  $self->add_element(( type => 'Information', value => 'Thank you - your data was successfully uploaded'));
}

sub finish {
  my $self = shift;

  $self->title('Finished');
  $self->text_above("<p>And we're done. All your data are belong to us.");
}


1;


