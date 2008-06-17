package EnsEMBL::Web::Wizard::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use File::Basename;
use Data::Bio::Text::FeatureParser;
use EnsEMBL::Web::File::Text;
use EnsEMBL::Web::Wizard::Node;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Wizard::Node);

our @formats = (
    {name => '-- Please Select --', value => ''},
    {name => 'generic', value => 'Generic'},
    {name => 'BED', value => 'BED'},
    {name => 'GBrowse', value => 'GBrowse'},
    {name => 'GFF', value => 'GFF'},
    {name => 'GTF', value => 'GTF'},
#    {name => 'LDAS', value => 'LDAS'},
    {name => 'PSL', value => 'PSL'},
);

sub select_file {
  my $self = shift;

  $self->title('Select File to Upload');

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
  $self->add_element(( type => 'CheckBox', name => 'save', label => 'Save to my user account', 'checked'=>'checked' ));
}

sub upload {
### Node to store uploaded data
  my $self = shift;
  my $parameter = {};

  my $method = $self->object->param('url') ? 'url' : 'file';
  if ($self->object->param($method)) {
    
    ## Get file contents
    my $data;
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs);
    if ($method eq 'url') {
      $data = $file->get_url_content($self->object, $method);
    }
    else {    
      $data = $file->get_file_content($self->object, $method);
    }
warn "DATA: $data";

    my($filename, $dirs, $ext) = fileparse($self->object->param($method), qr/\.[^.]*/); 
=pod
    my $memcached = 0;
    if ($memcached) {
      ## cache data to memory
    }
    else {
      $file->set_cache_filename('user_'.$method);
      warn "Saving input file as ", $file->filename;
      $result = $file->save($data);
      $error = $result->{'error'};
      if ($error) {
        $parameter->{'error'} = $error;
      }
      else {
        $parameter->{'cache'} = $file->filename;
      }
    }
=cut

    ## Identify format
    my $parser = Data::Bio::Text::FeatureParser->new();
    my $file_info = $parser->analyse($data);



    my $format = $self->_check_extension($ext);
    warn "FILE $file is of format $format";
    if (!$format || $format eq 'GFF') {
      $format = $self->_identify_format($data);
    }
    $parameter->{'format'} = $format;

    ## Work out if multiple assemblies available
    $parameter->{'assemblies'} = $self->_check_coord_system($data);

    $parameter->{'wizard_next'} = 'upload_feedback';
  }
  else {
    $parameter->{'wizard_next'} = 'select_file';
    $parameter->{'error_message'} = 'No data was uploaded. Please try again.';
  }

  return $parameter;
}

sub upload_feedback {
### Node to confirm data upload
  my $self = shift;
  $self->title('File Uploaded');

  ## Format selector
  my $upload_message = 'Thank you - your data was successfully uploaded.';
  if ($self->object->param('format')) {
    $upload_message .= ' File was identified as '.$self->object->param('format').' format.';
    $self->add_element(( type => 'Information', value => $upload_message));
  }
  else {
    $upload_message .= ' However, file format could not be identified - please select an option:';
    $self->add_element(( type => 'Information', value => $upload_message));
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  }

  ### Assembly selector
  if ($self->object->param('assemblies')) {
    $self->add_element(( type => 'Information', value => 'This species has more than one assembly in Ensembl. Please choose the assembly that corresponds to your chromosomal coordinates:'));
    my @assemblies = split(',', $self->object->param('assemblies'));
    my $values;
    foreach my $assembly (@assemblies) {
      push @$values, {'name'=>$assembly, 'value'=>$assembly};
    }
    $self->add_element(( type => 'DropDown', name => 'assembly', label => 'Assembly', select => 'select', values => $values));
  }

}

sub select_server {
  my $self = shift;
  my $object = $self->object;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  $self->title('Select a DAS server or data file');

  my $preconf_das = []; ## Preconfigured DAS servers
  my $NO_REG = 'No registry';
  my $rurl = $object->species_defs->DAS_REGISTRY_URL || $NO_REG;
  if (defined (my $url = $object->param("preconf"))) {
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= '/das' if ($url !~ m/\/das$/ && $url ne $rurl);
    $object->param('preconf_das', $url);
  }
  my @das_servers = $self->object->get_ensembl_das;
  if ($rurl eq $NO_REG) {
    $object->param('preconf_das') or $object->param('preconf_das', $das_servers[0]);
  } 
  else {
    $object->param('preconf_das') or $object->param('preconf_das', $rurl);
    push @$preconf_das, {'name' => 'DAS Registry', 'value'=>$rurl};
  }
  my $default = $object->param("preconf_das");
  foreach my $dom (@das_servers) { push @$preconf_das, {'name'=>$dom, 'value'=>$dom} ; }


  $self->add_element(( type => 'DropDown', name => 'preconf_das', 'select' => 'select',
    label => $sitename.' DAS server', 'values' => $preconf_das ));
  $self->add_element(( type => 'String', name => 'other_das', label => 'or other DAS server',
    'notes' => '( e.g. http://www.example.com/MyProject/das )' ));
  $self->add_element(( type => 'String', name => '_das_filter', label => 'Filter sources',
    'notes' => 'by name, description or URL' ));
  $self->add_element(('type'=>'Information', 'value'=>'OR'));
  $self->add_element(( type => 'String', name => 'url', label => 'File URL',
    'notes' => '( e.g. http://www.example.com/MyProject/mydata.gff )' ));
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {
    $self->add_element(( type => 'CheckBox', name => 'save', label => 'Attach source/url to my account', 'checked'=>'checked' ));
  }
}

sub source_logic {
  my $self = shift;
  my $parameter = {};

  if ($self->object->param('url')) {    
    $parameter->{'url'}         = $self->object->param('url');
    $parameter->{'wizard_next'} = 'attach';
  }
  else {
    $parameter->{'das_server'}  = $self->object->param('other_das') || $self->object->param('preconf_das');
    $parameter->{'wizard_next'} = 'select_source';
  }
  return $parameter;
}

sub select_source {
### Displays sources for the chosen server as a series of checkboxes 
### (or an error message if no dsns found)
  my $self = shift;

  $self->title('Select a DAS source');

  my $dsns = $self->object->get_server_dsns;
  if (ref($dsns) eq 'HASH') {
    my $dwidth = 120;
    foreach my $id (sort {$dsns->{$a}->{name} cmp $dsns->{$b}->{name} } keys (%{$dsns})) {
#warn Data::Dumper::Dumper( $dsns->{$id} );
      my $dassource = $dsns->{$id};
      my ($id, $name, $url, $desc) = ($dassource->{id}, $dassource->{name}, $dassource->{url}, substr($dassource->{description}, 0, $dwidth));
      if( length($desc) >= $dwidth ) {
      # find the last space character in the line and replace the tail with ...        
        $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./;
      }
      $self->add_element( 'type'=>'CheckBox', 'name'=>'dsns', 'value' => $id, 'label' => $name, 'notes' => $desc );
    }
  } 
  else {
    $self->add_element('type'=>'Information', 'value'=>$dsns);
  }
}

sub attach {
}

sub attach_feedback {
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

sub _identify_format {
### Tries to identify file format from content
  my ($self, $data) = @_;
  return undef;
}

sub _check_coord_system {
### Tries to identify coordinate system from file contents
### If on chromosomal coords and species has multiple assemblies, 
### return assembly info
  my ($self, $data) = @_;
  return undef;
}


1;


