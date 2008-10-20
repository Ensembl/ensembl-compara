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
  my $version_html = $self->_archive_link($OBJ, $latest, $latest->stable_id, $type, $id);

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
  my ($self, $object, $latest, $name, $type, $display_label, $release, $version ) = @_;

  $release ||= $latest->release;
  $version ||= $latest->version;

  # no archive for old release, return un-linked display_label
  return $display_label if ($release < $self->object->species_defs->EARLIEST_ARCHIVE);

  my ($url, $site_type, $action, $view, $param);

  if ($latest->is_current) {
    $site_type = "current";
  } else {
    $site_type = "archived";
  }

  if ($type =~/gene/){
    $type = 'Gene';
    $param = 'g';
    $action = 'Summary',
    $view = 'geneview'
  } elsif ($type=~/transcript/){
    $type = 'Transcript';
    $param = 't';
    $action = 'Summary';
    $view = 'transview'; 
  } else {
    $type = 'Transcript';
    $param = 'protein';
    $action = 'ProteinSummary';
    $view = 'protview';
  }

  $url = $object->_url ({'type' => $type, 'action' => $action, $param => $display_label});

  my $html;

  if ($site_type eq 'current' && $latest->release >= 51 ) {
    $url = $object->_url ({'type' => $type, 'action' => $action, $param => $display_label});
    $html = qq(<a title="View in $site_type $action" href="$url">$display_label</a>);
  } elsif ( $site_type eq "archived" ){
    my %archive_sites = %{$object->species_defs->ENSEMBL_ARCHIVES};
    $url = "http://$archive_sites{$release}.archive.ensembl.org/";
    my $species = $object->species;
    if ($latest->release >= 51){
      my $arch_url = $object->_url ({'type' => $type, 'action' => $action, $param => $display_label});
      $html = qq(<a title="View in $site_type $action" href="$url$species/$arch_url">$display_label</a>);
    }  else {
      $type = lc($type);
      $html = qq(<a title="View in $site_type $view" href="$url$species/$view?$type=$name">$display_label</a>);      
    }
  }


  return $html;
}

1;
