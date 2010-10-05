# $Id$

package EnsEMBL::Web::Component::Gene::HistoryReport;

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content_protein {
  my $self = shift;
  $self->content(1);
}

sub content {
  my $self    = shift; 
  my $protein = shift; 
  my $hub     = $self->hub;
  my $object  = $self->object;   
  my $archive_object;
  
  if ($protein == 1) {
    my $transcript = $object->transcript;
    my $translation_object;
    
    if ($transcript->isa('Bio::EnsEMBL::ArchiveStableId') || $transcript->isa('EnsEMBL::Web::Fake') ){ 
       my $p = $hub->param('p') || $hub->param('protein');
       
       if (!$p) {                                                                 
         my $p_archive = shift @{$transcript->get_all_translation_archive_ids};
         $p = $p_archive->stable_id;
       }
       my $db          = $hub->param('db') || 'core';
       my $db_adaptor  = $hub->database($db);
       my $a           = $db_adaptor->get_ArchiveStableIdAdaptor;
       $archive_object = $a->fetch_by_stable_id($p);
    } else { 
       $translation_object = $object->translation_object;
       $archive_object     = $translation_object->get_archive_object;
    }
  } else {  # retrieve archive object 
    $archive_object = $object->get_archive_object; 
  }
  
  my $latest = $archive_object->get_latest_incarnation;
  my $id     = $latest->stable_id . '.' . $latest->version;
  my $version_html;
  my $status;
  
  if ($archive_object->is_current) {
    $status = 'Current'; # this *is* the current version of this stable ID
  } elsif ($archive_object->current_version) {
    $status = 'Old version'; # there is a current version of this stable ID
  } else {
    $status = 'Retired (see below for possible successors)'; # this stable ID no longer exists
  }
  
  if ($archive_object->release >= $hub->species_defs->EARLIEST_ARCHIVE){ 
    $version_html = sprintf '<a href="%s">%s</a>', $self->_archive_link($archive_object), $id;
  } else {
    $version_html = $id;
  } 
 
  $version_html .= "<br />\n";
  $version_html .= 'Release: ' . $latest->release;
  $version_html .= ' (current)' if $archive_object->is_current;
  $version_html .= "<br />\n";
  $version_html .= 'Assembly: ' . $latest->assembly . "<br />\n";
  $version_html .= 'Database: ' . $latest->db_name  . '<br />';
  
  return qq{
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
    </dl><br />
  };
}


sub _archive_link {
  my ($self, $archive_object) = @_;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  
  # no archive for old release, return un-linked display_label
  return $archive_object->stable_id . '.' . $archive_object->version if $archive_object->release < $species_defs->EARLIEST_ARCHIVE;

  my $type    = $archive_object->type eq 'Translation' ? 'peptide' : lc $archive_object->type;
  my $name    = $archive_object->stable_id . '.' . $archive_object->version;
  my $current = $species_defs->ENSEMBL_VERSION;
  my $view    = "${type}view";
  my ($action, $p, $url);
  
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }
  
  ### Set parameters for new style URLs post release 50
  if ($archive_object->release >= 51) {
    if ($type eq 'gene') {
      $type   = 'Gene';
      $p      = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript') {
      $type   = 'Transcript';
      $p      = 't';
      $action = 'Summary';
    } else {
      $type   = 'Transcript';
      $p      = 'p';
      $action = 'ProteinSummary';
    }
  }

  if ($archive_object->release == $current) {
     $url = $hub->url({ type => $type, action => $action, $p => $name });
  } else {
    my $adaptor      = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub);
    my $release_info = $adaptor->fetch_release($archive_object->release);
    my $archive_site = $release_info->{'archive'};
    $url             = "http://$archive_site.archive.ensembl.org";
    
    if ($archive_object->release >= 51) {
      $url .= $hub->url({ type => $type, action => $action, $p => $name });
    } else {
      $url .= $hub->species_path . "/$view?$type=$name";
    }
  }

  return $url;
}

1;
