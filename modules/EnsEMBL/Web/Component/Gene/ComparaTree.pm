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
  my $compara_adapt  = $object->DBConnection->get_databases( 'core', 'compara' )->{'compara'};
  my $member         = $compara_adapt->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $object->stable_id);
  return '' unless defined $member;
  my $tree_adapt     = $compara_adapt->get_ProteinTreeAdaptor;
  my $clusterset_id  = 0; ### WHAT IS IT ???
  my $aligned_member = $tree_adapt->fetch_AlignedMember_by_member_id_root_id(
    $member->get_longest_peptide_Member->member_id,
    $clusterset_id
  );
  return '' unless defined $aligned_member;
  my $node = $aligned_member->subroot;
  my $tree = $tree_adapt->fetch_node_by_node_id($node->node_id);
     $node->release_tree;
  return $self->create_genetree_image( $tree, $member )->render;
}

sub create_genetree_image {
  my( $self, $tree, $member ) = @_;

  my $object       = $self->object;
  my $wuc          = $object->user_config_hash( 'genetreeview' );
  my $image_width  = $object->param( 'image_width' ) || 800;

  $wuc->container_width($image_width);
  $wuc->set_width( $object->param('image_width') );
  $wuc->{_object} = $object;

  my $image  = $object->new_image( $tree, $wuc, [$object->stable_id, $member->genome_db->dbID] );
#  $image->cacheable   = 'yes';
  $image->image_type  = 'genetree';
  $image->image_name  = ($object->param('image_width')).'-'.$object->stable_id;
  $image->imagemap    = 'yes';

  return $image;
}

1;
