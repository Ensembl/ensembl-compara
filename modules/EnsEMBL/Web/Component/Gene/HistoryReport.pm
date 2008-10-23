package EnsEMBL::Web::Component::Gene::HistoryReport;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::Release;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return; 
}

sub content_protein {
  my $self = shift;
  $self->content( 1 );
}

sub content {
  my $self = shift; 
  my $protein = shift; 
  my $OBJ = $self->object;  
  my $object;
 
  if ($protein == 1){ 
    my $translation_object;
    if ($OBJ->transcript->isa('Bio::EnsEMBL::ArchiveStableId')){ 
       my $protein = $self->object->param('p');
       my $db    = $self->{'parameters'}{'db'}  = $self->object->param('db')  || 'core';
       my $db_adaptor = $self->object->database($db);
       my $a = $db_adaptor->get_ArchiveStableIdAdaptor;
       $object = $a->fetch_by_stable_id( $protein );
    } else { 
       $translation_object = $OBJ->translation_object;
       $object = $translation_object->get_archive_object();
    }
  } else {    # retrieve archive object 
    $object = $OBJ->get_archive_object(); 
  }

  my $html = '';

  my $id = $object->stable_id.".".$object->version;
  my $status;
  if ($object->is_current) {
    # this *is* the current version of this stable ID
    $status = "Current";
  } elsif ($object->current_version) {
    # there is a current version of this stable ID
    $status = "Old version";
  } else {
    # this stable ID no longer exists
    $status = "Retired (see below for possible successors)";
  }

  my $latest = $object->get_latest_incarnation;
  my $type = $object->type eq 'Translation' ? 'protein' : lc($object->type);
  $id = $latest->stable_id.".".$latest->version;
  my $version_html;
  if ($object->release >= $OBJ->species_defs->EARLIEST_ARCHIVE){ 
    my $url = _archive_link($OBJ, $object); 
    $version_html = qq(<a href="$url">$id</a>);
  } else {
    $version_html = $id;
  } 
 
  $version_html .= "<br />\n";
  $version_html .= "Release: ".$latest->release;
  $version_html .= " (current)" if ($object->is_current);
  $version_html .= "<br />\n";
  $version_html .= "Assembly: ".$latest->assembly."<br />\n";
  $version_html .= "Database: ".$latest->db_name."<br />";
  

   $html .= qq(
    <dl class="summary">
      <dt>Stable ID</dt>
      <dd>$id</dd>
    </dl>
    <dl class="summary">
      <dt>Status</dt>
      <dd>$status</dd>  
    </dl>
    <dl class = "summary">
      <dt>Latest Version</dt>
      <dd>$version_html</dd> 
    </dl><br />);
         
  return $html;
}


sub _archive_link {
  my ($OBJ, $obj) = @_;

  # no archive for old release, return un-linked display_label
  return $obj->stable_id."." .$obj->version if ($obj->release < $OBJ->species_defs->EARLIEST_ARCHIVE);

  my $type =  $obj->type eq 'Translation' ? 'protein' : lc($obj->type);
  my $name = $obj->stable_id . "." . $obj->version;
  my $url;
  my $current =  $OBJ->species_defs->ENSEMBL_VERSION;

  my $view = $type."view";
  if ($type eq 'protein') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  my ($action, $p);
  ### Set parameters for new style URLs post release 50
  if ($obj->release >= 51 ){
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

  if ($obj->release == $current){
     $url = $OBJ->_url({'type' => $type, 'action' => $action, $p => $name });
     return $url;
  } else {
    my $release_info = EnsEMBL::Web::Data::Release->new($obj->release);
    my $archive_site = $release_info->archive;
    $url = "http://$archive_site.archive.ensembl.org";
    if ($obj->release >=51){
      $url .= $OBJ->_url({'type' => $type, 'action' => $action, $p => $name });
    } else {
      $url .= "/".$ENV{'ENSEMBL_SPECIES'};
      $url .= "/$view?$type=$name";
    }
  }

 return $url;
}

1;
