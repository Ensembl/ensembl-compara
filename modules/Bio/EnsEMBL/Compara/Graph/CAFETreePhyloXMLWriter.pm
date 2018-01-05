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

package Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter;

  my $string_handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -HANDLE => $string_handle
  );

  my $ct = $dba->get_CAFETreeAdaptor()->fetch_by_dbID(3);

  $w->write_trees($ct);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG

  my $xml_scalar_ref = $string_handle->string_ref();

  #Or to write to a file via IO::File
  my $file_handle = IO::File->new('output.xml', 'w');
  $w = Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -HANDLE => $file_handle
  );
  $w->write_trees($ct);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $file_handle->close();

  #Or letting this deal with it
  $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -FILE => 'loc.xml'
  );
  $w->write_trees($ct);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $w->handle()->close();

=head1 DESCRIPTION

Used as a way of emitting Compara Gene Gain/Loss Tree (aka CAFE Trees) in a format which conforms
to L<PhyloXML|http://www.phyloxml.org/>. The code is built to work with
instances of L<Bio::EnsEMBL::Compara::CAFETree>
The code provides a number of property extensions to the existing PhyloXML
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

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

use base qw/Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter/;

=pod

=head2 new()

  Description : Creates a new tree writer object.
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -HANDLE => $handle
                );
  Status      : Stable

=cut

sub new {
  my ($class, @args) = @_;
  $class = ref ($class) || $class;
  my $self = $class->SUPER::new(@args);

  return $self;
}

sub tree_elements {
  my ($self, $tree) = @_;

  my $w = $self->_writer();

  my $lambda = $tree->lambdas();
  $w->dataElement('property', $lambda,
		  'datatype' => 'xsd:double',
		  'ref' => 'Compara:lambda',
		  'applies_to' => 'phylogeny');

  return;
}

sub dispatch_tag {
  my ($self, $node) = @_;

  if (check_ref ($node, 'Bio::EnsEMBL::Compara::CAFEGeneFamilyNode')) {
    return $self->_node_tag($node);
  }

  my $ref = ref($node);
  throw ("Cannot process type $ref");
}

sub dispatch_body {
  my ($self, $node) = @_;

  if (check_ref ($node, 'Bio::EnsEMBL::Compara::CAFEGeneFamilyNode')) {
    $self->_node_body($node);
    return;
  }

  my $ref = ref($node);
  throw ("Cannot process type $ref");
}


####### PROCESSORS

sub _node_tag {
  my ($self, $node) = @_;
  return ['clade', {branch_length => $node->distance_to_parent()}];
}


sub _node_body {
  my ($self, $node) = @_;

  my $n_members = $node->n_members;
  my $pvalue = $node->pvalue;

  my $w = $self->_writer();

  $w->dataElement('confidence', $pvalue, 'type' => 'pvalue') if defined $pvalue;

  #Taxon
  $self->_write_species_tree_node($node);

  $w->startTag('binary_characters', 'present_count' => $n_members);
  # $w->dataElement('present_count', $n_members);
  $w->endTag();

  return;
}

sub tree_type {
  return 'Gene Gain/Loss Tree';
}

1;
