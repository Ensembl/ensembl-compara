package EnsEMBL::Web::Component::UserData::IDmapper;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::UserData);
use CGI qw(escapeHTML);
use Bio::EnsEMBL::StableIdHistoryTree;
use EnsEMBL::Web::Data::Release;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '<h2>Stable ID Mapper Results:</h2>';
  my $referer =  $object->param('_referer');
  $html .= qq(<br /><a href="$referer">Back to previous view</a><br />);
  
  my @files = ($object->param('convert_file'));

  foreach my $file_name (@files) {
    my ($file, $name) = split(':', $file_name);
    my ($super_tree, $ids, $unmapped) = @{$object->get_stable_id_history_data($file)};
    my $table = $self->format_mapped_ids($super_tree, $ids);
    $html .= $table;
    $html .= $self->_info('Information',
    " <p>The numbers in the above table indicate the version of a stable ID present in a particular release.</p>"
    );


    if (scalar keys %$unmapped > 0) { $html .= $self->add_unmapped_ids($unmapped); }    
  }

  return $html;
}    

sub add_unmapped_ids {
  my ($self, $unmapped) = @_;
  my $html = '<h2>No ID history was found for the following identifiers:</h2>';
  foreach (keys %$unmapped){
   $html .= '<br />' .$_;
  }
  return $html;
}

sub format_mapped_ids { 
  my ($self, $super_tree, $ids) = @_;
  my %stable_ids = %$ids; 
  if (scalar keys %stable_ids < 1) { return '<p>No IDs were succesfully converted</p>';}
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px' } );
  $table->add_option('triangular',1);
  $table->add_columns(
    { 'key' => 'request', 'align'=>'left', 'title' => 'Requested ID'},
    { 'key' => 'match', 'align'=>'left', 'title' => 'Matched ID(s)' },
    { 'key' => 'rel', 'align'=>'left', 'title' => 'Releases:' },
  );

  my @releases = @{ $super_tree->get_release_display_names };
  foreach my $release (@releases) {
    $table->add_columns(
      { 'key' => $release, 'align' => 'left', 'title' => $release },
    );
  }

  # now add the data rows
  foreach my $req_id (sort keys %stable_ids) {
    my $matches = {};

    # build grid matrix
    foreach my $a_id (@{ $stable_ids{$req_id}->[1]->get_all_ArchiveStableIds }) {
      # we only need x coordinate
      my ($x) = @{ $super_tree->coords_by_ArchiveStableId($a_id) };
      my $linked_text =   $a_id->version;
      unless ($releases[$x] <= $self->object->species_defs->EARLIEST_ARCHIVE){
        my $archive_link = $self->_archive_link($stable_ids{$req_id}->[0], $a_id->stable_id, $a_id->version, $releases[$x]);
        $linked_text = '<a href='.$archive_link.'>'.$linked_text.'</a>'; 
      }    
      $matches->{$a_id->stable_id}->{$releases[$x]} = $linked_text;
    }
    # self matches
    $table->add_row({
      'request' => $self->_idhistoryview_link($stable_ids{$req_id}->[0], $req_id),
      'match'   => $req_id,
      'rel'     => '',
       %{ $matches->{$req_id} },
    });
    # other matches
    foreach my $a_id (sort keys %$matches) {
      next if ($a_id eq $req_id);

      $table->add_row({
        'request' => '',
        'match'   => $a_id,
        'rel'     => '',
        %{ $matches->{$a_id} },
      });
    }

  }  
  return  $table->render;
}


sub _idhistoryview_link {
  my ($self, $type, $stable_id) = @_;
  return undef unless ($stable_id);

  my $action = 'Idhistory';
  if ($type eq 'Translation'){ 
    $type = 'Transcript';
    $action = 'Idhistory/Protein';
  }
  my $param = lc(substr($type,0,1));

  my $link = $self->object->_url({'type' => $type, 'action' => $action, $param => $stable_id});
  my $url =  '<a href='.$link.'>'. $stable_id.'</a>';
  return $url;
}

sub _archive_link {
  my ($self, $type, $stable_id, $version, $release)  = @_;

  $type =  $type eq 'Translation' ? 'peptide' : lc($type);
  my $name = $stable_id . "." . $version;
  my $url;
  my $current =  $self->object->species_defs->ENSEMBL_VERSION;

  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  my ($action, $p);
  ### Set parameters for new style URLs post release 50
  if ($release >= 51 ){
    if ($type eq 'gene') {
      $type = 'Gene';
      $p = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript'){
      $type = 'Transcript';
      $p = 't';
      $action = 'Summary';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'ProteinSummary';
    }
  }

  if ($release == $current){
     $url = $self->object->_url({'type' => $type, 'action' => $action, $p => $name });
     return $url;
  } else {
    my $release_info = EnsEMBL::Web::Data::Release->new($release);
    my $archive_site = $release_info->archive;
    $url = "http://$archive_site.archive.ensembl.org";
    if ($release >=51){
      $url .= $self->object->_url({'type' => $type, 'action' => $action, $p => $name });
    } else {
      $url .= "/".$ENV{'ENSEMBL_SPECIES'};
      $url .= "/$view?$type=$name";
    }
  }
  return $url;
}

1;
