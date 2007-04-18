package EnsEMBL::Web::Commander::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Commander::Node;

our @ISA = qw(EnsEMBL::Web::Commander::Node);

sub start {
  my $self = shift;

  $self->title('Where is the Data?');
  my $text = qq(
<ul class="spaced">
<li><a href="/common/user_data_wizard?node_name=file_upload;previous_node=start;source=local">In a file on my local machine</a></li>
<li>On the internet:
<ul>
  <li><a href="/common/user_data_wizard?node_name=file_info;previous_node=start;source=url">In a file on a web server</a> (URL-based data)</li>
  <li><a href="/common/user_data_wizard?node_name=das_servers;data_type=UserDAS;DASdomain=das.ensembl.org">On an existing DAS server</a></li>
  <li><a href="/info/data/external_data/das/das_server.html">I would like help in setting up my own DAS server</a></li>);
  if ($ENV{'ENSEMBL_USER_ID'}) {
    $text .= qq(
<li><a href="/common/user_data_wizard?node_name=account">I have already uploaded the data to my Ensembl user account</li>);
  }
  $text .= qq(</ul>
</li>
</ul>
  );
  $self->text_above($text);
}

sub das_servers {
  my $self = shift;
  $self->title('Select a Server');

  my $default = $self->object->param("DASdomain");
  my $server_list = $self->object->Obj->get_DAS_server_list($self->object->species_defs, $default);

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

sub file_info {
  my $self = shift;
  $self->title('How is your data distributed on the genome?');

  $self->add_element(( type => 'RadioButton', name => 'distribution', id => 'dist_1', value => 'global', label => 'Across the genome', checked => 'checked'));
  $self->add_element(( type => 'RadioButton', name => 'distribution', id => 'dist_2', value => 'local', label => 'Concentrated in one region'));

  ## TO DO: Replace with built-in option code

}

sub file_upload {
  my $self = shift;
  $self->title('File Upload');

  $self->text_above('<p>Tip: you can upload more than one data file, and configure them as separate tracks.</p>');

  my @formats = (
    {name => '-- Please Select --', value => ''},
    {name => 'generic', value => 'Generic'},
    {name => 'BED', value => 'BED'},
    {name => 'GBrowse', value => 'GBrowse'},
    {name => 'GFF', value => 'GFF'},
    {name => 'GTF', value => 'GTF'},
    {name => 'LDAS', value => 'LDAS'},
    {name => 'PSL', value => 'PSL'},
  );

  my $checked;
  if ($self->object->param('distribution') && $self->object->param('distribution') eq 'global') {
    $self->add_element(( type => 'Information', value => 'We recommend saving your data in an Ensembl account for quicker page loads'));
    $checked = 'yes';
  }

  if ($ENV{'ENSEMBL_USER_ID'}) {
    $self->add_element(( type => 'CheckBox', name => 'save', label => 'Save to my Ensembl user account', checked => $checked, notes => ''));
  }
  else {
    $self->add_element(( type => 'Information', value => 'Please <a href="javascript:login_link();">log in</a> or <a href="/common/user/register">register</a> if you wish to save your data in an Ensembl account'));
  }
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  $self->add_element(( type => 'String', name => 'track_name', label => 'Track name (optional)'));

  if ($self->object->param('source') eq 'url') {
    $self->add_element(( type => 'String', name => 'url', label => 'File URL' ));
  }
  else {
    $self->add_element(( type => 'Text', name => 'paste', label => 'Paste file content' ));
    $self->add_element(( type => 'File', name => 'upload', label => 'or upload file' ));
  }

}

sub finish {
  my $self = shift;

  $self->title('Finished');
  my $point_of_origin;
  $self->destination($point_of_origin);
  $self->text_above("<p>And we're done. All your data are belong to us.");
}


1;


