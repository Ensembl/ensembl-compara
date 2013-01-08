package Bio::EnsEMBL::Compara::Homology;

use strict;
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

=head1 COPYRIGHT

Copyright (c) 1999-2013. Ensembl Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org

=head1 INHERITANCE

This class inherits all the methods and attributes from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


=head2 subtype

  Arg [1]    : string $subtype (optional)
  Example    : $subtype = $homology->subtype();
               $homology->subtype($subtype);
  Description: getter/setter of string description of homology subtype.
               Examples: 'Chordata', 'Euteleostomi', 'Homo sapiens'
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub subtype {
  my $self = shift;
  # deprecate("Use taxonomy_level() instead.");
  return $self->taxonomy_level(@_);
}


=head2 taxonomy_level

  Arg [1]    : string $taxonomy_level (optional)
  Example    : $taxonomy_level = $homology->taxonomy_level();
               $homology->taxonomy_level($taxonomy_level);
  Description: getter/setter of string description of homology taxonomy_level.
               Examples: 'Chordata', 'Euteleostomi', 'Homo sapiens'
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub taxonomy_level {
  my $self = shift;
  $self->{'_subtype'} = shift if(@_);
  $self->{'_subtype'} = '' unless($self->{'_subtype'});
  return $self->{'_subtype'};
}


=head2 taxonomy_alias

  Arg [1]    : string $taxonomy_alias (optional)
  Example    : $taxonomy_alias = $homology->taxonomy_alias();
               $homology->taxonomy_alias($taxonomy_alias);
  Description: get string description of homology taxonomy_alias.
               Examples: 'Chordates', 'Bony vertebrates', 'Homo sapiens'
               Defaults to taxonomy_level if alias is not in the db
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub taxonomy_alias {

    my $self = shift;

    my $ancestor_node_id = $self->ancestor_node_id;
    return unless $ancestor_node_id;

    my $ancestor_node = $self->adaptor->db->get_GeneTreeNodeAdaptor->fetch_node_by_node_id($ancestor_node_id);
    return unless $ancestor_node;

    my $taxon_id = $ancestor_node->get_tagvalue('taxon_id');
    return unless $taxon_id;

    my $taxon = $self->adaptor->db->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($taxon_id);
    return unless $taxon;

    return $taxon->ensembl_alias();
}


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

  Arg [1]    : float $threshold_ond_ds (optional)
  Example    : $lnl = $homology->threshold_on_ds();
               $homology->threshold_on_ds(1.01340);
  Description: getter/setter of the threshold on ds for which the dnds ratio still makes sense.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub threshold_on_ds {
  my $self = shift;
  $self->{'_threshold_on_ds'} = shift if(@_);
  return $self->{'_threshold_on_ds'};
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
      defined $self->{'_threshold_on_ds'} &&
      $self->{'_ds'} > $self->{'_threshold_on_ds'}) {
    
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

  unless (defined $dn &&
          defined $ds &&
          $ds !=0) {
    return undef;
  }

  unless (defined $self->{'_dnds_ratio'}) {
    $self->{'_dnds_ratio'} = sprintf("%.5f",$dn/$ds);
  }

  return $self->{'_dnds_ratio'};
}



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


=head2 get_all_PeptideAlignFeature

  Description: returns a reference to an empty array as we don't have any
               PeptideAlignFeatures associated to the homologies
  Returntype : array ref
  Exceptions :
  Caller     :

=cut

sub get_all_PeptideAlignFeature {

    deprecate("Homologies don't have PeptideAlignFeatures any more. Use DBSQL::PeptideAlignFeatureAdaptor::fetch_all_by_qmember_id_hmember_id() instead. get_all_PeptideAlignFeature() will be removed in release 70");
    return [];
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


=head2 node_id

  Arg [1]    : int $node_id (optional)
  Example    : $node_id = $homology->node_id();
               $homology->subtype($node_id);
  Description: getter/setter of integer that refer to a node_id in the protein_tree data.
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub node_id {
  my $self = shift;

  $self->{'_ancestor_node_id'} = shift if(@_);
  $self->{'_ancestor_node_id'} = '' unless($self->{'_ancestor_node_id'});
  return $self->{'_ancestor_node_id'};
  
}

=head2 ancestor_node_id

  Arg [1]    : int $ancestor_node_id (optional)
  Example    : $ancestor_node_id = $homology->ancestor_node_id();
               $homology->subtype($ancestor_node_id);
  Description: getter/setter of integer that refer to the ancestor_node_id in the protein_tree data.
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub ancestor_node_id {
  my $self = shift;

  $self->{'_ancestor_node_id'} = shift if(@_);
  $self->{'_ancestor_node_id'} = '' unless($self->{'_ancestor_node_id'});
  return $self->{'_ancestor_node_id'};
  
}


=head2 tree_node_id

  Arg [1]    : int $tree_node_id (optional)
  Example    : $tree_node_id = $homology->tree_node_id();
               $homology->subtype($tree_node_id);
  Description: getter/setter of integer that refer to the tree node_id in the protein_tree data.
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub tree_node_id {
  my $self = shift;

  $self->{'_tree_node_id'} = shift if(@_);
  $self->{'_tree_node_id'} = '' unless($self->{'_tree_node_id'});
  return $self->{'_tree_node_id'};
  
}


1;

