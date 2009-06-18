#
# Ensembl module for Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetNeighbourNodes
#
# Cared for by Kathryn Beal <kbeal@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp 

=head1 SYNOPSIS

    $set_neighbour_nodes->fetch_input();
    $set_neighbour_nodes->run();
    $set_neighbour_nodes->write_output(); writes to database

=head1 DESCRIPTION


=head1 AUTHOR - Kathryn Beal

This modules is part of the Ensembl project http://www.ensembl.org

Email kbeal@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetNeighbourNodes;

use strict;

#use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
#use Bio::EnsEMBL::Compara::GenomicAlignBlock;
#use Bio::EnsEMBL::Compara::GenomicAlign;
#use Bio::EnsEMBL::Compara::AlignSlice;
#use Bio::SimpleAlign;
#use Bio::AlignIO;
#use Bio::LocatableSeq;
#use Getopt::Long;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

$| = 1;

my $flanking_region = 1000000;

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  #read from analysis table
  $self->get_params($self->parameters); 

  #read from analysis_job table
  $self->get_params($self->input_id);

}

sub run {
    my( $self) = @_;

    my $root_id = $self->root_id;

    my $start = $self->start;
    my $end = $self->end;
    my $step = $self->step;
    my $mlss_id = $self->mlss_id;
    my $alignment_type = $self->alignment_type;
    my $set_of_species = $self->set_of_species;

    my $method_link_species_set_adaptor = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor();
    my $genomic_align_tree_adaptor = $self->{'comparaDBA'}->get_GenomicAlignTreeAdaptor();
    my $genomic_align_block_adaptor = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor();
    
    my $method_link_species_set;
     if ($mlss_id) {
 	$method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);
 	if (!$method_link_species_set) {
 	    die "Cannot find a MLSS for ID $mlss_id\n";
 	}
     } else {
 	$method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases(
 														$alignment_type, [split(":", $set_of_species)]);
 	if (!$method_link_species_set) {
 	    die "Cannot find a MLSS for $alignment_type and $set_of_species\n";
 	}
     }
#     if ($end and $end < ($start + $step)) {
# 	$step = $end - $start;
#     }
#     my $all_genomic_align_trees = fetch_trees($self, $method_link_species_set->dbID, $start, $step);
    

#     while (@$all_genomic_align_trees) {
	print "$start: " if $self->debug;
	#foreach my $this_genomic_align_tree (@$all_genomic_align_trees) {
      my $this_genomic_align_tree = $genomic_align_tree_adaptor->fetch_node_by_node_id($root_id);
 
	    my $all_nodes = $this_genomic_align_tree->get_all_nodes_from_leaves_to_this();
	    foreach my $this_node (@{$all_nodes}) {
		if ($this_node->is_leaf()) {
		    $genomic_align_tree_adaptor->set_neighbour_nodes_for_leaf($this_node, $genomic_align_block_adaptor, $method_link_species_set);
		} else {
		    set_neighbour_nodes_for_internal_node($this_node);
		}
	    }
	    print " ", $this_genomic_align_tree->node_id . "(" . @$all_nodes . ")" if $self->debug;
	    $genomic_align_tree_adaptor->update_neighbourhood_data($this_genomic_align_tree);
	    #     foreach my $this_node (@{$this_genomic_align_tree->get_all_nodes_from_leaves_to_this()}) {
	    #       print "  *** ",
	    #           $this_node->name,":",
	    #           $this_node->genomic_align->genome_db->name,":",
	    #           $this_node->genomic_align->dnafrag->name,":",
	    #           $this_node->genomic_align->dnafrag_start,":",
	    #           $this_node->genomic_align->dnafrag_end,":",
	    #           $this_node->genomic_align->dnafrag_strand,":",
	    #           " (", ($this_node->left_node_id?$this_node->left_node->root->node_id:"...."),
	    #           " - ",  ($this_node->right_node_id?$this_node->right_node->root->node_id:"...."),")\n";
	    #     }
	    

#	}
#	print "\n" if $self->debug;
	
#	$start += $step;
#	last if (defined($end) and $end == 0);
#	last if ($start >= $end);
#	$all_genomic_align_trees = fetch_trees($self, $method_link_species_set->dbID, $start, $step);
#    }
}

##########################################
#
# internal methods
#
##########################################
sub get_params {
    my $self         = shift;
    my $param_string = shift;

    return unless($param_string);
    
    my $params = eval($param_string);
    return unless($params);

    if (defined($params->{'program'})) {
	$self->program($params->{'program'}); 
    }

   
    #read from parameters in analysis_job table
    if (defined($params->{'root_id'})) {
	$self->root_id($params->{'root_id'});
    }
    if (defined($params->{'start'})) {
	$self->start($params->{'start'});
    }
    if (defined($params->{'end'})) {
	$self->end($params->{'end'});
    }
    if (defined($params->{'step'})) {
	$self->step($params->{'step'});
    }
    if (defined($params->{'method_link_species_set_id'})) {
	$self->mlss_id($params->{'method_link_species_set_id'});
    }
    if (defined($params->{'mlss_id'})) {
	$self->mlss_id($params->{'mlss_id'});
    }
    if (defined($params->{'alignment_type'})) {
	$self->alignment_type($params->{'alignment_type'});
    }
    if (defined($params->{'set_of_species'})) {
	$self->set_of_species($params->{'set_of_species'});
    }
}
#read start from analysis_job table
sub root_id {
    my $self = shift;
    $self->{'_root_id'} = shift if(@_);
    return $self->{'_root_id'};
}

#read start from analysis_job table
sub start {
    my $self = shift;
    $self->{'_start'} = shift if(@_);
    return $self->{'_start'};
}

#read end from analysis_job table
sub end {
    my $self = shift;
    $self->{'_end'} = shift if(@_);
    return $self->{'_end'};
}

#read step from analysis_job table
sub step {
    my $self = shift;
    $self->{'_step'} = shift if(@_);
    return $self->{'_step'};
}

#read mlss_id from analysis_job table
sub mlss_id {
    my $self = shift;
    $self->{'_mlss_id'} = shift if(@_);
    return $self->{'_mlss_id'};
}

#read alignment_type from analysis_job table
sub alignment_type {
    my $self = shift;
    $self->{'_alignment_type'} = shift if(@_);
    return $self->{'_alignment_type'};
}

#read mlss_id from analysis_job table
sub set_of_species {
    my $self = shift;
    $self->{'_set_of_species'} = shift if(@_);
    return $self->{'_set_of_species'};
}

sub set_neighbour_nodes_for_leaf {
  my ($this_leaf, $genomic_align_block_adaptor, $method_link_species_set) = @_;

  my $this_genomic_align = $this_leaf->get_all_GenomicAligns->[0];
  my ($left_genomic_align, $right_genomic_align);
  my @genomic_align_blocks = sort {
        $a->reference_genomic_align->dnafrag_start <=>
        $b->reference_genomic_align->dnafrag_start }
      @{$genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
        $method_link_species_set, $this_genomic_align->dnafrag,
        $this_genomic_align->dnafrag_start - $flanking_region,
        $this_genomic_align->dnafrag_end + $flanking_region)};
  for (my $i = 0; $i < @genomic_align_blocks; $i++) {
    my $this_2nd_genomic_align = $genomic_align_blocks[$i]->reference_genomic_align;
    if ($this_2nd_genomic_align->dnafrag_start == $this_genomic_align->dnafrag_start and
        $this_2nd_genomic_align->dnafrag_end == $this_genomic_align->dnafrag_end) {
      if ($this_genomic_align->dnafrag_strand == 1) {
        $left_genomic_align = $genomic_align_blocks[$i-1]->reference_genomic_align if ($i > 0);
        $right_genomic_align = $genomic_align_blocks[$i+1]->reference_genomic_align
            if ($i + 1 < @genomic_align_blocks);
      } elsif ($this_genomic_align->dnafrag_strand == -1) {
        $right_genomic_align = $genomic_align_blocks[$i-1]->reference_genomic_align if ($i > 0);
        $left_genomic_align = $genomic_align_blocks[$i+1]->reference_genomic_align
            if ($i + 1 < @genomic_align_blocks);
      }
      last;
    }
  }
  if ($left_genomic_align) {
    $this_leaf->left_node_id($left_genomic_align->dbID());
  }
  if ($right_genomic_align) {
    $this_leaf->right_node_id($right_genomic_align->dbID());
  }

  return $this_leaf;
}


sub set_neighbour_nodes_for_internal_node {
  my ($this_node) = @_;

  my ($left_node_id, $right_node_id);
  foreach my $this_child (@{$this_node->children}) {
    my $left_node = $this_child->left_node;
    my $right_node = $this_child->right_node;

    if ($left_node and $left_node->parent) {
      if (!defined($left_node_id)) {
        $left_node_id = $left_node->parent->node_id;
      } elsif ($left_node_id != $left_node->parent->node_id) {
        $left_node_id = 0;
      }
    } else {
      $left_node_id = 0;
    }
    if ($right_node and $right_node->parent) {
      if (!defined($right_node_id)) {
        $right_node_id = $right_node->parent->node_id;
      } elsif ($right_node_id != $right_node->parent->node_id) {
        $right_node_id = 0;
      }
    } else {
      $right_node_id = 0;
    }
    $left_node->release_tree if (defined $left_node);
    $right_node->release_tree if (defined $right_node);
  }
  $this_node->left_node_id($left_node_id) if ($left_node_id);
  $this_node->right_node_id($right_node_id) if ($right_node_id);

  return $this_node;
}

sub fetch_trees {
  my ($self, $mlss_id, $start, $step) = @_;

  my $sql = "select node_id from genomic_align_tree where node_id between ${mlss_id}0000000000 and ${mlss_id}9999999999 and parent_id = 0 order by node_id limit $start, $step";

  my $trees = [];
  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
  $sth->execute();
  while (my $row = $sth->fetchrow_arrayref()) {
    my $root_id = $row->[0];
    my $this_tree = $self->{'comparaDBA'}->get_GenomicAlignTreeAdaptor->fetch_node_by_node_id($root_id);
    push(@$trees, $this_tree);
  }
  $sth->finish;

  return $trees;
}
