package EnsEMBL::Web::Component::Gene::ComparaTree;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

use EnsEMBL::Web::Constants;
use Bio::AlignIO;
use IO::Scalar;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub _get_details {
  my $self = shift;
  my $object = $self->object;
  my $member = $object->get_compara_Member;
  return (undef, $self->_error(
    'No compara member',
    q(<p>Unable to render gene tree as gene is not in the Comparative genomics database</p>)
  )) unless $member;

  my $tree   = $object->get_ProteinTree;
  return (undef,$self->_error(
    'Gene not in protein tree',
    q(<p>This gene has no orthologues in Ensembl Compara, so a gene tree cannot be built.</p>)
  )) unless $tree;
  my $node   = $tree->get_leaf_by_Member($member);
  return(undef,$self->_error(
    'Gene not in tree',
    sprintf( q(<p>Member %s not in tree %s</p>), $member->stable_id, $tree->node_id )
  )) unless $node;
  return ($member,$tree,$node);
}

sub content {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the Member and ProteinTree objects 
  #----------
  # Draw the tree

  my ( $member,$tree,$node ) = $self->_get_details;
  return $tree if !defined $member;

  my $wuc          = $object->image_config_hash( 'genetreeview' );
  my $image_width  = $object->param( 'image_width' ) || 800;
  my $collapsability = $object->param('collapsability') || 'gene';

  $wuc->set_parameters({
    'container_width'   => $image_width,
    'image_width',      => $image_width,
    'slice_number',     => '1|1',
  });

  #$wuc->tree->dump("GENE TREE CONF", '([[caption]])');
  my @highlights = ($object->stable_id, $member->genome_db->dbID);
  # Keep track of collapsed nodes

  my $collapsed_nodes = $object->param('collapse');
  
  my $collapsed_to_gene = $self->_collapsed_nodes($tree,$node, 'gene');
  my $collapsed_to_para = $self->_collapsed_nodes($tree,$node, 'paralogs');
  my $collapsed_to_dups = $self->_collapsed_nodes($tree,$node, 'duplications');

  unless( defined( $collapsed_nodes ) ){ #Examine collapsabilty
    $collapsed_nodes = $collapsed_to_gene if( $collapsability eq 'gene');
    $collapsed_nodes = $collapsed_to_para if( $collapsability eq 'paralogs');
    $collapsed_nodes = $collapsed_to_dups if( $collapsability eq 'duplications');
    $collapsed_nodes ||= '';
  }
  #warn "==> $collapsed_to_gene";
  #warn "==> $collapsed_to_para";
  #warn "==>$collapsed_to_dups";

  push @highlights, $collapsed_nodes || undef;

  my $image  = $object->new_image
      ( $tree, $wuc, [@highlights] );
#  $image->cacheable   = 'yes';
  $image->image_type  = 'genetree';
  $image->image_name  = ($object->param('image_width')).'-'.$object->stable_id;
  $image->imagemap    = 'yes';

  $image->{'panel_number'} = 'tree';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  my $li_tmpl = qq(
<li><a href="%s">%s</a></li>);
  my @view_links;
  push @view_links, sprintf( $li_tmpl,
                             $object->_url({'collapse'=>$collapsed_to_gene}),
                             'View current gene only');

  push @view_links, sprintf( $li_tmpl,
                             $object->_url({'collapse'=>$collapsed_to_para}),
                             'View paralogs of current gene');

  push @view_links, sprintf( $li_tmpl,
                             $object->_url({'collapse'=>$collapsed_to_dups}),
                             'View all duplication nodes');

  push @view_links, sprintf( $li_tmpl,
                             $object->_url({'collapse'=>''}),
                             'View fully expanded tree');
  
  my $view_options_html = sprintf( qq(
<div style="margin-top:1em"><b>View options:</b><br/>
<small><ul>%s</ul></small>
Use the 'configure page' link in the left panel to set the default. Further options are available from menus on individual tree nodes.</div>), join( '', @view_links) );

  return $image->render . $view_options_html ;
}

sub _collapsed_nodes{
  # Takes the ProteinTree and node related to this gene and a view action
  # ('gene', 'paralogs', 'duplications' ) and returns the list of
  # tree nodes that should be collapsed according to the view action.
  # TODO: Move to Object::Gene, as the code is shared by the ajax menus
  my $self = shift;
  my $tree = shift;
  my $node = shift;
  my $action = shift;
  $tree->isa('Bio::EnsEMBL::Compara::ProteinTree') 
      || die( "Need a ProteinTree, not a $tree" );
  $node->isa('Bio::EnsEMBL::Compara::AlignedMember')
      || die( "Need an AlignedMember, not a $node" );

  my %collapsed_nodes;
  my %expanded_nodes;
  
  if( $action eq 'gene' ){ # View current gene
    foreach my $adj( @{$node->get_all_adjacent_subtrees} ){
      $collapsed_nodes{$adj->node_id} = $_;
    }
  }
  elsif( $action eq 'paralogs' ){ # View all paralogs
    my $gdb_id = $node->genome_db_id;
    foreach my $leaf( @{$tree->get_all_leaves} ){
      if( $leaf->genome_db_id == $gdb_id ){
        foreach my $ancestor( @{$leaf->get_all_ancestors} ){
          $expanded_nodes{$ancestor->node_id} = $ancestor;
        }
        foreach my $adjacent( @{$leaf->get_all_adjacent_subtrees} ){
          $collapsed_nodes{$adjacent->node_id} = $adjacent;
        }
      }
    }
  }
  elsif( $action eq 'duplications' ){ # View all duplications
    foreach my $tnode( @{$tree->get_all_nodes} ){
      next if $tnode->is_leaf;
      if($tnode->get_tagvalue('dubious_duplication') or
         ! $tnode->get_tagvalue('Duplication') ){
        $collapsed_nodes{$tnode->node_id} = $tnode;
        next;
      }
      $expanded_nodes{$tnode->node_id} = $tnode;
      foreach my $ancestor( @{$tnode->get_all_ancestors} ){
        $expanded_nodes{$ancestor->node_id} = $ancestor;
      }
    }
  }
  my $collapsed_node_ids
      = join( ',', grep{! $expanded_nodes{$_}} keys %collapsed_nodes );
  return $collapsed_node_ids;
}

sub content_align {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object
  my ( $member,$tree,$node ) = $self->_get_details;
  return $tree if !defined $member;

  #----------
  # Return the text representation of the tree
  my $htmlt = qq(
<p>Multiple sequence alignment in "<i>%s</i>" format:</p>
<p>The sequence alignment format can be configured using the
'configure page' link in the left panel.<p>
<pre>%s</pre>);

  #----------
  # Determine the format
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS();
  my $mode = $object->param('text_format');
     $mode = 'fasta' unless $formats{$mode};
  my $fmt_caption = $formats{$mode} || $mode;

  my $align_format = $mode;

  my $formatted; # Variable to hold the formatted alignment string
  my $SH = IO::Scalar->new(\$formatted);
  #print $SH "FOO\n";
  my $aio = Bio::AlignIO->new( -format => $align_format, -fh => $SH );
  $aio->write_aln( $tree->get_SimpleAlign );

  return sprintf( $htmlt, $fmt_caption, $formatted );
}

sub content_text {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object
  my ( $member,$tree,$node ) = $self->_get_details;
  return $tree if !defined $member;

  #----------
  # Template for the section HTML
  my $htmlt = qq(
<p>The following is a representation of the tree in "<i>%s</i>" format</p>
<p>The tree representation can be configured using the
'configure page' link in the left panel.<p>
<pre>%s</pre>);


  #----------
  # Return the text representation of the tree
  my %formats = EnsEMBL::Web::Constants::TREE_FORMATS();
  my $mode = $object->param('tree_format');
     $mode = 'newick' unless $formats{$mode};
  my $fn   = $formats{$mode}{'method'};
  my $fmt_caption = $formats{$mode}{caption} || $mode;

  my @params = ( map { $object->param( $_ ) } 
                 @{ $formats{$mode}{'parameters'} || [] } );
  my $string = $tree->$fn(@params);
  if( $formats{$mode}{'split'} ) {
    my $reg = '(['.quotemeta($formats{$mode}{'split'}).'])';
    $string =~ s/$reg/\1\n/g;
  }

  return sprintf( $htmlt, $fmt_caption, $string );
}

1;
