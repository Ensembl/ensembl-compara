=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Compara::Homology;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning );

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet');

=head1 NAME

Bio::EnsEMBL::Compara::Homology - Homology between two proteins

=head1 SYNOPSIS

  use Bio::EnsEMBL::Registry;

  my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

  ## Please, refer to Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor
  ## to see how to get a Member from the database. Also, you can
  ## find alternative ways to fetch homologies in the POD for the
  ## Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor module.

  my $homologies = $homology_adaptor->fetch_all_by_Member($member);

  foreach my $this_homology (@$homologies) {
    my $homologue_genes = $this_homology->gene_list();
    print join(" and ", @$homologue_genes), " are ",
        $this_homology->description, "\n";
  }

=head1 AUTHOR

Ensembl Team


=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org

=head1 INHERITANCE

This class inherits all the methods and attributes from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


=head2 is_tree_compliant

  Arg [1]    : float $is_tree_compliant (optional)
  Example    : $is_compliant = $homology->is_tree_compliant();
               $homology->is_tree_compliant(1);
  Description: getter/setter for a flag that shows whether the homology is fully compliant with the tree
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub is_tree_compliant {
  my $self = shift;
  $self->{'_is_tree_compliant'} = shift if(@_);
  return $self->{'_is_tree_compliant'};
}



## dN/dS methods
#################

=head2 n

  Arg [1]    : float $n (optional)
  Example    : $n = $homology->n();
               $homology->n(3);
  Description: getter/setter of number of nonsynonymous positions for the homology.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub n {
  my $self = shift;
  $self->{'_n'} = shift if(@_);
  return $self->{'_n'};
}


=head2 s

  Arg [1]    : float $s (optional)
  Example    : $s = $homology->s();
               $homology->s(4);
  Description: getter/setter of number of synonymous positions for the homology.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub s {
  my $self = shift;
  $self->{'_s'} = shift if(@_);
  return $self->{'_s'};
}


=head2 lnl

  Arg [1]    : float $lnl (optional)
  Example    : $lnl = $homology->lnl();
               $homology->lnl(-1234.567);
  Description: getter/setter of number of the negative log likelihood for the dnds homology calculation.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub lnl {
  my $self = shift;
  $self->{'_lnl'} = shift if(@_);
  return $self->{'_lnl'};
}

=head2 threshold_on_ds

  Arg [1]    : float $threshold_on_ds (optional)
  Example    : $lnl = $homology->threshold_on_ds();
               $homology->threshold_on_ds(1.01340);
  Description: getter/setter of the threshold on ds for which the dnds ratio still makes sense.
               Note that threshold_on_ds is a property of the current MethodLinkSpeciesSet, and
               is shared by all its homologies
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub threshold_on_ds {
  my $self = shift;
  $self->method_link_species_set->add_tag('threshold_on_ds', shift) if (@_);
  return $self->method_link_species_set->get_value_for_tag('threshold_on_ds');
}

=head2 dn

  Arg [1]    : floating $dn (can be undef)
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1.
  Example    : $homology->dn or $homology->dn(0.1209)
               if you want to retrieve dn without applying threshold_on_ds, the right call
               is $homology->dn(undef,0).
  Description: set/get the non synonymous subtitution rate
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub dn {
  my ($self, $dn, $apply_threshold_on_ds) = @_;

  $self->{'_dn'} = $dn if (defined $dn);
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  unless (defined $self->ds(undef, $apply_threshold_on_ds)) {
    return undef;
  }

  return $self->{'_dn'};
}

=head2 ds

  Arg [1]    : floating $ds (can be undef)
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->ds or $homology->ds(0.9846)
               if you want to retrieve ds without applying threshold_on_ds, the right call
               is $homology->dn(undef,0).
  Description: set/get the synonymous subtitution rate
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub ds {
  my ($self, $ds, $apply_threshold_on_ds) = @_;

  $self->{'_ds'} = $ds if (defined $ds);
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  if (defined $self->{'_ds'} && 
      defined $self->threshold_on_ds &&
      $self->{'_ds'} > $self->threshold_on_ds) {
    
    if ($apply_threshold_on_ds) {
      return undef;
    } else {
      warning("Threshold on ds values is switched off. Be aware that you may obtain saturated ds values that are not to be trusted, neither the dn/ds ratio\n");
    }
  }

  return $self->{'_ds'};
}

=head2 dnds_ratio

  Arg [1]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->dnds_ratio or
               $homology->dnds_ratio(0) if you want to obtain a result
               even when the dS is above the threshold on dS.
  Description: return the ratio of dN/dS
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub dnds_ratio {
  my $self = shift;
  my $apply_threshold_on_ds = shift;
  
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  my $ds = $self->ds(undef, $apply_threshold_on_ds);
  my $dn = $self->dn(undef, $apply_threshold_on_ds);

  return undef if (not defined $dn) or (not defined $ds) or ($ds == 0);

  unless (defined $self->{'_dnds_ratio'}) {
    $self->{'_dnds_ratio'} = sprintf("%.5f",$dn/$ds);
  }

  return $self->{'_dnds_ratio'};
}


## General I/O
###############

=head2 print_homology

 Example    : $homology->print_homology
 Description: This method prints a short descriptor of the homology
	      USE ONLY FOR DEBUGGING not for data output since the
	      format of this output may change as need dictates.

=cut

sub print_homology {
  my $self = shift;
  
  printf("Homology %d,%s,%s : ", $self->dbID, $self->description, $self->subtype);
  foreach my $member (@{$self->gene_list}) {
    printf("%s(%d)\t", $member->stable_id, $member->dbID);
  }
  print("\n");
}




=head2 homology_key

  Example    : my $key = $homology->homology_key;
  Description: returns a string uniquely identifying this homology in world space.
               uses the gene_stable_ids of the members and orders them by taxon_id
               and concatonates them together.  
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub homology_key {
  my $self = shift;
  return $self->{'_homology_key'} if(defined($self->{'_homology_key'}));
  
  my @genes = sort {$a->taxon_id <=> $b->taxon_id || $a->stable_id cmp $b->stable_id} @{$self->gene_list};
  @genes = map ($_->stable_id, @genes);

  my $homology_key = join('_', @genes);
  return $homology_key;
}


=head2 gene_tree_node

  Arg [1]    : GeneTreeNode $node (optional)
  Example    : $node = $homology->gene_tree_node();
  Description: getter/setter for the GeneTreeNode this homology refers to
  Returntype : GeneTreeNode
  Exceptions : none
  Caller     : general

=cut

sub gene_tree_node {
    my $self = shift;

    if (@_) {
        $self->{_gene_tree_node} = shift;
        $self->{_gene_tree} = $self->{_gene_tree_node}->tree;
        $self->{_gene_tree_node_id} = $self->{_gene_tree_node}->node_id;
        $self->{_gene_tree_root_id} = $self->{_gene_tree_node}->{_root_id};
    } elsif (not exists $self->{_gene_tree_node} and defined $self->{_gene_tree_node_id}) {
        $self->{_gene_tree_node} = $self->adaptor->db->get_GeneTreeNodeAdaptor->fetch_node_by_node_id($self->{_gene_tree_node_id});
        $self->{_gene_tree} = $self->{_gene_tree_node}->tree;
    }
    return $self->{_gene_tree_node};
}


=head2 gene_tree

  Arg [1]    : GeneTree $node (optional)
  Example    : $tree = $homology->gene_tree();
  Description: getter for the GeneTree this homology refers to
  Returntype : GeneTree
  Exceptions : none
  Caller     : general

=cut

sub gene_tree {
    my $self = shift;

    $self->gene_tree_node;         # to load the gene tree objects
    return $self->{_gene_tree};
}


sub _species_tree_node_id {
    my $self = shift;
    $self->{_species_tree_node_id} = shift if @_;
    return $self->{_species_tree_node_id};
}


=head2 species_tree_node

  Example    : $species_tree_node = $homology->species_tree_node();
  Description: getter for the GeneTree this homology refers to
  Returntype : GeneTree
  Exceptions : none
  Caller     : general

=cut

sub species_tree_node {
    my $self = shift;

    if ($self->{_species_tree_node_id} and not $self->{_species_tree_node}) {
        $self->{_species_tree_node} = $self->adaptor->db->get_SpeciesTreeNodeAdaptor->fetch_node_by_node_id($self->{_species_tree_node_id});
    }
    return $self->{_species_tree_node};
}


=head2 taxonomy_level

  Example    : $taxonomy_level = $homology->taxonomy_level();
  Description: getter of string description of homology taxonomy_level.
               Examples: 'Chordata', 'Euteleostomi', 'Homo sapiens'
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub taxonomy_level {
    my $self = shift;
    return $self->species_tree_node()->node_name();
}




=head2 node_id

  Description: DEPRECATED: Use $self->gene_tree_node()->node_id() instead. node_id() will be removed in e76

=cut

sub node_id {  ## DEPRECATED
  my $self = shift;
  deprecate('$self->node_id() is deprecated and will be removed in e76. Use $self->gene_tree_node()->node_id() instead.');
  $self->{'_gene_tree_node_id'} = shift if(@_);
  return $self->{'_gene_tree_node_id'};
}

=head2 ancestor_node_id

  Description: DEPRECATED: Use $self->gene_tree_node()->node_id() instead. ancestor_tree_node_id() will be removed in e76

=cut

sub ancestor_node_id { ## DEPRECATED
  my $self = shift;
  deprecate('$self->ancestor_tree_node_id() is deprecated and will be removed in e76. Use $self->gene_tree_node()->node_id() instead.');
  $self->{'_gene_tree_node_id'} = shift if(@_);
  return $self->{'_gene_tree_node_id'};
}


=head2 tree_node_id

  Description: DEPRECATED: Use $self->gene_tree()->dbID() instead. tree_node_id() will be removed in e76

=cut

sub tree_node_id { ## DEPRECATED
  my $self = shift;
  deprecate('$self->tree_node_id() is deprecated and will be removed in e76. Use $self->gene_tree()->dbID() instead.');
  return $self->gene_tree()->dbID();
}


=head2 subtype

  Description:  DEPRECATED . Homology::subtype() is deprecated and will be removed in e76. Use taxonomy_level() instead

=cut

sub subtype {  ## DEPRECATED
    my $self = shift;
    deprecate("Homology::subtype() is deprecated and will be removed in e76. Use taxonomy_level() instead.");
    return $self->taxonomy_level();
}


=head2 taxonomy_alias

  Description:  DEPRECATED . Homology::taxonomy_alias() is deprecated and will be removed in e76. Use species_tree_node()->taxon()->ensembl_alias() instead

=cut

sub taxonomy_alias {  ## DEPRECATED
    my $self = shift;
    deprecate("Homology::taxonomy_alias() is deprecated and will be removed in e76. Use species_tree_node()->taxon()->ensembl_alias() instead.");
    return $self->species_tree_node()->taxon()->ensembl_alias();
}


1;

