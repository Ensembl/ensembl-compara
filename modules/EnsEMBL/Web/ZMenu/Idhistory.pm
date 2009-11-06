# $Id$

package EnsEMBL::Web::ZMenu::Idhistory;

use strict;

use EnsEMBL::Web::Data::Release;

use base qw(EnsEMBL::Web::ZMenu);

sub content {}

sub archive_adaptor {
  my $self   = shift;
  my $object = $self->object;
  
  return $object->database($object->param('db') || 'core')->get_ArchiveStableIdAdaptor;
}

sub archive_link {
  my ($self, $archive, $release) = @_;
  
  my $object = $self->object;
  
  return '' unless ($release || $archive->release) > $object->species_defs->EARLIEST_ARCHIVE;
  
  my $type    = $archive->type eq 'Translation' ? 'peptide' : lc $archive->type;
  my $name    = $archive->stable_id . '.' . $archive->version;
  my $current = $object->species_defs->ENSEMBL_VERSION;
  my $view    = "${type}view";
  my ($action, $p, $url);
  
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }
  
  # Set parameters for new style URLs post release 50
  if ($archive->release >= 51) {
    if ($type eq 'gene') {
      $type = 'Gene';
      $p = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript') {
      $type = 'Transcript';
      $p = 't';
      $action = 'Summary';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'ProteinSummary';
    }
  }
  
  if ($archive->release == $current) {
     $url = $object->_url({ type => $type, action => $action, $p => $name });
  } else {
    my $archive_site = new EnsEMBL::Web::Data::Release($archive->release)->archive;
    
    $url = "http://$archive_site.archive.ensembl.org";
    
    if ($archive->release >= 51) {
      $url .= $object->_url({ type => $type, action => $action, $p => $name });
    } else {
      $url .= $object->species_path . "/$view?$type=$name";
    }
  }
  
  return $url;
}

1;
