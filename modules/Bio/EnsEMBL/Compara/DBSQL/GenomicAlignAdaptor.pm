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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::DBSQL::GenomicAlignAdaptor - Object adaptor to access data in the genomic_align table

=head1 SYNOPSIS

  Please, consider using the Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor instead.

=head2 Get the adaptor from the Registry

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous");

  my $genomic_align_adaptor = $reg->get_adaptor(
      "Multi", "compara", "GenomicAlign");

=head2 Store method

  $genomic_align_adaptor->store($synteny_region);

=head2 Fetching methods

  my $genomic_align = $genomic_align_adaptor->fetch_by_dbID(1);

  my $genomic_aligns = $genomic_align_adaptor->
      fetch_by_GenomicAlignBlock($genomic_align_block);

  my $genomic_aligns = $genomic_align_adaptor->
      fetch_by_genomic_align_block_id(1001);

=head2 Other methods

  $genomic_align_adaptor->delete_by_genomic_align_block_id(1001);

  $genomic_align = $genomic_align_adaptor->
      retrieve_all_direct_attributes($genomic_align);

=head1 DESCRIPTION

This module is intended to access data in the genomic_align table. In most cases, you want to use
the Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor instead.

Each alignment is represented by Bio::EnsEMBL::Compara::GenomicAlignBlock. Each GenomicAlignBlock
contains several Bio::EnsEMBL::Compara::GenomicAlign, one per sequence included in the alignment.
The GenomicAlign contains information about the coordinates of the sequence and the sequence of
gaps, information needed to rebuild the aligned sequence. By combining all the aligned sequences
of the GenomicAlignBlock, it is possible to get the orignal alignment back.

=head1 INHERITANCE

This class inherits all the methods and attributes from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 SEE ALSO

 - Bio::EnsEMBL::Registry
 - Bio::EnsEMBL::DBSQL::BaseAdaptor
 - Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor
 - Bio::EnsEMBL::Compara::GenomicAlignBlock
 - Bio::EnsEMBL::Compara::GenomicAlign
 - Bio::EnsEMBL::Compara::DnaFrag;

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


=head2 store

  Arg  1     : listref  Bio::EnsEMBL::Compara::GenomicAlign $ga 
               The things you want to store
  Example    : none
  Description: It stores the given GA in the database. Attached
               objects are not stored. Make sure you store them first.
  Returntype : none
  Exceptions : throw if the linked Bio::EnsEMBL::Compara::DnaFrag object or
               the linked Bio::EnsEMBL::Compara::GenomicAlignBlock or
               the linked Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               are not in the database
  Caller     : $object->methodname
  Status     : Stable

=cut

sub store {
  my ( $self, $genomic_aligns ) = @_;

  my $genomic_align_sql = qq{INSERT INTO genomic_align (
          genomic_align_id,
          genomic_align_block_id,
          method_link_species_set_id,
          dnafrag_id,
          dnafrag_start,
          dnafrag_end,
          dnafrag_strand,
          cigar_line,
          visible,
          node_id
      ) VALUES (?,?,?, ?,?,?, ?,?,?,?)};
  
  my $genomic_align_sth = $self->prepare($genomic_align_sql);
  
  for my $ga ( @$genomic_aligns ) {
    if(!defined($ga->dnafrag_id)) {
      throw( "dna_fragment in GenomicAlign is not in DB" );
    }
    if(!defined($ga->genomic_align_block) or !defined($ga->genomic_align_block->dbID)) {
      throw( "genomic_align_block in GenomicAlign is not in DB" );
    }
    if(!defined($ga->method_link_species_set) or !defined($ga->method_link_species_set->dbID)) {
      throw( "method_link_species_set in GenomicAlign is not in DB" );
    }

    $genomic_align_sth->execute(
            ($ga->dbID or undef),
            $ga->genomic_align_block->dbID,
            $ga->method_link_species_set->dbID,
            $ga->dnafrag_id,
            $ga->dnafrag_start,
            $ga->dnafrag_end,
            $ga->dnafrag_strand,
            ($ga->cigar_line or "NULL"),    # FIXME: please check that this "NULL" string in a mediumtext field is what you really want
            $ga->visible,
	    ($ga->node_id or undef)
        );

    if (!$ga->dbID) {
      $ga->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'genomic_align', 'genomic_align_id') );
    }

    info("Stored Bio::EnsEMBL::Compara::GenomicAlign ".
          ($ga->dbID or "NULL").
          ", gab=".$ga->genomic_align_block->dbID.
          ", mlss=".$ga->method_link_species_set->dbID.
          ", dnaf=".$ga->dnafrag_id.
          " [".$ga->dnafrag_start.
          "-".$ga->dnafrag_end."]".
          " (".$ga->dnafrag_strand.")".
          ", cgr=".($ga->cigar_line or "NULL").
          ", vis=".$ga->visible);

  }
}


=head2 delete_by_genomic_align_block_id

  Arg  1     : integer $genomic_align_block_id
  Example    : $gen_ali_blk_adaptor->delete_by_genomic_align_block_id(352158763);
  Description: It removes the matching GenomicAlign objects from the database
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub delete_by_genomic_align_block_id {
  my ($self, $genomic_align_block_id) = @_;

  my $genomic_align_sql =
        qq{DELETE FROM genomic_align WHERE genomic_align_block_id = ?};
  
  ## Deletes genomic_block entries
  my $sth = $self->prepare($genomic_align_sql);
  $sth->execute($genomic_align_block_id);
}


=head2 fetch_all_by_GenomicAlignBlock

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock object with a valid dbID
  Example    : my $genomic_aligns =
                    $genomic_align_adaptor->fetch_all_by_GenomicAlignBlock($genomic_align_block);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlign objects
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : Returns a ref. to an empty array if there are no matching entries
  Exceptions : Thrown if $genomic_align_block is not a
               Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Caller     : object::methodname
  Status     : Stable

=cut

sub fetch_all_by_GenomicAlignBlock {
  my ($self, $genomic_align_block) = @_;
  my $genomic_aligns = [];

  assert_ref($genomic_align_block, 'Bio::EnsEMBL::Compara::GenomicAlignBlock', 'genomic_align_block');
  my $genomic_align_block_id = $genomic_align_block->dbID;

  return $self->fetch_all_by_genomic_align_block_id($genomic_align_block_id);
}


=head2 fetch_all_by_genomic_align_block_id

  Arg  1     : integer $genomic_align_block_id
  Example    : my $genomic_aligns =
                    $genomic_align_adaptor->fetch_all_by_genomic_align_block_id(23134);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlign objects
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : Returns a ref. to an empty array if there are no matching entries
  Exceptions : Thrown if $genomic_align_block is neither a number 
  Caller     : object::methodname
  Status     : Stable

=cut

sub fetch_all_by_genomic_align_block_id {
  my ($self, $incoming_genomic_align_block_id, $species_list) = @_;

  if ($species_list) {
    my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor;
    my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => $species_list);
    return [] unless @$genome_dbs;
    my @species_dbIDs = map {$_->dbID} @$genome_dbs;
    my $species_dbIDs_str=join(',',@species_dbIDs);
    my $join = [[['dnafrag', 'df'], 'ga.dnafrag_id = df.dnafrag_id']];
    $self->bind_param_generic_fetch($incoming_genomic_align_block_id, SQL_INTEGER);
    return $self->generic_fetch("genomic_align_block_id = ? AND df.genome_db_id IN ($species_dbIDs_str)", $join);

  } else {
    $self->bind_param_generic_fetch($incoming_genomic_align_block_id, SQL_INTEGER);
    return $self->generic_fetch('genomic_align_block_id = ?');
  }
}

=head2 fetch_all_by_node_id

  Arg  1     : integer $node_id
  Example    : my $genomic_aligns =
                    $genomic_align_adaptor->fetch_all_by_node_id(5530002705680);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlign objects
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : Returns a ref. to an empty array if there are no matching entries
  Exceptions : Thrown if $node_id is not a number 
  Caller     : object::methodname
  Status     : At risk

=cut

sub fetch_all_by_node_id {
  my ($self, $incoming_node_id) = @_;
  $self->bind_param_generic_fetch($incoming_node_id, SQL_INTEGER);
  return $self->generic_fetch('node_id = ?');
}

=head2 retrieve_all_direct_attributes

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Example    : $genomic_align_adaptor->retrieve_all_direct_attributes($genomic_align)
  Description: Retrieve the all the direct attibutes corresponding to the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlign object. It is used after lazy fetching
               of the object for populating it when required.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : 
  Caller     : none
  Status     : Stable

=cut

sub retrieve_all_direct_attributes {
  my ($self, $genomic_align) = @_;

  my $full_ga = $self->fetch_by_dbID($genomic_align->dbID);
  # NOTE: There is a slight risk that this may replace a node_id with undef
  return $full_ga->copy($genomic_align) if $full_ga;
}


sub count_by_mlss_id {
    my ($self, $mlss_id) = @_;

    $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    return $self->generic_count('method_link_species_set_id = ?');
}

#
# Virtual methods from BaseAdaptor
####################################

sub _tables {
    return (['genomic_align', 'ga'])
}

sub _columns {
    return qw(
        ga.genomic_align_id
        ga.genomic_align_block_id
        ga.method_link_species_set_id
        ga.dnafrag_id
        ga.dnafrag_start
        ga.dnafrag_end
        ga.dnafrag_strand
        ga.cigar_line
        ga.visible
        ga.node_id
    );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::GenomicAlign', [
            'dbID',
            'genomic_align_block_id',
            'method_link_species_set_id',
            'dnafrag_id',
            'dnafrag_start',
            'dnafrag_end',
            'dnafrag_strand',
            'cigar_line',
            'visible',
            'node_id',
        ], sub {
            return {
                'cigar_arrayref' => undef,
            }
        }
    );
}

1;
