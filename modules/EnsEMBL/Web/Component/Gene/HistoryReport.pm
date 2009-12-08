package EnsEMBL::Web::Component::Gene::HistoryReport;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
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
  my $object = $self->object;   
  my $archive_object;
  
   
  if ($protein == 1){ 
    my $translation_object;
    if ($object->transcript->isa('Bio::EnsEMBL::ArchiveStableId')  ||  $object->transcript->isa('EnsEMBL::Web::Fake') ){ 
       my $p;
       $p = $self->object->param('p') || $self->object->param('protein');       
       unless ($p) {                                                                 
         my $p_archive = shift @{$object->transcript->get_all_translation_archive_ids};
         $p = $p_archive->stable_id;
       }
       my $db    = $self->{'parameters'}{'db'}  = $self->object->param('db')  || 'core';
       my $db_adaptor = $self->object->database($db);
       my $a = $db_adaptor->get_ArchiveStableIdAdaptor;
       $archive_object = $a->fetch_by_stable_id( $p );
    } else { 
       $translation_object = $object->translation_object;
       $archive_object = $translation_object->get_archive_object();
    }
  } else {    # retrieve archive object 
    $archive_object = $object->get_archive_object(); 
  }

  my $html = '';

  my $id = $archive_object->stable_id.".".$archive_object->version;
  my $status;
  if ($archive_object->is_current) {
    # this *is* the current version of this stable ID
    $status = "Current";
  } elsif ($archive_object->current_version) {
    # there is a current version of this stable ID
    $status = "Old version";
  } else {
    # this stable ID no longer exists
    $status = "Retired (see below for possible successors)";
  }

  my $latest = $archive_object->get_latest_incarnation;
  my $type = $archive_object->type eq 'Translation' ? 'protein' : lc($archive_object->type);
  $id = $latest->stable_id.".".$latest->version;
  my $version_html;
  if ($archive_object->release >= $object->species_defs->EARLIEST_ARCHIVE){ 
    my $url = $self->_archive_link($archive_object); 
    $version_html = qq(<a href="$url">$id</a>);
  } else {
    $version_html = $id;
  } 
 
  $version_html .= "<br />\n";
  $version_html .= "Release: ".$latest->release;
  $version_html .= " (current)" if ($archive_object->is_current);
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
  my ($self, $archive_object) = @_;
  my $object = $self->object;
  
  # no archive for old release, return un-linked display_label
  return $archive_object->stable_id."." .$archive_object->version if ($archive_object->release < $object->species_defs->EARLIEST_ARCHIVE);

  my $type =  $archive_object->type eq 'Translation' ? 'peptide' : lc($archive_object->type);
  my $name = $archive_object->stable_id . "." . $archive_object->version;
  my $url;
  my $current =  $object->species_defs->ENSEMBL_VERSION;

  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  my ($action, $p);
  ### Set parameters for new style URLs post release 50
  if ($archive_object->release >= 51 ){
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

  if ($archive_object->release == $current){
     $url = $object->_url({'type' => $type, 'action' => $action, $p => $name });
     return $url;
  } else {
    my $release_info = EnsEMBL::Web::Data::Release->new($archive_object->release);
    my $archive_site = $release_info->archive;
    $url = "http://$archive_site.archive.ensembl.org";
    if ($archive_object->release >=51){
      $url .= $object->_url({'type' => $type, 'action' => $action, $p => $name });
    } else {
      $url .= $object->species_path;
      $url .= "/$view?$type=$name";
    }
  }

 return $url;
}

1;
