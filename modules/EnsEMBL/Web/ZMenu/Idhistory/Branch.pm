# $Id$

package EnsEMBL::Web::ZMenu::Idhistory::Branch;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Idhistory);

sub content {
  my $self = shift;
  
  my $object       = $self->object;
  my $old_id       = $object->param('old') || die 'No old id value in params';
  my $new_id       = $object->param('new') || die 'No new id value in params';
  my $score        = $object->param('score');
  my $arch_adaptor = $self->archive_adaptor;
  my $old_arch_obj = $arch_adaptor->fetch_by_stable_id_dbname($old_id, $object->param('old_db'));
  my $new_arch_obj = $arch_adaptor->fetch_by_stable_id_dbname($new_id, $object->param('new_db'));
  my $old_release  = $old_arch_obj->release;
  
  my %types = (
    Old => $old_arch_obj, 
    New => $new_arch_obj
  );
  
  $score = $score == 0 ? 'Unknown' : sprintf '%.2f', $score;
  
  $self->caption('Similarity Match');

  foreach (sort { $types{$a} <=> $types{$b} } keys %types) {
    my $archive = $types{$_};

    $self->add_entry({
      type       => $_ . ' ' . $archive->type,
      label_html => $archive->stable_id . '.' . $archive->version,
      link       => $self->archive_link($archive, $old_release)
    });
    
    $self->add_entry({
      type  => "$_ Release",
      label => $archive->release
    });
    
    $self->add_entry({
      type  => "$_ Assembly",
      label => $archive->assembly
    });
    
    $self->add_entry({
      type  => "$_ Database",
      label => $archive->db_name
    });
  }

  $self->add_entry({
    type  => 'Score',
    label => $score
  });
}

1;
