package EnsEMBL::Web::Component::Gene::ComparaTree;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the Member and ProteinTree objects 
  my $member = $object->get_compara_Member; 
  my $tree   = $object->get_ProteinTree;

  #----------
  # Draw the tree
  my $wuc          = $object->image_config_hash( 'genetreeview' );
  my $image_width  = $object->param( 'image_width' ) || 800;

  $wuc->container_width($image_width);
  $wuc->set_width( $object->param('image_width') );
  $wuc->{_object} = $object;

  my $image  = $object->new_image
      ( $tree, $wuc, [$object->stable_id, $member->genome_db->dbID] );
#  $image->cacheable   = 'yes';
  $image->image_type  = 'genetree';
  $image->image_name  = ($object->param('image_width')).'-'.$object->stable_id;
  $image->imagemap    = 'yes';

  $image->{'panel_number'} = 'tree';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}

1;
