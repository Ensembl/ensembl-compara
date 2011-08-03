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
  
  my $pt = $dba->get_ProteinTreeAdaptor()->fetch_node_by_node_id(2);
  
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

Used as a way of emitting Compara ProteinTrees in a format which conforms
to L<OrthoXML|http://www.orthoxml.org/>. The code is built to work with
instances of L<Bio::EnsEMBL::Compara::ProteinTree> but can be extended to
operate on any tree structure provided by the Compara Graph infrastructure.

The code provides a number of property extensions to the existing OrthoXML
standard:

=over 8

=item B<Compara:genome_db_name>

Used to show the name of the GenomeDB of the species found. Useful when 
taxonomy is not exact

=item B<Compara:dubious_duplication> 

Indicates locations of potential duplications we are unsure about

=back

The same document is persistent between write_trees() calls so to create
a new XML document create a new instance of this object.

=head1 SUBROUTINES/METHODS

See inline

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 LICENSE

 Copyright (c) 1999-2011 The European Bioinformatics Institute and
 Genome Research Limited.  All rights reserved.

 This software is distributed under a modified Apache license.
 For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <dev@ensembl.org>.

 Questions may also be sent to the Ensembl help desk at
 <helpdesk@ensembl.org>.

=cut

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Compara::Graph::BaseXMLWriter);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

my $ortho_uri = 'http://orthoXML.org';

=pod

=head2 new()

  Arg[SOURCE]           : String; the source of the stable identifiers.
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

  Arg [0] : Boolean; indiciates if we need to avoid releasing trees
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
  my $w = $self->_writer();
  $trees = wrap_array($trees);

  # Create a list of all members, groupes by species
  my $hash_members = {};
  foreach my $tree (@{$trees}) {
    $self->_get_members_list($tree, $hash_members);
  }

  # Prints each database
  foreach my $species (keys %{$hash_members}) {
    my $members = ${$hash_members}{$species};
    my $genome_db = ${$members}{"GENOMEDB"};

    $w->startTag("species", "NCBITaxId" => $genome_db->taxon_id, "name" => $genome_db->name);
    $w->startTag("database", "name" => $self->source_version, "version" => sprintf("%s/%s", $genome_db->assembly, $genome_db->genebuild));
    $w->startTag("genes");

    foreach my $leaf (values %{$members}) {
      next if check_ref($leaf, "Bio::EnsEMBL::Compara::GenomeDB");
	$w->emptyTag("gene", "id" => $leaf->member_id, "geneId" => $leaf->gene_member->stable_id, ($leaf->source_name eq "ENSEMBLPEP" ? "protId" : "transcriptId") => $leaf->stable_id);
    }

    $w->endTag("genes");
    $w->endTag("database");
    $w->endTag("species");
  }

  # Prints the score definition
  $w->startTag("scores");
  $w->emptyTag("scoreDef", "id" => "Bootstrap", "desc" => "Reliability of the branch");
  $w->emptyTag("scoreDef", "id" => "duplication_confidence_score", "desc" => "Reliability of the duplication");
  $w->endTag("scores");

  # Prints each tree
  $w->startTag("groups");
  foreach my $tree (@{$trees}) {
    $self->_write_tree($tree);
    $tree->release_tree() if ! $self->no_release_trees;
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

sub _get_members_list {
  my ($self, $tree, $hash_members) = @_;

  foreach my $leaf (@{$tree->get_all_leaves}) {
    if (not defined ${$hash_members}{$leaf->genome_db_id}) {
      ${$hash_members}{$leaf->genome_db_id} = {"GENOMEDB" => $leaf->genome_db};
    }
    ${${$hash_members}{$leaf->genome_db_id}}{$leaf->member_id} = $leaf;
  }
}

sub _write_tree {
  my ($self, $tree) = @_;
  
  # an OrthoXML file must begin with a orthologGroup
  if (_is_reliable_duplication($tree)) {
    # Goes recursively until the next speciation node
    foreach my $child (@{$tree->children()}) {
      $self->_write_tree($child);
    }
  } else {
    # Can now write the tree
    $self->_process($tree);
  }
  
  return;
}

sub _is_reliable_duplication {
  my $node = shift;
  my $sis = $node->get_tagvalue('duplication_confidence_score');
  return ($node->get_tagvalue('Duplication') >= 2 and defined $sis and $sis >= 0.25);
}

sub _process {
  my ($self, $node) = @_;

  if(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeMember')) {
    return $self->_writer->emptyTag("geneRef", "id" => $node->member_id);
  }
  elsif(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeNode')) {
    my $tagname = _is_reliable_duplication($node) ? "paralogGroup" : "orthologGroup";

    my $w = $self->_writer();
    $w->startTag(
      $tagname,
      $node->stable_id() ? ("id" => $node->stable_id()) : ("id" => $node->node_id()),
    );
 
    $self->_genetreenode_body($node);
 
    $w->endTag($tagname);
    return;
  }
  my $ref = ref($node);
  throw("Cannot process type $ref");
}

###### PROCESSORS

#body writes data
sub _genetreenode_body {
  my ($self, $node) = @_;
  
  my $w = $self->_writer();
  
   # Scores
  foreach my $tag (qw(duplication_confidence_score Bootstrap)) {
    my $value = $node->get_tagvalue($tag);
    if (defined $value and $value ne '') {
      $w->emptyTag('score', 'id' => $tag, 'value' => $value);
    }
  }
  
  # Properties
  foreach my $tag (qw(dubious_duplication taxon_id taxon_name)) {
    my $value = $node->get_tagvalue($tag);
    if (defined $value and $value ne '') {
      $w->emptyTag('property', 'name' => $tag, 'value' => $value);
    }
  }
  
  if($node->get_child_count()) {
    foreach my $child (@{$node->children()}) {
      $self->_process($child);
    }
    }
  
  return;
}


1;
