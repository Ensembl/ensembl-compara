# $Id$

package EnsEMBL::Web::ZMenu::Idhistory::Node;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Idhistory);

sub content {
  my $self = shift;
  
  my $object  = $self->object;
  my $a_id    = $object->param('node') || die 'No node value in params';
  my $archive = $self->archive_adaptor->fetch_by_stable_id_dbname($a_id, $object->param('db_name'));
  my $id      = $archive->stable_id . '.' . $archive->version;

  $self->caption($id);

  $self->add_entry({
    type       => $archive->type eq 'Translation' ? 'Protein' : $archive->type,
    label_html => $id,
    link       => $self->archive_link($archive)
  });
  
  $self->add_entry({
    type  => 'Release',
    label => $archive->release
  });
  
  $self->add_entry({
    type  => 'Assembly',
    label => $archive->assembly
  });
  
  $self->add_entry({
    type  => 'Database',
    label => $archive->db_name
  });
}

1;
