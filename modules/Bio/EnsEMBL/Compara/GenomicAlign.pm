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
          -visible => 1,
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
  $genomic_align->visible(1);

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
  $visible = $genomic_align->visible;
  $slice = $genomic_align->get_Slice();

=head1 DESCRIPTION

The GenomicAlign object stores information about a single sequence within an alignment.

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

=item visible

corresponds to genomic_align.visible

=item aligned_sequence

corresponds to the sequence rebuilt using dnafrag and cigar_line

=item original_sequence

corresponds to the original sequence. It can be rebuilt from the aligned_sequence, the dnafrag object or can be used
in conjuction with cigar_line to get the aligned_sequence.

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlign;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate verbose);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Scalar::Util qw(weaken);
use Bio::EnsEMBL::Compara::BaseGenomicAlignSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Mapper;

use base qw(Bio::EnsEMBL::Compara::Locus Bio::EnsEMBL::Storable);

use Data::Dumper;

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
                Bio::EnsEMBL::Compara::GenomicAlign within its corresponding $dnafrag)
  Arg [-DNAFRAG_END]
              : (opt.) int $dnafrag_end (the ending position of this
                Bio::EnsEMBL::Compara::GenomicAlign within its corresponding $dnafrag)
  Arg [-DNAFRAG_STRAND]
              : (opt.) int $dnafrag_strand (1 or -1; defines in which strand of its
                corresponding $dnafrag this Bio::EnsEMBL::Compara::GenomicAlign is)
  Arg [-ALIGNED_SEQUENCE]
              : (opt.) string $aligned_sequence (the sequence of this object, including
                gaps and all)
  Arg [-CIGAR_LINE]
              : (opt.) string $cigar_line (a compressed way of representing the indels in
                the $aligned_sequence of this object)
  Arg [-VISIBLE]
              : (opt.) int $visible. Used in self alignments to ensure only one Bio::EnsEMBL::Compara::GenomicAlignBlock is visible when you have more than 1 block covering the same region.
  Arg [-NODE_ID]
              : (opt.) int $node_id (the database internal ID linking the Bio::EnsEMBL::Compara::GenomicAlign object to the Bio::EnsEMBL::Compara::GenomicAlignTree object).
  Example     : my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                        -adaptor => $genomic_align_adaptor,
                        -genomic_align_block => $genomic_align_block,
                        -method_link_species_set => $method_link_species_set,
                        -dnafrag => $dnafrag,
                        -dnafrag_start => 100001,
                        -dnafrag_end => 100050,
                        -dnafrag_strand => -1,
                        -aligned_sequence => "TTGCAGGTAGGCCATCTGCAAGC----TGAGGAGCAAGGACTCCAGTCGGAGTC"
                        -visible => 1,
                      );
  Description : Creates a new Bio::EnsEMBL::Compara::GenomicAlign object
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub new {
    my($class, @args) = @_;

    my $self = $class->SUPER::new(@args);
    bless $self,$class;

    my ($cigar_line, $adaptor,
        $dbID, $genomic_align_block, $genomic_align_block_id, $method_link_species_set,
        $method_link_species_set_id,
        $aligned_sequence, $visible, $node_id ) = 
      
      rearrange([qw(
          CIGAR_LINE ADAPTOR
          DBID GENOMIC_ALIGN_BLOCK GENOMIC_ALIGN_BLOCK_ID METHOD_LINK_SPECIES_SET
          METHOD_LINK_SPECIES_SET_ID
          ALIGNED_SEQUENCE VISIBLE NODE_ID)], @args);

    $self->adaptor( $adaptor ) if defined $adaptor;
    $self->cigar_line( $cigar_line ) if defined $cigar_line;
    $self->aligned_sequence( $aligned_sequence ) if defined $aligned_sequence;

    $self->dbID($dbID) if (defined($dbID));
    $self->genomic_align_block($genomic_align_block) if (defined($genomic_align_block));
    $self->genomic_align_block_id($genomic_align_block_id) if (defined($genomic_align_block_id));
    $self->method_link_species_set($method_link_species_set) if (defined($method_link_species_set));
    $self->method_link_species_set_id($method_link_species_set_id) if (defined($method_link_species_set_id));
    $self->visible($visible) if (defined($visible));
    $self->node_id($node_id) if (defined($node_id));

    return $self;
}


=head2 copy (CONSTRUCTOR)

  Arg [1]     : (optional) Instance to copy the fields to
  Example     : my $new_genomic_align = $genomic_align->copy();
  Description : Create a new object with the same attributes
                as this one, or top-up the given object.
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlign (or subclassed) object
  Exceptions  :
  Status      : Stable

=cut

sub copy {
  my ($self, $new_copy) = @_;
  $new_copy ||= {};
  bless $new_copy, ref($self);

  while (my ($key, $value) = each %$self) {
    $new_copy->{$key} = $value;
  }

  return $new_copy;
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
  Status     : Stable

=cut

sub genomic_align_block {
  my ($self, $genomic_align_block) = @_;

  if (defined($genomic_align_block)) {
    throw("$genomic_align_block is not a Bio::EnsEMBL::Compara::BaseGenomicAlignSet object")
        if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::BaseGenomicAlignSet"));
    weaken($self->{'genomic_align_block'} = $genomic_align_block);

    ## Add adaptor to genomic_align_block object if possible and needed
    if (!defined($genomic_align_block->{'adaptor'}) and !defined($genomic_align_block->{'adaptor'}) and defined($self->{'adaptor'})) {
      $genomic_align_block->adaptor($self->adaptor->db->get_GenomicAlignBlockAdaptor);
    }

    if ($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
	if ($self->{'genomic_align_block_id'}) {
	    if (!$self->{'genomic_align_block'}->{'dbID'}) {
		$self->{'genomic_align_block'}->dbID($self->{'genomic_align_block_id'});
	    }
	    #       warning("Defining both genomic_align_block_id and genomic_align_block");
	    throw("dbID of genomic_align_block object does not match previously defined".
		  " genomic_align_block_id. If you want to override a".
		  " Bio::EnsEMBL::Compara::GenomicAlign object, you can reset the ".
		  "genomic_align_block_id using \$genomic_align->genomic_align_block_id(0)")
	      if ($self->{'genomic_align_block'}->{'dbID'} ne $self->{'genomic_align_block_id'});
	} else {
	    $self->{'genomic_align_block_id'} = $genomic_align_block->{'dbID'};
	}
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
  Status     : Stable

=cut

sub genomic_align_block_id {
  my ($self, $genomic_align_block_id) = @_;

  if (defined($genomic_align_block_id)) {

    $self->{'genomic_align_block_id'} = ($genomic_align_block_id or undef);
    if (defined($self->{'genomic_align_block'}) and $self->{'genomic_align_block_id'}) {
#       warning("Defining both genomic_align_block_id and genomic_align_block");
      throw("genomic_align_block_id does not match previously defined genomic_align_block object")
          if ($self->{'genomic_align_block'} and
              $self->{'genomic_align_block'}->dbID ne $self->{'genomic_align_block_id'});
    }
  } elsif (!($self->{'genomic_align_block_id'})) {
    # Try to get the ID from other sources...
    if (defined($self->{'genomic_align_block'})) {
	if ($self->{genomic_align_block}->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")and defined($self->{'genomic_align_block'}->dbID)) {
	    # ...from the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock object
	    $self->{'genomic_align_block_id'} = $self->{'genomic_align_block'}->dbID;
	}
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
  Status     : Stable

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
  Status     : Stable

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
  Status     : Stable

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
  Status     : Stable

=cut

sub length {
  my $self = shift;

  if ($self->{aligned_sequence}) {
    return length($self->{aligned_sequence});
  } elsif ($self->{cigar_line}) {
    my $length = 0;
    my $cigar_arrayref = $self->get_cigar_arrayref;
    foreach my $cigar_element (@$cigar_arrayref ) {
      my $cigar_type = substr($cigar_element, -1, 1);
      my $cigar_count = substr($cigar_element, 0 , -1);
      $cigar_count = 1 if ($cigar_count eq "");

      $length += $cigar_count unless ($cigar_type eq "I");
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
  Status     : Stable

=cut

sub cigar_line {
  my ($self, $arg) = @_;

  my $debug = 0;

  if (defined($arg)) {
    print "setting new cigar...\n" if ( $debug >= 1 );
    if ($arg) {
      $self->{'cigar_line'} = $arg;
    } else {
      $self->{'cigar_line'} = undef;
    }
    $self->{'cigar_arrayref'} = undef;

  } elsif (!defined($self->{'cigar_line'}) || $self->{'cigar_line'} eq '') {
    # Try to get the cigar_line from other sources...
      if ( $debug >= 1 ) {
    	  print "trying to find cigar from elsewhere.......\n";
    	  my $is_aln_seq = defined($self->{'aligned_sequence'}) ? "defined" : "undef";
    	  print "aligned_sequence is $is_aln_seq .......\n";
      }
    if (defined($self->{'aligned_sequence'})) {
        # ...from the aligned sequence
	      print "from aligned_seq??\n" if ( $debug >= 2 );
        my $cigar_line = _get_cigar_line_from_aligned_sequence($self->{'aligned_sequence'});
        $self->cigar_line($cigar_line);
    
    } elsif (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
        # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
	   print "Trying to find cigar line in DB!!!!!!\n" if ( $debug >= 2 );
	   $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->cigar_line".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  print "returning cigar: " . $self->{'cigar_line'} . "\n" if ( $debug >= 2 );

  return $self->{'cigar_line'};
}


=head2 get_cigar_arrayref

  Arg [1]    : -None-
  Example    : @cigar_array = @{$genomic_align->get_cigar_arrayref};
  Description: get for attribute cigar_line, but in a pre-computed array
               format. Each element is a cigar element like "143M", "D" or
               "3I".
               Please refer to cigar_line() method for more information on
               the cigar_line. Also note that you may want to make a copy
               of the array if you want to modify it.
  Returntype : listref of Strings
  Exceptions : none
  Caller     : object->methodname
  Status     : Stable

=cut


sub get_cigar_arrayref {
  my ($self) = @_;

  if (!$self->{'cigar_arrayref'}) {
    $self->{'cigar_arrayref'} = [ $self->cigar_line =~ /(\d*[GMDXI])/g ];
  }

  return $self->{'cigar_arrayref'};
}




=head2 visible

  Arg [1]    : int $visible
  Example    : $visible = $genomic_align->visible
  Example    : $genomic_align->visible(1);
  Description: get/set for attribute visible. If no argument is given, visible
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : int
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname
  Status     : Stable

=cut

sub visible {
  my ($self, $visible) = @_;

  if (defined($visible)) {
    $self->{'visible'} = $visible;

  } elsif (!defined($self->{'visible'})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->visible".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'visible'};
}

=head2 node_id

  Arg [1]    : [optional] int $node_id
  Example    : $node_id = $genomic_align->node_id;
  Example    : $genomic_align->node_id(5530000000004);
  Description: get/set for the node_id.This links the Bio::EnsEMBL::Compara::GenomicAlign to the 
               Bio::EnsEMBL::Compara::GenomicAlignTree. The default value is NULL. If no argument is given, the node_id
               is not defined but both the dbID and the adaptor are, it tries to
               fetch and set all the direct attributes from the database using the
               dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : int
  Exceptions : none
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname
  Status     : At risk 

=cut

sub node_id {
  my ($self, $node_id) = @_;

  if (defined($node_id)) {
    $self->{'node_id'} = $node_id;
  } elsif (!defined($self->{'node_id'})) {
    # it may be a restricted genomic_align object with no dbID or node_id
    if (defined($self->{'adaptor'}) and defined($self->{'_original_dbID'}) and (!defined($self->{'dbID'}))){
     $self->{'_original_node_id'} = $self->adaptor->fetch_by_dbID($self->{'_original_dbID'})->node_id;
    } elsif (defined($self->{'dbID'}) and defined($self->{'adaptor'})) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }
  return $self->{'node_id'} || $self->{'_original_node_id'};
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
  Status     : Stable

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
    #cigar_line is not necessarily defined so call the method rather than $self->{'cigar_line'} directly
    if ($self->{'aligned_sequence'} and $self->cigar_line !~ /I/) {
      # ...from the aligned sequence
      $self->{'original_sequence'} = $self->{'aligned_sequence'};
      $self->{'original_sequence'} =~ s/\-//g;

    } elsif (!defined($self->{'original_sequence'}) and defined($self->dnafrag)
          and defined($self->dnafrag_start) and defined($self->dnafrag_end)
          and defined($self->dnafrag_strand)) {
      # ...from the dnafrag object. Uses dnafrag, dnafrag_start and dnafrag_methods instead of the attibutes
      # in the <if> clause because the attributes can be retrieved from other sources if they have not been
      # already defined.
      $self->dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {
          if ($self->dnafrag->slice) {
              $self->{'original_sequence'} = $self->dnafrag->slice->subseq(
                  $self->dnafrag_start,
                  $self->dnafrag_end,
                  $self->dnafrag_strand
              );
          } else {
              warning("Could not get a Slice from this dnafrag");
          }
      } );
    } else {
      warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->original_sequence".
          " You either have to specify more information (see perldoc for".
          " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
    }
  }

  return $self->{'original_sequence'};
}

=head2 original_dbID

  Args       : none
  Example    : my $original_dbID = $genomic_align->original_dbID
  Description: getter/setter of original_dbID attribute. When a GenomicAlign is restricted, this attribute is set to the dbID of the original GenomicAlign object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub original_dbID {
  my ($self, $original_dbID) = @_;

  if (defined $original_dbID) {
    $self->{_original_dbID} = $original_dbID;
  }

  return $self->{_original_dbID};
}

=head2 _get_cigar_line_from_aligned_sequence

  Arg [1]    : string $aligned_sequence
  Example    : $cigar_line = _get_cigar_line_from_aligned_sequence("CGT-AACTGATG--TTA")
  Description: get cigar line from gapped sequence
  Returntype : string $cigar_line
  Exceptions : 
  Caller     : methodname
  Status     : Stable

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
  Status     : Stable

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
  Returntype : string $fake_aligned_sequence or undef if no $cigar_line
  Exceptions : 
  Caller     : methodname
  Status     : Stable

=cut

sub _get_fake_aligned_sequence_from_cigar_line {
  my ($cigar_line, $fix_seq) = @_;
  my $fake_aligned_sequence = "";

  return undef if (!$cigar_line);

  my $seq_pos = 0;

  my @cig = ( $cigar_line =~ /(\d*[GMDXI])/g );
  #for my $cigElem ( @cig ) {
  #    my $cigType = substr( $cigElem, -1, 1 );
  #    my $cigCount = substr( $cigElem, 0 ,-1 );
  while ($cigar_line =~ /(\d*)([GMDXI])/g) {
    my $cigCount = $1;
    my $cigType = $2;
    $cigCount = 1 if ($cigCount eq "");

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


sub _print {    ## DEPRECATED
  my ($self, $FILEH) = @_;

  deprecate('$genomic_align->_print() is deprecated and will be removed in e88. Use $genomic_align->toString() instead.');

  my $verbose = verbose;
  verbose(0);
  
  $FILEH ||= \*STDOUT;

#   print $FILEH
# "Bio::EnsEMBL::Compara::GenomicAlign object ($self)
#   dbID = ".($self->dbID or "-undef-")."
#   adaptor = ".($self->adaptor or "-undef-")."
#   genomic_align_block = ".($self->genomic_align_block or "-undef-")."
#   genomic_align_block_id = ".($self->genomic_align_block_id or "-undef-")."
#   method_link_species_set = ".($self->method_link_species_set or "-undef-")."
#   method_link_species_set_id = ".($self->method_link_species_set_id or "-undef-")."
#   dnafrag = ".($self->dnafrag or "-undef-")."
#   dnafrag_id = ".($self->dnafrag_id or "-undef-")."
#   dnafrag_start = ".($self->dnafrag_start or "-undef-")."
#   dnafrag_end = ".($self->dnafrag_end or "-undef-")."
#   dnafrag_strand = ".($self->dnafrag_strand or "-undef-")."
#   cigar_line = ".($self->cigar_line or "-undef-")."
#   visible = ".($self->visible or "-undef-")."
#   original_sequence = ".($self->original_sequence or "-undef-")."
#   aligned_sequence = ".($self->aligned_sequence or "-undef-")."
  
# ";
    print $FILEH
"Bio::EnsEMBL::Compara::GenomicAlign object ($self)
  dbID = ".($self->dbID or "-undef-")."
  adaptor = ".($self->adaptor or "-undef-")."
  genomic_align_block = ".($self->genomic_align_block or "-undef-")."
  genomic_align_block_id = ".($self->genomic_align_block_id or "-undef-")."
  method_link_species_set = ".($self->method_link_species_set or "-undef-")."
  method_link_species_set_id = ".($self->method_link_species_set_id or "-undef-")."
  dnafrag_start = ".($self->dnafrag_start or "-undef-")."
  dnafrag_end = ".($self->dnafrag_end or "-undef-")."
  dnafrag_strand = ".($self->dnafrag_strand or "-undef-")."
  dnafrag_name = ".($self->dnafrag->name)."
  genome_db_name = ".($self->dnafrag->genome_db->name)."
  cigar_line = ".($self->cigar_line or "-undef-")."
  visible = ".($self->visible or "-undef-")."
  original_sequence = ".($self->original_sequence or "-undef-")."
  aligned_sequence = ".($self->aligned_sequence or "-undef-")."
  
";

  verbose($verbose);

}


=head2 toString

  Example    : print $genomic_align->toString();
  Description: used for debugging, returns a string with the key descriptive
               elements of this alignment line
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub toString {
    my $self = shift;
    # my $str = 'GenomicAlign';
    # if ($self->original_dbID) {
    #     $str .= sprintf(' restricted from dbID=%s (block_id=%s)', $self->original_dbID, $self->genomic_align_block->original_dbID);
    # } else {
    #     $str .= sprintf(' dbID=%s (block_id=%d)', $self->dbID, $self->genomic_align_block_id);
    # }
    # $str .= sprintf(' (%s)', $self->method_link_species_set->name) if $self->method_link_species_set;
    # $str .= sprintf(' %s %s:%d-%d%s', $self->dnafrag->genome_db->name, $self->dnafrag->name, $self->dnafrag_start, $self->dnafrag_end, ($self->dnafrag_strand < 0 ? '(-1)' : '')) if $self->dnafrag_id;
    # return $str;

    my $str = "Bio::EnsEMBL::Compara::GenomicAlign object ($self)
        dbID = ".($self->dbID or "-undef-")."
        adaptor = ".($self->adaptor or "-undef-")."
        genomic_align_block = ".($self->genomic_align_block or "-undef-")."
        genomic_align_block_id = ".($self->genomic_align_block_id or "-undef-")."
        method_link_species_set = ".($self->method_link_species_set or "-undef-")."
        method_link_species_set_id = ".($self->method_link_species_set_id or "-undef-")."
        dnafrag_start = ".($self->dnafrag_start or "-undef-")."
        dnafrag_end = ".($self->dnafrag_end or "-undef-")."
        dnafrag_strand = ".($self->dnafrag_strand or "-undef-")."
        dnafrag_name = ".($self->dnafrag->name)."
        genome_db_name = ".($self->dnafrag->genome_db->name)."
        cigar_line = ".($self->cigar_line or "-undef-")."
        visible = ".($self->visible or "-undef-")."
        original_sequence = ".($self->original_sequence or "-undef-")."
        aligned_sequence = ".($self->aligned_sequence or "-undef-")."\n";
    return $str;
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
  Status     : Stable

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
  Status     : Stable

=cut

sub reverse_complement {
  my ($self) = @_;

  # reverse strand
  #$self->dnafrag_strand($self->dnafrag_strand * -1);
  $self->dnafrag_strand($self->{'dnafrag_strand'} * -1);

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
  my $cigar_line = $self->{'cigar_line'};
  
  #$cigar_line = join("", reverse grep {$_} split(/(\d*[GDMIX])/, $cigar_line));
  $cigar_line = join("", reverse ($cigar_line=~(/(\d*[GDMIX])/g)));
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
               The coordinates of the "alignment" starts with the start
               position of the GenomicAlignBlock if available or 1 otherwise.
               With the $cache argument you can decide whether you want to cache the
               result or not. Result is *not* cached by default.
  Returntype : Bio::EnsEMBL::Mapper object
  Exceptions : throw if no cigar_line can be found
  Status     : Stable

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
    if ($mode eq "condensed") {

      $mapper = Bio::EnsEMBL::Mapper->new("sequence", "alignment");

      my $rel_strand = $self->dnafrag_strand; # This call ensures all direct attribs have been fetched
      my $ref_cigar_line = $self->genomic_align_block->reference_genomic_align->cigar_line;

      my $aln_pos = (eval{$self->genomic_align_block->start} or 1);

      #if the reference genomic_align, I only need a simple 1 to 1 mapping
      if ($self eq $self->genomic_align_block->reference_genomic_align) {
	  $mapper->add_map_coordinates(
              'sequence',
              $self->{'dnafrag_start'},
              $self->{'dnafrag_end'},
              $self->{'dnafrag_strand'},
              'alignment',
	      $self->genomic_align_block->start,
	      $self->genomic_align_block->end,
          );
	  return $mapper if (!$cache);

	  $self->{$mode.'_mapper'} = $mapper;
	  return $self->{$mode.'_mapper'};
      }

      my $aln_seq_pos = 0;
      my $seq_pos = 0;

      my $insertions = 0;
      my $target_cigar_pieces;
#      @$target_cigar_pieces = $self->{'cigar_line'} =~ /(\d*[GMDXI])/g;
      $target_cigar_pieces = $self->get_cigar_arrayref;
      my $ref_cigar_pieces = $self->genomic_align_block->reference_genomic_align->get_cigar_arrayref();
      my $i = 0;
      my $j = 0;
      my ($ref_num, $ref_type) = $ref_cigar_pieces->[$i] =~ /(\d*)([GMDXI])/;
      $ref_num = 1 if (!defined($ref_num) or $ref_num eq "");
      my ($target_num, $target_type) = $target_cigar_pieces->[$j] =~ /(\d*)([GMDXI])/;
      $target_num = 1 if (!defined($target_num) or $target_num eq "");

      while ($i < @$ref_cigar_pieces and $j<@$target_cigar_pieces) {
	  while ($ref_type eq "I") {
	      $aln_pos += $ref_num;
	      $i++;
	      last if ($i >= @$ref_cigar_pieces);
	      ($ref_num, $ref_type) = $ref_cigar_pieces->[$i] =~ /(\d*)([GMDXI])/;
	      $ref_num = 1 if (!defined($ref_num) or $ref_num eq "");
	  }
	  while ($target_type eq "I") {
	      $seq_pos += $target_num;
	      $j++;
	      last if ($j >= @$target_cigar_pieces);
	      ($target_num, $target_type) = $target_cigar_pieces->[$j] =~ /(\d*)([GMDXI])/;
	      $target_num = 1 if (!defined($target_num) or $target_num eq "");
	  }

        my $length;

	if ($ref_num == $target_num) {
	  $length = $ref_num;
	} elsif ($ref_num > $target_num) {
	  $length = $target_num;
	} elsif ($ref_num < $target_num) {
	  $length = $ref_num;
        }
	my $this_piece_of_cigar_line = $length.$target_type;

	if ($ref_type eq "M") {
          my $this_mapper;
          if ($rel_strand == 1) {
            _add_cigar_line_to_Mapper($this_piece_of_cigar_line, $aln_pos,
                $seq_pos + $self->dnafrag_start, 1, $mapper);
          } else {
            _add_cigar_line_to_Mapper($this_piece_of_cigar_line, $aln_pos, $self->dnafrag_end - $seq_pos, -1, $mapper);
          }
	  $aln_pos += $length;
        }
	my $gaps = 0;
	if ($target_type eq "D" || $target_type eq "X") {
	    $gaps += $length;
	}

        $seq_pos -= $gaps;
	$seq_pos += $length;

	if ($ref_num == $target_num) {
	  $i++;
	  $j++;
	  last if ($i >= @$ref_cigar_pieces);
	  last if ($j >= @$target_cigar_pieces);
	  ($ref_num, $ref_type) = $ref_cigar_pieces->[$i] =~ /(\d*)([GMDXI])/;
	  $ref_num = 1 if (!defined($ref_num) or $ref_num eq "");
	  ($target_num, $target_type) = $target_cigar_pieces->[$j] =~ /(\d*)([GMDXI])/;
	  $target_num = 1 if (!defined($target_num) or $target_num eq "");
	} elsif ($ref_num > $target_num) {
	  $j++;
	  $ref_num -= $target_num;
	  last if ($j >= @$target_cigar_pieces);
	  ($target_num, $target_type) = $target_cigar_pieces->[$j] =~ /(\d*)([GMDXI])/;
	  $target_num = 1 if (!defined($target_num) or $target_num eq "");
	} elsif ($ref_num < $target_num) {
	  $i++;
	  $target_num -= $ref_num;
	  last if ($i >= @$ref_cigar_pieces);
	  ($ref_num, $ref_type) = $ref_cigar_pieces->[$i] =~ /(\d*)([GMDXI])/;
	  $ref_num = 1 if (!defined($ref_num) or $ref_num eq "");
        }
      }
    } else {
      my $cigar_line = $self->cigar_line;
      if (!$cigar_line) {
        $self->_print;
        throw("[$self] has no cigar_line and cannot be retrieved by any means");
      }
      my $alignment_position = (eval{$self->genomic_align_block->start} or 1);
      my $sequence_position = $self->dnafrag_start;
      my $rel_strand = $self->dnafrag_strand;
      if ($rel_strand == 1) {
        $sequence_position = $self->dnafrag_start;
      } else {
        $sequence_position = $self->dnafrag_end;
      }
      $mapper = _get_Mapper_from_cigar_arrayref($self->get_cigar_arrayref, $alignment_position, $sequence_position, $rel_strand);
    }

    return $mapper if (!$cache);

    $self->{$mode.'_mapper'} = $mapper;
  }

  return $self->{$mode.'_mapper'};
}


=head2 _get_Mapper_from_cigar_arrayref

  Arg[1]     : $cigar_arrayref
  Arg[2]     : $alignment_position
  Arg[3]     : $sequence_position
  Arg[4]     : $relative_strand
  Example    : $this_mapper = _get_Mapper_from_cigar_arrayref($cigar_arrayref, 
                $aln_pos, $seq_pos, 1);
  Description: creates a new Bio::EnsEMBL::Mapper object for mapping between
               sequence and alignment coordinate systems using the cigar_line
               decomposed in an arrayref (see get_cigar_arrayref() method)
               and starting from the $alignment_position and sequence_position.
  Returntype : Bio::EnsEMBL::Mapper object
  Exceptions : None
  Status     : Stable

=cut

sub _get_Mapper_from_cigar_arrayref {
  my ($cigar_arrayref, $alignment_position, $sequence_position, $rel_strand) = @_;

  my $mapper = Bio::EnsEMBL::Mapper->new("sequence", "alignment");

  if ($rel_strand == 1) {
    foreach my $cigar_element (@$cigar_arrayref) {
      my $cigar_type = substr($cigar_element, -1, 1);
      my $cigar_num = substr($cigar_element, 0 , -1);
      $cigar_num = 1 if ($cigar_num eq "");
      next if ($cigar_num < 1);
  
      if( $cigar_type eq "M" ) {
         $mapper->add_map_coordinates(
                "sequence", #$self->dbID,
                $sequence_position,
                $sequence_position + $cigar_num - 1,
                $rel_strand,
                "alignment", #$self->genomic_align_block->dbID,
                $alignment_position,
                $alignment_position + $cigar_num - 1
            );
        $sequence_position += $cigar_num;
        $alignment_position += $cigar_num;
      } elsif( $cigar_type eq "I") {
	#add to sequence_position but not alignment_position
	$sequence_position += $cigar_num;
      } elsif( $cigar_type eq "G" || $cigar_type eq "D" || $cigar_type eq "X") {
        $alignment_position += $cigar_num;
      }
    }
  } else {
    foreach my $cigar_element (@$cigar_arrayref) {
      my $cigar_type = substr($cigar_element, -1, 1);
      my $cigar_num = substr($cigar_element, 0 , -1);
      $cigar_num = 1 if ($cigar_num eq "");
      next if ($cigar_num < 1);
  
      if( $cigar_type eq "M" ) {
        $mapper->add_map_coordinates(
                "sequence", #$self->dbID,
                $sequence_position - $cigar_num + 1,
                $sequence_position,
                $rel_strand,
                "alignment", #$self->genomic_align_block->dbID,
                $alignment_position,
                $alignment_position + $cigar_num - 1
            );
        $sequence_position -= $cigar_num;
        $alignment_position += $cigar_num;
      } elsif( $cigar_type eq "I") {
	#add to sequence_position but not alignment_position
	$sequence_position -= $cigar_num;
      } elsif( $cigar_type eq "G" || $cigar_type eq "D" || $cigar_type eq "X") {
        $alignment_position += $cigar_num;
      }
    }
  }

  return $mapper;
}

sub _add_cigar_line_to_Mapper {
  my ($cigar_line, $alignment_position, $sequence_position, $rel_strand, $mapper) = @_;

  my @cigar_pieces = ($cigar_line =~ /(\d*[GMDXI])/g);
  if ($rel_strand == 1) {
    foreach my $cigar_piece (@cigar_pieces) {
      my $cigar_type = substr($cigar_piece, -1, 1 );
      my $cigar_num = substr($cigar_piece, 0 ,-1 );
      $cigar_num = 1 unless ($cigar_num =~ /^\d+$/);
      next if ($cigar_num < 1);
  
      if( $cigar_type eq "M" ) {
        $mapper->add_map_coordinates(
                "sequence", #$self->dbID,
                $sequence_position,
                $sequence_position + $cigar_num - 1,
                $rel_strand,
                "alignment", #$self->genomic_align_block->dbID,
                $alignment_position,
                $alignment_position + $cigar_num - 1
            );
        $sequence_position += $cigar_num;
        $alignment_position += $cigar_num;
      } elsif( $cigar_type eq "I") {
	#add to sequence_position but not alignment_position
	$sequence_position += $cigar_num;
      } elsif( $cigar_type eq "G" || $cigar_type eq "D" || $cigar_type eq "X") {
        $alignment_position += $cigar_num;
      }
    }
  } else {
    foreach my $cigar_piece (@cigar_pieces) {
      my $cigar_type = substr($cigar_piece, -1, 1 );
      my $cigar_num = substr($cigar_piece, 0 ,-1 );
      $cigar_num = 1 unless ($cigar_num =~ /^\d+$/);
      next if ($cigar_num < 1);
  
      if( $cigar_type eq "M" ) {
        $mapper->add_map_coordinates(
                "sequence", #$self->dbID,
                $sequence_position - $cigar_num + 1,
                $sequence_position,
                $rel_strand,
                "alignment", #$self->genomic_align_block->dbID,
                $alignment_position,
                $alignment_position + $cigar_num - 1
            );
        $sequence_position -= $cigar_num;
        $alignment_position += $cigar_num;
      } elsif( $cigar_type eq "I") {
	#add to sequence_position but not alignment_position
	$sequence_position -= $cigar_num;
      } elsif( $cigar_type eq "G" || $cigar_type eq "D" || $cigar_type eq "X") {
        $alignment_position += $cigar_num;
      }
    }
  }

  return $mapper;
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
  my ($self, $start, $end, $aligned_seq_length) = @_;
  throw("Wrong arguments") if (!$start or !$end);

  my $restricted_genomic_align = $self->copy();
  delete($restricted_genomic_align->{dbID});
  delete($restricted_genomic_align->{genomic_align_block_id});
  delete($restricted_genomic_align->{original_sequence});
  delete($restricted_genomic_align->{aligned_sequence});
  delete($restricted_genomic_align->{cigar_line});
  delete($restricted_genomic_align->{cigar_arrayref});
  $restricted_genomic_align->original_dbID($self->dbID or $self->original_dbID);

  # Need to calculate the original aligned sequence length myself
  if (!$aligned_seq_length) {
    my $cigar_arrayref = $self->get_cigar_arrayref;
    foreach my $cigar_element (@$cigar_arrayref) {
      my $cigar_type = substr($cigar_element, -1, 1);
      my $cigar_num = substr($cigar_element, 0 , -1);
      $cigar_num = 1 if ($cigar_num eq "");
      next if ($cigar_num < 1);

      $aligned_seq_length += $cigar_num unless ($cigar_type eq "I");
    }
  }

  my $final_aligned_length = $end - $start + 1;
  my $number_of_columns_to_trim_from_the_start = $start - 1;
  my $number_of_columns_to_trim_from_the_end = $aligned_seq_length - $end;

  #print "removing $number_of_columns_to_trim_from_the_start bp from start, $number_of_columns_to_trim_from_the_end from end<br>";

  my $cigar_arrayref = [@{$self->get_cigar_arrayref}]; # Make a new copy

  ## Trim start of cigar_line if needed
  if ($number_of_columns_to_trim_from_the_start >= 0) {
    my $counter_of_trimmed_columns_from_the_start = 0;
    my $counter_of_trimmed_base_pairs = 0; # num of bp we trim (from the start)
    ## Loop through the cigar pieces
    while (my $cigar_element = shift(@$cigar_arrayref)) {
      my $cigar_type = substr($cigar_element, -1, 1);
      my $cigar_num = substr($cigar_element, 0 , -1);
      $cigar_num = 1 if ($cigar_num eq "");
      next if ($cigar_num < 1);

      # Insertions are not part of the alignment, don't count them
      if ($cigar_type ne "I") {
        $counter_of_trimmed_columns_from_the_start += $cigar_num;
      }

      # Matches and insertions are actual base pairs in the sequence
      if ($cigar_type eq "M" || $cigar_type eq "I") {
        $counter_of_trimmed_base_pairs += $cigar_num;
      }

      # If this cigar piece is too long and we overshoot the number of columns we want to trim,
      # we substitute this cigar piece by a shorter one
      if ($counter_of_trimmed_columns_from_the_start >= $number_of_columns_to_trim_from_the_start) {
        my $new_cigar_piece;
        # length of the new cigar piece
        my $length = $counter_of_trimmed_columns_from_the_start - $number_of_columns_to_trim_from_the_start;
        if ($length > 1) {
          $new_cigar_piece = $length.$cigar_type;
        } elsif ($length == 1) {
          $new_cigar_piece = $cigar_type;
        }
        unshift(@$cigar_arrayref, $new_cigar_piece) if ($length > 0);
        if ($cigar_type eq "M") {
          $counter_of_trimmed_base_pairs -= $length;
        }

        ## We don't want to start with an insertion. Trim it!
        while (@$cigar_arrayref and $cigar_arrayref->[0] =~ /I/) {
          my $cigar_type = substr($cigar_arrayref->[0], -1, 1);
          my $cigar_num = substr($cigar_arrayref->[0], 0 , -1);
          $cigar_num = 1 if ($cigar_num eq "");

          $counter_of_trimmed_base_pairs += $cigar_num;
          shift(@$cigar_arrayref);
        }
        last;
      }
    }
    if ($self->{dnafrag_strand} == 1) {
      $restricted_genomic_align->{dnafrag_start} = ($self->{dnafrag_start} + $counter_of_trimmed_base_pairs);
    } else {
      $restricted_genomic_align->{dnafrag_end} = ($self->{dnafrag_end} - $counter_of_trimmed_base_pairs);
    }
  }

  ## Trim end of cigar_line if needed
  if ($number_of_columns_to_trim_from_the_end >= 0) {
    my $counter_of_trimmed_columns_from_the_end = 0;
    my $counter_of_trimmed_base_pairs = 0; # num of bp we trim (from the start)
    ## Loop through the cigar pieces
    while (my $cigar_element = pop(@$cigar_arrayref)) {
      my $cigar_type = substr( $cigar_element, -1, 1);
      my $cigar_num = substr( $cigar_element, 0 , -1);
      $cigar_num = 1 if ($cigar_num eq "");
      next if ($cigar_num < 1);

      # Insertions are not part of the alignment, don't count them
      if ($cigar_type ne "I") {
        $counter_of_trimmed_columns_from_the_end += $cigar_num;
      }

      # Matches and insertions are actual base pairs in the sequence
      if ($cigar_type eq "M" || $cigar_type eq "I") {
        $counter_of_trimmed_base_pairs += $cigar_num;
      }
      # If this cigar piece is too long and we overshoot the number of columns we want to trim,
      # we substitute this cigar piece by a shorter one
      if ($counter_of_trimmed_columns_from_the_end >= $number_of_columns_to_trim_from_the_end) {
        my $new_cigar_piece;
        # length of the new cigar piece
        my $length = $counter_of_trimmed_columns_from_the_end - $number_of_columns_to_trim_from_the_end;
        if ($length > 1) {
          $new_cigar_piece = $length.$cigar_type;
        } elsif ($length == 1) {
          $new_cigar_piece = $cigar_type;
        }
        push(@$cigar_arrayref, $new_cigar_piece) if ($length > 0);
        if ($cigar_type eq "M") {
          $counter_of_trimmed_base_pairs -= $length;
        }

        ## We don't want to end with an insertion. Trim it!
        while (@$cigar_arrayref and $cigar_arrayref->[-1] =~ "I") {
          my $cigar_type = substr($cigar_arrayref->[-1], -1, 1);
          my $cigar_num = substr($cigar_arrayref->[-1], 0 , -1);
          $cigar_num = 1 if ($cigar_num eq "");
          $counter_of_trimmed_base_pairs += $cigar_num;
          pop(@$cigar_arrayref);
        }
        last;
      }
    }
    if ($self->{dnafrag_strand} == 1) {
      $restricted_genomic_align->{dnafrag_end} = ($restricted_genomic_align->{dnafrag_end} - $counter_of_trimmed_base_pairs);
    } else {
      $restricted_genomic_align->{dnafrag_start} = ($restricted_genomic_align->{dnafrag_start} + $counter_of_trimmed_base_pairs);
    }
  }

  ## Save genomic_align's cigar_line
  my $l = ($end-$start) > 0 ? ($end-$start) : ($start-$end);
  #print "Adding new aligned_sequence!! $l bp from $start-1 <br>";
  $restricted_genomic_align->{aligned_sequence} = substr( $self->{aligned_sequence}, $start-1, $l+1 ) if $self->{aligned_sequence};
  $restricted_genomic_align->{cigar_line} = join("", @$cigar_arrayref);
  $restricted_genomic_align->{cigar_arrayref} = $cigar_arrayref;

  #print Dumper {'restricted_genomic_align::GenomicAlign::1867' => $restricted_genomic_align};

  return $restricted_genomic_align;
}

1;
