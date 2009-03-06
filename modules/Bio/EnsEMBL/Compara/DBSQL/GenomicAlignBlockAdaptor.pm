
# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlignBlockAdaptor
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::DBSQL::Compara::GenomicAlignBlockAdaptor

=head1 SYNOPSIS

=head2 Connecting to the database using the Registry

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";

  $reg->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous");

  my $genomic_align_block_adaptor = $reg->get_adaptor(
      "Multi", "compara", "GenomicAlignBlock");

=head2 Store/Delete data from the database

  $genomic_align_block_adaptor->store($genomic_align_block);

  $genomic_align_block_adaptor->delete_by_dbID($genomic_align_block->dbID);

=head2 Retrieve data from the database

  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID(12);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet(
      $method_link_species_set);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $method_link_species_set, $human_slice);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
      $method_link_species_set, $human_dnafrag);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag(
      $method_link_species_set, $human_dnafrag, $mouse_dnafrag);

=head2 Other methods

$genomic_align_block = $genomic_align_block_adaptor->
    retrieve_all_direct_attributes($genomic_align_block);

$genomic_align_block_adaptor->lazy_loading(1);

$genomic_align_block_adaptor->use_autoincrement

=head1 DESCRIPTION

This module is intended to access data in the genomic_align_block table.

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
 - Bio::EnsEMBL::BaseAdaptor
 - Bio::EnsEMBL::Compara::GenomicAlignBlock
 - Bio::EnsEMBL::Compara::GenomicAlign
 - Bio::EnsEMBL::Compara::GenomicAlignGroup,
 - Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
 - Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor
 - Bio::EnsEMBL::Slice
 - Bio::EnsEMBL::SliceAdaptor
 - Bio::EnsEMBL::Compara::DnaFrag
 - Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

This modules is part of the EnsEMBL project (http://www.ensembl.org). You may distribute
it under the same terms as EnsEMBL itself.

=head1 CONTACT

Questions can be posted to the ensembl-dev mailing list: ensembl-dev@ebi.ac.uk

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
use Bio::EnsEMBL::Utils::Exception;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 new

  Arg [1]    : list of args to super class constructor
  Example    : $ga_a = new Bio::EnsEMBL::Compara::GenomicAlignBlockAdaptor($dbobj);
  Description: Creates a new GenomicAlignBlockAdaptor.  The superclass 
               constructor is extended to initialise an internal cache.  This
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

  $self->{_lazy_loading} = 0;
  $self->{_use_autoincrement} = 1;

  return $self;
}

=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock
               The things you want to store
  Example    : $gen_ali_blk_adaptor->store($genomic_align_block);
  Description: It stores the given GenomicAlginBlock in the database as well
               as the GenomicAlign objects it contains
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : - no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet is linked
               - no Bio::EnsEMBL::Compara::GenomicAlign object is linked
               - no Bio::EnsEMBL::Compara::DnaFrag object is linked 
               - unknown method link
               - cannot lock tables
               - cannot store GenomicAlignBlock object
               - cannot store corresponding GenomicAlign objects
  Caller     : general
  Status     : Stable

=cut

sub store {
  my ($self, $genomic_align_block) = @_;

  my $genomic_align_block_sql =
        qq{INSERT INTO genomic_align_block (
                genomic_align_block_id,
                method_link_species_set_id,
                score,
                perc_id,
                length,
                group_id
        ) VALUES (?,?,?,?,?,?)};
  
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
  if (!$genomic_align_block->genomic_align_array or !@{$genomic_align_block->genomic_align_array}) {
    throw("This block does not contain any GenomicAlign. Nothing to store!");
  }
  foreach my $genomic_align (@{$genomic_align_block->genomic_align_array}) {
    # check if every GenomicAlgin has a dbID
    if (!defined($genomic_align->dnafrag->dbID)) {
      throw("dna_fragment in GenomicAlignBlock is not in DB");
    }
  }
  
  my $lock_tables = 0;
  if (!$genomic_align_block->dbID and !$self->use_autoincrement()) {
    ## Lock tables
    $lock_tables = 1;
    $self->dbc->do(qq{ LOCK TABLES genomic_align_block WRITE });

    ## Get max genomic_align_block_id for the corresponding range of ids
    my $sql = 
            "SELECT MAX(genomic_align_block_id) FROM genomic_align_block WHERE".
            " genomic_align_block_id > ".$genomic_align_block->method_link_species_set->dbID.
            "0000000000 AND genomic_align_block_id < ".
            ($genomic_align_block->method_link_species_set->dbID + 1)."0000000000";
    my $sth = $self->prepare($sql);
    $sth->execute();
    my $genomic_align_block_id = ($sth->fetchrow_array() or
        ($genomic_align_block->method_link_species_set->dbID * 10000000000));

    ## Set the genomic_align_block_id
    $genomic_align_block->dbID($genomic_align_block_id+1);
  }

  ## Stores data, all of them with the same id
  my $sth = $self->prepare($genomic_align_block_sql);
  #print $align_block_id, "\n";
  $sth->execute(
                ($genomic_align_block->dbID or "NULL"),
                $genomic_align_block->method_link_species_set->dbID,
                $genomic_align_block->score,
                $genomic_align_block->perc_id,
                $genomic_align_block->length,
                $genomic_align_block->group_id
        );
  if ($lock_tables) {
    ## Unlock tables
    $self->dbc->do("UNLOCK TABLES");
  }
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
  Status     : Stable

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
  Status     : Stable

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $genomic_align_block; # returned object

  my $sql = qq{
          SELECT
              method_link_species_set_id,
              score,
              perc_id,
              length,
              group_id
          FROM
              genomic_align_block
          WHERE
              genomic_align_block_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  my $array_ref = $sth->fetchrow_arrayref();
  if ($array_ref) {
    my ($method_link_species_set_id, $score, $perc_id, $length, $group_id) = @$array_ref;
  
    ## Create the object
    # Lazy loading of genomic_align objects. They are fetched only when needed.
    $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                          -adaptor => $self,
                          -dbID => $dbID,
                          -method_link_species_set_id => $method_link_species_set_id,
                          -score => $score,
			  -perc_id => $perc_id,
			  -length => $length,
                          -group_id => $group_id
                  );
    if (!$self->lazy_loading) {
      $genomic_align_block = $self->retrieve_all_direct_attributes($genomic_align_block);
    }
  }

  return $genomic_align_block;
}


=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : integer $limit_number [optional]
  Arg  3     : integer $limit_index_start [optional]
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->
                      fetch_all_by_MethodLinkSpeciesSet($mlss);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Objects 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
               Corresponding Bio::EnsEMBL::Compara::GenomicAlign are only retrieved
               when required.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
  my ($self, $method_link_species_set, $limit_number, $limit_index_start) = @_;

  my $genomic_align_blocks = []; # returned object

  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
      unless ($method_link_species_set and ref $method_link_species_set and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  my $method_link_species_set_id = $method_link_species_set->dbID;
  throw("[$method_link_species_set_id] has no dbID") if (!$method_link_species_set_id);

  my $sql = qq{
          SELECT
              gab.genomic_align_block_id,
              gab.score,
              gab.perc_id,
              gab.length,
              gab.group_id
          FROM
              genomic_align_block gab
          WHERE 
              gab.method_link_species_set_id = $method_link_species_set_id
      };
  if ($limit_number && $limit_index_start) {
    $sql .= qq{ LIMIT $limit_index_start , $limit_number };
  } elsif ($limit_number) {
    $sql .= qq{ LIMIT $limit_number };
  }

  my $sth = $self->prepare($sql);
  $sth->execute();
  my ($genomic_align_block_id, $score, $perc_id, $length, $group_id);
  $sth->bind_columns(\$genomic_align_block_id, \$score, \$perc_id, \$length, \$group_id);
  
  while ($sth->fetch) {
    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
            -adaptor => $self,
            -dbID => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
            -score => $score,
            -perc_id => $perc_id,
            -length => $length,
	    -group_id => $group_id
        );
    push(@$genomic_align_blocks, $this_genomic_align_block);
  }
  
  return $genomic_align_blocks;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Slice $original_slice
  Arg  3     : integer $limit_number [optional]
  Arg  4     : integer $limit_index_start [optional]
  Arg  5     : boolean $restrict_resulting_blocks [optional]
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
                      $method_link_species_set, $original_slice);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects. The alignments may be
               reverse-complemented in order to match the strand of the original slice.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when required.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : $object->method_name
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
  my ($self, $method_link_species_set, $reference_slice, $limit_number, $limit_index_start, $restrict) = @_;
  my $all_genomic_align_blocks = []; # Returned value

  ## method_link_species_set will be checked in the fetch_all_by_MethodLinkSpeciesSet_DnaFrag method

  ## Check original_slice
  unless($reference_slice && ref $reference_slice && 
         $reference_slice->isa('Bio::EnsEMBL::Slice')) {
    throw("[$reference_slice] should be a Bio::EnsEMBL::Slice object\n");
  }

  $limit_number = 0 if (!defined($limit_number));
  $limit_index_start = 0 if (!defined($limit_index_start));

  if ($reference_slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    return $reference_slice->get_all_GenomicAlignBlocks(
        $method_link_species_set->method_link_type, $method_link_species_set->species_set);
  }

  ## Get the Bio::EnsEMBL::Compara::GenomeDB object corresponding to the
  ## $reference_slice
  my $slice_adaptor = $reference_slice->adaptor();
  if(!$slice_adaptor) {
    warning("Slice has no attached adaptor. Cannot get Compara alignments.");
    return $all_genomic_align_blocks;
  }

  my $gdb_a = $self->db->get_GenomeDBAdaptor();
	my $meta_container = $reference_slice->adaptor->db->get_MetaContainer();
	my $primary_species_name = $gdb_a->get_species_name_from_core_MetaContainer($meta_container);
  my ($highest_cs) = @{$slice_adaptor->db->get_CoordSystemAdaptor->fetch_all()};
  my $primary_species_assembly = $highest_cs->version();
  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor;
  my $genome_db = $genome_db_adaptor->fetch_by_name_assembly(
          $primary_species_name,
          $primary_species_assembly
      );

#   my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor;
#   my $this_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
#           $genome_db, $reference_slice->seq_region_name
#       );
#   if ($this_dnafrag) {
#     my $these_genomic_align_blocks = $self->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
#             $method_link_species_set,
#             $this_dnafrag,
#             $reference_slice->start,
#             $reference_slice->end,
#             $limit_number,
#             $limit_index_start,
#             $restrict
#         );
#     foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {
#       $this_genomic_align_block->reference_slice($reference_slice);
#       $this_genomic_align_block->reference_slice_start(
#           $this_genomic_align_block->reference_genomic_align->dnafrag_start - $reference_slice->start + 1);
#       $this_genomic_align_block->reference_slice_end(
#           $this_genomic_align_block->reference_genomic_align->dnafrag_end - $reference_slice->start + 1);
#       $this_genomic_align_block->reference_slice_strand($reference_slice->strand);
#       $this_genomic_align_block->reverse_complement()
#           if ($reference_slice->strand != $this_genomic_align_block->reference_genomic_align->dnafrag_strand);
#       push (@$all_genomic_align_blocks, $this_genomic_align_block);
#     }
#     return $all_genomic_align_blocks;
#   }
  my $projection_segments = $reference_slice->project('toplevel');
  return [] if(!@$projection_segments);

  foreach my $this_projection_segment (@$projection_segments) {
    my $this_slice = $this_projection_segment->to_Slice;
    my $dnafrag_type = $this_slice->coord_system->name;
    my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor;
    my $this_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
            $genome_db, $this_slice->seq_region_name
        );
    next if (!$this_dnafrag);

    my $these_genomic_align_blocks = $self->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set,
            $this_dnafrag,
            $this_slice->start,
            $this_slice->end,
            $limit_number,
            $limit_index_start,
            $restrict
        );

    #If the GenomicAlignBlock has been restricted, set up the correct values 
    #for restricted_aln_start and restricted_aln_end
    foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {

	#print "GAB restricted start " . $this_genomic_align_block->{'restricted_aln_start'} . " end " . $this_genomic_align_block->{'restricted_aln_end'} . " length " . $this_genomic_align_block->{'original_length'} . "\n";
    
    
	if (defined $this_genomic_align_block->{'restricted_aln_start'}) {
	    my $tmp_start = $this_genomic_align_block->{'restricted_aln_start'};
	    #if ($reference_slice->strand != $this_genomic_align_block->reference_genomic_align->dnafrag_strand) {

	    #the start and end are always calculated for the forward strand
	    if ($reference_slice->strand == 1) {
		$this_genomic_align_block->{'restricted_aln_start'}++;
		$this_genomic_align_block->{'restricted_aln_end'} = $this_genomic_align_block->{'original_length'} - $this_genomic_align_block->{'restricted_aln_end'};
	    } else {
		$this_genomic_align_block->{'restricted_aln_start'} = $this_genomic_align_block->{'restricted_aln_end'} + 1;
		$this_genomic_align_block->{'restricted_aln_end'} = $this_genomic_align_block->{'original_length'} - $tmp_start;
	    }
	    #print "GAB after restricted start " . $this_genomic_align_block->{'restricted_aln_start'} . " end " . $this_genomic_align_block->{'restricted_aln_end'} . " length " . $this_genomic_align_block->{'original_length'} . "\n";
	}
    }

    my $top_slice = $slice_adaptor->fetch_by_region($dnafrag_type, 
                                                    $this_slice->seq_region_name);

    # need to convert features to requested coord system
    # if it was different then the one we used for fetching

    if($top_slice->name ne $reference_slice->name) {
      foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {
        my $feature = new Bio::EnsEMBL::Feature(
                -slice => $top_slice,
                -start => $this_genomic_align_block->reference_genomic_align->dnafrag_start,
                -end => $this_genomic_align_block->reference_genomic_align->dnafrag_end,
                -strand => $this_genomic_align_block->reference_genomic_align->dnafrag_strand
            );
        $feature = $feature->transfer($reference_slice);
	next if (!$feature);
        $this_genomic_align_block->reference_slice($reference_slice);
        $this_genomic_align_block->reference_slice_start($feature->start);
        $this_genomic_align_block->reference_slice_end($feature->end);
        $this_genomic_align_block->reference_slice_strand($reference_slice->strand);
        $this_genomic_align_block->reverse_complement()
            if ($reference_slice->strand != $this_genomic_align_block->reference_genomic_align->dnafrag_strand);
        push (@$all_genomic_align_blocks, $this_genomic_align_block);
      }
    } else {
      foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {
        $this_genomic_align_block->reference_slice($top_slice);
        $this_genomic_align_block->reference_slice_start(
            $this_genomic_align_block->reference_genomic_align->dnafrag_start);
        $this_genomic_align_block->reference_slice_end(
            $this_genomic_align_block->reference_genomic_align->dnafrag_end);
        $this_genomic_align_block->reference_slice_strand($reference_slice->strand);
        $this_genomic_align_block->reverse_complement()
            if ($reference_slice->strand != $this_genomic_align_block->reference_genomic_align->dnafrag_strand);
        push (@$all_genomic_align_blocks, $this_genomic_align_block);
      }
    }
  }

  return $all_genomic_align_blocks;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  3     : integer $start [optional, default = 1]
  Arg  4     : integer $end [optional, default = dnafrag_length]
  Arg  5     : integer $limit_number [optional, default = no limit]
  Arg  6     : integer $limit_index_start [optional, default = 0]
  Arg  7     : boolean $restrict_resulting_blocks [optional, default = no restriction]
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
                      $mlss, $dnafrag, 50000000, 50250000);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit_number, $limit_index_start, $restrict) = @_;

  my $genomic_align_blocks = []; # returned object

  throw("[$dnafrag] is not a Bio::EnsEMBL::Compara::DnaFrag object")
      unless ($dnafrag and ref $dnafrag and $dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"));
  my $query_dnafrag_id = $dnafrag->dbID;
  throw("[$dnafrag] has no dbID") if (!$query_dnafrag_id);

  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
      unless ($method_link_species_set and ref $method_link_species_set and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  my $query_method_link_species_set_id = $method_link_species_set->dbID;
  throw("[$method_link_species_set] has no dbID") if (!$query_method_link_species_set_id);

  if ($limit_number) {
    return $self->_fetch_all_by_MethodLinkSpeciesSet_DnaFrag_with_limit($method_link_species_set,
        $dnafrag, $start, $end, $limit_number, $limit_index_start, $restrict);
  }

  #Create this here to pass into _create_GenomicAlign module
  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;

  my $sql = qq{
          SELECT
              ga1.genomic_align_id,
              ga1.genomic_align_block_id,
              ga1.method_link_species_set_id,
              ga1.dnafrag_id,
              ga1.dnafrag_start,
              ga1.dnafrag_end,
              ga1.dnafrag_strand,
              ga1.cigar_line,
              ga1.level_id,
              ga2.genomic_align_id,
              gab.score,
              gab.perc_id,
              gab.length,
              gab.group_id
          FROM
              genomic_align ga1, genomic_align_block gab, genomic_align ga2
          WHERE 
              ga1.genomic_align_block_id = ga2.genomic_align_block_id
              AND gab.genomic_align_block_id = ga1.genomic_align_block_id
              AND ga2.method_link_species_set_id = $query_method_link_species_set_id
              AND ga2.dnafrag_id = $query_dnafrag_id
      };
  if (defined($start) and defined($end)) {
    my $max_alignment_length = $method_link_species_set->max_alignment_length;
    my $lower_bound = $start - $max_alignment_length;
    $sql .= qq{
            AND ga2.dnafrag_start <= $end
            AND ga2.dnafrag_start >= $lower_bound
            AND ga2.dnafrag_end >= $start
        };
  }

  my $sth = $self->prepare($sql);
  $sth->execute();
  
  my $all_genomic_align_blocks;
  my $genomic_align_groups = {};
  my ($genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $level_id,
      $query_genomic_align_id, $score, $perc_id, $length, $group_id);
  $sth->bind_columns(\$genomic_align_id, \$genomic_align_block_id, \$method_link_species_set_id,
      \$dnafrag_id, \$dnafrag_start, \$dnafrag_end, \$dnafrag_strand, \$cigar_line, \$level_id,
      \$query_genomic_align_id, \$score, \$perc_id, \$length, \$group_id);
  while ($sth->fetch) {

    ## Index GenomicAlign by ga2.genomic_align_id ($query_genomic_align). All the GenomicAlign
    ##   with the same ga2.genomic_align_id correspond to the same GenomicAlignBlock.
    if (!defined($all_genomic_align_blocks->{$query_genomic_align_id})) {
      # Lazy loading of genomic_align_blocks. All remaining attributes are loaded on demand.
      $all_genomic_align_blocks->{$query_genomic_align_id} = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
              -adaptor => $self,
              -dbID => $genomic_align_block_id,
              -method_link_species_set_id => $method_link_species_set_id,
              -score => $score,
              -perc_id => $perc_id,
              -length => $length,
              -group_id => $group_id,
              -reference_genomic_align_id => $query_genomic_align_id,
          );
      push(@$genomic_align_blocks, $all_genomic_align_blocks->{$query_genomic_align_id});
    }

# # #     ## Avoids to create 1 GenomicAlignGroup object per composite segment (see below)
# # #     next if ($genomic_align_groups->{$query_genomic_align_id}->{$genomic_align_id});
    my $this_genomic_align = $self->_create_GenomicAlign($genomic_align_id,
        $genomic_align_block_id, $method_link_species_set_id, $dnafrag_id,
        $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $level_id,
	$genomic_align_adaptor);
# # #     ## Set the flag to avoid creating 1 GenomicAlignGroup object per composite segment
# # #     if ($this_genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlignGroup")) {
# # #       foreach my $this_genomic_align (@{$this_genomic_align->genomic_align_array}) {
# # #         $genomic_align_groups->{$query_genomic_align_id}->{$this_genomic_align->dbID} = 1;
# # #       }
# # #     }
    $all_genomic_align_blocks->{$query_genomic_align_id}->add_GenomicAlign($this_genomic_align);
  }

  foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    my $ref_genomic_align = $this_genomic_align_block->reference_genomic_align;
    if ($ref_genomic_align->cigar_line =~ /X/) {
      # The reference GenomicAlign is part of a composite segment. We have to restrict it
      $this_genomic_align_block = $this_genomic_align_block->restrict_between_reference_positions(
          $ref_genomic_align->dnafrag_start, $ref_genomic_align->dnafrag_end, undef,
          "skip_empty_genomic_aligns");
    }
  }

  if (defined($start) and defined($end) and $restrict) {
    my $restricted_genomic_align_blocks = [];
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      $this_genomic_align_block = $this_genomic_align_block->restrict_between_reference_positions(
          $start, $end, undef, "skip_empty_genomic_aligns");
      if (@{$this_genomic_align_block->get_all_GenomicAligns()} > 1) {
        push(@$restricted_genomic_align_blocks, $this_genomic_align_block);
      }
    }
    $genomic_align_blocks = $restricted_genomic_align_blocks;
  }

  if (!$self->lazy_loading) {
    $self->_load_DnaFrags($genomic_align_blocks);
  }

  return $genomic_align_blocks;
}


=head2 _fetch_all_by_MethodLinkSpeciesSet_DnaFrag_with_limit

  This is an internal method. Please, use the fetch_all_by_MethodLinkSpeciesSet_DnaFrag() method instead.

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  3     : integer $start [optional]
  Arg  4     : integer $end [optional]
  Arg  5     : integer $limit_number
  Arg  6     : integer $limit_index_start [optional, default = 0]
  Arg  7     : boolean $restrict_resulting_blocks [optional, default = no restriction]
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->_fetch_all_by_MethodLinkSpeciesSet_DnaFrag_with_limit(
                      $mlss, $dnafrag, 50000000, 50250000);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Objects 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : fetch_all_by_MethodLinkSpeciesSet_DnaFrag
  Status     : Stable

=cut

sub _fetch_all_by_MethodLinkSpeciesSet_DnaFrag_with_limit {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit_number, $limit_index_start, $restrict) = @_;

  my $genomic_align_blocks = []; # returned object

  my $dnafrag_id = $dnafrag->dbID;
  my $method_link_species_set_id = $method_link_species_set->dbID;

  my $sql = qq{
          SELECT
              ga2.genomic_align_block_id,
              ga2.genomic_align_id
          FROM
              genomic_align ga2
          WHERE 
              ga2.method_link_species_set_id = $method_link_species_set_id
              AND ga2.dnafrag_id = $dnafrag_id
      };
  if (defined($start) and defined($end)) {
    my $max_alignment_length = $method_link_species_set->max_alignment_length;
    my $lower_bound = $start - $max_alignment_length;
    $sql .= qq{
            AND ga2.dnafrag_start <= $end
            AND ga2.dnafrag_start >= $lower_bound
            AND ga2.dnafrag_end >= $start
        };
  }
  $limit_index_start = 0 if (!$limit_index_start);
  $sql .= qq{ LIMIT $limit_index_start , $limit_number };

  my $sth = $self->prepare($sql);
  $sth->execute();
  
  while (my ($genomic_align_block_id, $query_genomic_align_id) = $sth->fetchrow_array) {
    # Lazy loading of genomic_align_blocks. All remaining attributes are loaded on demand.
    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
            -adaptor => $self,
            -dbID => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
            -reference_genomic_align_id => $query_genomic_align_id,
        );
    push(@$genomic_align_blocks, $this_genomic_align_block);
  }
  if (defined($start) and defined($end) and $restrict) {
    my $restricted_genomic_align_blocks = [];
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      $this_genomic_align_block = $this_genomic_align_block->restrict_between_reference_positions(
          $start, $end, undef, "skip_empty_genomic_aligns");
      if (@{$this_genomic_align_block->get_all_GenomicAligns()} > 1) {
        push(@$restricted_genomic_align_blocks, $this_genomic_align_block);
      }
    }
    $genomic_align_blocks = $restricted_genomic_align_blocks;
  }
  
  return $genomic_align_blocks;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag (query)
  Arg  3     : integer $start [optional]
  Arg  4     : integer $end [optional]
  Arg  5     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag (target)
  Arg  6     : integer $limit_number [optional]
  Arg  7     : integer $limit_index_start [optional]
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag(
                      $mlss, $qy_dnafrag, 50000000, 50250000,$tg_dnafrag);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag1, $start, $end, $dnafrag2, $limit_number, $limit_index_start) = @_;

  my $genomic_align_blocks = []; # returned object

  throw("[$dnafrag1] is not a Bio::EnsEMBL::Compara::DnaFrag object")
      unless ($dnafrag1 and ref $dnafrag1 and $dnafrag1->isa("Bio::EnsEMBL::Compara::DnaFrag"));
  my $dnafrag_id1 = $dnafrag1->dbID;
  throw("[$dnafrag1] has no dbID") if (!$dnafrag_id1);

  throw("[$dnafrag2] is not a Bio::EnsEMBL::Compara::DnaFrag object")
      unless ($dnafrag2 and ref $dnafrag2 and $dnafrag2->isa("Bio::EnsEMBL::Compara::DnaFrag"));
  my $dnafrag_id2 = $dnafrag2->dbID;
  throw("[$dnafrag2] has no dbID") if (!$dnafrag_id2);

  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
      unless ($method_link_species_set and ref $method_link_species_set and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  my $method_link_species_set_id = $method_link_species_set->dbID;
  throw("[$method_link_species_set_id] has no dbID") if (!$method_link_species_set_id);

  #Create this here to pass into _create_GenomicAlign module
  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;

  my $sql = qq{
          SELECT
              ga1.genomic_align_id,
              ga1.genomic_align_block_id,
              ga1.method_link_species_set_id,
              ga1.dnafrag_id,
              ga1.dnafrag_start,
              ga1.dnafrag_end,
              ga1.dnafrag_strand,
              ga1.cigar_line,
              ga1.level_id,
              ga2.genomic_align_id,
              ga2.genomic_align_block_id,
              ga2.method_link_species_set_id,
              ga2.dnafrag_id,
              ga2.dnafrag_start,
              ga2.dnafrag_end,
              ga2.dnafrag_strand,
              ga2.cigar_line,
              ga2.level_id
          FROM
              genomic_align ga1, genomic_align ga2
          WHERE 
              ga1.genomic_align_block_id = ga2.genomic_align_block_id
              AND ga1.genomic_align_id != ga2.genomic_align_id
              AND ga2.method_link_species_set_id = $method_link_species_set_id
              AND ga1.dnafrag_id = $dnafrag_id1 AND ga2.dnafrag_id = $dnafrag_id2
      };
  if (defined($start) and defined($end)) {
    my $max_alignment_length = $method_link_species_set->max_alignment_length;
    my $lower_bound = $start - $max_alignment_length;
    $sql .= qq{
            AND ga1.dnafrag_start <= $end
            AND ga1.dnafrag_start >= $lower_bound
            AND ga1.dnafrag_end >= $start
        };
  }
  if ($limit_number && $limit_index_start) {
    $sql .= qq{ LIMIT $limit_index_start , $limit_number };
  } elsif ($limit_number) {
    $sql .= qq{ LIMIT $limit_number };
  }

  my $sth = $self->prepare($sql);
  $sth->execute();
  
  my $all_genomic_align_blocks;
  while (my ($genomic_align_id1, $genomic_align_block_id1, $method_link_species_set_id1,
             $dnafrag_id1, $dnafrag_start1, $dnafrag_end1, $dnafrag_strand1, $cigar_line1, $level_id1,
             $genomic_align_id2, $genomic_align_block_id2, $method_link_species_set_id2,
             $dnafrag_id2, $dnafrag_start2, $dnafrag_end2, $dnafrag_strand2, $cigar_line2, $level_id2) = $sth->fetchrow_array) {
    ## Skip if this genomic_align_block has been defined already
    next if (defined($all_genomic_align_blocks->{$genomic_align_block_id1}));
    $all_genomic_align_blocks->{$genomic_align_block_id1} = 1;
    my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock
      (-adaptor => $self,
       -dbID => $genomic_align_block_id1,
       -method_link_species_set_id => $method_link_species_set_id1,
       -reference_genomic_align_id => $genomic_align_id1);

    # If set up, lazy loading of genomic_align
    unless ($self->lazy_loading) {
      ## Create a Bio::EnsEMBL::Compara::GenomicAlign corresponding to ga1.*
      my $this_genomic_align1 = $self->_create_GenomicAlign($genomic_align_id1,
          $genomic_align_block_id1, $method_link_species_set_id1, $dnafrag_id1,
          $dnafrag_start1, $dnafrag_end1, $dnafrag_strand1, $cigar_line1, $level_id1, $genomic_align_adaptor);
      ## ... attach it to the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock
      $gab->add_GenomicAlign($this_genomic_align1);

      ## Create a Bio::EnsEMBL::Compara::GenomicAlign correponding to ga2.*
      my $this_genomic_align2 = $self->_create_GenomicAlign($genomic_align_id2,
          $genomic_align_block_id2, $method_link_species_set_id2, $dnafrag_id2,
          $dnafrag_start2, $dnafrag_end2, $dnafrag_strand2, $cigar_line2, $level_id2, $genomic_align_adaptor);
      ## ... attach it to the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock
      $gab->add_GenomicAlign($this_genomic_align2);
    }
    push(@$genomic_align_blocks, $gab);
  }

  return $genomic_align_blocks;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag_GroupType

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag (query)
  Arg  3     : integer $start [optional]
  Arg  4     : integer $end [optional]
  Arg  5     : string $group_type
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_GroupType(
                      $mlss, $qy_dnafrag, 50000000, 50250000,"chain");
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. 
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag_GroupType {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $group_type) = @_;

  my $genomic_align_blocks = []; # returned object
  unless (defined $group_type) {
      throw("group_type is not defined");
  }

  throw("[$dnafrag] is not a Bio::EnsEMBL::Compara::DnaFrag object")
      unless ($dnafrag and ref $dnafrag and $dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"));
  my $dnafrag_id = $dnafrag->dbID;
  throw("[$dnafrag] has no dbID") if (!$dnafrag_id);

  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
      unless ($method_link_species_set and ref $method_link_species_set and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  my $method_link_species_set_id = $method_link_species_set->dbID;
  throw("[$method_link_species_set_id] has no dbID") if (!$method_link_species_set_id);

  my $sql = qq{
          SELECT
              ga1.genomic_align_id,
              ga1.genomic_align_block_id,
              ga1.method_link_species_set_id,
              ga1.dnafrag_id,
              ga1.dnafrag_start,
              ga1.dnafrag_end,
              ga1.dnafrag_strand,
              ga1.cigar_line,
              ga1.level_id,
              ga2.genomic_align_id,
              gag.group_id
          FROM
              genomic_align ga1, genomic_align ga2, genomic_align_group gag
          WHERE 
              ga1.genomic_align_block_id = ga2.genomic_align_block_id
              AND ga1.genomic_align_id=gag.genomic_align_id
              AND gag.type = \'$group_type\'
              AND ga2.method_link_species_set_id = $method_link_species_set_id
              AND ga2.dnafrag_id = $dnafrag_id
      };
  if (defined($start) and defined($end)) {
    my $max_alignment_length = $method_link_species_set->max_alignment_length;
    my $lower_bound = $start - $max_alignment_length;
    $sql .= qq{
            AND ga2.dnafrag_start <= $end
            AND ga2.dnafrag_start >= $lower_bound
            AND ga2.dnafrag_end >= $start
        };
  }
#  print STDERR $sql,"\n";
  my $sth = $self->prepare($sql);
  $sth->execute();
  
  my $all_genomic_align_blocks;
  while (my ($genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $level_id,
      $query_genomic_align_id, $group_id) = $sth->fetchrow_array) {

    ## Index GenomicAlign by ga2.genomic_align_id ($query_genomic_align). All the GenomicAlign
    ##   with the same ga2.genomic_align_id correspond to the same GenomicAlignBlock.
    if (!defined($all_genomic_align_blocks->{$query_genomic_align_id})) {
      # Lazy loading of genomic_align_blocks. All remaining attributes are loaded on demand.
      $all_genomic_align_blocks->{$query_genomic_align_id} = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
              -adaptor => $self,
              -dbID => $genomic_align_block_id,
              -method_link_species_set_id => $method_link_species_set_id,
              -reference_genomic_align_id => $query_genomic_align_id,
          );
      push(@$genomic_align_blocks, $all_genomic_align_blocks->{$query_genomic_align_id});
    }

    ## Create a Bio::EnsEMBL::Compara::GenomicAlign correponding to ga1.* and...
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => $genomic_align_id,
            -adaptor => $self->db->get_GenomicAlignAdaptor,
            -genomic_align_block_id => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
            -dnafrag_id => $dnafrag_id,
            -dnafrag_start => $dnafrag_start,
            -dnafrag_end => $dnafrag_end,
            -dnafrag_strand => $dnafrag_strand,
            -cigar_line => $cigar_line,
            -level_id => $level_id,
        );
    $this_genomic_align->genomic_align_group_id_by_type($group_type, $group_id);
    ## ... attach it to the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock
    $all_genomic_align_blocks->{$query_genomic_align_id}->add_GenomicAlign($this_genomic_align);
  }
  
  return $genomic_align_blocks;
}

=head2 fetch_all_by_MethodLinkSpeciesSet_GroupID

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : integer $group_id
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_GroupID($mlss, $group_id);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. 
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_GroupID {
  my ($self, $method_link_species_set, $group_id) = @_;

  my $genomic_align_blocks = []; # returned object

  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
      unless ($method_link_species_set and ref $method_link_species_set and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  my $method_link_species_set_id = $method_link_species_set->dbID;
  throw("[$method_link_species_set_id] has no dbID") if (!$method_link_species_set_id);

  unless (defined $group_id) {
      throw("group_id is not defined");
  }

  my $sql = qq{
          SELECT
              gab.genomic_align_block_id,
              gab.score,
              gab.perc_id,
              gab.length
          FROM
              genomic_align_block gab
          WHERE 
              gab.method_link_species_set_id = $method_link_species_set_id
              AND gab.group_id = $group_id
      };

  my $sth = $self->prepare($sql);
  $sth->execute();
  my ($genomic_align_block_id, $score, $perc_id, $length);
  $sth->bind_columns(\$genomic_align_block_id, \$score, \$perc_id, \$length);
  
  while ($sth->fetch) {
    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
            -adaptor => $self,
            -dbID => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
            -score => $score,
            -perc_id => $perc_id,
            -length => $length,
	    -group_id => $group_id
        );
    push(@$genomic_align_blocks, $this_genomic_align_block);
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
  Status     : Stable

=cut

sub retrieve_all_direct_attributes {
  my ($self, $genomic_align_block) = @_;

  my $sql = qq{
          SELECT
            method_link_species_set_id,
            score,
            perc_id,
            length,
            group_id
          FROM
            genomic_align_block
          WHERE
            genomic_align_block_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align_block->dbID);
  my ($method_link_species_set_id, $score, $perc_id, $length, $group_id) = $sth->fetchrow_array();
  
  ## Populate the object
  $genomic_align_block->adaptor($self);
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id)
      if (defined($method_link_species_set_id));
  $genomic_align_block->score($score) if (defined($score));
  $genomic_align_block->perc_id($perc_id) if (defined($perc_id));
  $genomic_align_block->length($length) if (defined($length));
  $genomic_align_block->group_id($group_id) if (defined($group_id));

  return $genomic_align_block;
}


=head2 store_group_id

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignBlock
  Arg  2     : group_id
  Example    : $genomic_align_block_adaptor->store_group_id($genomic_align_block, $group_id);
  Description: Method for storing the group_id for a genomic_align_block
  Returntype : 
  Exceptions : - cannot lock tables
               - cannot update GenomicAlignBlock object
  Caller     : none
  Status     : Stable

=cut

sub store_group_id {
    my ($self, $genomic_align_block, $group_id) = @_;
    
    my $sth = $self->prepare("UPDATE genomic_align_block SET group_id=? WHERE genomic_align_block_id=?;");
    $sth->execute($group_id, $genomic_align_block->dbID);
    $sth->finish();
}

=head2 lazy_loading

  [Arg  1]   : (optional)int $value
  Example    : $genomic_align_block_adaptor->lazy_loading(1);
  Description: Getter/setter for the _lazy_loading flag. This flag
               is used when fetching objects from the database. If
               the flag is OFF (default), the adaptor will fetch the
               all the attributes of the object. This is usually faster
               unless you run in some memory limitation problem. This
               happens typically when fetching loads of objects in one
               go.In this case you might want to consider using the
               lazy_loading option which return lighter objects and
               deleting objects as you use them:
               $gaba->lazy_loading(1);
               my $all_gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet($mlss);
               foreach my $this_gab (@$all_gabs) {
                 # do something
                 ...
                 # delete object
                 undef($this_gab);
               }
  Returntype : integer
  Exceptions :
  Caller     : none
  Status     : Stable

=cut

sub lazy_loading {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_lazy_loading} = $value;
  }

  return $self->{_lazy_loading};
}


=head2 use_autoincrement

  [Arg  1]   : (optional)int value
  Example    : $genomic_align_block_adaptor->use_autoincrement(0);
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

=head2 _create_GenomicAlign

  [Arg  1]   : int genomic_align_id
  [Arg  2]   : int genomic_align_block_id
  [Arg  3]   : int method_link_species_set_id
  [Arg  4]   : int dnafrag_id
  [Arg  5]   : int dnafrag_start
  [Arg  6]   : int dnafrag_end
  [Arg  7]   : int dnafrag_strand
  [Arg  8]   : string cigar_line
  [Arg  9]   : int level_id
  Example    : my $this_genomic_align1 = $self->_create_GenomicAlign(
                  $genomic_align_id, $genomic_align_block_id,
                  $method_link_species_set_id, $dnafrag_id,
                  $dnafrag_start, $dnafrag_end, $dnafrag_strand,
                  $cigar_line, $level_id);
  Description: Creates a new Bio::EnsEMBL::Compara::GenomicAlign object
               with the values provided as arguments. If this GenomicAlign
               is part of a composite GenomicAlign, the method will return
               a Bio::EnsEMBL::Compara::GenomicAlignGroup containing all the
               underlying Bio::EnsEMBL::Compara::GenomicAlign objects instead
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object or
               Bio::EnsEMBL::Compara::GenomicAlignGroup object
  Exceptions : 
  Caller     : internal
  Status     : stable

=cut

sub _create_GenomicAlign {
  my ($self, $genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line,
      $level_id, $adaptor) = @_;

  my $new_genomic_align = Bio::EnsEMBL::Compara::GenomicAlign->new_fast
    ({'dbID' => $genomic_align_id,
      'adaptor' => $adaptor,
     'genomic_align_block_id' => $genomic_align_block_id,
     'method_link_species_set_id' => $method_link_species_set_id,
     'dnafrag_id' => $dnafrag_id,
     'dnafrag_start' => $dnafrag_start,
     'dnafrag_end' => $dnafrag_end,
     'dnafrag_strand' => $dnafrag_strand,
     'cigar_line' => $cigar_line,
     'level_id' => $level_id}
    );

  return $new_genomic_align;
}

sub _create_GenomicAlignORIG {
  my ($self, $genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line,
      $level_id) = @_;

  my $new_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
  $new_genomic_align->dbID($genomic_align_id);
  $new_genomic_align->adaptor($self->db->get_GenomicAlignAdaptor);
  $new_genomic_align->genomic_align_block_id($genomic_align_block_id);
  $new_genomic_align->method_link_species_set_id($method_link_species_set_id);
  $new_genomic_align->dnafrag_id($dnafrag_id);
  $new_genomic_align->dnafrag_start($dnafrag_start);
  $new_genomic_align->dnafrag_end($dnafrag_end);
  $new_genomic_align->dnafrag_strand($dnafrag_strand);
  $new_genomic_align->cigar_line($cigar_line);
  $new_genomic_align->level_id($level_id);

  return $new_genomic_align;
}


=head2 _load_DnaFrags

  [Arg  1]   : listref Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Example    : $self->_load_DnaFrags($genomic_align_blocks);
  Description: Load the DnaFrags for all the GenomicAligns in these
               GenomicAlignBlock objects. This is much faster, especially
               for a large number of objects, as we fetch all the DnaFrags
               at once. Note: These DnaFrags are not cached by the
               DnaFragAdaptor at the moment
  Returntype : -none-
  Exceptions : 
  Caller     : fetch_all_* methods
  Status     : at risk

=cut

sub _load_DnaFrags {
  my ($self, $genomic_align_blocks) = @_;

  # 1. Collect all the dnafrag_ids
  my $dnafrag_ids = {};
  foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
      $dnafrag_ids->{$this_genomic_align->{dnafrag_id}} = 1;
    }
  }

  # 2. Fetch all the DnaFrags
  my %dnafrags = map {$_->{dbID}, $_}
      @{$self->db->get_DnaFragAdaptor->fetch_all_by_dbID_list([keys %$dnafrag_ids])};

  # 3. Assign the DnaFrags to the GenomicAligns
  foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
      $this_genomic_align->{'dnafrag'} = $dnafrags{$this_genomic_align->{dnafrag_id}};
    }
  }
}

1;
