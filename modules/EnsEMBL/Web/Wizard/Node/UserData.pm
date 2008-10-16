package EnsEMBL::Web::Wizard::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use Data::Bio::Text::FeatureParser;
use EnsEMBL::Web::File::Text;
use EnsEMBL::Web::Wizard::Node;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::DASConfig;
require Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Wizard::Node);
my $DEFAULT_CS = 'DnaAlignFeature';
my $DAS_DESC_WIDTH = 120;

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
  my $parameter = {};
  my $temp_data = $self->object->get_session->get_tmp_data;
  if ($temp_data) {
    $parameter->{'wizard_next'} = 'overwrite_warning';
  }
  else {
    $parameter->{'wizard_next'} = 'select_file';
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
    my $upload = $self->object->get_session->get_tmp_data;
  }

  my $current_species = $ENV{'ENSEMBL_SPECIES'};
  if ($current_species eq 'common') {
    $current_species = '';
  }
  if (!$current_species) {
    $current_species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }
  my @valid_species = sort $self->object->species_defs->valid_species;
  my $species = [];
  foreach my $sp (@valid_species) {
    (my $name = $sp) =~ s/_/ /g;
    push @$species, {'name' => $name, 'value' => $sp}; 
  }

  $self->notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on Ensembl coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/Attach">attach it to Ensembl</a> without uploading.)});
  $self->add_element(( type => 'DropDown', name => 'species', label => 'Species', select => 'select', values => $species, 'value' => $current_species));
  $self->add_element(( type => 'File', name => 'file', label => 'Upload file' ));
  $self->add_element(( type => 'String', name => 'url', label => 'or provide file URL' ));
  
}

sub upload {
### Node to store uploaded data
  my $self = shift;
  my $parameter = {};

  my $method = $self->object->param('url') ? 'url' : 'file';
  if ($self->object->param($method)) {
    
    ## Cache data (File::Text knows whether to use memcached or temp file)
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs);
    $file->set_cache_filename('user_'.$method);
    $file->save($self->object, $method);

    ## Identify format
    my $data = $file->retrieve;
    my $parser = Data::Bio::Text::FeatureParser->new();
    $parser = $parser->init($data);
#    warn Dumper $parser;
    my $format = $parser->{'_info'}->{'format'};

    $parameter->{'parser'} = $parser;
    ## Attach data species to session
    $self->object->get_session->set_tmp_data(
                  'filename'  => $file->filename, 
                  'species'   => $self->object->param('species'),
                  'format'    => $format,
    );
    $self->object->get_session->save_tmp_data;

    ## Work out if multiple assemblies available
    my $assemblies = $self->_get_assemblies($self->object->param('species'));

    if (scalar(@$assemblies) > 1 || !$format) {
      ## Get more input from user
      if (scalar(@$assemblies)) {
        $parameter->{'species'} = $self->object->param('species');
      }
      if (!$format) {
        $parameter->{'format'} = 'none';
      }
      $parameter->{'wizard_next'} = 'more_input';
    }
    else {
      $parameter->{'assembly'} = $assemblies->[0];
      $parameter->{'format'} = $format;
      $parameter->{'wizard_next'} = 'upload_feedback';
    }
  }
  else {
    $parameter->{'wizard_next'} = 'select_file';
    $parameter->{'error_message'} = 'No data was uploaded. Please try again.';
  }

  return $parameter;
}


sub more_input {
  my $self = shift;
  $self->title('File Details');

  ## Format selector
  if ($self->object->param('format') eq 'none') {
    $self->add_element(( type => 'Information', value => 'Your file format could not be identified - please select an option:'));
    $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  }

  ### Assembly selector
  if ($self->object->param('species')) {
    my $assemblies = $self->_get_assemblies($self->object->param('species'));
    $self->add_element(( type => 'Information', value => 'This species has more than one assembly in Ensembl. If your data uses chromosomal coordinates, please specify the assembly'));
    my $values = [];
#    push @$values, {'name'=>'--- Non-chromosomal ---', 'value'=>'ensembl_peptide'};
    foreach my $assembly (@$assemblies) {
      push @$values, {'name'=>$assembly, 'value'=>$assembly};
    }
    $self->add_element(( type => 'DropDown', name => 'assembly', label => 'Assembly', select => 'select', values => $values));
  }

}

sub upload_feedback {
### Node to confirm data upload
  my $self = shift;
  $self->title('File Uploaded');

  if ($self->object->param('assembly')) {
    $self->object->get_session->set_tmp_data('assembly' => $self->object->param('assembly'));
  }
  if ($self->object->param('format')) {
    $self->object->get_session->set_tmp_data('format'  => $self->object->param('format'));
  }
  $self->object->get_session->save_tmp_data;

  my $link = $self->object->param('_referer');

  $self->add_element( 
    type  => 'Information',
    value => qq(Thank you - your file was successfully uploaded. <a href="javascript:return_to_parent('$link')">Exit this Control Panel</a> to view your data),
  );
}

sub check_shareable {
## Checks if the user actually has any shareable data
  my $self = shift;
  my $parameter = {};

  my $upload = $self->object->get_session->get_tmp_data;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $user_tracks = 0; ## TO DO!
  if ($user) {
  }

  if ($upload || $user_tracks) {
#    $parameter->{'wizard_next'} = 'select_upload';
    $parameter->{'wizard_next'} = 'save_upload';
  }
  else {
    $parameter->{'wizard_next'} = 'no_shareable';
  }
  return $parameter; 
}

sub no_shareable {
## Feedback page directing user to data upload
  my $self = shift;
  $self->title('No Shareable Data');

  $self->add_element('type'=>'Information', 'value'=>'You have no shareable data. Please <a href="/UserData/Upload">upload a file</a> (maximum 5MB) if you wish to share data with colleagues or collaborators.');
}

sub select_upload {
## Node to select which data will be shared
  my $self = shift;
  my $parameter;
  $self->title('Share Your Data');

  my @values = ();
  my ($name, $value);

  ## Temporary data
  my $upload = $self->object->get_session->get_tmp_data;
  if ($upload && keys %$upload) {
    $name  = 'Unsaved upload: '.$upload->{'format'}.' file for '.$upload->{'species'};
    $value = 'session_'.$self->object->get_session->get_session_id;
    push @values, {'name' => $name, 'value' => $value};
  }
  ## Saved data - TO DO!
  my @user_records = ();
  foreach my $record (@user_records) {
    $name = 'user_';
    $value = 0;
    push @values, {'name' => $name, 'value' => $value};
  }
  ## If only one record, have the checkbox automatically checked
  my $autoselect = scalar(@values) == 1 ? [$values[0]->{'value'}] : '';

  $self->add_element('type' => 'MultiSelect', 'name' => 'share_id', 'value' => $autoselect, 'values' => \@values);

  $parameter->{'wizard_next'} = 'check_save';
  return $parameter;
}

sub check_save {
## Check to see if the user wants to share any temporary data (which thus needs saving)
  my $self = shift;
  my $parameter = {};

  my @shares = ($self->object->param('share_id'));
  $parameter->{'share_id'} = \@shares;
  if (grep /^session/, @shares) {
    $parameter->{'wizard_next'} = 'save_upload';
  }
  else {
    $parameter->{'wizard_next'} = 'share_url';
  }
  return $parameter;
}


sub share_url {
  my $self = shift;
  $self->title('Select Data to Share');

  my $share_data  = $self->object->get_session->share_tmp_data;
  my $share_ref   = '000000'. $share_data->{share_id} .'-'.
                    EnsEMBL::Web::Tools::Encryption::checksum($share_data->{share_id});
                    
  my $url = $self->object->species_defs->ENSEMBL_BASE_URL ."/Location/Karyotype?share_ref=ss-$share_ref";

  $self->add_element('type'=>'Information', 'value' => $self->object->param('feedback'));
  $self->add_element('type'=>'Information', 'value' => "To share this data, use the URL $url");
  $self->add_element('type'=>'Information', 'value' => 'Please note that this link will expire after 72 hours.');

}


#------------------------ SAVE DATA TO USERDATA DB -----------------------


#----------------------------- DAS/ATTACHMENT NODES -----------------------

sub select_server {
  my $self = shift;
  my $object = $self->object;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $ENV{ENSEMBL_SPECIES};
  if ($current_species eq 'common') {
    $current_species = '';
  }

  $self->title('Select a DAS server or data file');

  my @das_servers = $self->object->get_das_servers;
  my @preconf_das = map { { 'value' => $_, 'name' => $_ } } @das_servers;

  # DAS server section
  $self->add_element('type'   => 'DropDown',
                     'name'   => 'preconf_das',
                     'select' => 'select',
                     'label'  => "$sitename DAS server",
                     'values' => \@preconf_das,
                     'value'  => $object->param('preconf_das'));
  $self->add_element('type'  => 'String',
                     'name'  => 'other_das',
                     'label' => 'or other DAS server',
                     'value' => $object->param('other_das'),
                     'notes' => '( e.g. http://www.example.com/MyProject/das )');
  $self->add_element('type'  => 'String',
                     'name'  => '_das_species_filter',
                     'label' => 'Species',
                     'value' => $object->param('_das_species_filter') || $current_species,
                     'notes' => sprintf '( e.g. %s )', $object->species_defs->ENSEMBL_PRIMARY_SPECIES);
  $self->add_element('type'  => 'String',
                     'name'  => '_das_name_filter',
                     'label' => 'Filter sources',
                     'value' => $object->param('_das_name_filter'),
                     'notes' => 'by name, description or URL');
  
  $self->add_element('type'  => 'Information', 'value' => 'OR');
  
  # URL-based section
  $self->add_element('type'  => 'String',
                     'name'  => 'url',
                     'label' => 'File URL',
                     'value' => $object->param('url'),
                     'notes' => '( e.g. http://www.example.com/MyProject/mydata.gff )');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {
    $self->add_element('type'    => 'CheckBox',
                       'name'    => 'save',
                       'label'   => 'Attach source/url to my account',
                       'checked' => 'checked');
  }
}

sub source_logic {
  my $self = shift;
  my $parameter = {};

  if ($self->object->param('url')) {    
    $parameter->{'url'}         = $self->object->param('url');
    $parameter->{'wizard_next'} = 'attach_url';
  }
  else {
    $parameter->{'das_server'}  = $self->object->param('other_das') || $self->object->param('preconf_das');
    $parameter->{'das_name'}    = $self->object->param('_das_name_filter');
    $parameter->{'das_species'} = $self->object->species_defs->species_full_name( $self->object->param('_das_species_filter') );
    $parameter->{'wizard_next'} = 'select_source';
  }
  return $parameter;
}

sub select_source {
### Displays sources for the chosen server as a series of checkboxes 
### (or an error message if no dsns found)
  my $self = shift;

  $self->title('Select a DAS source');
  
  my $species_filter = $self->object->param('das_species');
  my $name_filter    = $self->object->param('das_name');
  
  if ($species_filter) {
    $self->add_element( 'type' => 'Information', 'value' => "Filtering sources by species '$species_filter'" );
  }
  if ($name_filter) {
    $self->add_element( 'type' => 'Information', 'value' => "Filtering sources by name '$name_filter'" );
  }
  
  # Get a list of DAS sources (filtered if specified)
  my $sources = $self->object->get_das_server_dsns($species_filter, $name_filter);
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  
  # Otherwise add a checkbox element for each DAS source
  else {
    
    local $Data::Dumper::Purity = 1;
    
    for my $source (@{ $sources }) {
      
      # If the description is long, shorten it and pretty it up
      my $desc  = $source->description;
      if (length $desc > $DAS_DESC_WIDTH) {
        $desc = substr $desc, 0, $DAS_DESC_WIDTH;
        $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./; # replace final space with " ..."
      }
      
## ANDY THIS MUST BE SORTED I'VE COMMITTED IT WITH THIS
## LINE TAKEN OUT AS IT IS A SECURITY HOLE.
## IT MUST NEVER GO BACK INTO CVS.

#      my $frozen = Data::Dumper->Dump( [$source],["source"] );
      my $frozen = $source      
      $self->add_element( 'type'  => 'CheckBox',
                          'name'  => 'dsns',
                          'value' => $frozen,
                          'label' => $source->label,
                          'notes' => $desc );
    } # end DAS source loop
  } # end if-else
  
}

# Page method for attaching from URL
sub attach_url {
  my $self = shift;

  my $url = $self->object->param('url');
}

# Logic method, used for checking a DAS source before adding it
sub validate_das {
  my $self      = shift;
  my $parameter = {};
  
  my @dsns = grep { $_ } $self->object->param('dsns');
  if (!@dsns) {
    $parameter->{'error_message'} = 'No sources selected';
    $parameter->{'wizard_next'}   = 'select_source';
    return $parameter;
  }

  for my $raw (@dsns) {
    my $source;
    eval ( $raw  ); # Rebuild DAS Source object from string
    die $@ if ($@);
    #$source = $$source;
    
    # If one or more source has missing details, need to fill them in and resubmit
    unless ($source->coord_systems || $self->object->param('coords')) {
      $parameter->{'wizard_next'} = 'select_species';
      return $parameter;
    }
  }
  
  $parameter->{'wizard_next'} = 'attach_das';
  return $parameter;
}

# Page method for filling in missing DAS source details
sub select_species {
  my $self = shift;
  
  $self->title('Choose a species');
  
  $self->add_element( 'type' => 'Header',      'value' => 'Species' );
  $self->add_element( 'type' => 'Information', 'value' => "Which species' do the DAS sources below have data for? If they contain data for all species' (e.g. gene or protein-based sources) choose 'all'. If the DAS sources do not use the same coordinate system, go back and add them individually." );
  
  $self->add_element('name'   => 'has_species',
                     'type'   => 'RadioButton',
                     'label'  => "Species-specific (e.g. genomic sources)",
                     'checked'=> 1,
                     'value'  => 'yes');
  my @values = map {
    { 'name' => $_, 'value' => $_, }
  } @{ $self->object->species_defs->ENSEMBL_SPECIES };
  $self->add_element('name'   => 'species',
                     'type'   => 'MultiSelect',
                     'select' => 1,
                     'value'  => [$self->object->species_defs->ENSEMBL_PRIMARY_SPECIES], # default species
                     'values' => \@values);
  $self->add_element('name'   => 'has_species',
                     'type'   => 'RadioButton',
                     'label'  => "All species' (e.g. protein-based sources)",
                     'value'  => 'no');
  
  $self->add_element( 'type' => 'Header',   'value' => 'DAS Sources' );
  
  for my $raw ($self->object->param('dsns')) {
    my $source;
    eval ( $raw  ); # Rebuild DAS Source object from string
    die $@ if ($@);
    
    if (!$source->coord_systems) {
      $self->add_element( 'type' => 'Information', 'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                              $source->label,
                                                              $source->description,
                                                              $source->homepage );
    }
    
  }
}

sub select_coords {
  my $self = shift;
  my @species = $self->object->param('has_species') eq 'yes' ? $self->object->param('species') : ();
  
  $self->title('Choose a coordinate system');
  $self->add_element( 'type' => 'Header', 'value' => 'Coordinate Systems' );
  
  for my $species (@species) {
    $self->add_element( 'type' => 'SubHeader', 'value' => "Genomic ($species)" );
    
    my $csa =  Bio::EnsEMBL::Registry->get_adaptor($species, "core", "CoordSystem");
    my @coords = sort {
      $a->rank <=> $b->rank
    } grep {
      ! $_->is_top_level
    } @{ $csa->fetch_all };
    for my $cs (@coords) {
      $self->add_element( 'type'    => 'CheckBox',
                          'name'    => 'coords',
                          'value'   => (join ':', $cs->name, $cs->version),
                          'label'   => (join ' ', ucfirst $cs->name, $cs->version) );
    }
  }
  
  $self->add_element( 'type' => 'SubHeader', 'value' => "Gene & Protein" );
  for my $cs (values %Bio::EnsEMBL::ExternalData::DAS::Coordinator::NON_GENOMIC_COORDS) {
    my ($auth, $type) = split '_', $cs->name;
    $self->add_element( 'type'    => 'CheckBox',
                        'name'    => 'coords',
                        'value'   => (join ':', $cs->name, $cs->version, $cs->species),
                        'label'   => $cs->label );
  }
}

# Page method for attaching a DAS source (saving to the session)
sub attach_das {
  my $self = shift;
  
  my @success = ();
  my @skipped = ();
  
  my $expand_coords = $self->object->param('coords');
  if ($expand_coords) {
    $expand_coords = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($expand_coords);
  }
  
  for my $raw ($self->object->param('dsns')) {
    my $source;
    eval ( $raw  ); # Rebuild DAS Source object from string
    die $@ if ($@);
    
    # Convert to Web object
    $source = EnsEMBL::Web::DASConfig->new_from_hashref($source);
    if (!$source->coord_systems) {
      $source->coord_systems([$expand_coords]);
    }
    
    
    if ($self->object->get_session->add_das($source)) {
      push @success, $source->label;
    } else {
      push @skipped, $source->label;
    }
    $self->object->get_session->save_das;
  }
  
  $self->title('Attached DAS sources');
  
  if (scalar @success) {
    $self->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources have now been attached:' );
    for my $source_label (@success) {
      $self->add_element( 'type' => 'Information', 'value' => $source_label );
    }
  }
  
  if (scalar @skipped) {
    $self->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources were already attached:' );
    for my $source_label (@skipped) {
      $self->add_element( 'type' => 'Information', 'value' => $source_label );
    }
  }
}

sub _check_extension {
### Tries to identify file format from file extension
  my ($self, $ext) = @_;
  $ext =~ s/^\.//;
  return unless $ext;
  $ext = uc($ext);
  if ($ext eq 'PSLX') { $ext = 'PSL'; }
  if ($ext ne 'BED' && $ext ne 'PSL' && $ext ne 'GFF' && $ext ne 'GTF') { 
    $ext = ''; 
  }
  return $ext;
}

sub _get_assemblies {
### Tries to identify coordinate system from file contents
### If on chromosomal coords and species has multiple assemblies, 
### return assembly info
  my ($self, $species) = @_;

  my @assemblies = split(',', $self->object->species_defs->get_config($species, 'CURRENT_ASSEMBLIES'));
  return \@assemblies;
}


sub _delete_datasource {
    my ($self, $species, $ds_name) = @_;

    my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $species );
    my $dba = $dbs->get_DBAdaptor('userdata');
    my $ud_adaptor  = $dba->get_adaptor( 'Analysis' );
    my $datasource = $ud_adaptor->fetch_by_logic_name($ds_name);
    my $error = $self->_delete_datasource_features($datasource);
    return $error if $error;

    $ud_adaptor->remove($datasource);
    return "$ds_name has been removed. ";
}


sub _delete_datasource_features {
    my ($self, $datasource) = @_;

    my $dba = $datasource->adaptor->db;
    my $source_type = $datasource->module || $DEFAULT_CS;
    my $parameter;

    if (my $feature_adaptor = $dba->get_adaptor($source_type)) { # 'DnaAlignFeature' or 'ProteinFeature'
	$feature_adaptor->remove_by_analysis_id($datasource->dbID);    
    } else {
	$parameter->{error_message} = "Could not get $source_type adaptor";
    }

    return $parameter;
}

sub save_upload {
## Save uploaded data to a genus_species_userdata database
    my $self = shift;
    my $parameter = {};

    my $tmpdata = $self->object->get_session->get_tmp_data;
    my $assembly = $tmpdata->{assembly};
    
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs);
    my $data = $file->retrieve($tmpdata->{'filename'});
    my $format  = $tmpdata->{'format'};

    
    my $parser = Data::Bio::Text::FeatureParser->new();
    $parser->init($data);
    $parser->parse($data, $format);

#    warn Dumper $parser;

    my $user = $ENSEMBL_WEB_REGISTRY->get_user;
    
    my $config = {
	'action' => 'overwrite', # or append
	'species' => $tmpdata->{species},
	'assembly' => $tmpdata->{assembly},
    };
    
    if ($user) {
	$config->{id} = $user->id;
	$config->{track_type} = 'user';
    } else {
	$config->{id} = $self->object->session->get_session_id;
	$config->{track_type} = 'session';	
    }
    
    
    foreach my $track ($parser->get_all_tracks) {
	foreach my $key (keys %$track) {
	    my $tparam = $self->_store_user_track($config, $track->{$key});
	    $parameter->{feedback} .= $tparam->{feedback};
	    if ($tparam->{error_message}) {
		$parameter->{error_message} .= $tparam->{error_message};
	    } else {
		push @{$parameter->{'share_id'}} , $tparam->{id};
	    }
	}
    }

    $parameter->{'wizard_next'} = 'share_url';
    
    return $parameter;
}

sub _store_user_track {
    my $self = shift;
    my $config = shift;
    my $track = shift;

#    warn "D:", Dumper $track;
    my $parameter = {};

    if (my $current_species = $config->{'species'}) {
	my $action = $config->{action} || 'error';

	if (my $track_name = $track->{config}->{name} || 'default') {
	    $config->{web_data}->{styles} = $track->{styles};
	    my $logic_name = join ':', $config->{track_type}, $config->{id}, $track_name;
	    my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
	    my $dba = $dbs->get_DBAdaptor('userdata');
	    my $ud_adaptor  = $dba->get_adaptor( 'Analysis' );

	    my $datasource = $ud_adaptor->fetch_by_logic_name($logic_name);
	    if ($datasource) {
		if ($action eq 'error') {
		    $parameter->{error_message} = "$track_name : Such track already exists";
		    return $parameter;
		}

		if ($action eq 'overwrite') {
		    $self->_delete_datasource_features($datasource);
		    $self->_update_datasource($datasource, $config);
		} else { #append 
		    if ($datasource->module_version ne $config->{assembly}) {
			$parameter->{error_message} = sprintf "$track_name : Can not add %s features to %s datasource", 
			$config->{assembly} , $datasource->module_version;
			return $parameter;
		    }
		}
	    } else {
		$config->{source_adaptor} = $ud_adaptor;
		$config->{track_name} = $logic_name;
		$config->{track_label} = $track_name;
		$datasource = $self->_create_datasource($config);
		
		unless ($datasource) {
		    $parameter->{error_message} =  "$track_name: Could not create datasource!";
		    return $parameter;
		}
	    }

	    my $tparam = $track->{config}->{coordinate_system} eq 'ProteinFeature' ? 
		$self->_save_protein_features($datasource, $track->{features}):
		$self->_save_genomic_features($datasource, $track->{features});


	    $parameter = $tparam;
	    $parameter->{feedback} = "$track_name: $tparam->{feedback}";
	    $parameter->{id} = $datasource->logic_name;
	    
	} else {
	    $parameter->{error_message} =  "Need a trackname!";
	}
    } else {
	$parameter->{error_message} =  "Need species name";
    }


    return $parameter;
}

sub _create_datasource {
    my ($self, $config) = @_;


    my $ds_name = $config->{track_name};
    my $ds_label = $config->{track_label} || $ds_name;

    my $ds_desc = $config->{description};
    my $adaptor = $config->{source_adaptor};

    my $datasource = new Bio::EnsEMBL::Analysis(
						-logic_name => $ds_name, 
						-description => $ds_desc,
						-display_label => $ds_label,
						-displayable => 1,
						-module => $config->{coordinate_system} || $DEFAULT_CS, 
						-module_version => $config->{assembly},
				    );

    $adaptor->store($datasource);
    return $datasource;
}

sub _update_datasource {
    my ($self, $datasource, $config) = @_;

    my $adaptor = $datasource->adaptor;

    $datasource->logic_name($config->{track_name});
    $datasource->display_label($config->{track_label});
    $datasource->description($config->{description});
    $datasource->module($config->{coordinate_system} || $DEFAULT_CS);
    $datasource->module_version($config->{assembly});
    $datasource->web_data($config->{web_data});
#    warn Dumper $datasource;

    $adaptor->update($datasource);
    return $datasource;
}

sub _save_protein_features {
    my ($self, $datasource, $features) = @_;

    my $parameter;
 
    my $uu_dba = $datasource->adaptor->db;
    my $feature_adaptor = $uu_dba->get_adaptor('ProteinFeature');

    my $current_species = $uu_dba->species;

    my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
    my $core_dba = $dbs->get_DBAdaptor('core');
    my $translation_adaptor = $core_dba->get_adaptor( 'Translation' );

    my $shash;
    my @feat_array;
    
    foreach my $f (@$features) {
#	warn Dumper $f;
	my $seqname = $f->seqname;
	unless ($shash->{ $seqname }) {
	    if (my $object =  $translation_adaptor->fetch_by_stable_id( $seqname )) {
		$shash->{ $seqname } = $object->dbID;
	    }
	};

	next unless $shash->{ $seqname };
	    
	if (my $object_id = $shash->{$seqname}) {
	    my $extra_data = {
		'type' => $f->type,
		'note' => $f->note,
		'link' => $f->link,
	    };

	    my $feat = new Bio::EnsEMBL::ProteinFeature(
							-translation_id => $object_id,
							-start    => $f->rawstart,
							-end      => $f->rawend,
							-strand   => $f->strand,
							-hseqname => $f->id,
							-hstart   => $f->rawstart,
							-hend     => $f->rawend,
							-hstrand  => $f->strand,
							-score => $f->score,
							-analysis => $datasource,
							-extra_data => $extra_data,
							);
	    
	    push @feat_array, $feat;
	} else {
	    $parameter->{error_messsage} .= "Invalid segment: $seqname.";
	}

    }

    $feature_adaptor->save(\@feat_array) if (@feat_array);
    $parameter->{feedback} = scalar(@feat_array).' saved.';
    if (my $fdiff = scalar(@$features) - scalar(@feat_array)) {
	$parameter->{feedback} .= " $fdiff features ignored.";
    }
 
 
    return $parameter;
}

sub _save_genomic_features {
    my ($self, $datasource, $features) = @_;

    my $parameter;

    my $uu_dba = $datasource->adaptor->db;
    my $feature_adaptor = $uu_dba->get_adaptor('DnaAlignFeature');

    my $current_species = $uu_dba->species;

    my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
    my $core_dba = $dbs->get_DBAdaptor('core');
    my $slice_adaptor = $core_dba->get_adaptor( 'Slice' );

    my $assembly = $datasource->module_version;
    my $shash;
    my @feat_array;
    
    foreach my $f (@$features) {
#	warn Dumper $f;
	my $seqname = $f->seqname;
	$shash->{ $seqname } ||= $slice_adaptor->fetch_by_region( undef,$seqname, undef, undef, undef, $assembly );
	if (my $slice = $shash->{$seqname}) {
	    my $extra_data = {
		'type' => $f->type,
		'note' => $f->note,
		'link' => $f->link,
	    };

	    my $feat = new Bio::EnsEMBL::DnaDnaAlignFeature(
							    -slice    => $slice,
							    -start    => $f->rawstart,
							    -end      => $f->rawend,
							    -strand   => $f->strand,
							    -hseqname => $f->id,
							    -hstart   => $f->rawstart,
							    -hend     => $f->rawend,
							    -hstrand  => $f->strand,
							    -score => $f->score,
							    -analysis => $datasource,
							    -cigar_string => $f->{_attrs} || '1M',
							    -extra_data => $extra_data,
							    );
	    
	    push @feat_array, $feat;
	} else {
	    $parameter->{error_messsage} .= "Invalid segment: $seqname.";
	}

    }

    $feature_adaptor->save(\@feat_array) if (@feat_array);
    $parameter->{feedback} = scalar(@feat_array).' saved.';
    if (my $fdiff = scalar(@$features) - scalar(@feat_array)) {
	$parameter->{feedback} = " $fdiff features ignored.";
    }
    return $parameter;

}

1;


