# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlignBlockAdaptor
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::DBSQL::Compara::GenomicAlignBlockAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::Utils::Exception qw(throw info);


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

my $DEFAULT_MAX_ALIGNMENT = 20000;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  my $vals =
    $self->db->get_MetaContainer->list_value_by_key('max_alignment_length');

  if(@$vals) {
    $self->{'max_alignment_length'} = $vals->[0];
  } else {
    $self->warn("Meta table key 'max_alignment_length' not defined\n" .
        "using default value [$DEFAULT_MAX_ALIGNMENT]");
    $self->{'max_alignment_length'} = $DEFAULT_MAX_ALIGNMENT;
  }

  return $self;
}


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock
               The things you want to store
  Example    : $gen_ali_blk_adaptor->store($genomic_align_block);
  Description: It stores the given GenomicAlginBlock in the database as well
               as the GenomicAlign objects it contains
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : - method_link_species_set_id not stored in the DB
               - no Bio::EnsEMBL::Compara::GenomicAlign object is linked
               - not stored linked dnafrag objects throw.
               - unknown method link
               - cannot lock tables
               - cannot store GenomicAlignBlock object
               - cannot store corresponding GenomicAlign objects
  Caller     : general

=cut

sub store {
  my ($self, $genomic_align_block) = @_;

  my $genomic_align_block_sql =
        qq{INSERT INTO genomic_align_block (
                genomic_align_block_id,
                method_link_species_set_id,
                score,
                perc_id,
                length
        ) VALUES (?,?,?,?,?)};
  
  my @values;
  
  ## CHECKING
  if (!defined($genomic_align_block) or
      !$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    throw("[$genomic_align_block] is not a Bio::EnsEMBL::Compara::GenomicAlignBlock");
  }
  if (!defined($genomic_align_block->method_link_species_set)) {
    throw("There is no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object attached to this".
        " Bio::EnsEMBL::Compara::GenomicAlignBlock object [$self]");
  }
  if (!defined($genomic_align_block->method_link_species_set->dbID)) {
    throw("Attached Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object has no dbID");
  }
  throw if (!$genomic_align_block->genomic_align_array);
  foreach my $genomic_align (@{$genomic_align_block->genomic_align_array}) {
    # check if every GenomicAlgin has a dbID
    if (!defined($genomic_align->dnafrag->dbID)) {
      throw("dna_fragment in GenomicAlignBlock is not in DB");
    }
  }
  
  ## Stores data, all of them with the same id
  my $sth = $self->prepare($genomic_align_block_sql);
  #print $align_block_id, "\n";
  $sth->execute(
                ($genomic_align_block->dbID or "NULL"),
                $genomic_align_block->method_link_species_set->dbID,
                $genomic_align_block->score,
                $genomic_align_block->perc_id,
                $genomic_align_block->length
        );
  if (!$genomic_align_block->dbID) {
    $genomic_align_block->dbID($sth->{'mysql_insertid'});
  }
  info("Stored Bio::EnsEMBL::Compara::GenomicAlignBlock ".
        ($genomic_align_block->dbID or "NULL").
        ", mlss=".$genomic_align_block->method_link_species_set->dbID.
        ", scr=".($genomic_align_block->score or "NA").
        ", id=".($genomic_align_block->perc_id or "NA")."\%".
        ", l=".($genomic_align_block->length or "NA").
        "");

  ## Stores genomic_align entries
  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  $genomic_align_adaptor->store($genomic_align_block->genomic_align_array);

  return $genomic_align_block;
}


=head2 delete_by_dbID

  Arg  1     : integer $genomic_align_block_id
  Example    : $gen_ali_blk_adaptor->delete_by_dbID(352158763);
  Description: It removes the given GenomicAlginBlock in the database as well
               as the GenomicAlign objects it contains
  Returntype : none
  Exceptions : 
  Caller     : general

=cut

sub delete_by_dbID {
  my ($self, $genomic_align_block_id) = @_;

  my $genomic_align_block_sql =
        qq{DELETE FROM genomic_align_block WHERE genomic_align_block_id = ?};
  
  ## Deletes genomic_align_block entry 
  my $sth = $self->prepare($genomic_align_block_sql);
  $sth->execute($genomic_align_block_id);
  
  ## Deletes corresponding genomic_align entries
  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  $genomic_align_adaptor->delete_by_genomic_align_block_id($genomic_align_block_id);
}


=head2 fetch_by_dbID

  Arg  1     : integer $genomic_align_block_id
  Example    : my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID(1)
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : Returns undef if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $genomic_align_block; # returned object

  my $sql = qq{
          SELECT
              method_link_species_set_id,
              score,
              perc_id,
              length
          FROM
              genomic_align_block
          WHERE
              genomic_align_block_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  my $array_ref = $sth->fetchrow_arrayref();
  if ($array_ref) {
    my ($method_link_species_set_id, $score, $perc_id, $length) = @$array_ref;
  
    ## Create the object
    # Lazy loading of genomic_align objects. They are fetched only when needed.
    $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                          -adaptor => $self,
                          -dbID => $dbID,
                          -method_link_species_set_id => $method_link_species_set_id,
                          -score => $score,
                          -perc_id => $perc_id,
                          -length => $length
                  );
  }

  return $genomic_align_block;
}


=head2 fetch_all_by_Slice

  Arg  1     : integer $method_link_species_set_id
                    - or -
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Slice $original_slice
  Arg  3     : [optional] integer $limit
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_Slice(
                      2, $original_slice);
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_Slice(
                      $method_link_species_set, $original_slice);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when required.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : $object->mthod_name

=cut

sub fetch_all_by_Slice {
  my ($self, $method_link_species_set, $original_slice, $limit) = @_;
  my $all_genomic_align_blocks = []; # Returned value

  ## method_link_species_set_id will be checked in the fetch_all_by_DnaFrag method

  ## Check original_slice
  unless($original_slice && ref $original_slice && 
         $original_slice->isa('Bio::EnsEMBL::Slice')) {
    throw("[$original_slice] should be a Bio::EnsEMBL::Slice object\n");
  }

  $limit = 0 if (!defined($limit));

  ## Get the Bio::EnsEMBL::Compara::GenomeDB object corresponding to the
  ## $original_slice
  my $slice_adaptor = $original_slice->adaptor();
  if(!$slice_adaptor) {
    warning("Slice has no attached adaptor. Cannot get Compara alignments.");
    return $all_genomic_align_blocks;
  }
  my $primary_species_binomial_name = 
      $slice_adaptor->db->get_MetaContainer->get_Species->binomial;
  my $primary_species_assembly = $original_slice->coord_system->version;
  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor;
  my $genome_db = $genome_db_adaptor->fetch_by_name_assembly(
          $primary_species_binomial_name,
          $primary_species_assembly
      );

  my $projection_segments = $original_slice->project('toplevel');
  return [] if(!@$projection_segments);

  foreach my $this_projection_segment (@$projection_segments) {
    my $this_slice = $this_projection_segment->to_Slice;
    my $dnafrag_type = $this_slice->coord_system->name;
    my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor;
    my $this_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
            $genome_db, $this_slice->seq_region_name
        );
    my $these_genomic_align_blocks = $self->fetch_all_by_DnaFrag(
            $method_link_species_set,
            $this_dnafrag,
            $this_slice->start,
            $this_slice->end,
            $limit
        );

    my $top_slice = $slice_adaptor->fetch_by_region($dnafrag_type, 
                                                    $this_slice->seq_region_name);

    # need to convert features to requested coord system
    # if it was different then the one we used for fetching

    if($top_slice->name ne $original_slice->name) {
      foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {
        my $feature = new Bio::EnsEMBL::Feature(
                -slice => $top_slice,
                -start => $this_genomic_align_block->starting_genomic_align->dnafrag_start,
                -end => $this_genomic_align_block->starting_genomic_align->dnafrag_end
            );
        $feature = $feature->transfer($original_slice);
        $this_genomic_align_block->requesting_slice($original_slice);
        $this_genomic_align_block->requesting_slice_start($feature->start);
        $this_genomic_align_block->requesting_slice_end($feature->end);
        push (@$all_genomic_align_blocks, $this_genomic_align_block);
      }
    } else {
      foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {
        $this_genomic_align_block->requesting_slice($top_slice);
        $this_genomic_align_block->requesting_slice_start(
            $this_genomic_align_block->starting_genomic_align->dnafrag_start);
        $this_genomic_align_block->requesting_slice_end(
            $this_genomic_align_block->starting_genomic_align->dnafrag_end);
        push (@$all_genomic_align_blocks, $this_genomic_align_block);
      }
    }
  }

  return $all_genomic_align_blocks;
}


=head2 fetch_all_by_DnaFrag

  Arg  1     : integer $method_link_species_set_id
                    - or -
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : integer $dnafrag_id
                    - or -
               Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  3     : integer $start
  Arg  4     : integer $end
  Arg  5     : integer $limit
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_DnaFrag(
                      2, 19, 50000000, 50250000);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Objects 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

=cut

sub fetch_all_by_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit) = @_;
  my $genomic_align_blocks = []; # returned object

  my $dnafrag_id;
  if ($dnafrag =~ /^\d+$/) {
    $dnafrag_id = $dnafrag;
  } else {
    throw("$dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag object")
        if (!$dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"));
    $dnafrag_id = $dnafrag->dbID;
  }

  my $method_link_species_set_id;
  if ($method_link_species_set =~ /^\d+$/) {
    $method_link_species_set_id = $method_link_species_set;
  } else {
    throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $method_link_species_set_id = $method_link_species_set->dbID;
  }

  my $lower_bound = $start - $self->{'max_alignment_length'};
  my $sql = qq{
          SELECT
              genomic_align_id,
              genomic_align_block_id
          FROM
              genomic_align
          WHERE 
              method_link_species_set_id = $method_link_species_set_id
              AND dnafrag_id = $dnafrag_id
      };
  if (defined($start) and defined($end)) {
    $sql .= qq{
            AND dnafrag_start <= $end
            AND dnafrag_start >= $lower_bound
            AND dnafrag_end >= $start
        };
  }
  if ($limit) {
    $sql .= qq{ LIMIT $limit };
  }
  my $sth = $self->prepare($sql);
  $sth->execute();

  my $all_genomic_align_block_ids;
  while (my ($genomic_align_id, $genomic_align_block_id) = $sth->fetchrow_array) {
#     # Avoid to return several times the same genomic_align_block
#     next if (defined($all_genomic_align_block_ids->{$genomic_align_block_id}));
#     $all_genomic_align_block_ids->{$genomic_align_block_id} = 1;

    # Lazy loading of genomic_align_blocks. All attributes are loaded on demand.
    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                        -adaptor => $self,
                        -dbID => $genomic_align_block_id,
                        -method_link_species_set_id => $method_link_species_set_id,
                        -starting_genomic_align_id => $genomic_align_id
                );
    push(@{$genomic_align_blocks}, $this_genomic_align_block);
  }
  
  return $genomic_align_blocks;
}


=head2 retrieve_all_direct_attributes

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
  Example    : $genomic_align_block_adaptor->retrieve_all_direct_attributes($genomic_align_block)
  Description: Retrieve the all the direct attibutes corresponding to the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlignBlock object. It is used after lazy fetching
               of the object for populating it when required.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : 
  Caller     : none

=cut

sub retrieve_all_direct_attributes {
  my ($self, $genomic_align_block) = @_;

  my $sql = qq{
          SELECT
            method_link_species_set_id,
            score,
            perc_id,
            length
          FROM
            genomic_align_block
          WHERE
            genomic_align_block_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align_block->dbID);
  my ($method_link_species_set_id, $score, $perc_id, $length) = $sth->fetchrow_array();
  
  ## Populate the object
  $genomic_align_block->adaptor($self);
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id)
      if (defined($method_link_species_set_id));
  $genomic_align_block->score($score) if (defined($score));
  $genomic_align_block->perc_id($perc_id) if (defined($perc_id));
  $genomic_align_block->length($length) if (defined($length));

  return $genomic_align_block;
}


1;
