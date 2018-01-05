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

package Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;
  
  my $string_handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
    -SOURCE => 'Ensembl', -SOURCE_VERSION => 63, -HANDLE => $string_handle
  );
  
  my $pt = $dba->get_GeneTreeAdaptor()->fetch_by_dbID(3);
  
  $w->write_trees($pt);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  
  my $xml_scalar_ref = $string_handle->string_ref();
  
  #Or to write to a file via IO::File
  my $file_handle = IO::File->new('output.xml', 'w');
  $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
    -SOURCE => 'Ensembl', -SOURCE_VERSION => 63, -HANDLE => $file_handle
  );
  $w->write_trees($pt);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $file_handle->close();
  
  #Or letting this deal with it
  $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
    -SOURCE => 'Ensembl', -SOURCE_VERSION => 63, -FILE => 'loc.xml'
  );
  $w->write_trees($pt);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $w->handle()->close();

=head1 DESCRIPTION

Used as a way of emitting Compara GeneTrees in a format which conforms
to L<OrthoXML|http://www.orthoxml.org/>. The code is built to work with
instances of L<Bio::EnsEMBL::Compara::GeneTreeNode>.

The same document is persistent between write_trees() calls so to create
a new XML document create a new instance of this object.

=head1 SUBROUTINES/METHODS

See inline

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Compara::Graph::BaseXMLWriter);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array check_array_contents);

use Bio::EnsEMBL::Compara::Utils::Preloader;

my $ortho_uri = 'http://orthoXML.org';

=pod

=head2 new()

  Arg[SOURCE]           : String; the source of the dumped data.
                          Defaults to B<Unknown>.
  Arg[SOURCE_VERSION]   : String; the version source of the dumped data.
                          Defaults to B<Unknown>.
  Arg[HANDLE]           : IO::Handle; pass in an instance of IO::File or
                          an instance of IO::String so long as it behaves
                          the same as IO::Handle. Can be left blank in 
                          favour of the -FILE parameter
  Arg[FILE]             : Scalar; file to write to              
  Arg[NO_RELEASE_TREES] : Boolean; if set to true this will force the writer
                          to avoid calling C<release_tree()> on every tree
                          given. Defaults to false
  Description : Creates a new tree writer object. 
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
                  -SOURCE => 'Ensembl',  -HANDLE => $handle
                );
  Status      : Stable  

=cut

sub new {
  my ($class, @args) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new(@args);
  
  my ($source, $source_version, $no_release_trees) =
    rearrange([qw(source source_version no_release_trees)], @args);

  $source ||= 'Unknown';
  $source_version ||= 'Unknown';

  $self->source($source);
  $self->source_version($source_version);
  $self->no_release_trees($no_release_trees);

  return $self;
}

=pod

=head2 namespaces()

Provides the namespaces used in this writer (the OrthoXML namespace)

=cut

sub namespaces {
  my ($self) = @_;
  return {
    "$ortho_uri/2011/" => ''
  };
}

=pod

=head2 no_release_trees()

  Arg [0] : Boolean; indicates if we need to avoid releasing trees
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub no_release_trees {
  my ($self, $no_release_trees) = @_;
  $self->{no_release_trees} = $no_release_trees if defined $no_release_trees;
  return $self->{no_release_trees};
}

=pod

=head2 source()

  Arg[0] : The value to set this to
  Description : Indicates the source of the stable identifiers for the 
                peptides.
  Returntype : String
  Exceptions : None
  Status     : Stable

=cut

sub source {
  my ($self, $source) = @_;
  $self->{source} = $source if defined $source;
  return $self->{source};
}

=pod

=head2 source_version()

  Arg[0] : The value to set this to
  Description : Indicates the version of the data
  Returntype : String
  Exceptions : None
  Status     : Stable

=cut

sub source_version {
  my ($self, $source_version) = @_;
  $self->{source_version} = $source_version if defined $source_version;
  return $self->{source_version};
}

=pod


=head2 write_homologies()

  Arg[0]      : The homology to write. Can be a single Homology or an ArrayRef
  Description : Writes an homology into the backing document representation
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the homology
  instance
  Example     : $writer->write_homologies($homology);
                $writer->write_homologies([$homology_one, $homology_two]);
  Status      : Stable

=cut

sub write_homologies {
    my ($self, $homologies) = @_;

    return unless scalar(@$homologies);
    my $db_adaptor = $homologies->[0]->adaptor->db;
    my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($db_adaptor->get_AlignedMemberAdaptor, $homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($db_adaptor->get_GeneMemberAdaptor, $sms);
    my $stns = Bio::EnsEMBL::Compara::Utils::Preloader::load_all_SpeciesTreeNodes($db_adaptor->get_SpeciesTreeNodeAdaptor, $homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_NCBITaxon($db_adaptor->get_NCBITaxonAdaptor, $stns);
    return $self->_write_AlignedMemberSets('Bio::EnsEMBL::Compara::Homology', $homologies);
}


=pod


=head2 write_trees()

  Arg[0]      : The tree to write. Can be a single Tree or an ArrayRef
  Description : Writes a tree into the backing document representation
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the tree
  instance
  Example     : $writer->write_trees($tree);
                $writer->write_trees([$tree_one, $tree_two]);
  Status      : Stable  

=cut

sub write_trees {
    my ($self, $trees) = @_;

    return $self->_write_AlignedMemberSets('Bio::EnsEMBL::Compara::GeneTree', $trees);
}


=head2 write_subtrees()

  Arg[0]      : The tree nodes to write. Can be a single GeneTreeNode or an ArrayRef
  Description : Writes a subtree into the backing document representation
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the tree
  instance
  Example     : $writer->write_subtrees($tree_node);
  Status      : Stable

=cut

sub write_subtrees {
    my ($self, $tree_nodes) = @_;

    return $self->_write_AlignedMemberSets('Bio::EnsEMBL::Compara::GeneTreeNode', $tree_nodes);
}


sub _write_AlignedMemberSets {
  my ($self, $type, $alns_sets) = @_;

  $alns_sets = wrap_array($alns_sets);

  throw("Not all the arguments are of type '$type'") unless check_array_contents($alns_sets, $type);

  # Create a list of all members, grouped by species
  my $hash_members = {};
  my $list_species = [];
  foreach my $aln_set (@{$alns_sets}) {
    my $all_members = $aln_set->isa('Bio::EnsEMBL::Compara::GeneTreeNode') ? $aln_set->get_all_leaves() : $aln_set->get_all_Members();
    foreach my $member (@$all_members) {
      if (not exists $hash_members->{$member->genome_db_id}) {
        push @{$list_species}, $member->genome_db;
        $hash_members->{$member->genome_db_id} = {};
      }
      $hash_members->{$member->genome_db_id}->{$member->seq_member_id} = $member;
    }
  }

  return $self->_write_data(
    $list_species,
    sub {
      my ($species) = @_;
      return [values %{$hash_members->{$species->dbID}}];
    },
    $alns_sets,
  );
}

=pod

=head2 _write_data()

  Arg[0]      : List reference of all the species (must contain GenomeDB objects)
  Arg[1]      : A function that, given a GenomeDB, returns a list of all the
                members used in the trees for this species
  Arg[2]      : List reference of all the trees
  Description : Generic method to write the content
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the tree
  instance
  Status      : Stable  

=cut

sub _write_data {
  my ($self, $list_species, $callback_list_members, $list_data_objects) = @_;
  my $w = $self->_writer();

  # Prints each database
  foreach my $species (@$list_species) {
    # species should be a GenomeDB instance

    my $all_members = $callback_list_members->($species);
    next unless scalar(@$all_members);

    $w->startTag("species", "NCBITaxId" => $species->taxon_id, "name" => $species->name);
    $w->startTag("database", "name" => $self->source_version, "version" => sprintf("%s/%s", $species->assembly, $species->genebuild));
    $w->startTag("genes");

    foreach my $member (@$all_members) {
	$w->emptyTag("gene", "id" => $member->seq_member_id, "geneId" => $member->gene_member->stable_id, ($member->source_name =~ /PEP$/ ? "protId" : "transcriptId") => $member->stable_id);
    }

    $w->endTag("genes");
    $w->endTag("database");
    $w->endTag("species");
  }

  # Prints the score definition
  $w->startTag("scores");
  $w->emptyTag("scoreDef", "id" => "bootstrap", "desc" => "Reliability of the branch");
  $w->emptyTag("scoreDef", "id" => "duplication_confidence_score", "desc" => "Reliability of the duplication");
  $w->emptyTag("scoreDef", "id" => "n", "desc" => "Number of non-synonymous mutations");
  $w->emptyTag("scoreDef", "id" => "s", "desc" => "Number of synonymous mutations");
  $w->emptyTag("scoreDef", "id" => "dn", "desc" => "Rate of non-synonymous mutations");
  $w->emptyTag("scoreDef", "id" => "ds", "desc" => "Rate of synonymous mutations");
  $w->emptyTag("scoreDef", "id" => "lnl", "desc" => "Likelihood of the n/s scores");
  $w->emptyTag("scoreDef", "id" => "dnds_ratio", "desc" => "dN/dS ratio");
  $w->emptyTag("scoreDef", "id" => "goc_score", "desc" => "Gene order conservation score");
  $w->emptyTag("scoreDef", "id" => "wga_coverage", "desc" => "Whole genome alignment coverage");
  $w->emptyTag("scoreDef", "id" => "perc_identity", "desc" => "Percentage of identity of this protein to the alignment");
  $w->endTag("scores");

  # Prints each tree
  $w->startTag("groups");
  foreach my $object (@{$list_data_objects}) {
    if ($object->isa('Bio::EnsEMBL::Compara::GeneTree')) {
      $self->_find_valid_genetree_roots($object->root);
      $object->release_tree() if ! $self->no_release_trees;
    } elsif ($object->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
      $self->_find_valid_genetree_roots($object);
    } elsif ($object->isa('Bio::EnsEMBL::Compara::Homology')) {
      $self->_homology_body($object);
    } else {
      throw("Cannot handle ".ref($object)."\n");
    }
  }
  $w->endTag("groups");

  return;
}

########### PRIVATE

sub _write_opening {
  my ($self, $w) = @_;
  my $xsi_uri = $self->xml_schema_namespace();
  $w->xmlDecl("UTF-8");
  $w->forceNSDecl("${ortho_uri}/2011/");
  $w->forceNSDecl($xsi_uri);
  $w->startTag("orthoXML", [$xsi_uri, 'schemaLocation'] => 
    "${ortho_uri} ${ortho_uri}/0.3/orthoxml.xsd",
    'version'=>'0.3',
    "origin" => $self->source,
    "originVersion" => $self->source_version,
  );

  return;
}

sub _write_closing {
  my ($self) = @_;
  $self->_writer()->endTag("orthoXML");
}


# an OrthoXML file must begin with a orthologGroup
# We need to scan the tree to call _genetreenode_body() on all such nodes
sub _find_valid_genetree_roots {
  my ($self, $tree) = @_;
  no warnings 'recursion';
  
  if (not $tree->is_leaf() and ($tree->node_type ne 'speciation')) {
    # Goes recursively until the next speciation node
    foreach my $child (@{$tree->children()}) {
      $self->_find_valid_genetree_roots($child);
    }
  } elsif (not $tree->is_leaf) {
    # Can now write the tree
    $self->_genetreenode_body($tree);
  }
  
  return;
}


###### PROCESSORS

#body writes data
sub _genetreenode_body {
  my ($self, $node) = @_;
  no warnings 'recursion';
  
  my $w = $self->_writer();
  
  if ($node->is_leaf) {
    return $w->emptyTag("geneRef", "id" => $node->seq_member_id);
  }

  my $tagname = $node->node_type ne 'speciation' ? "paralogGroup" : "orthologGroup";

  $w->startTag(
    $tagname,
    $node->can("stable_id") ? ("id" => $node->stable_id()) : ("id" => $node->node_id()),
  );

   # Scores
  foreach my $tag (qw(duplication_confidence_score bootstrap)) {
    next unless $node->has_tag($tag);
    my $value = $node->$tag;
    if (defined $value and $value ne '') {
      $w->emptyTag('score', 'id' => $tag, 'value' => $value);
    }
  }
  
  # Properties
  _taxonomy_info_properties($w, $node->species_tree_node);

  # dubious_duplication is in another field
  if ($node->get_value_for_tag('node_type', '') eq 'dubious') {
     $w->emptyTag('property', 'name' => 'dubious_duplication', 'value' => 1);
  }
  
  if($node->get_child_count()) {
    foreach my $child (@{$node->children()}) {
      $self->_genetreenode_body($child);
    }
    }
  
  return $w->endTag($tagname);
}


sub _homology_body {
    my ($self, $homology) = @_;

    my $w = $self->_writer();

    my $tagname = $homology->method_link_species_set->method->type eq 'ENSEMBL_PARALOGUES' ? "paralogGroup" : "orthologGroup";

    $w->startTag($tagname, 'id' => $homology->dbID);

    # Scores
    foreach my $tag (qw(n s dn ds lnl dnds_ratio goc_score wga_coverage)) {
        my $value = $homology->$tag;
        if (defined $value and $value ne '') {
            $w->emptyTag('score', 'id' => $tag, 'value' => $value);
        }
    }

    # Properties
    _taxonomy_info_properties($w, $homology->species_tree_node);
    foreach my $tag (qw(description is_tree_compliant is_high_confidence)) {
        $w->emptyTag('property', 'name' => $tag, 'value' => $homology->$tag) if defined $homology->$tag;
    }

    foreach my $member (@{$homology->get_all_Members}) {
        $w->startTag("geneRef", "id" => $member->seq_member_id);
        $w->emptyTag('score', 'id' => 'perc_identity', 'value' => $member->perc_id);
        $w->endTag('geneRef');
    }

    return $w->endTag($tagname);
}


sub _taxonomy_info_properties {
    my ($w, $species_tree_node) = @_;
    return unless $species_tree_node;
    $w->emptyTag('property', 'name' => 'taxon_name', 'value' => $species_tree_node->node_name);
    my $tax_id    = $species_tree_node->taxon_id;
    if ($tax_id) {
        $w->emptyTag('property', 'name' => 'taxon_id', 'value' => $tax_id);
        my $taxon = $species_tree_node->taxon;
        my $common_name = $species_tree_node->get_common_name;
        $w->emptyTag('property', 'name' => 'common_name', 'value' => $common_name) if $common_name;
        my $timetree = $species_tree_node->get_divergence_time;
        $w->emptyTag('property', 'name' => 'timetree_mya', 'value' => $timetree) if $timetree;
    }
}


1;
