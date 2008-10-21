package EnsEMBL::Web::Wizard::Node::UploadData;

### Contains methods to create nodes for a wizard that uploads data to the userdata db

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::Text;
use EnsEMBL::Web::Wizard::Node;
use EnsEMBL::Web::RegObj;
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
  if (!$current_species || $current_species eq 'common') {
    $current_species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  ## Work out if multiple assemblies available
  my $assemblies = $self->_get_assemblies($current_species);

  $self->notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on Ensembl coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL">attach it to Ensembl</a> without uploading.)});
  $self->add_element( type => 'NoEdit', name => 'species', label => 'Species', 'value' => $self->object->species_defs->species_label($current_species));

  if (scalar(@$assemblies) > 1) {
    my $assembly_list = [];
    foreach my $a (@$assemblies) {
      push @$assembly_list, {'name' => $a, 'value' => $a};
    }
    $self->add_element( type => 'DropDown', 'select' => 'select', name => 'assembly', label => 'Assembly', 'values' => $assembly_list, 'value' => $assemblies->[0]);
  }
  else {
    $self->add_element( type => 'NoEdit', name => 'assembly', label => 'Assembly', 'value' => $assemblies->[0]);
  }

  $self->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $self->add_element( type => 'String', name => 'url', label => 'or provide file URL' );
  
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
    my $parser = EnsEMBL::Web::Text::FeatureParser->new();
    $parser = $parser->init($data);
#    warn Dumper $parser;
    my $format = $parser->{'_info'}->{'format'};

    $parameter->{'parser'} = $parser;
    $parameter->{'species'} = $self->object->param('species');
    ## Attach data species to session
    $self->object->get_session->set_tmp_data(
      'filename'  => $file->filename, 
      'species'   => $self->object->param('species'),
      'format'    => $format,
    );
    $self->object->get_session->save_tmp_data;

    if (!$format) {
      ## Get more input from user
      $parameter->{'format'} = 'none';
      $parameter->{'wizard_next'} = 'more_input';
    }
    else {
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



#------------------------ PRIVATE METHODS -----------------------

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

    
    my $parser = EnsEMBL::Web::Text::FeatureParser->new();
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


