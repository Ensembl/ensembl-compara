#
# Ensembl module for Bio::EnsEMBL::Compara::ConstrainedElement
#
# Cared for by Stephen Fitzgerald <ensembl-compara@ebi.ac.uk>
#
# Copyright EMBL-ebi
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::ConstrainedElement - constrained element data produced by Gerp

=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Compara::ConstrainedElement;
  
  my $constrained_element = new Bio::EnsEMBL::Compara::ConstrainedElement(
          -adaptor => $constrained_element_adaptor,
          -method_link_species_set_id => $method_link_species_set_id,
	  -reference_dnafrag_id => $dnafrag_id,
          -score => 56.2,
          -p_value => '1.203e-6',
          -alignment_segments => [ [$dnafrag1_id, $start, $end, $genome_db_id, $dnafrag1_name ], [$dnafrag2_id, ... ], ... ],
	  -taxonomic_level => "eutherian mammals",
      );

GET / SET VALUES
  $constrained_element->adaptor($constrained_element_adaptor);
  $constrained_element->dbID($constrained_element_id);
  $constrained_element->method_link_species_set_id($method_link_species_set_id);
  $constrained_element->score(56.2);
  $constrained_element->p_value('5.62e-9');
  $constrained_element->taxonomic_level("eutherian mammals");
  $constrained_element->alignment_segments([ [$dnafrag_id, $start, $end, $genome_db_id, $dnafrag_name ], ... ]);
  $constrained_element->slice($slice);
  $constrained_element->start($constrained_element_start - $slice_start + 1);
  $constrained_element->end($constrained_element_end - $slice_start + 1);
  $constrained_element->reference_dnafrag_id($dnafrag_id);

=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to constrained_element.constrained_element_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor object to access DB

=item method_link_species_set_id

corresponds to method_link_species_set.method_link_species_set_id (external ref.)

=item score

corresponds to constrained_element.score

=item p_value

corresponds to constrained_element.p_value

=item taxonomic_level 

corresponds to constrained_element.taxonoic_level

=item slice

corresponds to a Bio::EnsEMBL::Slice 

=item start

corresponds to a constrained_element.dnafrag_start (in slice coordinates)

=item end

corresponds to a constrained_element.dnafrag_end (in slice coordinates)

=item $alignment_segments

listref of listrefs (each of which contain 5 strings (dnafrag.dnafrag_id, constrained_element.dnafrag_start, 
constrained_element.dnafrag_end, genome_db.genome_db_id, dnafrag.dnafrag_name) 
   [ [ $dnafrag_id, $start, $end, $genome_db_id, $dnafrag_name ], .. ]
Each inner listref contains information about one of the species sequences which make up the constarained 
element block from the alignment. 

=back

=head1 AUTHOR

Stephen Fitzgerald (ensembl-compara@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2009. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::ConstrainedElement;
use strict;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info deprecate verbose);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::SimpleAlign;
use Data::Dumper;


=head2 new (CONSTRUCTOR)

  Arg [-dbID] : int $dbID (the database ID for 
		the constrained element block for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-METHOD_LINK_SPECIES_SET_ID]
              : int $mlss_id (the database internal ID for the $mlss)
  Arg [-SCORE]
              : float $score (the score of this alignment)
  Arg [-ALIGNMENT_SEGMENTS]
              : (opt.) listref of listrefs which each contain 5 values 
		[ [ $dnafrag_id, $dnafrag_start, $dnafrag_end, $genome_db_id, $dnafrag_name ], ... ]
		corresponding to the all the species in the constrained element block.
  Arg [-P_VALUE]
              : (opt.) string $p_value (the p_value of this constrained element)
  Arg [-TAXONOMIC_LEVEL]
              : (opt.) string $taxonomic_level (the taxonomic level of the alignments from which the 
		constrained element was derived)
  Arg [-SLICE]
	     : (opt.) Bio::EnsEMBL::Slice object
  Arg [-START]
	     : (opt.) int ($dnafrag_start - Bio::EnsEMBL::Slice->start + 1).
  Arg [-END]
	     : (opt.) int ($dnafrag_end - Bio::EnsEMBL::Slice->start + 1).
  Arg [-REFERENCE_DNAFRAG_ID]
	     : (opt.) int $dnafrag_id of the slice or dnafrag 

  Example    : my $constrained_element =
                   new Bio::EnsEMBL::Compara::ConstrainedElement(
		       -dbID => $constrained_element_id,
                       -adaptor => $adaptor,
                       -method_link_species_set_id => $method_link_species_set_id,
                       -score => 28.2,
                       -alignment_segments => [ [ $dnafrag_id, $dnafrag_start, $dnafrag_end, $genome_db_id, $dnafrag_name ], .. ], 
									#danfarg_[start|end|id] from constrained_element table
                       -p_value => '5.023e-6',
                       -taxonomic_level => "eutherian mammals",
		       -slice => $slice_obj,
		       -start => ( $dnafrag_start - $slice_obj->start + 1),
		       -end => ( $dnafrag_end - $slice_obj->start + 1),
		       -reference_dnafrag_id => $dnafrag_id,
                   );
  Description: Creates a new ConstrainedElement object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::ConstrainedElement
  Exceptions : none
  Caller     : general

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = {};
  bless $self,$class;
    
  my ($adaptor, $dbID, $alignment_segments, 
	$method_link_species_set_id, $score, $p_value, 
	$taxonomic_level, $slice, $start, $end, $reference_dnafrag_id) = 
    rearrange([qw(
        ADAPTOR DBID ALIGNMENT_SEGMENTS 
  METHOD_LINK_SPECIES_SET_ID SCORE P_VALUE TAXONOMIC_LEVEL
  SLICE START END REFERENCE_DNAFRAG_ID 
	)],
            @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->dbID($dbID) 
	if (defined ($dbID));
  $self->method_link_species_set_id($method_link_species_set_id)
      if (defined ($method_link_species_set_id));
  $self->alignment_segments($alignment_segments) 
      if (defined ($alignment_segments));
  $self->score($score) if (defined ($score));
  $self->p_value($p_value) if (defined ($p_value));
  $self->taxonomic_level($taxonomic_level)
      if (defined($taxonomic_level));
  $self->slice($slice) if (defined ($slice));
  $self->start($start) if (defined ($start));
  $self->end($end) if (defined ($end));
  $self->reference_dnafrag_id($reference_dnafrag_id)
      if (defined($reference_dnafrag_id));
  return $self;
}

sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}

=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor
  Example    : my $cons_ele_adaptor = $constrained_element->adaptor();
  Example    : $cons_ele_adaptor->adaptor($cons_ele_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor object
  Exceptions : thrown if $adaptor is not a
               Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor object
  Caller     : general

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
    throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor object")
        unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 dbID

  Arg [1]    : integer $dbID
  Example    : my $dbID = $constrained_element->dbID();
  Example    : $constrained_element->dbID(2);
  Description: Getter/Setter for the attribute dbID 
  Returntype : integer
  Exceptions : returns undef if no ref.dbID
  Caller     : general

=cut

sub dbID {
  my ($self, $dbID) = @_;

  if (defined($dbID)) {
    $self->{'dbID'} = $dbID;
  }

  return $self->{'dbID'};
}


=head2 p_value 

  Arg [1]    : float $p_value
  Example    : my $p_value = $constrained_element->p_value();
  Example    : $constrained_element->p_value('5.35242e-105');
  Description: Getter/Setter for the attribute p_value
  Returntype : float 
  Exceptions : returns undef if no ref.p_value
  Caller     : general

=cut

sub p_value {
  my ($self, $p_value) = @_;

  if (defined($p_value)) {
    $self->{'p_value'} = $p_value;
  }

  return $self->{'p_value'};
}

=head2 taxonomic_level 

  Arg [1]    : string $taxonomic_level
  Example    : my $taxonomic_level = $constrained_element->taxonomic_level();
  Example    : $constrained_element->taxonomic_level("eutherian mammals");
  Description: Getter/Setter for the attribute taxonomic_level 
  Returntype : string
  Exceptions : returns undef if no ref.taxonomic_level
  Caller     : general

=cut

sub taxonomic_level {
  my ($self, $taxonomic_level) = @_;

  if (defined($taxonomic_level)) {
    $self->{'taxonomic_level'} = $taxonomic_level;
  } 
  return $self->{'taxonomic_level'};
}

=head2 score

  Arg [1]    : float $score
  Example    : my $score = $constrained_element->score();
  Example    : $constrained_element->score(16.8);
  Description: Getter/Setter for the attribute score 
  Returntype : float
  Exceptions : returns undef if no ref.score
  Caller     : general

=cut

sub score {
  my ($self, $score) = @_;

  if (defined($score)) {
    $self->{'score'} = $score;
  } 
  return $self->{'score'};
}

=head2 method_link_species_set_id

  Arg [1]    : integer $method_link_species_set_id
  Example    : $method_link_species_set_id = $constrained_element->method_link_species_set_id;
  Example    : $constrained_element->method_link_species_set_id(3);
  Description: Getter/Setter for the attribute method_link_species_set_id.
  Returntype : integer
  Exceptions : returns undef if no ref.method_link_species_set_id
  Caller     : object::methodname

=cut

sub method_link_species_set_id {
  my ($self, $method_link_species_set_id) = @_;

  if (defined($method_link_species_set_id)) {
    $self->{'method_link_species_set_id'} = $method_link_species_set_id;
  } 

  return $self->{'method_link_species_set_id'};
}

=head2 alignment_segments
 
  Arg [1]    : listref $alignment_segments [ [ $dnafrag_id, $start, $end, $genome_db_id, $dnafrag_name ], .. ]
  Example    : my $alignment_segments = $constrained_element->alignment_segments();
               $constrained_element->alignment_segments($alignment_segments);
  Description: Getter/Setter for the attribute alignment_segments 
  Returntype : listref  
  Exceptions : returns undef if no ref.alignment_segments
  Caller     : general

=cut

sub alignment_segments {
  my ($self, $alignment_segments) = @_;

  if (defined($alignment_segments)) {
    $self->{'alignment_segments'} = $alignment_segments;
  } 

  return $self->{'alignment_segments'};
}


=head2 slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Example    : $slice = $constrained_element->slice;
  Example    : $constrained_element->slice($slice);
  Description: Getter/Setter for the attribute slice.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : returns undef if no ref.slice
  Caller     : object::methodname

=cut

sub slice {
  my ($self, $slice) = @_;

  if (defined($slice)) {
    $self->{'slice'} = $slice;
  } 

  return $self->{'slice'};
}

=head2 start

  Arg [1]    : (optional) int $start
  Example    : $start = $constrained_element->start;
  Example    : $constrained_element->start($start);
  Description: Getter/Setter for the attribute start.
  Returntype : int
  Exceptions : returns undef if no ref.start
  Caller     : object::methodname

=cut

sub start {
  my ($self, $start) = @_;

  if (defined($start)) {
    $self->{'start'} = $start;
  }

  return $self->{'start'};
}

=head2 end

  Arg [1]    : (optional) int $end
  Example    : $end = $constrained_element->end;
  Example    : $constrained_element->end($end);
  Description: Getter/Setter for the attribute end.
  Returntype : int
  Exceptions : returns undef if no ref.end
  Caller     : object::methodname

=cut

sub end {
  my ($self, $end) = @_;

  if (defined($end)) {
    $self->{'end'} = $end;
  }

  return $self->{'end'};
}

=head2 reference_dnafrag_id

  Arg [1]    : (optional) int $reference_dnafrag_id
  Example    : $dnafrag_id = $constrained_element->reference_dnafrag_id;
  Example    : $constrained_element->reference_dnafrag_id($dnafrag_id);
  Description: Getter/Setter for the attribute end.
  Returntype : int
  Exceptions : returns undef if no ref.reference_dnafrag_id 
  Caller     : object::methodname

=cut

sub reference_dnafrag_id {
  my ($self, $reference_dnafrag_id) = @_;

  if (defined($reference_dnafrag_id)) {
    $self->{'reference_dnafrag_id'} = $reference_dnafrag_id;
  }

  return $self->{'reference_dnafrag_id'};
}

=head2 get_SimpleAlign

  Arg [1]    : The method_link_species_set_object of the original alignment
  Example    : my $out = Bio::AlignIO->newFh(-fh=>\*STDOUT, -format=> "clustalw");
	       my$cons = $ce_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
               foreach my $simple_align(@{ $ce->get_SimpleAlign($prev_mlss, "uc") }) {
			print $out $simple_align;
	       }
  Note       : Where constrained elements occur in overlapping genomic_align_blocks there will be ambiguities
               in associating an alignment with the correct constrined_element_id.
  Description: Rebuilds the constrained element alignment
  Returntype : an arrayref of Bio::SimpleAlign objects
  Exceptions : throw if Arg-1 is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Caller     : object::methodname

=cut

sub get_SimpleAlign {
	my ($self, $orig_mlss, @flags) = @_;

        if (defined($orig_mlss)) {
                throw("$orig_mlss is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")  
                unless ($orig_mlss->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
        } else {
                throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
        }

	# setting the flags
	my $skip_empty_GenomicAligns = 1;
	my @SimpleAligns;
	my $uc = 0;
	my $translated = 0;

	for my $flag ( @flags ) {
		$uc = 1 if ($flag =~ /^uc$/i);
		$translated = 1 if ($flag =~ /^translated$/i);
	}		

	my $genomic_align_block_adaptor = $self->adaptor->db->get_GenomicAlignBlock;
	$self->start(1) if $self->start <= 0;
	my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
		$orig_mlss, $self->slice->sub_Slice($self->start, $self->end, $self->slice->strand));

	foreach my $this_genomic_align_block(@$gabs) {
		my $sa = Bio::SimpleAlign->new();
		my $bio07 = 0; 
		if(!$sa->can('add_seq')) {
			$bio07 = 1; 
		}
		my $reference_genomic_align = $this_genomic_align_block->reference_genomic_align();

		my $restricted_gab = $this_genomic_align_block->restrict_between_reference_positions(
			($self->slice->start + $self->start - 1),
			($self->slice->start + $self->end - 1),
			$reference_genomic_align,
			$skip_empty_GenomicAligns);
		foreach my $genomic_align( @{ $restricted_gab->get_all_GenomicAligns } ) {
			my $alignSeq = $genomic_align->aligned_sequence;
			my $loc_seq = Bio::LocatableSeq->new(
				-SEQ    => $uc ? uc $alignSeq : lc $alignSeq,
				-START  => $genomic_align->dnafrag_start,
				-END    => $genomic_align->dnafrag_end,
				-ID     => $this_genomic_align_block->dbID . "/" .
				 $genomic_align->dnafrag->genome_db_id . "/" . $genomic_align->dnafrag->name,
				-STRAND => $genomic_align->dnafrag_strand);

			if($bio07) { 
				$sa->addSeq($loc_seq); 
			}else{ 
				$sa->add_seq($loc_seq); 
			}				
		}
		push(@SimpleAligns, $sa);
	}
	warn "overlapping constrained elements for ", $self->dbID, "\n" if (@SimpleAligns > 1);	
	
	return \@SimpleAligns;
}

1;
