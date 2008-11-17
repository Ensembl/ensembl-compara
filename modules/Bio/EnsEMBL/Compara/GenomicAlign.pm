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
  $genomic_align->cigar_line("23M4D27M");
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
  $slice = $genomic_align->get_Slice();


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

corresponds to method_link_species_set.method_link_species_set_id (external ref.)

=item method_link_species_set

Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet object corresponding to method_link_species_set_id

=item dnafrag_id

corresponds to dnafrag.dnafrag_id (external ref.)

=item dnafrag

Bio::EnsEMBL::Compara::DnaFrag object corresponding to dnafrag_id

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

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlign;
use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate verbose);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Scalar::Util qw(weaken);
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Mapper;


=head2 new (CONSTRUCTOR)

  Arg [-DBID] : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-GENOMIC_ALIGN_BLOCK]
              : (opt.) Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
                (the block to which this Bio::EnsEMBL::Compara::GenomicAlign object
                belongs to)
  Arg [-GENOMIC_ALIGN_BLOCK_ID]
              : (opt.) int $genomic_align_block_id (the database internal ID for the
                $genomic_align_block)
  Arg [-METHOD_LINK_SPECIES_SET]
              : (opt.) Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
                (this defines the type of alignment and the set of species used
                to get this GenomicAlignBlock)
  Arg [-METHOD_LINK_SPECIES_SET_ID]
              : (opt.) int $mlss_id (the database internal ID for the $mlss)
  Arg [-DNAFRAG]
              : (opt.) Bio::EnsEMBL::Compara::DnaFrag $dnafrag (the genomic
                sequence object to which this object refers to)
  Arg [-DNAFRAG_ID]
              : (opt.) int $dnafrag_id (the database internal ID for the $dnafrag)
  Arg [-DNAFRAG_START]
              : (opt.) int $dnafrag_start (the starting position of this
                Bio::EnsEMBL::Compara::GenomicAling within its corresponding $dnafrag)
  Arg [-DNAFRAG_END]
              : (opt.) int $dnafrag_end (the ending position of this
                Bio::EnsEMBL::Compara::GenomicAling within its corresponding $dnafrag)
  Arg [-DNAFRAG_STRAND]
              : (opt.) int $dnafrag_strand (1 or -1; defines in which strand of its
                corresponding $dnafrag this Bio::EnsEMBL::Compara::GenomicAlign is)
  Arg [-ALIGNED_SEQUENCE]
              : (opt.) string $aligned_sequence (the sequence of this object, including
                gaps and all)
  Arg [-CIGAR_LINE]
              : (opt.) string $cigar_line (a compressed way of representing the indels in
                the $aligned_sequence of this object)
  Arg [-LEVEL_ID]
              : (opt.) int $level_id (level of orhologous layer. 1 corresponds to the first
                layer of orthologous sequences found, 2 and over are addiotional layers)
  Example     : my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
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
  Description : Creates a new Bio::EnsEMBL::Compara::GenomicAlign object
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my($class, @args) = @_;

    my $self = {};
    bless $self,$class;

    my ($cigar_line, $adaptor,
        $dbID, $genomic_align_block, $genomic_align_block_id, $method_link_species_set,
        $method_link_species_set_id, $dnafrag, $dnafrag_id,
        $dnafrag_start, $dnafrag_end, $dnafrag_strand,
        $aligned_sequence, $level_id ) = 
      
      rearrange([qw(
          CIGAR_LINE ADAPTOR
          DBID GENOMIC_ALIGN_BLOCK GENOMIC_ALIGN_BLOCK_ID METHOD_LINK_SPECIES_SET
          METHOD_LINK_SPECIES_SET_ID DNAFRAG DNAFRAG_ID
          DNAFRAG_START DNAFRAG_END DNAFRAG_STRAND
          ALIGNED_SEQUENCE LEVEL_ID)], @args);

    $self->adaptor( $adaptor ) if defined $adaptor;
    $self->cigar_line( $cigar_line ) if defined $cigar_line;
    
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


=head2 copy (CONSTRUCTOR)

  Arg         : -none-
  Example     : my $new_genomic_align = $genomic_align->copy();
  Description : Create a new object with the same attributes
                as this one.
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlign (or subclassed) object
  Exceptions  :
  Status      : Stable

=cut

sub copy {
  my ($self) = @_;
  my $new_copy = {};
  bless $new_copy, ref($self);

  while (my ($key, $value) = each %$self) {
    $new_copy->{$key} = $value;
  }

  return $new_copy;
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
  Caller     : object->methodname

=cut

sub adaptor {
  my $self = shift;

  if (@_) {
    $self->{'adaptor'} = shift;
    throw($self->{'adaptor'}." is not a Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor object")
        if ($self->{'adaptor'} and !UNIVERSAL::isa($self->{'adaptor'}, "Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor"));
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
  Caller     : object->methodname

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
  Exception  : throws if $genomic_align_block is not a
               Bio::EnsEMBL::Compara::GenomicAlignBlock object or if 
               $genomic_align_block does not match a previously defined
               genomic_align_block_id
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub genomic_align_block {
  my ($self, $genomic_align_block) = @_;

  if (defined($genomic_align_block)) {
    throw("$genomic_align_block is not a Bio::EnsEMBL::Compara::GenomicAlignBlock object")
        if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
    weaken($self->{'genomic_align_block'} = $genomic_align_block);

    ## Add adaptor to genomic_align_block object if possible and needed
    if (!defined($genomic_align_block->adaptor) and defined($self->adaptor)) {
      $genomic_align_block->adaptor($self->adaptor->db->get_GenomicAlignBlockAdaptor);
    }

    if ($self->{'genomic_align_block_id'}) {
      if (!$self->{'genomic_align_block'}->dbID) {
        $self->{'genomic_align_block'}->dbID($self->{'genomic_align_block_id'});
      }
#       warning("Defining both genomic_align_block_id and genomic_align_block");
      throw("dbID of genomic_align_block object does not match previously defined".
            " genomic_align_block_id. If you want to override a".
            " Bio::EnsEMBL::Compara::GenomicAlign object, you can reset the ".
            "genomic_align_block_id using \$genomic_align->genomic_align_block_id(0)")
          if ($self->{'genomic_align_block'}->dbID != $self->{'genomic_align_block_id'});
    } else {
      $self->{'genomic_align_block_id'} = $genomic_align_block->dbID;
    }

  } elsif (!defined($self->{'genomic_align_block'})) {
    # Try to get the genomic_align_block from other sources...
    if (defined($self->genomic_align_block_id) and defined($self->{'adaptor'})) {
      # ...from the genomic_align_block_id. Uses genomic_align_block_id function
      # and not the attribute in the <if> clause because the attribute can be retrieved from other
      # sources if it has not been set before.
      my $genomic_align_block_adaptor = $self->{'adaptor'}->db->get_GenomicAlignBlockAdaptor;
      $self->{'genomic_align_block'} = $genomic_align_block_adaptor->fetch_by_dbID(
              $self->{'genomic_align_block_id'});
    } else {
#      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_block".
#          " You either have to specify more information (see perldoc for".
#          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
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
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub genomic_align_block_id {
  my ($self, $genomic_align_block_id) = @_;

  if (defined($genomic_align_block_id)) {
    $self->{'genomic_align_block_id'} = ($genomic_align_block_id or undef);
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
    } else {
#      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_block_id".
#          " You either have to specify more information (see perldoc for".
#          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
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
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub method_link_species_set {
  my ($self, $method_link_species_set) = @_;

  if (defined($method_link_species_set)) {
    throw("$method_link_species_set is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $self->{'method_link_species_set'} = $method_link_species_set;
    if ($self->{'method_link_species_set_id'}) {
      if (!$self->{'method_link_species_set'}->dbID) {
        $self->{'method_link_species_set'}->dbID($self->{'method_link_species_set_id'});
      } else {
        $self->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID();
      }
    } else {
      $self->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID;
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
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->method_link_species_set".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
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
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub method_link_species_set_id {
  my ($self, $method_link_species_set_id) = @_;

  if (defined($method_link_species_set_id)) {
    $self->{'method_link_species_set_id'} = $method_link_species_set_id;
    if (defined($self->{'method_link_species_set'}) and $self->{'method_link_species_set_id'}) {
      $self->{'method_link_species_set'} = undef;
    }
  } elsif (!$self->{'method_link_species_set_id'}) {
    # Try to get the ID from other sources...
    if (defined($self->{'method_link_species_set'}) and $self->{'method_link_species_set'}->dbID) {
      # ...from the corresponding Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
      $self->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID;
    } elsif (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->method_link_species_set_id".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'method_link_species_set_id'};
}


=head2 genome_db

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $genome_db = $genomic_align->genome_db;
  Example    : $genomic_align->genome_db($genome_db);
  Description: Getter/Setter for the attribute genome_db of
               the dnafrag. This method is a short cut for
               $genomic_align->dnafrag->genome_db()
  Returntype : Bio::EnsEMBL::Compara::DnaFrag object
  Exceptions : thrown if $genomic_align->dnafrag is not
               defined and cannot be fetched from other
               sources.
  Caller     : object->methodname

=cut

sub genome_db {
  my ($self, $genome_db) = @_;

  if (defined($genome_db)) {
    throw("$genome_db is not a Bio::EnsEMBL::Compara::GenomeDB object")
        if (!UNIVERSAL::isa($genome_db, "Bio::EnsEMBL::Compara::GenomeDB"));
    my $dnafrag = $self->dnafrag();
    if (!$dnafrag) {
      throw("Cannot set genome_db if dnafrag does not exist");
    } else {
      $self->dnafrag->genome_db($genome_db);
    }
  }
  return $self->dnafrag->genome_db;
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
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub dnafrag {
  my ($self, $dnafrag) = @_;

  if (defined($dnafrag)) {
    throw("$dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag object")
        if (!$dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"));
    $self->{'dnafrag'} = $dnafrag;
    if ($self->{'dnafrag_id'}) {
      if (!$self->{'dnafrag'}->dbID) {
        $self->{'dnafrag'}->dbID($self->{'dnafrag_id'});
      }
#       warning("Defining both dnafrag_id and dnafrag");
      throw("dnafrag object does not match previously defined dnafrag_id")
          if ($self->{'dnafrag'}->dbID != $self->{'dnafrag_id'});
    } else {
      $self->{'dnafrag_id'} = $self->{'dnafrag'}->dbID;
    }
  
  } elsif (!defined($self->{'dnafrag'})) {

    # Try to get data from other sources...
    if (defined($self->dnafrag_id) and defined($self->{'adaptor'})) {
      # ...from the dnafrag_id. Use dnafrag_id function and not the attribute in the <if>
      # clause because the attribute can be retrieved from other sources if it has not been already defined.
      my $dnafrag_adaptor = $self->adaptor->db->get_DnaFragAdaptor;
      $self->{'dnafrag'} = $dnafrag_adaptor->fetch_by_dbID($self->{'dnafrag_id'});
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->dnafrag".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
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
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

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
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->dnafrag_id".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'dnafrag_id'};
}


=head2 dnafrag_start

  Arg [1]    : integer $dnafrag_start
  Example    : $dnafrag_start = $genomic_align->dnafrag_start;
  Example    : $genomic_align->dnafrag_start(1233354);
  Description: Getter/Setter for the attribute dnafrag_start. If no argument is given, the
               dnafrag_start is not defined but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub dnafrag_start {
  my ($self, $dnafrag_start) = @_;

  if (defined($dnafrag_start)) {
     $self->{'dnafrag_start'} = $dnafrag_start;

   } elsif (!defined($self->{'dnafrag_start'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->dnafrag_start".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'dnafrag_start'};
}


=head2 dnafrag_end

  Arg [1]    : integer $dnafrag_end
  Example    : $dnafrag_end = $genomic_align->dnafrag_end;
  Example    : $genomic_align->dnafrag_end(1235320);
  Description: Getter/Setter for the attribute dnafrag_end. If no argument is given, the
               dnafrag_end is not defined but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub dnafrag_end {
  my ($self, $dnafrag_end) = @_;

  if (defined($dnafrag_end)) {
     $self->{'dnafrag_end'} = $dnafrag_end;

  } elsif (!defined($self->{'dnafrag_end'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->dnafrag_end".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'dnafrag_end'};
}


=head2 dnafrag_strand

  Arg [1]    : integer $dnafrag_strand (1 or -1)
  Example    : $dnafrag_strand = $genomic_align->dnafrag_strand;
  Example    : $genomic_align->dnafrag_strand(1);
  Description: Getter/Setter for the attribute dnafrag_strand. If no argument is given, the
               dnafrag_strand is not defined but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub dnafrag_strand {
  my ($self, $dnafrag_strand) = @_;

  if (defined($dnafrag_strand)) {
     $self->{'dnafrag_strand'} = $dnafrag_strand;

  } elsif (!defined($self->{'dnafrag_strand'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->dnafrag_strand".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'dnafrag_strand'};
}


=head2 aligned_sequence

  Arg [1...] : string $aligned_sequence or string @flags
  Example    : $aligned_sequence = $genomic_align->aligned_sequence
  Example    : $aligned_sequence = $genomic_align->aligned_sequence("+FIX_SEQ");
  Example    : $genomic_align->aligned_sequence("ACTAGTTAGCT---TATCT--TTAAA")
  Description: With no arguments, rebuilds the alignment string for this sequence
               using the cigar_line information and the original sequence if needed.
               This sequence depends on the strand defined by the dnafrag_strand attribute.
  Flags      : +FIX_SEQ
                   With this flag, the method will return a sequence that could be
                   directly aligned with the original_sequence of the reference
                   genomic_align.
  Returntype : string $aligned_sequence
  Exceptions : thrown if sequence contains unknown symbols
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub aligned_sequence {
  my ($self, @aligned_sequence_or_flags) = @_;
  my $aligned_sequence;

  my $fix_seq = 0;
  my $fake_seq = 0;
  foreach my $flag (@aligned_sequence_or_flags) {
    if ($flag =~ /^\+/) {
      if ($flag eq "+FIX_SEQ") {
        $fix_seq = 1;
      } elsif ($flag eq "+FAKE_SEQ") {
        $fake_seq = 1;
      } else {
        warning("Unknow flag $flag when calling".
            " Bio::EnsEMBL::Compara::GenomicAlign::aligned_sequence()");
      }
    } else {
      $aligned_sequence = $flag;
    }
  }

  if (defined($aligned_sequence)) {
    $aligned_sequence =~ s/[\r\n]+$//;
    
    if ($aligned_sequence) {
      ## Check sequence
      throw("Unreadable sequence ($aligned_sequence)") if ($aligned_sequence !~ /^[\-\.A-Z]+$/i);
      $self->{'aligned_sequence'} = $aligned_sequence;
    } else {
      $self->{'aligned_sequence'} = undef;
    }
  } elsif (!defined($self->{'aligned_sequence'})) {
    # Try to get the aligned_sequence from other sources...
    if (defined($self->cigar_line) and $fake_seq) {
      # ...from the corresponding cigar_line (using a fake seq)
      $aligned_sequence = _get_fake_aligned_sequence_from_cigar_line(
          $self->{'cigar_line'});
    
    } elsif (defined($self->cigar_line) and defined($self->original_sequence)) {
      my $original_sequence = $self->original_sequence;
      # ...from the corresponding orginial_sequence and cigar_line
      $aligned_sequence = _get_aligned_sequence_from_original_sequence_and_cigar_line(
          $original_sequence, $self->{'cigar_line'});
      $self->{'aligned_sequence'} = $aligned_sequence;

    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->aligned_sequence".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  $aligned_sequence = $self->{'aligned_sequence'} if (defined($self->{'aligned_sequence'}));
  if ($aligned_sequence and $fix_seq) {
    $aligned_sequence = _get_aligned_sequence_from_original_sequence_and_cigar_line(
        $aligned_sequence, $self->genomic_align_block->reference_genomic_align->cigar_line, $fix_seq);
  } 

  return $aligned_sequence;
}


=head2 length

  Arg [1]    : -none-
  Example    : $length = $genomic_align->length;
  Description: get the length of the aligned sequence. This method will try to
               get the length from the aligned_sequence if already set or by
               parsing the cigar_line otherwise
  Returntype : int
  Exceptions : none
  Warning    : 
  Caller     : object->methodname

=cut

sub length {
  my $self = shift;

  if ($self->{aligned_sequence}) {
    return length($self->{aligned_sequence});
  } elsif ($self->{cigar_line}) {
    my $length = 0;
    my $cigar_line = $self->{cigar_line};
    my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );
    for my $cigElem ( @cig ) {
      my $cigType = substr( $cigElem, -1, 1 );
      my $cigCount = substr( $cigElem, 0 ,-1 );
      $cigCount = 1 unless ($cigCount =~ /^\d+$/);
      $length += $cigCount unless ($cigType eq "I");
    }
    return $length;
  }

  return undef;
}

=head2 cigar_line

  Arg [1]    : string $cigar_line
  Example    : $cigar_line = $genomic_align->cigar_line;
  Example    : $genomic_align->cigar_line("35M2D233M7D23MD100M");
  Description: get/set for attribute cigar_line.
               If no argument is given, the cigar line has not been
               defined yet but the aligned sequence was, it calculates
               the cigar line based on the aligned (gapped) sequence.
               If no argument is given, the cigar_line is not defined but both
               the dbID and the adaptor are, it tries to fetch and set all
               the direct attributes from the database using the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlign object. You can reset this
               attribute using an empty string as argument.
               The cigar_line depends on the strand defined by the dnafrag_strand
               attribute.
  Returntype : string
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub cigar_line {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    if ($arg) {
      $self->{'cigar_line'} = $arg;
    } else {
      $self->{'cigar_line'} = undef;
    }

  } elsif (!defined($self->{'cigar_line'})) {
    # Try to get the cigar_line from other sources...
    if (defined($self->{'aligned_sequence'})) {
      # ...from the aligned sequence


      my $cigar_line = _get_cigar_line_from_aligned_sequence($self->{'aligned_sequence'});
      $self->cigar_line($cigar_line);
    
    } elsif (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->cigar_line".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
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
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub level_id {
  my ($self, $level_id) = @_;

  if (defined($level_id)) {
    $self->{'level_id'} = $level_id;

  } elsif (!defined($self->{'level_id'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->level_id".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'level_id'};
}


=head2 genomic_align_groups
 
  Arg [1]    : a ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignGroup $genomic_align_groups
  Example    : $genomic_align_groups = $genomic_align->genomic_align_groups;
  Example    : $genomic_align->genomic_align_groups($genomic_align_groups);
  Description: get/set for attribute genomic_align_groups. If no argument is given, the
               genomic_align_groups are not defined but both the dbID and the adaptor are,
               it tries to fetch and set teh data from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : int
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub genomic_align_groups {
  my ($self, $genomic_align_groups) = @_;

  if (defined($genomic_align_groups)) {
    foreach my $this_genomic_align_group (@$genomic_align_groups) {
      my $type = $this_genomic_align_group->type;
      $self->{'genomic_align_group'}->{$type} = $this_genomic_align_group;
    }

  } elsif (!defined($self->{'genomic_align_group'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $genomic_align_groups = $self->adaptor->db->get_GenomicAlignGroupAdaptor->fetch_all_by_GenomicAlign($self);
      foreach my $this_genomic_align_group (@$genomic_align_groups) {
        my $type = $this_genomic_align_group->type;
        $self->{'genomic_align_group'}->{$type} = $this_genomic_align_group;
        $self->{'genomic_align_group_id'}->{$type} = $this_genomic_align_group->dbID;
      }
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_groups".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  $genomic_align_groups = [values %{$self->{'genomic_align_group'}}];
  return $genomic_align_groups;
}


=head2 genomic_align_group_by_type
 
  Arg [1]    : [mandatory] string $type (genomic_align_group.type)
  Arg [2]    : [optional] Bio::EnsEMBL::Compara::GenomicAlignGroup $genomic_align_group
  Example    : $genomic_align_group = $genomic_align->genomic_align_group_by_type("default");
  Example    : $genomic_align->genomic_align_group_by_type("default", $genomic_align_group);
  Description: get/set for the Bio::EnsEMBL::Compara::GenomicAlginGroup object
               corresponding to this Bio::EnsEMBL::Compara::GenomicAlign object and the
               given type.
  Returntype : int
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub genomic_align_group_by_type {
  my ($self, $type, $genomic_align_group) = @_;

  $type = "default" if (!$type);

  if (defined($genomic_align_group)) {
    $self->{'genomic_align_group'}->{$type} = $genomic_align_group;
  } elsif (!defined($self->{'genomic_align_group'}->{$type})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      my $genomic_align_group_adaptor = $self->adaptor->db->get_GenomicAlignGroupAdaptor;
      my $genomic_align_groups = $genomic_align_group_adaptor->fetch_all_by_GenomicAlign($self);
      foreach my $this_genomic_align_group (@$genomic_align_groups) {
        $self->{'genomic_align_group'}->{$this_genomic_align_group->{'type'}} = $this_genomic_align_group;
        $self->{'genomic_align_group_id'}->{$this_genomic_align_group->{'type'}} = $this_genomic_align_group->dbID;

      }
    }
  }
  return $self->{'genomic_align_group'}->{$type};
}


=head2 genomic_align_group_id_by_type
 
  Arg [1]    : [mandatory] string $type (genomic_align_group.type)
  Arg [2]    : [optional] int $genomic_align_group_id
  Example    : $genomic_align_group_id = $genomic_align->genomic_align_group_by_type("default");
  Example    : $genomic_align->genomic_align_group_by_type("default", 18);
  Description: get/set for the genomic_align_group_id corresponding to this
               Bio::EnsEMBL::Compara::GenomicAlign object and the given type.
  Returntype : int
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname

=cut

sub genomic_align_group_id_by_type {
  my ($self, $type, $genomic_align_group_id) = @_;

  $type = "default" if (!$type);

  if (defined($genomic_align_group_id)) {
    $self->{'genomic_align_group_id'}->{$type} = $genomic_align_group_id;
  } elsif (!defined($self->{'genomic_align_group_id'}->{$type})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      my $genomic_align_group_adaptor = $self->adaptor->db->get_GenomicAlignGroupAdaptor;
      my $genomic_align_groups = $genomic_align_group_adaptor->fetch_all_by_GenomicAlign($self);
      foreach my $this_genomic_align_group (@$genomic_align_groups) {
        $self->{'genomic_align_group'}->{$this_genomic_align_group->{'type'}} = $this_genomic_align_group;
        $self->{'genomic_align_group_id'}->{$this_genomic_align_group->{'type'}} = $this_genomic_align_group->dbID;
      }
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_group_id_by_type".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'genomic_align_group_id'}->{$type};
}


=head2 original_sequence

  Arg [1]    : none
  Example    : $original_sequence = $genomic_align->original_sequence
  Description: get/set original sequence. If no argument is given and the original_sequence
               is not defined, it tries to fetch the data from other sources like the
               aligned sequence or the the Bio::EnsEMBL::Compara:DnaFrag object. You can
               reset this attribute using an empty string as argument.
               This sequence depends on the strand defined by the dnafrag_strand attribute.
  Returntype : string $original_sequence
  Exceptions : 
  Caller     : object->methodname

=cut

sub original_sequence {
  my ($self, $original_sequence) = @_;

  if (defined($original_sequence)) {
    if ($original_sequence) {
      $self->{'original_sequence'} = $original_sequence;
    } else {
      $self->{'original_sequence'} = undef;
    }

  } elsif (!defined($self->{'original_sequence'})) {
    # Try to get the data from other sources...
    
    if ($self->{'aligned_sequence'} and $self->{'cigar_line'} !~ /I/) {
      # ...from the aligned sequence
      $self->{'original_sequence'} = $self->{'aligned_sequence'};
      $self->{'original_sequence'} =~ s/\-//g;

    } elsif (!defined($self->{'original_sequence'}) and defined($self->dnafrag)
          and defined($self->dnafrag_start) and defined($self->dnafrag_end)
          and defined($self->dnafrag_strand) and defined($self->dnafrag->slice)) {
      # ...from the dnafrag object. Uses dnafrag, dnafrag_start and dnafrag_methods instead of the attibutes
      # in the <if> clause because the attributes can be retrieved from other sources if they have not been
      # already defined.
      $self->{'original_sequence'} = $self->dnafrag->slice->subseq(
              $self->dnafrag_start,
              $self->dnafrag_end,
              $self->dnafrag_strand
          );
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_groups".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
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
  
  my @pieces = grep {$_} split(/(\-+)|(\.+)/, $aligned_sequence);
  foreach my $piece (@pieces) {
    my $mode;
    if ($piece =~ /\-/) {
      $mode = "D"; # D for gaps (deletions)
    } elsif ($piece =~ /\./) {
      $mode = "X"; # X for pads (in 2X genomes)
    } else {
      $mode = "M"; # M for matches/mismatches
    }
    if (CORE::length($piece) == 1) {
      $cigar_line .= $mode;
    } elsif (CORE::length($piece) > 1) { #length can be 0 if the sequence starts with a gap
      $cigar_line .= CORE::length($piece).$mode;
    }
  }

  return $cigar_line;
}


=head2 _get_aligned_sequence_from_original_sequence_and_cigar_line

  Arg [1]    : string $original_sequence
  Arg [1]    : string $cigar_line
  Example    : $aligned_sequence = _get_aligned_sequence_from_original_sequence_and_cigar_line(
                   "CGTAACTGATGTTA", "3MD8M2D3M")
  Description: get gapped sequence from original one and cigar line
  Returntype : string $aligned_sequence
  Exceptions : thrown if cigar_line does not match sequence length
  Caller     : methodname

=cut

sub _get_aligned_sequence_from_original_sequence_and_cigar_line {
  my ($original_sequence, $cigar_line, $fix_seq) = @_;
  my $aligned_sequence = "";

  return undef if (!defined($original_sequence) or !$cigar_line);

  my $seq_pos = 0;
  
  my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );
  for my $cigElem ( @cig ) {
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless ($cigCount =~ /^\d+$/);

    if( $cigType eq "M" ) {
      $aligned_sequence .= substr($original_sequence, $seq_pos, $cigCount);
      $seq_pos += $cigCount;
    } elsif( $cigType eq "I") {
      $seq_pos += $cigCount;
    } elsif( $cigType eq "X") {
      $aligned_sequence .=  "." x $cigCount;
    } elsif( $cigType eq "G" || $cigType eq "D") {
      if ($fix_seq) {
        $seq_pos += $cigCount;
      } else {
        $aligned_sequence .=  "-" x $cigCount;
      }
    }
  }
  throw("Cigar line ($seq_pos) does not match sequence length (".CORE::length($original_sequence).")")
      if ($seq_pos != CORE::length($original_sequence));

  return $aligned_sequence;
}


=head2 _get_fake_aligned_sequence_from_cigar_line

  Arg [1]    : string $cigar_line
  Example    : $aligned_sequence = _get_fake_aligned_sequence_from_cigar_line(
                   "3MD8M2D3M")
  Description: get gapped sequence of N\'s from the cigar line
  Returntype : string $fake_aligned_sequence
  Exceptions : 
  Caller     : methodname

=cut

sub _get_fake_aligned_sequence_from_cigar_line {
  my ($cigar_line, $fix_seq) = @_;
  my $fake_aligned_sequence = "";

  return undef if (!$cigar_line);

  my $seq_pos = 0;

  my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );
  for my $cigElem ( @cig ) {
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless ($cigCount =~ /^\d+$/);

    if( $cigType eq "M" ) {
      $fake_aligned_sequence .= "N" x $cigCount;
      $seq_pos += $cigCount;
    } elsif( $cigType eq "I") {
      $seq_pos += $cigCount;
    } elsif( $cigType eq "X") {
      $fake_aligned_sequence .=  "." x $cigCount;
    } elsif( $cigType eq "G" || $cigType eq "D") {
      if ($fix_seq) {
        $seq_pos += $cigCount;
      } else {
        $fake_aligned_sequence .=  "-" x $cigCount;
      }
    }
  }

  return $fake_aligned_sequence;
}


=head2 _print

  Arg [1]    : ref to a FILEHANDLE
  Example    : $genomic_align->_print
  Description: print attributes of the object to the STDOUT or to the FILEHANDLE.
               Used for debuging purposes.
  Returntype : none
  Exceptions : 
  Caller     : object->methodname

=cut

sub _print {
  my ($self, $FILEH) = @_;

  my $verbose = verbose;
  verbose(0);
  
  $FILEH ||= \*STDOUT;

  print $FILEH
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
  verbose($verbose);

}

=head2 display_id
  
  Args       : none
  Example    : my $id = $genomic_align->display_id;
  Description: returns string describing this genomic_align which can be used
               as display_id of a Bio::Seq object or in a fasta file. The actual form is
               taxon_id:genome_db_id:coord_system_name:dnafrag_name:dnafrag_start:dnafrag_end:dnafrag_strand
               e.g.
               9606:1:chromosome:14:50000000:51000000:-1

               Uses dnafrag information in addition to start and end.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub display_id {
  my $self = shift;

  my $dnafrag = $self->dnafrag;
  return "" unless($dnafrag);
  my $id = join(':',
                $dnafrag->genome_db->taxon_id,
                $dnafrag->genome_db->dbID,
                $dnafrag->coord_system_name,
                $dnafrag->name,
                $self->dnafrag_start,
                $self->dnafrag_end,
                $self->dnafrag_strand);
  return $id;
}

=head2 reverse_complement

  Args       : none
  Example    : none
  Description: reverse complement the object modifing dnafrag_strand and cigar_line
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub reverse_complement {
  my ($self) = @_;

  # reverse strand
  $self->dnafrag_strand($self->dnafrag_strand * -1);

  # reverse original and aligned sequences if cached
  my $original_sequence = $self->{'original_sequence'};
  if ($original_sequence) {
    $original_sequence = reverse $original_sequence;
    $original_sequence =~ tr/ATCGatcg/TAGCtagc/;
    $self->original_sequence($original_sequence);
  }
  my $aligned_sequence = $self->{'aligned_sequence'};
  if ($aligned_sequence) {
    $aligned_sequence = reverse $aligned_sequence;
    $aligned_sequence =~ tr/ATCGatcg/TAGCtagc/;
    $self->aligned_sequence($aligned_sequence);
  }
  
  # reverse cigar_string as consequence
  my $cigar_line = $self->cigar_line;
  $cigar_line = join("", reverse grep {$_} split(/(\d*[GDMIX])/, $cigar_line));

  $self->cigar_line($cigar_line);
}


=head2 get_Mapper

  Arg[1]     : [optional] integer $cache (default = FALSE)
  Arg[2]     : [optional] boolean $condensed (default = FALSE)
  Example    : $this_mapper = $genomic_align->get_Mapper();
  Example    : $mapper1 = $genomic_align1->get_Mapper();
               $mapper2 = $genomic_align2->get_Mapper();
  Description: creates and returns a Bio::EnsEMBL::Mapper to map coordinates from
               the original sequence of this Bio::EnsEMBL::Compara::GenomicAlign
               to the aligned sequence, i.e. the alignment. In order to map a sequence
               from this Bio::EnsEMBL::Compara::GenomicAlign object to another
               Bio::EnsEMBL::Compara::GenomicAlign of the same
               Bio::EnsEMBL::Compara::GenomicAlignBlock object, you may use this mapper
               to transform coordinates into the "alignment" coordinates and then to
               the other Bio::EnsEMBL::Compara::GenomicAlign coordinates using the
               corresponding Bio::EnsEMBL::Mapper.
               The coordinates of the "alignment" starts with the reference_slice_start
               position of the GenomicAlingBlock if available or 1 otherwise.
               With the $cache argument you can decide whether you want to cache the
               result or not. Result is *not* cached by default.
  Returntype : Bio::EnsEMBL::Mapper object
  Exceptions : throw if no cigar_line can be found

=cut

sub get_Mapper {
  my ($self, $cache, $condensed) = @_;
  my $mapper;
  $cache = 0 if (!defined($cache));
  my $mode = "expanded";
  if (defined($condensed) and $condensed) {
    $mode = "condensed";
  }

  if (!defined($self->{$mode.'_mapper'})) {
    my $cigar_line = $self->cigar_line;
    $cigar_line = $self->get_fixed_cigar_line if ($mode eq "condensed");
    if (!$cigar_line) {
      throw("[$self] has no cigar_line and cannot be retrieved by any means");
    }
    my $alignment_position = (eval{$self->genomic_align_block->reference_slice_start} or 1);
    my $sequence_position = $self->dnafrag_start;
    my $rel_strand = $self->dnafrag_strand;
    if ($rel_strand == 1) {
      $sequence_position = $self->dnafrag_start;
    } else {
      $sequence_position = $self->dnafrag_end;
    }
    $mapper = _get_Mapper_from_cigar_line($cigar_line, $alignment_position, $sequence_position, $rel_strand);

    return $mapper if (!$cache);

    $self->{$mode.'_mapper'} = $mapper;
  }

  return $self->{$mode.'_mapper'};
}

sub _get_Mapper_from_cigar_line {
  my ($cigar_line, $alignment_position, $sequence_position, $rel_strand) = @_;

  my $mapper = Bio::EnsEMBL::Mapper->new("sequence", "alignment");

  my @cigar_pieces = ($cigar_line =~ /(\d*[GMDX])/g);
  if ($rel_strand == 1) {
    foreach my $cigar_piece (@cigar_pieces) {
      my $cigar_type = substr($cigar_piece, -1, 1 );
      my $cigar_count = substr($cigar_piece, 0 ,-1 );
      $cigar_count = 1 unless ($cigar_count =~ /^\d+$/);
      next if ($cigar_count < 1);
  
      if( $cigar_type eq "M" ) {
        $mapper->add_map_coordinates(
                "sequence", #$self->dbID,
                $sequence_position,
                $sequence_position + $cigar_count - 1,
                $rel_strand,
                "alignment", #$self->genomic_align_block->dbID,
                $alignment_position,
                $alignment_position + $cigar_count - 1
            );
        $sequence_position += $cigar_count;
        $alignment_position += $cigar_count;
      } elsif( $cigar_type eq "G" || $cigar_type eq "D" || $cigar_type eq "X") {
        $alignment_position += $cigar_count;
      }
    }
  } else {
    foreach my $cigar_piece (@cigar_pieces) {
      my $cigar_type = substr($cigar_piece, -1, 1 );
      my $cigar_count = substr($cigar_piece, 0 ,-1 );
      $cigar_count = 1 unless ($cigar_count =~ /^\d+$/);
      next if ($cigar_count < 1);
  
      if( $cigar_type eq "M" ) {
        $mapper->add_map_coordinates(
                "sequence", #$self->dbID,
                $sequence_position - $cigar_count + 1,
                $sequence_position,
                $rel_strand,
                "alignment", #$self->genomic_align_block->dbID,
                $alignment_position,
                $alignment_position + $cigar_count - 1
            );
        $sequence_position -= $cigar_count;
        $alignment_position += $cigar_count;
      } elsif( $cigar_type eq "G" || $cigar_type eq "D" || $cigar_type eq "X") {
        $alignment_position += $cigar_count;
      }
    }
  }

  return $mapper;
}


=head2 get_Slice

  Arg[1]     : -none-
  Example    : $slice = $genomic_align->get_Slice();
  Description: creates and returns a Bio::EnsEMBL::Slice which corresponds to
               this Bio::EnsEMBL::Compara::GenomicAlign
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : return -undef- if slice cannot be created (this is likely to
               happen if the Registry is misconfigured)

=cut

sub get_Slice {
  my ($self) = @_;

  my $slice = $self->dnafrag->slice;
  return undef if (!defined($slice));

  $slice = $slice->sub_Slice(
              $self->dnafrag_start,
              $self->dnafrag_end,
              $self->dnafrag_strand
          );

  return $slice;
}


=head2 restrict

  Arg[1]     : int start
  Arg[1]     : int end
  Example    : my $genomic_align = $genomic_align->restrict(10, 20);
  Description: restrict (trim) this GenomicAlign to the start and end
               positions (in alignment coordinates). If no trimming is
               required, the original object is returned instead.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions :
  Status     : At risk

=cut

sub restrict {
  my ($self, $start, $end) = @_;
  throw("Wrong arguments") if (!$start or !$end);

  my $restricted_genomic_align = $self->copy();
  delete($restricted_genomic_align->{dbID});
  delete($restricted_genomic_align->{genomic_align_block_id});
  delete($restricted_genomic_align->{original_sequence});
  delete($restricted_genomic_align->{aligned_sequence});
  delete($restricted_genomic_align->{cigar_line});
  $restricted_genomic_align->{original_dbID} = $self->dbID if ($self->dbID);

  my $aligned_seq_length = 0;

  #unable to retrieve $self->genomic_align_block->length 
  if ((!$self->{'genomic_align_block_id'}) or (!$self->genomic_align_block->length)) {
      my @cigar = grep {$_} split(/(\d*[GDMX])/, $self->cigar_line);
      while (my $cigar = shift(@cigar)) {
          my ($num, $type) = ($cigar =~ /^(\d*)([GDMX])/);
          $num = 1 if ($num eq "");
          $aligned_seq_length += $num;
      }
  } else {
    $aligned_seq_length = $self->genomic_align_block->length;
  }

  my $final_aligned_length = $end - $start + 1;
  my $length_of_truncated_seq_at_the_start = $start - 1;
  my $length_of_truncated_seq_at_the_end = $aligned_seq_length - $end;
  
  my @cigar = grep {$_} split(/(\d*[GDMX])/, $self->cigar_line);  

  ## Trim start of cigar_line if needed
  if ($length_of_truncated_seq_at_the_start >= 0) {
    $aligned_seq_length = 0;
    my $original_seq_length = 0;
    my $new_cigar_piece = "";
    while (my $cigar = shift(@cigar)) {
      my ($num, $type) = ($cigar =~ /^(\d*)([GDMX])/);
      $num = 1 if ($num eq "");
      $aligned_seq_length += $num;
      if ($aligned_seq_length >= $length_of_truncated_seq_at_the_start) {
        my $length = $aligned_seq_length - $length_of_truncated_seq_at_the_start;
        if ($length > 1) {
          $new_cigar_piece = $length.$type;
        } elsif ($length == 1) {
          $new_cigar_piece = $type;
        }
        unshift(@cigar, $new_cigar_piece) if ($new_cigar_piece);
        if ($type eq "M") {
          $original_seq_length += $length_of_truncated_seq_at_the_start - ($aligned_seq_length - $num);
        }
        last;
      }
      $original_seq_length += $num if ($type eq "M");
    }
    if ($self->dnafrag_strand == 1) {
      $restricted_genomic_align->dnafrag_start($self->dnafrag_start + $original_seq_length);
    } else {
      $restricted_genomic_align->dnafrag_end($self->dnafrag_end - $original_seq_length);
    }
  }

  my @final_cigar = ();

  ## Trim end of cigar_line if needed
  if ($length_of_truncated_seq_at_the_end >= 0) {
    ## Truncate all the GenomicAligns
    $aligned_seq_length = 0;
    my $original_seq_length = 0;
    my $new_cigar_piece = "";
    while (my $cigar = shift(@cigar)) {
      my ($num, $type) = ($cigar =~ /^(\d*)([GDMX])/);
      $num = 1 if ($num eq "");
      $aligned_seq_length += $num;
      if ($aligned_seq_length >= $final_aligned_length) {
        my $length = $num - $aligned_seq_length + $final_aligned_length;
        if ($length > 1) {
          $new_cigar_piece = $length.$type;
        } elsif ($length == 1) {
          $new_cigar_piece = $type;
        }
        push(@final_cigar, $new_cigar_piece) if ($new_cigar_piece);
        if ($type eq "M") {
          $original_seq_length += $length;
        }
        last;
      } else {
        push(@final_cigar, $cigar);
      }
      $original_seq_length += $num if ($type eq "M");
    }
    if ($self->dnafrag_strand == 1) {
      $restricted_genomic_align->dnafrag_end($restricted_genomic_align->dnafrag_start + $original_seq_length - 1);
    } else {
      $restricted_genomic_align->dnafrag_start($restricted_genomic_align->dnafrag_end - $original_seq_length + 1);
    }
  } else {
    @final_cigar = @cigar;
  }

  ## Save genomic_align's cigar_line
  $restricted_genomic_align->aligned_sequence(0);
  $restricted_genomic_align->cigar_line(join("", @final_cigar));

  return $restricted_genomic_align;
}


1;
