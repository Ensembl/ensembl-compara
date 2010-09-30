package EnsEMBL::Web::Component::Gene::HistoryMap;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  return 'ID History Map';
}

sub content_protein {
  my $self = shift;
  $self->content(1);
}

sub content {
  my $self    = shift;
  my $protein = shift;
  my $object  = $self->object;
  my $archive;
  my $htree;

  if ($protein == 1) {
    my $transcript = $object->transcript;
    
    if ($transcript->isa('Bio::EnsEMBL::ArchiveStableId') || $transcript->isa('EnsEMBL::Web::Fake')) { 
       my $p  = $object->param('p')  || $object->param('protein') || $transcript->get_all_translation_archive_ids->[0]->stable_id; 
       my $db = $object->param('db') || 'core';
       my $a  = $object->database($db)->get_ArchiveStableIdAdaptor;
       
       $archive = $a->fetch_by_stable_id($p);
       $htree   = $a->fetch_history_tree_by_stable_id($p); ## get tree from Archve stableid object
    } else {
       my $translation = $object->translation_object;
       $archive        = $translation->get_archive_object;
       $htree          = $translation->history;
    }
  } else {
    $archive = $object->get_archive_object; # retrieve archive object
  }

  my $name        = $archive->stable_id . '.' . $archive->version;
  my $historytree = $htree || $object->history; 

  return '<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>' unless defined $historytree;
  return '<p style="text-align:center"><b>There is no history for $name stored in the database.</b></p>' if scalar @{$historytree->get_release_display_names} < 2;

  my $tree = $self->_create_idhistory_tree($archive, $historytree);
  my $html = $historytree->is_incomplete ? '<p>Too many related stable IDs found to draw complete tree - tree shown is only partial.</p>' : '';

  return $html . $tree->render;
}

sub _create_idhistory_tree {
  my ($self, $archive, $tree) = @_;

  my $object       = $self->object;
  my $image_config = $object->get_imageconfig('idhistoryview');
  
  $image_config->set_parameters({
    container_width => $self->image_width || 800,
    image_width     => $self->image_width || 800, ## hack at the moment....
    slice_number    => '1|1',
  });

  $image_config->{'_object'} = $archive;
  
  my $image = $self->new_image($tree, $image_config, [ $archive->stable_id ], $object);
  
  return if $self->_export_image($image, 'no_text');
  
  $image->image_type       = 'idhistorytree';
  $image->image_name       = $object->param('image_width') . '-' . $archive->stable_id;
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');

  return $image;
}

1;
