=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::Homology - Homology between two proteins

=head1 DESCRIPTION

Homology is the object that stores orthology and paralogy data.
It inherits from AlignedMemberSet, and extends it on two aspects.
Firstly, each homology is reconciled with the gene tree and the
species tree. Secondly, we compute dN and dS values on some of the
homologies.

Please note that 1-to-many relations are stored as multiple pairs.
For instance, "hum" <-> ("rat1", "rat2") is stored as "hum" <-> "rat1"
and "hum" <-> "rat2".

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::Homology
  `- Bio::EnsEMBL::Compara::AlignedMemberSet

=head1 SYNOPSIS

General getters:
 - description()
 - toString()

dN/dS values:
 - n()
 - s()
 - lnl()
 - threshold_on_ds()
 - dn()
 - ds()
 _ dnds_ratio()

Reconciliation with the gene tree:
 - is_tree_compliant()
 - gene_tree_node()
 - gene_tree()
 - species_tree_node()
 - taxonomy_level() (alias to species_tree_node()->node_name())

 Ortholog quality scores
 - goc_score
 - wga_coverage
 - is_high_confidence

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Homology;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet');


# These are the general-purpose full-text descriptions of the homology types
our %PLAIN_TEXT_DESCRIPTIONS = (

      ortholog_one2one          => '1-to-1 orthologues',
      ortholog_one2many         => '1-to-many orthologues',
      ortholog_many2many        => 'many-to-many orthologues',

      homoeolog_one2one         => '1-to-1 homoeologues',
      homoeolog_one2many        => '1-to-many homoeologues',
      homoeolog_many2many       => 'many-to-many homoeologues',

      within_species_paralog    => 'Paralogues',
      other_paralog             => 'Ancient paralogues',
      between_species_paralog   => 'Paralogues (different species)',

      gene_split                => 'Split genes',

      alt_allele                => 'Alternative alleles'
);


# These are context-aware descriptions used by the web-code
our %PLAIN_TEXT_WEB_DESCRIPTIONS = (

      %PLAIN_TEXT_DESCRIPTIONS,

      ortholog_one2one          => '1-to-1',
      ortholog_one2many         => '1-to-many',
      ortholog_many2many        => 'many-to-many',

      homoeolog_one2one         => '1-to-1',
      homoeolog_one2many        => '1-to-many',
      homoeolog_many2many       => 'many-to-many',

);



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

##gene order conservation based orthologQC

=head2 goc_score

  Arg [1]    : float $goc_score (optional)
  Example    : $goc_score = $homology->goc_score();
               $homology->goc_score(3);
  Description: getter/setter of number of nonsynonymous positions for the homology.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub goc_score {
  my $self = shift;
  $self->{'_goc_score'} = shift if(@_);
  return $self->{'_goc_score'};
}

## ortholog score based on whole genome alignments

=head2 wga_coverage

  Arg [1]    : float $wga_coverage (optional)
  Example    : $wga_coverage = $homology->wga_coverage();
               $homology->wga_coverage(39.7);
  Description: getter/setter of wga coverage for the homology.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub wga_coverage {
  my $self = shift;
  $self->{'_wga_coverage'} = shift if(@_);
  return $self->{'_wga_coverage'};
}


=head2 is_high_confidence

  Example     : $homology->is_high_confidence();
  Description : Tells whether the homology is considered "high-confidence" (after considering goc_score, wga_coverage, %id, %cov, etc)
  Returntype  : boolean
  Exceptions  : none
  Caller      : general

=cut

sub is_high_confidence {
    my $self = shift;
    $self->{'_is_high_confidence'} = shift if(@_);
    return $self->{'_is_high_confidence'};
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
  return $self->method_link_species_set->_getter_setter_for_tag('threshold_on_ds', @_);
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

=head2 toString

  Example     : print $homology->toString();
  Description : This method returns a short text-description of the homology
                USE ONLY FOR DEBUGGING not for data output since the
                format of this output may change as need dictates.
  Returntype  : String
  Exceptions  : none
  Caller      : general

=cut

sub toString {
    my $self = shift;
    my $txt = sprintf('Homology dbID=%d %s @ %s', $self->dbID, $self->description, $self->taxonomy_level);
    $txt .= ' between '.join(' and ', map {$_->stable_id} @{$self->gene_list});
    $txt .= sprintf(' [dN=%.2f dS=%.2f dN/dS=%s]', $self->dn, $self->ds, $self->dnds_ratio ? sprintf('%.2f', $self->dnds_ratio) : 'NA' ) if $self->ds;
    return $txt;
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


=head2 _gene_tree_node_id

  Example     : my $_gene_tree_node_id = $homology->_gene_tree_node_id();
  Example     : $homology->_gene_tree_node_id($_gene_tree_node_id);
  Description : Getter/Setter for the dbID of the gene-tree node this homology comes from
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub _gene_tree_node_id {
    my $self = shift;
    $self->{'_gene_tree_node_id'} = shift if @_;
    return $self->{'_gene_tree_node_id'};
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


=head2 _gene_tree_root_id

  Example     : my $_gene_tree_root_id = $homology->_gene_tree_root_id();
  Example     : $homology->_gene_tree_root_id($_gene_tree_root_id);
  Description : Getter/Setter for the gene-tree root dBID this homology refers to.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub _gene_tree_root_id {
    my $self = shift;
    $self->{'_gene_tree_root_id'} = shift if @_;
    return $self->{'_gene_tree_root_id'};
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
        $self->{_species_tree_node} = $self->adaptor->db->get_SpeciesTreeNodeAdaptor->cached_fetch_by_dbID($self->{_species_tree_node_id});
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
    return $self->species_tree_node() ? $self->species_tree_node()->node_name() : undef;
}


1;

