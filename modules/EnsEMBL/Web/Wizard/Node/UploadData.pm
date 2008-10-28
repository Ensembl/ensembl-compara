package EnsEMBL::Web::Wizard::Node::UploadData;

### Contains methods to create nodes for a wizard that uploads data to the userdata db

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::File::Text;
use EnsEMBL::Web::RegObj;
use Data::Dumper;
use base qw(EnsEMBL::Web::Wizard::Node);

our @formats = (
    {name => '-- Please Select --', value => ''},
    {name => 'generic', value => 'Generic'},
    {name => 'BED', value => 'BED'},
    {name => 'GBrowse', value => 'GBrowse'},
    {name => 'GFF', value => 'GFF'},
    {name => 'GTF', value => 'GTF'},
#    {name => 'LDAS', value => 'LDAS'},
    {name => 'PSL', value => 'PSL'},
    {name => 'WIG', value => 'WIG'},
);


#----------------------------- FILE UPLOAD NODES -----------------------

sub check_session {
  my $self = shift;
  my $temp_data = $self->object->get_session->get_tmp_data('upload');
  if (keys %$temp_data) {
    $self->parameter('wizard_next', 'overwrite_warning');
  }
  else {
    $self->parameter('wizard_next', 'select_file');
  }
}

sub overwrite_warning {
  my $self = shift;
  
  $self->add_element(('type'=>'Information', 'value'=>'You have unsaved data uploaded. Uploading a new file will overwrite this data, unless it is first saved to your user account.'));
  
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    $self->add_element(( type => 'CheckBox', name => 'save', label => 'Save current data to my account', 'checked'=>'checked' ));
  }
  else {
    $self->add_element(('type'=>'Information', 'value'=>'<a href="/Account/Login" class="modal_link">Log into your user account</a> to save this data.'));
  }
}

sub select_file {
  my $self = shift;

  $self->title('Select File to Upload');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($self->object->param('save') && $user) {
    ## Save current temporary data upload to user account
    $user->add_to_uploads($self->object->get_session->get_tmp_data('upload'));
    $self->object->get_session->purge_tmp_data('upload');
  }

  my $current_species = $ENV{'ENSEMBL_SPECIES'};
  if (!$current_species || $current_species eq 'common') {
    $current_species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  $self->notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on Ensembl coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL">attach it to Ensembl</a> without uploading.)});

  ## Species now set automatically for the page you are on
  $self->add_element( type => 'NoEdit', name => 'show_species', label => 'Species', 'value' => $self->object->species_defs->species_label($current_species));
  $self->add_element( type => 'Hidden', name => 'species', 'value' => $current_species);

  ## Work out if multiple assemblies available
  my $assemblies = $self->_get_assemblies($current_species);
  my %assembly_element = ( name => 'assembly', label => 'Assembly', 'value' => $assemblies->[0]);

  if (scalar(@$assemblies) > 1) {
    my $assembly_list = [];
    foreach my $a (@$assemblies) {
      push @$assembly_list, {'name' => $a, 'value' => $a};
    }
    $assembly_element{'type'}   = 'DropDown';
    $assembly_element{'select'} = 'select'; 
    $assembly_element{'values'} = $assembly_list;
  }
  else {
    $assembly_element{'type'} = 'Hidden';
  }
  $self->add_element(%assembly_element);

  $self->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $self->add_element( type => 'String', name => 'url', label => 'or provide file URL' );
  
}

sub upload {
### Node to store uploaded data
  my $self = shift;

  my $method = $self->object->param('url') ? 'url' : 'file';
  if ($self->object->param($method)) {
   
    ## Get original path, so can save file name as default name for upload
    my @orig_path = split('/', $self->object->param($method));

    ## Cache data (File::Text knows whether to use memcached or temp file)
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs);
    $file->set_cache_filename('user_'.$method);
    $file->save($self->object, $method);

    ## Identify format
    my $data = $file->retrieve;
    my $parser = EnsEMBL::Web::Text::FeatureParser->new();
    $parser = $parser->init($data);
    my $format = $parser->{'_info'}->{'format'};

    $self->parameter('parser', $parser);
    $self->parameter('species', $self->object->param('species'));
    ## Attach data species to session
    $self->object->get_session->set_tmp_data('upload' => {
      'filename'  => $file->filename, 
      'name'      => $orig_path[-1],
      'species'   => $self->object->param('species'),
      'format'    => $format,
      'assembly'  => $self->object->param('assembly'),
    });

    if (!$format) {
      ## Get more input from user
      $self->parameter('format', 'none');
      $self->parameter('wizard_next', 'more_input');
    }
    else {
      $self->parameter('format', $format);
      $self->parameter('wizard_next', 'upload_feedback');
    }
  }
  else {
    $self->parameter('wizard_next', 'select_file');
    $self->parameter('error_message', 'No data was uploaded. Please try again.');
  }
}

sub more_input {
  my $self = shift;
  $self->title('File Details');

  ## Format selector
  $self->add_element(( type => 'Information', value => 'Your file format could not be identified - please select an option:'));
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
}

sub upload_feedback {
### Node to confirm data upload
  my $self = shift;
  $self->title('File Uploaded');

  ## Set format if coming via more_input
  if ($self->object->param('format')) {
    $self->object->get_session->set_tmp_data('upload' => {'format'  => $self->object->param('format')});
  }

  my $link = $self->object->param('_referer');

  $self->add_element( 
    type  => 'Information',
    value => qq(Thank you - your file was successfully uploaded. Close this Control Panel to view your data),
  );
}

#-------------------- DATA-SHARING NODES ---------------------------------

sub check_shareable {
## Checks if the user actually has any shareable data
  my $self = shift;

  my $upload = $self->object->get_session->get_tmp_data('upload');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $user_tracks; 
  if ($user) {
    $user_tracks = $user->uploads; 
  }

  if ($upload || $user_tracks) { 
    $self->parameter('wizard_next', 'select_upload');
  }
  else {
    $self->parameter('wizard_next', 'no_shareable');
  }
}

sub no_shareable {
## Feedback page directing user to data upload
  my $self = shift;
  $self->title('No Shareable Data');

  $self->add_element('type'=>'Information', 'value'=>"You have no shareable data. Please click on the 'Upload Data' if you wish to share data with colleagues or collaborators.");
}

sub select_upload {
## Node to select which data will be shared
  my $self = shift;
  $self->title('Share Your Data');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @values = ();
  my ($name, $value);

  ## Temporary data
  my $upload = $self->object->get_session->get_tmp_data('upload');
  if ($upload && keys %$upload) {
    $name  = 'Unsaved upload: '.$upload->{'format'}.' file for '.$upload->{'species'};
    $value = 'session';
    push @values, {'name' => $name, 'value' => $value};
  }
  my @user_records = $user->uploads;
  foreach my $record (@user_records) {
    $name = 'Saved upload: '.$record->name;
    $value = $record->id;
    push @values, {'name' => $name, 'value' => $value};
  }
  ## If only one record, have the checkbox automatically checked
  my $autoselect = scalar(@values) == 1 ? [$values[0]->{'value'}] : '';

  $self->add_element('type' => 'MultiSelect', 'name' => 'share_id', 'value' => $autoselect, 'values' => \@values);

  $self->parameter('wizard_next', 'check_save');
}

sub check_save {
## Check to see if the user has opted to share temporary data (which thus needs saving)
  my $self = shift;

  my @shares = ($self->object->param('share_id'));
  $self->parameter('share_id', \@shares);
  if (grep /^session/, @shares) {
    $self->parameter('wizard_next', 'save_upload');
  }
  else {
    $self->parameter('wizard_next', 'share_url');
  }
}

sub save_upload {
## Save uploaded data to a genus_species_userdata database
  my $self = shift;

  ## Parse file and save to genus_species_userdata
  my $report = $self->object->save_to_userdata;
  my $success = $report->{'errors'} ? 0 : 1;
  if ($success) {
    my $temp_data = $self->object->get_session->get_tmp_data('upload');
    ## Delete cached file
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs, $temp_data->{'filename'});
    $file->delete;
    ## Delete file name in session_record, but keep session record as we need it later
    $self->object->get_session->set_tmp_data('upload' => {'filename' => ''});
    ## Save logic names to session record
    my $analyses = $report->{'analyses'};
    my @logic_names = ref($analyses) eq 'ARRAY' ? @$analyses : ($analyses);
    $self->object->get_session->set_tmp_data('upload' => {'analyses' => join(', ', @logic_names)});
    ## If the user is logged in, automatically save this record so that the data will "survive" 
    ## any purging of session records or overwriting of the temporary session data 
    ## As long as the analysis IDs are the same, identical session_record and user_record
    ## will only generate one track in the web display
    my $user = $ENSEMBL_WEB_REGISTRY->get_user;
    if ($user) {
      $self->object->copy_to_user;
    } 
    $self->parameter('wizard_next', 'share_url');
  }
  else {
    $self->parameter('wizard_next', 'database_error');
    $self->parameter('error_message', 'Sorry, we were unable to save your file to our temporary storage area.');
  }
}

sub database_error {
  my $self = shift;
  $self->title('Database Error');
}

sub share_url {
  my $self = shift;
  $self->title('Shareable URL');

  my $share_data  = $self->object->get_session->share_tmp_data('upload');
  my @ids = split(', ', $share_data->{analyses});
  my @share_refs;
  foreach my $id (@ids) {
    push @share_refs, 'share_ref=ss-000000'. $id .'-'.EnsEMBL::Web::Tools::Encryption::checksum($id);
  }
                    
  my $url = $self->object->species_defs->ENSEMBL_BASE_URL .$self->object->param('_referer');
  $url .= $self->object->param('_referer') =~ /\?/ ? ';' : '?';
  $url .= join(';', @share_refs);

  $self->add_element('type'=>'Information', 'value' => $self->object->param('feedback'), 'style' => 'spaced');
  $self->add_element('type'=>'Information', 'value' => "To share this data, use the URL:", 'style' => 'spaced');
  $self->add_element('type'=>'Information', 'value' => $url, 'style' => 'spaced');
  $self->add_element('type'=>'Information', 'value' => 'Please note that this link will expire after 72 hours.');

}

#------------------------------ USER ELECTS TO SAVE DATA --------------------------------------

sub show_tempdata {
  my $self = shift;
  $self->title('Save Data to Your Account');

  my $upload = $self->object->get_session->get_tmp_data('upload');
  if ($upload && keys %$upload) {
    $self->add_element('type'=>'Information', 'value' => "You have the following temporary data uploaded:", 'style' => 'spaced');
    (my $species = $upload->{'species'}) =~ s/_/ /g; 
    my $info  = 'Unsaved upload: '.$upload->{'format'}.' file for '.$upload->{'species'};
    $self->add_element('type'=>'Information', 'value' => $info, 'style' => 'spaced');
    $self->add_element('type'=>'String', 'name' => 'name', 'label' => 'Name of this upload', 'value' => $upload->{'name'});
  }
  else {
    $self->add_element('type'=>'Information', 'value' => "You have no temporary data uploaded. Click on 'Upload Data' in the left-hand menu to upload your file(s) to our server.");
  }
}

sub save_tempdata {
  my $self = shift;

  my $temp_data = $self->object->get_session->get_tmp_data('upload');
  my $name = $self->object->param('name') || 'uploaded file';
  $self->object->get_session->set_tmp_data('upload' => {'name' => $name});

  ## Has this data already been parsed and saved?
  my $parsed;
  if (!$temp_data->{'analyses'}) {
    my $report = $self->object->save_to_userdata;
    unless ($report->{'errors'}) {
      ## Delete file name in session_record
      $self->object->get_session->set_tmp_data('upload' => {'filename' => ''});
      ## Save logic names to session record
      my $analyses = $report->{'analyses'};
      my @logic_names = ref($analyses) eq 'ARRAY' ? @$analyses : ($analyses);
      $self->object->get_session->set_tmp_data('upload' => {'analyses' => join(', ', @logic_names)});
    }
  }

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && !$self->parameter('error_message')) {
    my $copied = $self->object->copy_to_user;
    if ($copied) { 
      ## Delete cached file
      my $file = new EnsEMBL::Web::File::Text($self->object->species_defs, $temp_data->{'filename'});
      $file->delete;
      ## Delete temporary session data
      $self->object->get_session->purge_tmp_data('upload');
      $self->parameter('wizard_next', 'ok_tempdata');
    }
    else {
      $self->parameter('wizard_next', 'show_tempdata');
      #$self->parameter('error_message', 'Unable to save to user account');
    }
  }
  else {
    $self->parameter('wizard_next', 'show_tempdata');
    #$self->parameter('error_message', 'Unable to save to user account');
  }  
}

sub ok_tempdata {
  my $self = shift;
  $self->title('Data Saved');
  $self->add_element('type'=>'Information', 'value' => 'Your file was saved to your user account.');
}

#------------------------ PRIVATE METHODS -----------------------

sub _get_assemblies {
### Tries to identify coordinate system from file contents
### If on chromosomal coords and species has multiple assemblies, 
### return assembly info
  my ($self, $species) = @_;

  my @assemblies = split(',', $self->object->species_defs->get_config($species, 'CURRENT_ASSEMBLIES'));
  return \@assemblies;
}

1;


