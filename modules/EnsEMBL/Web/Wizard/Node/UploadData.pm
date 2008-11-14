package EnsEMBL::Web::Wizard::Node::UploadData;

### Contains methods to create nodes for a wizard that uploads data to the userdata db

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Tools::Encryption qw(checksum);
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
  my $temp_data = $self->object->get_session->get_tmp_data;
  if ($temp_data && %$temp_data) {
    $self->parameter('wizard_next', 'overwrite_warning');
  } else {
    $self->parameter('wizard_next', 'select_file');
  }
}

sub overwrite_warning {
  my $self = shift;
  
  $self->add_element('type'=>'Information', 'value'=>'You have unsaved data uploaded. Uploading a new file will overwrite this data, unless it is first saved to your user account.');
  
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    $self->add_element( type => 'CheckBox', name => 'save', label => 'Save current data to my account', 'checked'=>'checked' );
    $self->add_element( type => 'String', name => 'name', label => 'Name' );
  }
  else {
    $self->add_element('type'=>'Information', 'classes' => ['no-bold'], 'value'=>'<a href="/Account/Login" class="modal_link">Log into your user account</a> to save this data.');
  }
}

sub overwrite_save {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($self->object->param('save') && $user) {
    ## Save current temporary data upload to user account
    my $data = $self->object->get_session->get_tmp_data;
    $data->{'name'} = $self->object->param('name') if $self->object->param('name');
    $user->add_to_uploads($data);
    $self->object->get_session->purge_tmp_data;
  }
  $self->parameter('wizard_next', 'select_file');
}

sub select_file {
  my $self = shift;

  $self->title('Select File to Upload');
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  my $current_species = $ENV{'ENSEMBL_SPECIES'};
  if (!$current_species || $current_species eq 'common') {
    $current_species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }
  $self->notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on Ensembl coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL?$referer" class="modal_link">attach it to Ensembl</a> without uploading.)});

  $self->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

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
    my $name = $self->object->param('name');
    unless ($name) {
      my @orig_path = split('/', $self->object->param($method));
      $name = $orig_path[-1];
    }

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
    $self->object->get_session->add_data(
      type      => 'upload', 
      filename  => $file->filename, 
      code      => $file->md5, 
      md5       => $file->md5, 
      name      => $name,
      species   => $self->object->param('species'),
      format    => $format,
      assembly  => $self->object->param('assembly'),
    );

    if (!$format) {
      ## Get more input from user
      $self->parameter(format      => 'none');
      $self->parameter(code        => $file->md5);
      $self->parameter(wizard_next => 'more_input');
    }
    else {
      $self->parameter(format      => $format);
      $self->parameter(code        => $file->md5);
      $self->parameter(wizard_next => 'upload_feedback');
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
  $self->add_element(type => 'Hidden', name => 'code', value => $self->object->param('code'));
  $self->add_element(type => 'Information', value => 'Your file format could not be identified - please select an option:');
  $self->add_element(type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats);
}

sub upload_feedback {
### Node to confirm data upload
  my $self = shift;
  $self->title('File Uploaded');

  ## Set format if coming via more_input
  if ($self->object->param('format')) {
    $self->object->get_session->set_data(
      type   => 'upload',
      code   => $self->object->param('code'),
      format => $self->object->param('format'),
    );
  }

  my $link = $self->object->param('_referer');

  $self->add_element(type => 'Information', value => qq(Thank you - your file was successfully uploaded. Close this Control Panel to view your data));
  $self->add_element(type => 'Hidden', name => 'md5', value => $self->object->param('md5'));
}

#-------------------- DATA-SHARING NODES ---------------------------------

sub check_shareable {
## Checks if the user actually has any shareable data
  my $self = shift;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my @temp_uploads = $self->object->get_session->get_data(type => 'upload');
  my @user_uploads = $user ? $user->uploads : ();

  if (@temp_uploads || @user_uploads) { 
    $self->parameter('wizard_next', 'select_upload');
  } else {
    $self->parameter('wizard_next', 'no_shareable');
  }
}

sub no_shareable {
## Feedback page directing user to data upload
  my $self = shift;
  $self->title('No Shareable Data');
  $self->add_element(
    type  => 'Information',
    value => "You have no shareable data. Please click on the 'Upload Data' if you wish to share data with colleagues or collaborators.",
  );
}

sub select_upload {
## Node to select which data will be shared
  my $self = shift;
  $self->title('Share Your Data');

  $self->notes({
    heading => 'How it works',
    text    => qq(You can share your uploaded data with anyone, even if they don't have an
                  Ensembl account. Just select one or more of your uploads and click on 'Next'
                  to get a shareable URL.
                  Please note that these URLs expire after 72 hours, but if you save the upload
                  to your account, you can create a new shareable URL at any time.)
  });
  
  $self->set_layout('narrow-labels');

  my @values = ();

  ## Session data
  my @session_uploads = $self->object->get_session->get_data(type => 'upload');
  foreach my $upload (@session_uploads) {
    push @values, {
      name  => 'Temporary upload: ' . $upload->{name},
      value => $upload->{code},
    };
  }

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    foreach my $record ($user->uploads) {
      push @values, {
        name  => 'Saved upload: '. $record->name,
        value => $record->id,
      };
    }
  }
  
  ## If only one record, have the checkbox automatically checked
  my $autoselect = (@values == 1) ? [$values[0]->{'value'}] : '';

  $self->add_element(
    type   => 'MultiSelect',
    name   => 'share_id',
    label  => 'Uploaded files',
    value  => $autoselect,
    values => \@values
  );

  $self->parameter('wizard_next', 'check_save');
}

sub check_save {
## Check to see if the user has opted to share temporary data (which thus needs saving)
  my $self = shift;

  my @shares = ($self->object->param('share_id'));

  foreach my $code (@shares) {
    if ($code !~ /^d+$/) {
      my $data = $self->object->get_session->get_data(type => 'upload', code => $code);
      if ($data->{filename} && !$self->object->store_data(type => 'upload', code => $code)) {
        $self->parameter(wizard_next   => 'select_upload');
        $self->parameter(error_message => "Sorry, we were unable to save your file <i>$data->{name}</i> to our temporary storage area.");
        return undef;
      }
    }
  }
  
  $self->parameter(wizard_next => 'show_shareable');
  $self->parameter(share_id    => \@shares);
}

sub show_shareable {
  my $self = shift;
  $self->title('Shareable URL');

  my @shares = grep { $_ } ($self->object->param('share_id'));

  my $share_ref = join ';', (
    map { ($_ =~ /^d+$/) ? "share_ref=000000$_-". checksum($_) : "share_ref=$_" } @shares
  );

  my $url = $self->object->species_defs->ENSEMBL_BASE_URL . $self->object->param('_referer');
  $url .= $self->object->param('_referer') =~ /\?/ ? ';' : '?';
  $url .= $share_ref;

  $self->add_element('type'=>'Information', 'value' => $self->object->param('feedback'), 'style' => 'spaced');
  $self->add_element('type'=>'Information', 'value' => "To share this data, use the URL:", 'style' => 'spaced');
  $self->add_element('type'=>'Information', 'value' => $url, 'style' => 'spaced');
  $self->add_element('type'=>'Information', 'value' => 'Please note that this link will expire after 72 hours.');

}

#------------------------------ USER ELECTS TO SAVE DATA --------------------------------------

sub show_tempdata {
  my $self = shift;
  $self->title('Save Data to Your Account');

## TODO: Anne, this must display all session->get_data(type => 'upload'); data to save
##
#  my @uploads = $self->object->get_session->get_data(type => 'upload');
#  if (@uploads) {
#    $self->add_element('type'=>'Information', 'value' => "You have the following temporary data uploaded:", 'style' => 'spaced');
#    (my $species = $upload->{'species'}) =~ s/_/ /g; 
#    my $info  = 'Unsaved upload: '.$upload->{'format'}.' file for '.$upload->{'species'};
#    $self->add_element('type'=>'Information', 'value' => $info, 'style' => 'spaced');
#    $self->add_element('type'=>'String', 'name' => 'name', 'label' => 'Name of this upload', 'value' => $upload->{'name'});
#  } else {
#    $self->add_element('type'=>'Information', 'value' => "You have no temporary data uploaded. Click on 'Upload Data' in the left-hand menu to upload your file(s) to our server.");
#  }

}


## TODO: get rid of this function, it's duplicates save_upload, and does it wrong
sub save_tempdata {
  my $self = shift;

## TODO: Anne, this must save with session->store_tmp_data(type => 'upload', code => param('code'));
##
## Parse file and save to genus_species_userdata
## Move data reference from tmp to user or permanent session record if not logged in
#  if ($self->object->store_tmp_data) {
#    $self->parameter('wizard_next', 'ok_tempdata');
#  } else {
#    $self->parameter('wizard_next', 'show_tempdata');
#    $self->parameter('error_message', 'Unable to save to user account');
#  }
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


