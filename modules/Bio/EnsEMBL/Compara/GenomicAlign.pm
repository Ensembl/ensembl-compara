#
# Ensembl module for Bio::EnsEMBL::Compara::GenomicAlign
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::GenomicAlign - Defines one of the sequences involved in a genomic alignment

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::GenomicAlign; 
  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
          -adaptor => $genomic_align_adaptor,
          -genomic_align_block => $genomic_align_block,
          -method_link_species_set => $method_link_species_set,
          -dnafrag => $dnafrag,
          -dnafrag_start => 100001,
          -dnafrag_end => 100050,
          -dnafrag_strand => -1,
          -aligned_sequence => "TTGCAGGTAGGCCATCTGCAAGC----TGAGGAGCAAGGACTCCAGTCGGAGTC"
          -level_id => 1,
        );


SET VALUES
  $genomic_align->adaptor($adaptor);
  $genomic_align->dbID(12);
  $genomic_align->genomic_align_block($genomic_align_block);
  $genomic_align->genomic_align_block_id(1032);
  $genomic_align->method_link_species_set($method_link_species_set);
  $genomic_align->method_link_species_set_id(3);
  $genomic_align->dnafrag($dnafrag);
  $genomic_align->dnafrag_id(134);
  $genomic_align->dnafrag_start(100001);
  $genomic_align->dnafrag_end(100050);
  $genomic_align->dnafrag_strand(-1);
  $genomic_align->aligned_sequence("TTGCAGGTAGGCCATCTGCAAGC----TGAGGAGCAAGGACTCCAGTCGGAGTC");
  $genomic_align->original_sequence("TTGCAGGTAGGCCATCTGCAAGCTGAGGAGCAAGGACTCCAGTCGGAGTC");
  $genomic_align->cigar_line("23M4G27M");
  $genomic_align->level_id(1);

GET VALUES
  $adaptor = $genomic_align->adaptor;
  $dbID = $genomic_align->dbID;
  $genomic_align_block = $genomic_align->genomic_block;
  $genomic_align_block_id = $genomic_align->genomic_align_block_id;
  $method_link_species_set = $genomic_align->method_link_species_set;
  $method_link_species_set_id = $genomic_align->method_link_species_set_id;
  $dnafrag = $genomic_align->dnafrag;
  $dnafrag_id = $genomic_align->dnafrag_id;
  $dnafrag_start = $genomic_align->dnafrag_start;
  $dnafrag_end = $genomic_align->dnafrag_end;
  $dnafrag_strand = $genomic_align->dnafrag_strand;
  $aligned_sequence = $genomic_align->aligned_sequence;
  $original_sequence = $genomic_align->original_sequence;
  $cigar_line = $genomic_align->cigar_line;
  $level_id = $genomic_align->level_id;


=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to genomic_align.genomic_align_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor object to access DB

=item genomic_align_block_id

corresponds to genomic_align_block.genomic_align_block_id (ext. reference)

=item genomic_align_block

Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock object corresponding to genomic_align_block_id

=item method_link_species_set_id

corresponds to method_link_species.method_link_species_set (external ref.)

=item method_link_species_set

Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet object corresponding to method_link_species_set_id

=item dnafrag_id

corresponds to dnafrag.dnafrag_id (external ref.)

=item dnafrag

Bio::EnsEMBL::Compara::DBSQL::DnaFrag object corresponding to dnafrag_id

=item dnafrag_start

corresponds to genomic_align.dnafrag_start

=item dnafrag_end

corresponds to genomic_align.dnafrag_end

=item dnafrag_strand

corresponds to genomic_align.dnafrag_strand

=item cigar_line

corresponds to genomic_align.cigar_line

=item level_id

corresponds to genomic_align.level_id

=item aligned_sequence

corresponds to the sequence rebuilt using dnafrag and cigar_line

=item original_sequence

corresponds to the original sequence. It can be rebuilt from the aligned_sequence, the dnafrag object or can be used
in conjuction with cigar_line to get the aligned_sequence.

=back

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlign;
use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Scalar::Util qw(weaken);

# Object preamble

my $warn_message = "Deprecated use of GenomicAlign object. Consensus and Query DnaFrag are no longer used.\n";


# new() is written here 

sub new {
    my($class, @args) = @_;

    my $self = {};
    bless $self,$class;

    
    ## First lines are for backward compatibility, middle one is for both versions and
    ## last ones are for the new schema
    my ($consensus_dnafrag, $consensus_start, $consensus_end,
        $query_dnafrag, $query_start, $query_end, $query_strand, $alignment_type,
        $score, $perc_id,

        $cigar_line, $adaptor,

        $dbID, $genomic_align_block, $genomic_align_block_id, $method_link_species_set,
        $method_link_species_set_id, $dnafrag, $dnafrag_id,
        $dnafrag_start, $dnafrag_end, $dnafrag_strand,
        $aligned_sequence, $level_id ) = 
      
      rearrange([qw(
          CONSENSUS_DNAFRAG CONSENSUS_START CONSENSUS_END
          QUERY_DNAFRAG QUERY_START QUERY_END QUERY_STRAND ALIGNMENT_TYPE
          SCORE PERC_ID
                            
          CIGAR_LINE ADAPTOR
                            
          DBID GENOMIC_ALIGN_BLOCK GENOMIC_ALIGN_BLOCK_ID METHOD_LINK_SPECIES_SET
          METHOD_LINK_SPECIES_SET_ID DNAFRAG DNAFRAG_ID
          DNAFRAG_START DNAFRAG_END DNAFRAG_STRAND
          ALIGNED_SEQUENCE LEVEL_ID)], @args);

    $self->adaptor( $adaptor ) if defined $adaptor;
    $self->cigar_line( $cigar_line ) if defined $cigar_line;
    
    ## Support for backward compatibility
    if (defined($consensus_dnafrag) or defined($consensus_start) or defined($consensus_end)
        or defined($query_dnafrag) or defined($query_start) or defined($query_end)
        or defined($query_strand) or defined($alignment_type) or defined($score)
        or defined($perc_id)) {
      
      if (defined($dbID) or defined($genomic_align_block) or defined($genomic_align_block_id)
          or defined($method_link_species_set) or defined($method_link_species_set_id)
          or defined($dnafrag) or defined($dnafrag_id) or defined($dnafrag_start)
          or defined($dnafrag_end) or defined($dnafrag_strand) or defined($aligned_sequence)
          or defined($level_id)) {
        throw("Mixing new and old parameters.\n");
      }
      
      deprecate($warn_message);

      $self->consensus_dnafrag( $consensus_dnafrag ) if defined $consensus_dnafrag;
      $self->consensus_start( $consensus_start ) if defined $consensus_start;
      $self->consensus_end( $consensus_end ) if defined $consensus_end;
      $self->query_dnafrag( $query_dnafrag ) if defined $query_dnafrag;
      $self->query_start( $query_start ) if defined $query_start;
      $self->query_end( $query_end ) if defined $query_end;
      $self->query_strand( $query_strand ) if defined $query_strand;
      $self->alignment_type( $alignment_type ) if defined $alignment_type;
      $self->score( $score ) if defined $score;
      $self->perc_id( $perc_id ) if defined $perc_id;

      return $self;
    }
    
    $self->dbID($dbID) if (defined($dbID));
    $self->genomic_align_block($genomic_align_block) if (defined($genomic_align_block));
    $self->genomic_align_block_id($genomic_align_block_id) if (defined($genomic_align_block_id));
    $self->method_link_species_set($method_link_species_set) if (defined($method_link_species_set));
    $self->method_link_species_set_id($method_link_species_set_id) if (defined($method_link_species_set_id));
    $self->dnafrag($dnafrag) if (defined($dnafrag));
    $self->dnafrag_id($dnafrag_id) if (defined($dnafrag_id));
    $self->dnafrag_start($dnafrag_start) if (defined($dnafrag_start));
    $self->dnafrag_end($dnafrag_end) if (defined($dnafrag_end));
    $self->dnafrag_strand($dnafrag_strand) if (defined($dnafrag_strand));
    $self->aligned_sequence($aligned_sequence) if (defined($aligned_sequence));
    $self->level_id($level_id) if (defined($level_id));

    return $self;
}


sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor
  Example    : $adaptor = $genomic_align->adaptor;
  Example    : $genomic_align->adaptor($adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor
  Exceptions : thrown if $adaptor is not a
               Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor object
  Caller     : object::methodname

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
     throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor object")
         if (!$adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor"));
     $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 dbID

  Arg [1]    : integer $dbID
  Example    : $dbID = $genomic_align->dbID;
  Example    : $genomic_align->dbID(12);
  Description: Getter/Setter for the attribute dbID
  Returntype : integer
  Exceptions : none
  Caller     : object::methodname

=cut

sub dbID {
  my ($self, $dbID) = @_;

  if (defined($dbID)) {
     $self->{'dbID'} = $dbID;
  }

  return $self->{'dbID'};
}


=head2 genomic_align_block

  Arg [1]    : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
  Example    : $genomic_align_block = $genomic_align->genomic_align_block;
  Example    : $genomic_align->genomic_align_block($genomic_align_block);
  Description: Getter/Setter for the attribute genomic_align_block
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object. If no
               argument is given, the genomic_align_block is not defined but
               both the genomic_align_block_id and the adaptor are, it tries
               to fetch the data using the genomic_align_block_id.
  Exceptions : thrown if $genomic_align_block is not a
               Bio::EnsEMBL::Compara::GenomicAlignBlock object or if 
               $genomic_align_block does not match a previously defined
               genomic_align_block_id
  Caller     : object::methodname

=cut

sub genomic_align_block {
  my ($self, $genomic_align_block) = @_;

  if (defined($genomic_align_block)) {
    throw("$genomic_align_block is not a Bio::EnsEMBL::Compara::GenomicAlignBlock object")
        if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
    weaken($self->{'genomic_align_block'} = $genomic_align_block);
    if ($self->{'genomic_align_block_id'}) {
#       warning("Defining both genomic_align_block_id and genomic_align_block");
      throw("dbID of genomic_align_block object does not match previously defined genomic_align_block_id")
          if ($self->{'genomic_align_block'}->dbID != $self->{'genomic_align_block_id'});
    }

  } elsif (!defined($self->{'genomic_align_block'}) and defined($self->genomic_align_block_id) and
          defined($self->{'adaptor'})) {
    # Try to fetch the data using the genomic_align_block_id. Uses genomic_align_block_id function and not
    # the attribute in the <if> clause because the attribute can be retrieved from other sources if it has
    # not been already defined.
    my $genomic_align_block_adaptor = $self->{'adaptor'}->db->get_GenomicAlignBlockAdaptor;
    $self->{'genomic_align_block'} = $genomic_align_block_adaptor->fetch_by_dbID(
            $self->{'genomic_align_block_id'});
  }

  return $self->{'genomic_align_block'};
}


=head2 genomic_align_block_id

  Arg [1]    : integer $genomic_align_block_id
  Example    : $genomic_align_block_id = $genomic_align->genomic_align_block_id;
  Example    : $genomic_align->genomic_align_block_id(1032);
  Description: Getter/Setter for the attribute genomic_align_block_id. If no
               argument is given and the genomic_align_block_id is not defined, it
               tries to get the data from other sources like the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock object or the database using
               the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
               Use 0 as argument to clear this attribute.
  Returntype : integer
  Exceptions : thrown if $genomic_align_block_id does not match a previously defined
               genomic_align_block
  Caller     : object::methodname

=cut

sub genomic_align_block_id {
  my ($self, $genomic_align_block_id) = @_;

  if (defined($genomic_align_block_id)) {
    $self->{'genomic_align_block_id'} = $genomic_align_block_id;
    if (defined($self->{'genomic_align_block'}) and $self->{'genomic_align_block_id'}) {
#       warning("Defining both genomic_align_block_id and genomic_align_block");
      throw("genomic_align_block_id does not match previously defined genomic_align_block object")
          if ($self->{'genomic_align_block'} and
              $self->{'genomic_align_block'}->dbID != $self->{'genomic_align_block_id'});
    }

  } elsif (!($self->{'genomic_align_block_id'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'genomic_align_block'}) and defined($self->{'genomic_align_block'}->dbID)) {
      # ...from the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock object
      $self->{'genomic_align_block_id'} = $self->{'genomic_align_block'}->dbID;
    } elsif (defined($self->{'adaptor'}) and defined($self->{'dbID'})) {
      # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{'genomic_align_block_id'};
}


=head2 method_link_species_set

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Example    : $method_link_species_set = $genomic_align->method_link_species_set;
  Example    : $genomic_align->method_link_species_set($method_link_species_set);
  Description: Getter/Setter for the attribute method_link_species_set. If no
               argument is given and the method_link_species_set is not defined, it
               tries to get the data from other sources like the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock object or from
               the method_link_species_set_id.
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : thrown if $method_link_species_set is not a
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object or if 
               $method_link_species_set does not match a previously defined
               method_link_species_set_id
  Caller     : object::methodname

=cut

sub method_link_species_set {
  my ($self, $method_link_species_set) = @_;

  if (defined($method_link_species_set)) {
    throw("$method_link_species_set is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $self->{'method_link_species_set'} = $method_link_species_set;
    if ($self->{'method_link_species_set_id'}) {
#       warning("Defining both method_link_species_set_id and method_link_species_set");
      throw("method_link_species_set object does not match previously defined method_link_species_set_id")
          if ($self->{'method_link_species_set'}->dbID != $self->{'method_link_species_set_id'});
    }
  
  } elsif (!defined($self->{'method_link_species_set'})) {
    # Try to get the object from other sources...
    if (defined($self->genomic_align_block) and ($self->{'genomic_align_block'}->method_link_species_set)) {
      # ...from the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock object. Uses genomic_align_block
      # function and not the attribute in the <if> clause because the attribute can be retrieved from other
      # sources if it has not been already defined.
      $self->{'method_link_species_set'} = $self->genomic_align_block->method_link_species_set;
    } elsif (defined($self->method_link_species_set_id) and defined($self->{'adaptor'})) {
      # ...from the method_link_species_set_id. Uses method_link_species_set_id function and not the attribute
      # in the <if> clause because the attribute can be retrieved from other sources if it has not been
      # already defined.
      my $method_link_species_set_adaptor = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor;
      $self->{'method_link_species_set'} = $method_link_species_set_adaptor->fetch_by_dbID(
              $self->{'method_link_species_set_id'});
    }
  }

  return $self->{'method_link_species_set'};
}


=head2 method_link_species_set_id

  Arg [1]    : integer $method_link_species_set_id
  Example    : $method_link_species_set_id = $genomic_align->method_link_species_set_id;
  Example    : $genomic_align->method_link_species_set_id(3);
  Description: Getter/Setter for the attribute method_link_species_set_id. If no
               argument is given and the method_link_species_set_id is not defined, it
               tries to get the data from other sources like the corresponding
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object or the database
               using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
               Use 0 as argument to clear this attribute.
  Returntype : integer
  Exceptions : thrown if $method_link_species_set_id does not match a previously defined
               method_link_species_set
  Caller     : object::methodname

=cut

sub method_link_species_set_id {
  my ($self, $method_link_species_set_id) = @_;

  if (defined($method_link_species_set_id)) {
    $self->{'method_link_species_set_id'} = $method_link_species_set_id;
    if (defined($self->{'method_link_species_set'}) and $self->{'method_link_species_set_id'}) {
#       warning("Defining both method_link_species_set_id and method_link_species_set");
      throw("method_link_species_set_id does not match previously defined method_link_species_set object")
          if ($self->{'method_link_species_set'} and
              $self->{'method_link_species_set'}->dbID != $self->{'method_link_species_set_id'});
    }
  } elsif (!$self->{'method_link_species_set_id'}) {
    # Try to get the ID from other sources...
    if (defined($self->{'method_link_species_set'}) and $self->{'method_link_species_set'}->dbID) {
      # ...from the corresponding Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
      $self->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID;
    } elsif (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{'method_link_species_set_id'};
}


=head2 dnafrag

  Arg [1]    : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Example    : $dnafrag = $genomic_align->dnafrag;
  Example    : $genomic_align->dnafrag($dnafrag);
  Description: Getter/Setter for the attribute dnafrag. If no
               argument is given, the dnafrag is not defined but
               both the dnafrag_id and the adaptor are, it tries
               to fetch the data using the dnafrag_id
  Returntype : Bio::EnsEMBL::Compara::DnaFrag object
  Exceptions : thrown if $dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag
               object or if $dnafrag does not match a previously defined
               dnafrag_id
  Caller     : object::methodname

=cut

sub dnafrag {
  my ($self, $dnafrag) = @_;

  if (defined($dnafrag)) {
    throw("$dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag object")
        if (!$dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"));
    $self->{'dnafrag'} = $dnafrag;
    if ($self->{'dnafrag_id'}) {
#       warning("Defining both dnafrag_id and dnafrag");
      throw("dnafrag object does not match previously defined dnafrag_id")
          if ($self->{'dnafrag'}->dbID != $self->{'dnafrag_id'});
    }
  
  } elsif (!defined($self->{'dnafrag'}) and defined($self->dnafrag_id) and defined($self->{'adaptor'})) {
    # Try to get the object from the dnafrag_id. Use dnafrag_id function and not the attribute in the <if>
    # clause because the attribute can be retrieved from other sources if it has not been already defined.
    my $dnafrag_adaptor = $self->adaptor->db->get_DnaFragAdaptor;
    $self->{'dnafrag'} = $dnafrag_adaptor->fetch_by_dbID($self->{'dnafrag_id'});
  }

  return $self->{'dnafrag'};
}


=head2 dnafrag_id

  Arg [1]    : integer $dnafrag_id
  Example    : $dnafrag_id = $genomic_align->dnafrag_id;
  Example    : $genomic_align->dnafrag_id(134);
  Description: Getter/Setter for the attribute dnafrag_id. If no
               argument is given and the dnafrag_id is not defined, it tries to
               get the ID from other sources like the corresponding
               Bio::EnsEMBL::Compara::DnaFrag object or the database using the dbID
               of the Bio::EnsEMBL::Compara::GenomicAlign object.
               Use 0 as argument to clear this attribute.
  Returntype : integer
  Exceptions : thrown if $dnafrag_id does not match a previously defined
               dnafrag
  Caller     : object::methodname

=cut

sub dnafrag_id {
  my ($self, $dnafrag_id) = @_;

  if (defined($dnafrag_id)) {
    $self->{'dnafrag_id'} = $dnafrag_id;
    if (defined($self->{'dnafrag'}) and $self->{'dnafrag_id'}) {
#       warning("Defining both dnafrag_id and dnafrag");
      throw("dnafrag_id does not match previously defined dnafrag object")
          if ($self->{'dnafrag'} and $self->{'dnafrag'}->dbID != $self->{'dnafrag_id'});
    }

  } elsif (!($self->{'dnafrag_id'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'dnafrag'}) and defined($self->{'dnafrag'}->dbID)) {
      # ...from the corresponding Bio::EnsEMBL::Compara::DnaFrag object
      $self->{'dnafrag_id'} = $self->{'dnafrag'}->dbID;
    } elsif (defined($self->{'adaptor'}) and defined($self->{'dbID'})) {
      # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{'dnafrag_id'};
}


=head2 dnafrag_start

  Arg [1]    : integer $dnafrag_start
  Example    : $dnafrag_start = $genomic_align->dnafrag_start;
  Example    : $genomic_align->dnafrag_start(1233354);
  Description: Getter/Setter for the attribute dnafrag_start. If no argument is given, the level_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : none
  Caller     : object::methodname

=cut

sub dnafrag_start {
  my ($self, $dnafrag_start) = @_;

  if (defined($dnafrag_start)) {
     $self->{'dnafrag_start'} = $dnafrag_start;

  } elsif (!defined($self->{'dnafrag_start'}) and defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
    # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
    $self->adaptor->retrieve_all_direct_attributes($self);
  }

  return $self->{'dnafrag_start'};
}


=head2 dnafrag_end

  Arg [1]    : integer $dnafrag_end
  Example    : $dnafrag_end = $genomic_align->dnafrag_end;
  Example    : $genomic_align->dnafrag_end(1235320);
  Description: Getter/Setter for the attribute dnafrag_end. If no argument is given, the level_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : none
  Caller     : object::methodname

=cut

sub dnafrag_end {
  my ($self, $dnafrag_end) = @_;

  if (defined($dnafrag_end)) {
     $self->{'dnafrag_end'} = $dnafrag_end;

  } elsif (!defined($self->{'dnafrag_end'}) and defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
    # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
    $self->adaptor->retrieve_all_direct_attributes($self);
  }

  return $self->{'dnafrag_end'};
}


=head2 dnafrag_strand

  Arg [1]    : integer $dnafrag_strand (1 or -1)
  Example    : $dnafrag_strand = $genomic_align->dnafrag_strand;
  Example    : $genomic_align->dnafrag_strand(1);
  Description: Getter/Setter for the attribute dnafrag_strand. If no argument is given, the level_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : none
  Caller     : object::methodname

=cut

sub dnafrag_strand {
  my ($self, $dnafrag_strand) = @_;

  if (defined($dnafrag_strand)) {
     $self->{'dnafrag_strand'} = $dnafrag_strand;

  } elsif (!defined($self->{'dnafrag_strand'}) and defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
    # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
    $self->adaptor->retrieve_all_direct_attributes($self);
  }

  return $self->{'dnafrag_strand'};
}


=head2 aligned_sequence

  Arg [1]    : string $aligned_sequence
  Example    : $aligned_sequence = $genomic_align->aligned_sequence
  Example    : $genomic_align->aligned_sequence("ACTAGTTAGCT---TATCT--TTAAA")
  Description: With no arguments, rebuilds the alignment string for this sequence
               using the cigar_line information and the original sequence if needed.
  Returntype : string $aligned_sequence
  Exceptions : thrown if sequence contains unknown symbols
  Caller     : object::methodname

=cut

sub aligned_sequence {
  my ($self, $aligned_sequence) = @_;

  if (defined($aligned_sequence)) {
    $aligned_sequence =~ s/[\r\n]+$//;
    ## Check sequence
    throw("Unreadable sequence ($aligned_sequence)") if ($aligned_sequence !~ /^[\-A-Z]+$/i);

    $self->{'aligned_sequence'} = $aligned_sequence;

  } elsif (!defined($self->{'aligned_sequence'}) and defined($self->cigar_line)) {
    $aligned_sequence = _get_aligned_sequence_from_original_sequence_and_cigar_line(
        $self->original_sequence, $self->{'cigar_line'});
    $self->{'aligned_sequence'} = $aligned_sequence;
  }

  return $self->{'aligned_sequence'};
}


=head2 cigar_line
 
  Arg [1]    : string $cigar_line
  Example    : $cigar_line = $genomic_align->cigar_line;
  Example    : $genomic_align->cigar_line("35M2G233M7G23MG100M");
  Description: get/set for attribute cigar_line.
               If no argument is given, the cigar line has not been
               defined yet but the aligned sequence was, it calculates
               the cigar line based on the aligned (gapped) sequence.
               If no argument is given, the cigar_line is not defined but both
               the dbID and the adaptor are, it tries to fetch and set all
               the direct attributes from the database using the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : string
  Exceptions : none
  Caller     : object::methodname
 
=cut

sub cigar_line {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'cigar_line'} = $arg ;

  } elsif (!defined($self->{'cigar_line'}) and defined($self->{'aligned_sequence'})) {
    # Try to get the cigar_line from the aligned sequence
    my $cigar_line = _get_cigar_line_from_aligned_sequence($self->{'aligned_sequence'});
    $self->cigar_line($cigar_line);
  
  } elsif (!defined($self->{'cigar_line'}) and defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
    # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
    $self->adaptor->retrieve_all_direct_attributes($self);
  }

  return $self->{'cigar_line'};
}


=head2 level_id
 
  Arg [1]    : int $level_id
  Example    : $level_id = $genomic_align->level_id;
  Example    : $genomic_align->level_id(1);
  Description: get/set for attribute level_id. If no argument is given, the level_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : int
  Exceptions : none
  Caller     : object::methodname
 
=cut

sub level_id {
  my ($self, $level_id) = @_;

  if (defined($level_id)) {
    $self->{'level_id'} = $level_id;

  } elsif (!defined($self->{'level_id'}) and defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
    # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
    $self->adaptor->retrieve_all_direct_attributes($self);
  }

  return $self->{'level_id'};
}


=head2 original_sequence

  Arg [1]    : none
  Example    : $original_sequence = $genomic_align->original_sequence
  Description: get/set original sequence. If no argument is given and the original_sequence
               is not defined, it tries to fetch the data from other sources like the
               aligned sequence or the the Bio::EnsEMBL::Compara:DnaFrag object.
  Returntype : string $original_sequence
  Exceptions : 
  Caller     : object::methodname

=cut

sub original_sequence {
  my ($self, $original_sequence) = @_;

  if (defined($original_sequence)) {
    $self->{'original_sequence'} = $original_sequence;

  } elsif (!defined($self->{'original_sequence'})) {
    # Try to get the data from other sources...
    
    if ($self->{'aligned_sequence'}) {
      # ...from the aligned sequence
      $self->{'original_sequence'} = $self->{'aligned_sequence'};
      $self->{'original_sequence'} =~ s/\-//g;

    } elsif (!defined($self->{'original_sequence'}) and defined($self->dnafrag)
          and defined($self->dnafrag_start) and defined($self->dnafrag_end)) {
      # ...from the dnafrag object. Uses dnafrag, dnafrag_start and dnafrag_methods instead of the attibutes
      # in the <if> clause because the attributes can be retrieved from other sources if they have not been
      # already defined.
      $self->{'original_sequence'} = $self->dnafrag->slice->subseq($self->dnafrag_start, $self->dnafrag_end);
    }
  }

  return $self->{'original_sequence'};
}

=head2 _get_cigar_line_from_aligned_sequence

  Arg [1]    : string $aligned_sequence
  Example    : $cigar_line = _get_cigar_line_from_aligned_sequence("CGT-AACTGATG--TTA")
  Description: get cigar line from gapped sequence
  Returntype : string $cigar_line
  Exceptions : 
  Caller     : methodname

=cut

sub _get_cigar_line_from_aligned_sequence {
  my ($aligned_sequence) = @_;
  my $cigar_line = "";
  
  my @pieces = split(/(\-+)/, $aligned_sequence);
  foreach my $piece (@pieces) {
    my $mode;
    if ($piece =~ /\-/) {
      $mode = "G"; # G for gaps
    } else {
      $mode = "M"; # M for matches/mismatches
    }
    if (length($piece) == 1) {
      $cigar_line .= $mode;
    } elsif (length($piece) > 1) { #length can be 0 if the sequence starts with a gap
      $cigar_line .= length($piece).$mode;
    }
  }

  return $cigar_line;
}


=head2 _get_aligned_sequence_from_original_sequence_and_cigar_line

  Arg [1]    : string $original_sequence
  Arg [1]    : string $cigar_line
  Example    : $aligned_sequence = _get_aligned_sequence_from_original_sequence_and_cigar_line(
                   "CGTAACTGATGTTA", "3MG8M2G3M")
  Description: get gapped sequence from original one and cigar line
  Returntype : string $aligned_sequence
  Exceptions : thrown if cigar_line does not match sequence length
  Caller     : methodname

=cut

sub _get_aligned_sequence_from_original_sequence_and_cigar_line {
  my ($original_sequence, $cigar_line) = @_;
  my $aligned_sequence = "";

  return undef if (!$original_sequence or !$cigar_line);

  my $seq_pos = 0;
  
  my @cig = ( $cigar_line =~ /(\d*[GM])/g );
  for my $cigElem ( @cig ) {
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless $cigCount;

    if( $cigType eq "M" ) {
      $aligned_sequence .= substr($original_sequence, $seq_pos, $cigCount);
      $seq_pos += $cigCount;
    } elsif( $cigType eq "G" ) {
      $aligned_sequence .=  "-" x $cigCount;
    }
  }
  throw("Cigar line does not match sequence lenght") if ($seq_pos != length($original_sequence));

  return $aligned_sequence;
}


=head2 _print

  Arg [1]    : none
  Example    : $genomic_align->_print
  Description: print attributes of the object to the STDOUT. Used for debuging purposes.
  Returntype : none
  Exceptions : 
  Caller     : object::methodname

=cut

sub _print {
  my ($self) = @_;

  print
"Bio::EnsEMBL::Compara::GenomicAlign object ($self)
  dbID = ".($self->dbID or "-undef-")."
  adaptor = ".($self->adaptor or "-undef-")."
  genomic_align_block = ".($self->genomic_align_block or "-undef-")."
  genomic_align_block_id = ".($self->genomic_align_block_id or "-undef-")."
  method_link_species_set = ".($self->method_link_species_set or "-undef-")."
  method_link_species_set_id = ".($self->method_link_species_set_id or "-undef-")."
  dnafrag = ".($self->dnafrag or "-undef-")."
  dnafrag_id = ".($self->dnafrag_id or "-undef-")."
  dnafrag_start = ".($self->dnafrag_start or "-undef-")."
  dnafrag_end = ".($self->dnafrag_end or "-undef-")."
  dnafrag_strand = ".($self->dnafrag_strand or "-undef-")."
  cigar_line = ".($self->cigar_line or "-undef-")."
  level_id = ".($self->level_id or "-undef-")."
  original_sequence = ".($self->original_sequence or "-undef-")."
  aligned_sequence = ".($self->aligned_sequence or "-undef-")."
  
";

}


#####################################################################
#####################################################################

=head1 DEPRECATED METHODS

Consensus and Query DnaFrag are no longer used. Please refer to
Bio::EnsEMBL::Compara::GenomicAlignBlock for further details.

=cut

#####################################################################
#####################################################################

=head2 consensus_dnafrag (DEPRECATED)
 
  Arg [1]    : Bio::EnsEMBL::Compara::DnaFrag $consensus_dnafrag
  Example    : none
  Description: get/set for attribute consensus_dnafrag_id
  Returntype : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Exceptions : none
  Caller     : general
 
=cut

sub consensus_dnafrag {
  my ($self, $arg) = @_;

  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'consensus_dnafrag'} = $arg ;
  }
   
  return $self->{'consensus_dnafrag'};
}


=head2 consensus_start (DEPRECATED)
 
  Arg [1]    : int $consensus_start
  Example    : none
  Description: get/set for attribute consensus_start
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub consensus_start {
  my ($self, $arg) = @_;

  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'consensus_start'} = $arg ;
  }

  return $self->{'consensus_start'};
}


=head2 consensus_end (DEPRECATED)
 
  Arg [1]    : int $consensus_end
  Example    : none
  Description: get/set for attribute consensus_end
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub consensus_end {
  my ($self, $arg) = @_;

  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'consensus_end'} = $arg ;
  }

  return $self->{'consensus_end'};
}


=head2 query_dnafrag (DEPRECATED)
 
  Arg [1]    : Bio::EnsEMBL::Compara::DnaFrag $query_dnafrag
  Example    : none
  Description: get/set for attribute query_dnafrag
  Returntype : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Exceptions : none
  Caller     : general
 
=cut

sub query_dnafrag {
  my ($self, $arg) = @_;
  
  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'query_dnafrag'} = $arg ;
  }
  
  return $self->{'query_dnafrag'};
}


=head2 query_start (DEPRECATED)
 
  Arg [1]    : int $query_start
  Example    : none
  Description: get/set for attribute query_start
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub query_start {
  my ($self, $arg) = @_;
 
  if ( defined $arg ) {
    $self->{'query_start'} = $arg ;
    deprecate($warn_message);
  }

  return $self->{'query_start'};
}


=head2 query_end (DEPRECATED)
 
  Arg [1]    : int $query_end
  Example    : none
  Description: get/set for attribute query_end
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub query_end {
  my ($self, $arg) = @_;
 
  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'query_end'} = $arg ;
  }
  
  return $self->{'query_end'};
}


=head2 query_strand (DEPRECATED)
 
  Arg [1]    : int $query_strand
  Example    : none
  Description: get/set for attribute query_strand
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub query_strand {
  my ($self, $arg) = @_;

  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'query_strand'} = $arg ;
  }
  
  return $self->{'query_strand'};
}


=head2 alignment_type (DEPRECATED)
 
  Arg [1]    : string $alignment_type
  Example    : 'WGA' or 'WGA_HCR'
  Description: get/set for attribute alignment_type
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub alignment_type {
  my ($self, $arg) = @_;
 
  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'alignment_type'} = $arg ;
  }
  
  return $self->{'alignment_type'};
}


=head2 score (DEPRECATED)
 
  Arg [1]    : double $score
  Example    : none
  Description: get/set for attribute score  
  Returntype : double
  Exceptions : none
  Caller     : general
 
=cut

sub score {
  my ($self, $arg) = @_;
 
  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'score'} = $arg ;
  }
  
  return $self->{'score'};
}


=head2 perc_id (DEPRECATED)
 
  Arg [1]    : int $perc_id
  Example    : none
  Description: get/set for attribute perc_id  
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub perc_id {
  my ($self, $arg) = @_;
 
  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'perc_id'} = $arg ;
  }

  $self->{'perc_id'} = "NULL" unless (defined $self->{'perc_id'});

  return $self->{'perc_id'};
}


=head2 strands_reversed (DEPRECATED)
 
  Arg [1]    : int $strands_reversed
  Example    : none
  Description: get/set for attribute strands_reversed
               0 means that strand and hstrand are the original strands obtained
                 from the alignment program used
               1 means that strand and hstrand have been flipped as compared to
                 the original result provided by the alignment program used.
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub strands_reversed {
  my ($self, $arg) = @_;


  if ( defined $arg ) {
    deprecate($warn_message);
    $self->{'strands_reversed'} = $arg ;
  }

  $self->{'strands_reversed'} = 0 unless (defined $self->{'strands_reversed'});

  return $self->{'strands_reversed'};
}


=head2 alignment_strings (DEPRECATED)

NEW API: Use Bio::EnsEMBL::Compara::GenomicAlignBlock to retrieve sequences. For
backwards compatibility, we will assume that the genome with a smaller genome_db_id is
the consensus genome. We will also assume that there are only two sequences in this
alignment. Please, use the new API for multiple alignments.
  
  Arg [1]    : list of string $flags
               FIX_SEQ = does not introduce gaps (dashes) in seq (consensus) aligned sequence
                         and delete the corresponding insertions in hseq aligned sequence
               FIX_HSEQ = does not introduce gaps (dashes) in hseq (query) aligned sequence
                         and delete the corresponding insertions in seq aligned sequence
               NO_SEQ = return the seq (consensus) aligned sequence as an empty string
               NO_HSEQ = return the hseq (query) aligned sequence as an empty string
               This 2 last flags would save a bit of time as doing so no querying to the core
               database in done to get the sequence.
  Example    : $ga->alignment_strings or
               $ga->alignment_strings("FIX_HSEQ") or
               $ga->alignment_strings("NO_SEQ","FIX_SEQ")
  Description: Allows to rebuild the alignment string of both the seq (consensus) and 
               hseq (query) sequence using the cigar_string information and the slice 
               and hslice objects
  Returntype : array reference containing 2 strings
               the first corresponds to seq (consensus)
               the second corresponds to hseq (query)
  Exceptions : 
  Caller     : 

=cut

sub alignment_strings {
  my ( $self, @flags ) = @_;

  deprecate($warn_message);
  
  # set the flags
  my $seq_flag = 1;
  my $hseq_flag = 1;
  my $fix_seq_flag = 0;
  my $fix_hseq_flag = 0;

  for my $flag ( @flags ) {
    $seq_flag = 0 if ($flag eq "NO_SEQ");
    $hseq_flag = 0 if ($flag eq "NO_HSEQ");
    $fix_seq_flag = 1 if ($flag eq "FIX_SEQ");
    $fix_hseq_flag = 1 if ($flag eq "FIX_HSEQ");
  } 

  deprecate($warn_message);
   
  my ($seq, $hseq);
  $seq = $self->consensus_dnafrag->slice->subseq($self->consensus_start, $self->consensus_end) if ($seq_flag || $fix_seq_flag);
  $hseq = $self->query_dnafrag->slice->subseq($self->query_start, $self->query_end) if ($hseq_flag || $fix_hseq_flag);

  my $rseq= "";
  # rseq - result sequence
  my $rhseq= "";
  # rhseq - result hsequence

  my $seq_pos = 0;
  my $hseq_pos = 0;

  my @cig = ( $self->cigar_line =~ /(\d*[DIM])/g );

  for my $cigElem ( @cig ) {
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless $cigCount;

    if( $cigType eq "M" ) {
        $rseq .= substr( $seq, $seq_pos, $cigCount ) if ($seq_flag);
        $rhseq .= substr( $hseq, $hseq_pos, $cigCount ) if ($hseq_flag);
      $seq_pos += $cigCount;
      $hseq_pos += $cigCount;
    } elsif( $cigType eq "D" ) {
      if( ! $fix_seq_flag ) {
        $rseq .=  "-" x $cigCount if ($seq_flag);
        $rhseq .= substr( $hseq, $hseq_pos, $cigCount ) if ($hseq_flag);
      }
      $hseq_pos += $cigCount;
    } elsif( $cigType eq "I" ) {
      if( ! $fix_hseq_flag ) {
        $rseq .= substr( $seq, $seq_pos, $cigCount ) if ($seq_flag);
        $rhseq .= "-" x $cigCount if ($hseq_flag);
      }
      $seq_pos += $cigCount;
    }
  }
  return [ $rseq,$rhseq ];
}


1;
