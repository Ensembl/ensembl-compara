package EnsEMBL::Web::Component::Gene::HistoryMap;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return 'ID History Map';
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
  my $htree;

if ($protein == 1){
    my $translation_object;
    if ($OBJ->transcript->isa('Bio::EnsEMBL::ArchiveStableId')){
       my $protein = $self->object->param('p') || $self->object->param('protein');
       my $db    = $self->{'parameters'}{'db'}  = $self->object->param('db')  || 'core';
       my $db_adaptor = $self->object->database($db);
       my $a = $db_adaptor->get_ArchiveStableIdAdaptor;
       $object = $a->fetch_by_stable_id( $protein );
       ## get tree from Archve stableid object
       $htree = $a->fetch_history_tree_by_stable_id($protein);
    } else {
       $translation_object = $OBJ->translation_object;
       $object = $translation_object->get_archive_object();
       $htree = $translation_object->history;
    }
  } else {    # retrieve archive object
    $object = $OBJ->get_archive_object();
  }

  my $name = $object->stable_id .".". $object->version;

  my $historytree = $OBJ->history; 
  if ($htree) {$historytree = $htree;}

  unless (defined $historytree) {
    my $html =  qq(<p style="text-align:center"><b>There are too many stable IDs related to $name to draw a history tree.</b></p>);
    return $html;
  }

  my $size = scalar(@{ $historytree->get_release_display_names });
  if ($size < 2) {
    my $html =  qq(<p style="text-align:center"><b>There is no history for $name stored in the database.</b></p>);
    return $html;
  }

  my $tree = $self->_create_idhistory_tree($object, $historytree, $OBJ);
  my $T = $tree->render;
  if ($historytree->is_incomplete) {
    $T = qq(<p>Too many related stable IDs found to draw complete tree - tree shown is only partial.</p>) . $T;
  }

  return $T;
}

sub _create_idhistory_tree {
  my ($self, $object, $tree, $OBJ) = @_;

  #user defined width in pixels
  my $wuc = $OBJ->image_config_hash( 'idhistoryview' );
   $wuc->set_parameters({
      'container_width' => $self->image_width || 800,
      'image_width'     => $self->image_width || 800, ## hack at the moment....
      'slice_number',     => '1|1',
  });

  $wuc->{_object} = $object;

  
  my $image = $OBJ->new_image($tree, $wuc, [$object->stable_id], $OBJ );
  return if $self->_export_image( $image );
  $image->image_type = 'idhistorytree';
  $image->image_name = $OBJ->param('image_width').'-'.$object->stable_id;
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image;
}

1;
