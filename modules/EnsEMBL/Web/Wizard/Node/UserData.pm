package EnsEMBL::Web::Wizard::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Wizard::Node;

our @ISA = qw(EnsEMBL::Web::Wizard::Node);

sub start {
  my $self = shift;

  $self->title('Where is the Data?');
  $self->add_element(( type => 'RadioButton', name => 'location', value => 'local', 
                      label => 'Offline', notes => 'In a file on my local machine'));
  $self->add_element(( type => 'RadioButton', name => 'location', value => 'das', 
                      label => 'On the Internet', notes => 'On a DAS server'));
  if ($ENV{'ENSEMBL_USER_ID'}) {
    $self->add_element(( type => 'RadioButton', name => 'location', value => 'account', 
                      label => ' ', notes => 'I have already uploaded the data to my Ensembl user account'));
  }
  $self->add_element(( type => 'RadioButton', name => 'location', value => 'url', 
                      label => ' ', notes => 'In a file on a webserver (i.e. URL-based data)'));
  $self->add_element(( type => 'CheckBox', name => 'help', value => 'yes', 
                      label => ' ', notes => 'Suggest the best way to access my URL data', checked => 'checked'));
  $self->text_below(qq(If you would like help in setting up your own DAS server, please see our <a href="/info/using/external_data/das/das_server.html">DAS documentation</a></li>));
}

sub start_logic {
  my $self = shift;
  my $parameter = {};
  if ($self->object->param('location') eq 'das') {
    $parameter->{'wizard_next'} = 'das_servers';
  }
  elsif ($self->object->param('location') eq 'url') {
warn "URL needs help? ", $self->object->param('help');
    if ($self->object->param('help')) {
      $parameter->{'wizard_next'} = 'distribution';
    }
    else {
      $parameter->{'wizard_next'} = 'url_data';
    }
  }
  else {
    $parameter->{'wizard_next'} = 'file_upload';
  }
  return $parameter;
}

sub distribution {
  my $self = shift;
  $self->title('How is your data distributed on the genome?');

  $self->add_element(( type => 'RadioButton', name => 'distribution', id => 'dist_1', value => 'global', label => 'Across the genome', checked => 'checked'));
  $self->add_element(( type => 'RadioButton', name => 'distribution', id => 'dist_2', value => 'local', label => 'Concentrated in one region'));
}

sub file_guide {
  my $self = shift;
  $self->title('Please select an upload method');
  my $text;
  if ($self->object->param('distribution') eq 'global') {
    $text = qq(<p>If you wish to view your data in ContigView, we recommend uploading it to an Ensembl user account, otherwise performance may be slow.</p>);
  }
  else {
    $text = qq(<p>Storing your data in your Ensembl account makes it easy to reuse and may improve performance, 
whereas attaching a URL source makes it easy to update your data.</p>);

  }

  unless ($ENV{'ENSEMBL_USER_ID'}) {
    $text .= qq(<p>Please note that you must be logged in to upload data: <a href="javascript:login_link();">log in</a> or <a href="/common/user/register">register</a></p>);
  }

  $self->text_above($text);

  $self->add_element(( type => 'RadioButton', name => 'method', value => 'upload', label => 'Upload data to my Ensembl account', checked => 'checked'));
  $self->add_element(( type => 'RadioButton', name => 'method', value => 'url', label => 'Attach data via URL', checked => 'checked'));
}

sub file_logic {
  my $self = shift;
  my $parameter = {};
  if ($self->object->param('method') eq 'upload') {
    $parameter->{'wizard_next'} = 'file_upload';
  }
  else {
    $parameter->{'wizard_next'} = 'url_data';
  }
  return $parameter;
}

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

sub file_details {
  my $self = shift;
  $self->title('File Upload');

  $self->add_element(( type => 'Information', value => 'Tip: you can upload more than one data file, and configure them as separate tracks.'));
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  $self->add_element(( type => 'String', name => 'track_name', label => 'Track name (optional)'));
  $self->add_element(( type => 'File', name => 'file', label => 'Upload file' ));
  $self->add_element(( type => 'Information', value => 'OR'));
  $self->add_element(( type => 'Text', name => 'paste', label => 'Paste file content' ));
}

sub file_upload {
  my $self = shift;
  my $parameter = {};

  if ($self->object->param('file') || $self->object->param('paste')) {
  }
  else {
    $parameter->{'wizard_next'} = 'file_details';
    $parameter->{'error_message'} = 'No data was uploaded. Please try again.';
  }

  return $parameter;
}

sub file_feedback {
  my $self = shift;
}

sub user_record {
  my $self = shift;
}

sub url_data {
  my $self = shift;
  $self->title('Attach URL data');
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  $self->add_element(( type => 'String', name => 'track_name', label => 'Track name (optional)'));
  $self->add_element(( type => 'String', name => 'url', label => 'File URL' ));
}

sub das_servers {
  my $self = shift;
  $self->title('Select a Server');

  my $default = $self->object->param("DASdomain");
  my $server_list = []; # = $self->object->Obj->get_DAS_server_list($self->object->species_defs, $default);

  $self->add_element(( type => 'DropDown', name => 'server', label => 'Select an existing server',
                            'select' => 'select', value => $default, values => $server_list ));
  $self->add_element(( type => 'String', name => 'filter', id => 'filter', label => 'Filter sources by name/URL/description (optional)' ));
  $self->add_element(( type => 'Information', value => 'OR'));
  $self->add_element(( type => 'String', name => 'new_server', label => 'Add another DAS server' ));
}

sub das_sources {
  my $self = shift;
  $self->title('Add Sources');

  ## To Do - get sources dynamically from object
  my @sources = (
  {'value' => 'source_1', 'name' => qq(<h4 class="alt">Source 1</h4><strong>http://db.systemsbiology.net:8080/das/HumanPlasma_ALL_Ens32_P09</strong><br />Peptides from the PeptideAtlas build HumanPlasma_ALL_Ens32_P09<br /><a href="javascript:X=window.open('http://db.systemsbiology.net:8080/das/HumanPlasma_ALL_Ens32_P09', 'DAS source details', 'left=50,top=50,resizable,scrollbars=yes');X.focus();void(0);">details about PeptideAtlas build HumanPlasma_ALL_Ens32_P09</a><br /><br />)},
  {'value' => 'source_2', 'name' => qq(<h4 class="alt">Source 2</h4><strong>http://db.systemsbiology.net:8080/das/Human_2006_06_Ens39_P09</strong><br />Peptides from the PeptideAtlas build Human_P0.9_Ens39_NCBI36<br /><a href="javascript:X=window.open('http://db.systemsbiology.net:8080/das/Human_2006_06_Ens39_P09', 'DAS source details', 'left=50,top=50,resizable,scrollbars=yes');X.focus();void(0);">details about PeptideAtlas build Human_2006_06_Ens39_P09</a><br /><br />)},
  {'value' => 'source_3', 'name' => qq(<h4 class="alt">Source 3</h4>)},
);
  $self->add_element(( type => 'MultiSelect', name => 'source', 'noescape' => 1, class => 'radiocheck1col',
                           values => \@sources ));
  $self->add_element(( type => 'String', name => 'other_source', label => 'Or other DAS source' ));
}

sub conf_tracks {
  my $self = shift;
}

sub finish {
  my $self = shift;

  $self->title('Finished');
  my $point_of_origin;
  $self->destination($point_of_origin);
  $self->text_above("<p>And we're done. All your data are belong to us.");
}


1;


