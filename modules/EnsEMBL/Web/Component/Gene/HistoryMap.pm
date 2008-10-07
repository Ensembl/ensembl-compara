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

sub content {
  my $self = shift;
  my $OBJ = $self->object;
  my $type = lc($OBJ->type);
  my $image;
  my $object = $OBJ->get_archive_object; 

  my $name = $object->stable_id .".". $object->version;
  my $historytree = $OBJ->history;

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
  $image->image_type = 'idhistorytree';
  $image->image_name = $OBJ->param('image_width').'-'.$object->stable_id;
  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image;
}

1;
