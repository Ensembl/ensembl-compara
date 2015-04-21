=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  $genomic_align_adaptor->use_autoincrement(0);

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

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 new

  Arg [1]    : list of args to super class constructor
  Example    : $ga_a = new Bio::EnsEMBL::Compara::GenomicAlignAdaptor($dbobj);
  Description: Creates a new GenomicAlignAdaptor. This
               class should be instantiated through the get method on the 
               DBAdaptor rather than calling this method directly.
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::DBConnection
  Status     : Stable

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  $self->{_use_autoincrement} = 1;

  return $self;
}


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
    if(!defined($ga->dnafrag) or !defined($ga->dnafrag->dbID)) {
      throw( "dna_fragment in GenomicAlign is not in DB" );
    }
    if(!defined($ga->genomic_align_block) or !defined($ga->genomic_align_block->dbID)) {
      throw( "genomic_align_block in GenomicAlign is not in DB" );
    }
    if(!defined($ga->method_link_species_set) or !defined($ga->method_link_species_set->dbID)) {
      throw( "method_link_species_set in GenomicAlign is not in DB" );
    }

    my $lock_tables = 0;
    if (!$ga->dbID and !$self->use_autoincrement()) {
      ## Lock tables
      $lock_tables = 1;
      $self->dbc->do(qq{ LOCK TABLES genomic_align WRITE });

      my $sql =
              "SELECT MAX(genomic_align_id) FROM genomic_align WHERE".
              " genomic_align_block_id > ".$ga->method_link_species_set->dbID.
              "0000000000 AND genomic_align_block_id < ".
              ($ga->method_link_species_set->dbID + 1)."0000000000";
      my $sth = $self->prepare($sql);
      $sth->execute();
      my $genomic_align_id = ($sth->fetchrow_array() or
          ($ga->method_link_species_set->dbID * 10000000000));
      $ga->dbID($genomic_align_id + 1);
    }

    $genomic_align_sth->execute(
            ($ga->dbID or undef),
            $ga->genomic_align_block->dbID,
            $ga->method_link_species_set->dbID,
            $ga->dnafrag->dbID,
            $ga->dnafrag_start,
            $ga->dnafrag_end,
            $ga->dnafrag_strand,
            ($ga->cigar_line or "NULL"),    # FIXME: please check that this "NULL" string in a mediumtext field is what you really want
            $ga->visible,
	    ($ga->node_id or undef)
        );

    if ($lock_tables) {
      ## Unlock tables
      $self->dbc->do("UNLOCK TABLES");
    }
    if (!$ga->dbID) {
      $ga->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'genomic_align', 'genomic_align_id') );
    }

    info("Stored Bio::EnsEMBL::Compara::GenomicAlign ".
          ($ga->dbID or "NULL").
          ", gab=".$ga->genomic_align_block->dbID.
          ", mlss=".$ga->method_link_species_set->dbID.
          ", dnaf=".$ga->dnafrag->dbID.
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


=head2 fetch_by_dbID

  Arg  1     : integer $dbID
  Example    : my $genomic_align = $genomic_align_adaptor->fetch_by_dbID(23134);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlign object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : Returns undef if no matching entry is found in the database.
  Caller     : object::methodname
  Status     : Stable

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $genomic_align;

  my $sql = qq{
          SELECT
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
          FROM
              genomic_align
          WHERE
              genomic_align_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  my @values = $sth->fetchrow_array();
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
          -dbID => $values[0],
          -adaptor => $self,
          -genomic_align_block_id => $values[1],
          -method_link_species_set_id => $values[2],
          -dnafrag_id => $values[3],
          -dnafrag_start => $values[4],
          -dnafrag_end => $values[5],
          -dnafrag_strand => $values[6],
          -cigar_line => $values[7],
          -visible => $values[8],
	  -node_id => $values[9],
      );

  return $genomic_align;
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

  throw("$genomic_align_block is not a Bio::EnsEMBL::Compara::GenomicAlignBlock object")
      if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
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
  my ($self, $incoming_genomic_align_block_id) = @_;
  my $genomic_aligns = [];

  my $sql = qq{
          SELECT
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
          FROM
              genomic_align
          WHERE
              genomic_align_block_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($incoming_genomic_align_block_id);
  my ($genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line,
      $visible, $node_id);
  $sth->bind_columns(\$genomic_align_id, \$genomic_align_block_id,
      \$method_link_species_set_id, \$dnafrag_id, \$dnafrag_start, \$dnafrag_end,
      \$dnafrag_strand, \$cigar_line, \$visible, \$node_id);
  my $genomic_align_groups = {};
  while ($sth->fetchrow_arrayref()) {
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => $genomic_align_id,
            -adaptor => $self,
            -genomic_align_block_id => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
            -dnafrag_id => $dnafrag_id,
            -dnafrag_start => $dnafrag_start,
            -dnafrag_end => $dnafrag_end,
            -dnafrag_strand => $dnafrag_strand,
            -cigar_line => $cigar_line,
            -visible => $visible,
	    -node_id => $node_id
        );
    push(@$genomic_aligns, $this_genomic_align);
  }

  return $genomic_aligns;
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
  my $genomic_aligns = [];

  my $sql = qq{
          SELECT
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
          FROM
              genomic_align
          WHERE
              node_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($incoming_node_id);
  my ($genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line,
      $visible, $node_id);
  $sth->bind_columns(\$genomic_align_id, \$genomic_align_block_id,
      \$method_link_species_set_id, \$dnafrag_id, \$dnafrag_start, \$dnafrag_end,
      \$dnafrag_strand, \$cigar_line, \$visible, \$node_id);
  while ($sth->fetchrow_arrayref()) {
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => $genomic_align_id,
            -adaptor => $self,
            -genomic_align_block_id => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
            -dnafrag_id => $dnafrag_id,
            -dnafrag_start => $dnafrag_start,
            -dnafrag_end => $dnafrag_end,
            -dnafrag_strand => $dnafrag_strand,
            -cigar_line => $cigar_line,
            -visible => $visible,
	    -node_id => $node_id
        );
    push(@$genomic_aligns, $this_genomic_align);
  }

  return $genomic_aligns;
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

  my $sql = qq{
                SELECT
                    genomic_align_block_id,
                    method_link_species_set_id,
                    dnafrag_id,
                    dnafrag_start,
                    dnafrag_end,
                    dnafrag_strand,
                    cigar_line,
                    visible,
                    node_id
                FROM
                    genomic_align
                WHERE
                    genomic_align_id = ?
        };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align->dbID);
  my ($genomic_align_block_id, $method_link_species_set_id, $dnafrag_id, $dnafrag_start, $dnafrag_end,
          $dnfrag_strand, $cigar_line, $visible, $node_id) = $sth->fetchrow_array();
  
  ## Populate the object
  $genomic_align->adaptor($self);
  $genomic_align->genomic_align_block_id($genomic_align_block_id) if (defined($genomic_align_block_id));
  $genomic_align->method_link_species_set_id($method_link_species_set_id) if (defined($method_link_species_set_id));
  $genomic_align->dnafrag_id($dnafrag_id) if (defined($dnafrag_id));
  $genomic_align->dnafrag_start($dnafrag_start) if (defined($dnafrag_start));
  $genomic_align->dnafrag_end($dnafrag_end) if (defined($dnafrag_end));
  $genomic_align->dnafrag_strand($dnfrag_strand) if (defined($dnfrag_strand));
  $genomic_align->cigar_line($cigar_line) if (defined($cigar_line));
  $genomic_align->visible($visible) if (defined($visible));
  $genomic_align->node_id($node_id) if (defined($node_id));

  return $genomic_align;
}


=head2 use_autoincrement

  [Arg  1]   : (optional)int value
  Example    : $genomic_align_adaptor->use_autoincrement(0);
  Description: Getter/setter for the _use_autoincrement flag. This flag
               is used when storing new objects with no dbID in the
               database. If the flag is ON (default), the adaptor will
               let the DB set the dbID using the AUTO_INCREMENT ability.
               If you unset the flag, then the adaptor will look for the
               first available dbID after 10^10 times the
               method_link_species_set_id.
  Returntype : integer
  Exceptions : 
  Caller     : none
  Status     : Stable

=cut

sub use_autoincrement {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_use_autoincrement} = $value;
  }

  return $self->{_use_autoincrement};
}


sub count_by_mlss_id {
    my ($self, $mlss_id) = @_;

    my $sql = "SELECT count(*) FROM genomic_align WHERE method_link_species_set_id=?";
    my $sth = $self->prepare($sql);
    $sth->execute($mlss_id);
    my ($count) = $sth->fetchrow_array();
    $sth->finish();

    return $count;
}

1;
