# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlignBlockAdaptor
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::DBSQL::Compara::GenomicAlignBlockAdaptor

=head1 SYNOPSIS

=head2 Connecting to the database using the old way:

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (
      -host => $host,
      -user => $dbuser,
      -pass => $dbpass,
      -port => $port,
      -dbname => $dbname,
      -conf_file => $conf_file);

  my $genomic_align_block_adaptor = $db->get_GenomicAlignBlockAdaptor();

=head2 Connecting to the database using the new way (recommended):
  
  use Bio::EnsEMBL::Registry; 
  Bio::EnsEMBL::Registry->load_all($conf_file); # $conf_file can be undef

  Bio::EnsEMBL::Registry->load_all();

  my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
      $compara_db_name, "compara", "GenomicAlignBlock");

=head2 Store/Delete data from the database
  
  $genomic_align_block_adaptor->store($genomic_align_block);

  $genomic_align_block_adaptor->delete_by_dbID($genomic_align_block->dbID);

=head2 Retrieve data from the database
  
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID(12);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $method_link_species_set, $human_slice);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
      $method_link_species_set, $human_dnafrag);

  $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag(
      $method_link_species_set, $human_dnafrag, $mouse_dnafrag);

=head1 DESCRIPTION

This object is intended for accessiong data in the genomic_align_block table.

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
use Bio::EnsEMBL::Utils::Exception qw(throw info deprecate);


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  $self->{_lazy_loading} = 0;

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


# # =head2 fetch_all_by_Slice
# # 
# #   Arg  1     : integer $method_link_species_set_id
# #                     - or -
# #                Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
# #   Arg  2     : Bio::EnsEMBL::Slice $original_slice
# #   Arg  3     : [optional] integer $limit
# #   Example    : my $genomic_align_blocks =
# #                   $genomic_align_block_adaptor->fetch_all_by_Slice(
# #                       2, $original_slice);
# #   Example    : my $genomic_align_blocks =
# #                   $genomic_align_block_adaptor->fetch_all_by_Slice(
# #                       $method_link_species_set, $original_slice);
# #   Description: Retrieve the corresponding
# #                Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
# #   Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
# #                adaptor and method_link_species_set are actually stored in the objects. The remaining
# #                attributes are only retrieved when required.
# #   Exceptions : Returns ref. to an empty array if no matching
# #                Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
# #   Caller     : $object->mthod_name
# # 
# # =cut

sub fetch_all_by_Slice {
  my ($self, $method_link_species_set, $original_slice, $limit) = @_;
  my $all_genomic_align_blocks = []; # Returned value

  deprecate("Use fetch_all_by_MethodLinkSpeciesSet_Slice method instead");

  if ($method_link_species_set =~ /^\d+$/) {
    my $method_link_species_set_adaptor = $self->db->get_MethodLinkSpeciesSetAdaptor;
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set);
  }

  return $self->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set,
          $original_slice,
          $limit
      );
}


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Slice $original_slice
  Arg  3     : [optional] integer $limit
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

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
  my ($self, $method_link_species_set, $reference_slice, $limit) = @_;
  my $all_genomic_align_blocks = []; # Returned value

  ## method_link_species_set will be checked in the fetch_all_by_MethodLinkSpeciesSet_DnaFrag method

  ## Check original_slice
  unless($reference_slice && ref $reference_slice && 
         $reference_slice->isa('Bio::EnsEMBL::Slice')) {
    throw("[$reference_slice] should be a Bio::EnsEMBL::Slice object\n");
  }

  $limit = 0 if (!defined($limit));

  ## Get the Bio::EnsEMBL::Compara::GenomeDB object corresponding to the
  ## $reference_slice
  my $slice_adaptor = $reference_slice->adaptor();
  if(!$slice_adaptor) {
    warning("Slice has no attached adaptor. Cannot get Compara alignments.");
    return $all_genomic_align_blocks;
  }
  my $primary_species_binomial_name = 
      $slice_adaptor->db->get_MetaContainer->get_Species->binomial;
  my ($highest_cs) = @{$slice_adaptor->db->get_CoordSystemAdaptor->fetch_all()};
  my $primary_species_assembly = $highest_cs->version();
  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor;
  my $genome_db = $genome_db_adaptor->fetch_by_name_assembly(
          $primary_species_binomial_name,
          $primary_species_assembly
      );

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
            $limit
        );

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


# # =head2 fetch_all_by_DnaFrag
# # 
# #   Arg  1     : integer $method_link_species_set_id
# #                     - or -
# #                Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
# #   Arg  2     : integer $dnafrag_id
# #                     - or -
# #                Bio::EnsEMBL::Compara::DnaFrag $dnafrag
# #   Arg  3     : integer $start
# #   Arg  4     : integer $end
# #   Arg  5     : integer $limit
# #   Example    : my $genomic_align_blocks =
# #                   $genomic_align_block_adaptor->fetch_all_by_DnaFrag(
# #                       2, 19, 50000000, 50250000);
# #   Description: Retrieve the corresponding
# #                Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Objects 
# #   Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
# #                adaptor and method_link_species_set are actually stored in the objects. The remaining
# #                attributes are only retrieved when requiered.
# #   Exceptions : Returns ref. to an empty array if no matching
# #                Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
# #   Caller     : none
# # 
# # =cut

sub fetch_all_by_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit) = @_;
  my $genomic_align_blocks = []; # returned object

  deprecate("Use fetch_all_by_MethodLinkSpeciesSet_DnaFrag method instead");

  if ($dnafrag =~ /^\d+$/) {
    my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor;
    $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag);
  }

  if ($method_link_species_set =~ /^\d+$/) {
    my $method_link_species_set_adaptor = $self->db->get_MethodLinkSpeciesSetAdaptor;
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set);
  }

  return $self->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
          $method_link_species_set,
          $dnafrag,
          $start,
          $end,
          $limit
      )
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  3     : integer $start [optional]
  Arg  4     : integer $end [optional]
  Arg  5     : integer $limit_number [optional]
  Arg  6     : integer $limit_index_start [optional]
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
                      $mlss, $dnafrag, 50000000, 50250000);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Objects 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit_number, $limit_index_start) = @_;

  my $genomic_align_blocks = []; # returned object

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
              ga2.genomic_align_id
          FROM
              genomic_align ga1, genomic_align ga2
          WHERE 
              ga1.genomic_align_block_id = ga2.genomic_align_block_id
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
  if ($limit_number && $limit_index_start) {
    $sql .= qq{ LIMIT $limit_index_start , $limit_number };
  } elsif ($limit_number) {
    $sql .= qq{ LIMIT $limit_number };
  }

  my $sth = $self->prepare($sql);
  $sth->execute();
  
  my $all_genomic_align_blocks;
  while (my ($genomic_align_id, $genomic_align_block_id, $method_link_species_set_id,
      $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $level_id,
      $query_genomic_align_id) = $sth->fetchrow_array) {

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
    ## ... attach it to the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock
    $all_genomic_align_blocks->{$query_genomic_align_id}->add_GenomicAlign($this_genomic_align);
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
                  $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
                      $mlss, $qy_dnafrag, 50000000, 50250000,$tg_dnafrag);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

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
              AND ga2.method_link_species_set_id = $method_link_species_set_id
              AND ga1.dnafrag_id = $dnafrag_id1 AND ga2.dnafrag_id = $dnafrag_id2;
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

    my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock
      (-adaptor => $self,
       -dbID => $genomic_align_block_id1,
       -method_link_species_set_id => $method_link_species_set_id1,
       -reference_genomic_align_id => $genomic_align_id1);

    # If set up, lazy loading of genomic_align
    unless ($self->lazy_loading) {
      ## Create a Bio::EnsEMBL::Compara::GenomicAlign correponding to ga1.*
      my $this_genomic_align1 = new Bio::EnsEMBL::Compara::GenomicAlign
        (-dbID => $genomic_align_id1,
         -adaptor => $self->db->get_GenomicAlignAdaptor,
         -genomic_align_block_id => $genomic_align_block_id1,
         -method_link_species_set_id => $method_link_species_set_id1,
         -dnafrag_id => $dnafrag_id1,
         -dnafrag_start => $dnafrag_start1,
         -dnafrag_end => $dnafrag_end1,
         -dnafrag_strand => $dnafrag_strand1,
         -cigar_line => $cigar_line1,
         -level_id => $level_id1);
      ## ... attach it to the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock
      $gab->add_GenomicAlign($this_genomic_align1);

      ## Create a Bio::EnsEMBL::Compara::GenomicAlign correponding to ga2.*
      my $this_genomic_align2 = new Bio::EnsEMBL::Compara::GenomicAlign
        (-dbID => $genomic_align_id2,
         -adaptor => $self->db->get_GenomicAlignAdaptor,
         -genomic_align_block_id => $genomic_align_block_id2,
         -method_link_species_set_id => $method_link_species_set_id2,
         -dnafrag_id => $dnafrag_id2,
         -dnafrag_start => $dnafrag_start2,
         -dnafrag_end => $dnafrag_end2,
         -dnafrag_strand => $dnafrag_strand2,
         -cigar_line => $cigar_line2,
         -level_id => $level_id2);

      ## ... attach it to the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock
      $gab->add_GenomicAlign($this_genomic_align2);
    }
    push(@$genomic_align_blocks, $gab);
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

sub lazy_loading {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_lazy_loading} = $value;
  }

  return $self->{_lazy_loading};
}

1;
