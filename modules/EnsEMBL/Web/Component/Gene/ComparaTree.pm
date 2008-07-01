package EnsEMBL::Web::Component::Gene::ComparaTree;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use Bio::EnsEMBL::Registry;
our $REGISTRY = "Bio::EnsEMBL::Registry";

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
  # Prepare the database connections and adaptors
  my $dbconn = $object->DBConnection
      || return( "No DBConnection on $object" );
  my $db_hashref = $dbconn->get_databases( 'compara' )
      || return( "<h3>No compara in $dbconn</h3>" );
  my $compara_dba = $db_hashref->{compara}
      || return( "<h3>No compara in $dbconn</h3>" );
  my $member_adaptor = $compara_dba->get_adaptor('Member')
      || return( "<h3>Cannot COMPARA->get_adaptor('Member')</h3>" );
  my $tree_adaptor   = $compara_dba->get_adaptor('ProteinTree')
      || return( "<h3>Cannot COMPARA->get_adaptor('ProteinTree')</h3>" );

  #----------
  # get the corresponding ProteinTree object corresponding to the gene
  my $id = $object->stable_id;
  my $member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE',$id)
      || return( "<h3>No compara ENSEMBLGENE member for $id</h3>" );
  my $tree = $tree_adaptor->fetch_by_Member_root_id($member, 0) 
      || return( "<h3>No compara tree for ENSEMBLGENE member for $id</h3>" );

    #----------
  # Draw the tree
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

  return $image->render;
}

1;
