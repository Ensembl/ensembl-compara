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
      );

GET / SET VALUES
  $constrained_element->adaptor($constrained_element_adaptor);
  $constrained_element->dbID($constrained_element_id);
  $constrained_element->method_link_species_set_id($method_link_species_set_id);
  $constrained_element->score(56.2);
  $constrained_element->p_value('5.62e-9');
  $constrained_element->alignment_segments([ [$dnafrag_id, $start, $end, $genome_db_id, $dnafrag_name ], ... ]);
  $constrained_element->slice($slice);
  $constrained_element->start($constrained_element_start - $slice_start + 1);
  $constrained_element->end($constrained_element_end - $slice_start + 1);
  $constrained_element->seq_region_start($self->slice->start + $self->{'start'} - 1);
  $constrained_element->seq_region_end($self->slice->start + $self->{'end'} - 1);
  $constrained_element->strand($strand);
  $constrained_element->reference_dnafrag_id($dnafrag_id);
  $constrained_element->get_all_overlapping_exons();

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

=item slice

corresponds to a Bio::EnsEMBL::Slice 

=item start

corresponds to a constrained_element.dnafrag_start (in slice coordinates)

=item end

corresponds to a constrained_element.dnafrag_end (in slice coordinates)

=item seq_region_start

corresponds to a constrained_element.dnafrag_start (in genomic (absolute) coordinates)

=item seq_region_end

corresponds to a constrained_element.dnafrag_end (in genomic (absolute) coordinates)

=item strand

corresponds to a constrained_element.strand

=item $alignment_segments

listref of listrefs (each of which contain 5 strings (dnafrag.dnafrag_id, constrained_element.dnafrag_start, 
constrained_element.dnafrag_end, constrained_element.strand, genome_db.genome_db_id, dnafrag.dnafrag_name) 
   [ [ $dnafrag_id, $start, $end, $genome_db_id, $dnafrag_name ], .. ]
Each inner listref contains information about one of the species sequences which make up the constarained 
element block from the alignment. 

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::ConstrainedElement;

use strict;
use warnings;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info verbose);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::SimpleAlign;
use Data::Dumper;

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


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
  Arg [-SLICE]
	     : (opt.) Bio::EnsEMBL::Slice object
  Arg [-START]
	     : (opt.) int ($dnafrag_start - Bio::EnsEMBL::Slice->start + 1).
  Arg [-END]
	     : (opt.) int ($dnafrag_end - Bio::EnsEMBL::Slice->start + 1).
  Arg [-STRAND]
	     : (opt.) int (the strand from the genomic_align).
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
		       -slice => $slice_obj,
		       -start => ( $dnafrag_start - $slice_obj->start + 1),
		       -end => ( $dnafrag_end - $slice_obj->start + 1),
		       -strand => $strand,
		       -reference_dnafrag_id => $dnafrag_id,
                   );
  Description: Creates a new ConstrainedElement object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::ConstrainedElement
  Exceptions : none
  Caller     : general

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = $class->SUPER::new(@args);       # deal with Storable stuff
    
  my ($alignment_segments,
	$method_link_species_set_id, $score, $p_value, 
	$slice, $start, $end, $strand, $reference_dnafrag_id) = 
    rearrange([qw(
        ALIGNMENT_SEGMENTS
  METHOD_LINK_SPECIES_SET_ID SCORE P_VALUE 
  SLICE START END STRAND REFERENCE_DNAFRAG_ID 
	)],
            @args);

  $self->method_link_species_set_id($method_link_species_set_id)
      if (defined ($method_link_species_set_id));
  $self->alignment_segments($alignment_segments) 
      if (defined ($alignment_segments));
  $self->score($score) if (defined ($score));
  $self->p_value($p_value) if (defined ($p_value));
  $self->slice($slice) if (defined ($slice));
  $self->start($start) if (defined ($start));
  $self->end($end) if (defined ($end));
  $self->strand($strand) if (defined ($strand));
  $self->reference_dnafrag_id($reference_dnafrag_id)
      if (defined($reference_dnafrag_id));
  return $self;
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
  Description: Getter/Setter for the attribute alignment_segments. It represents the alignments segments of this
               constrained element in all the species.
               Note: this is lazy-loaded
  Returntype : listref  
  Exceptions : returns undef if no ref.alignment_segments
  Caller     : general

=cut

sub alignment_segments {
  my ($self, $alignment_segments) = @_;

  if (defined($alignment_segments)) {
    $self->{'alignment_segments'} = $alignment_segments;
  } 

  unless ($self->{'alignment_segments'}) {
    $self->{'alignment_segments'} = $self->adaptor->fetch_by_dbID($self->dbID)->{'alignment_segments'};
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
  Description: Getter/Setter for the attribute end relative to the begining of the slice.
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


=head2 seq_region_start

  Arg [1]    : (optional) int $seq_region_start
  Example    : $seq_region_start = $constrained_element->seq_region_start;
  Example    : $constrained_element->seq_region_start($seq_region_start);
  Description: Getter/Setter for the attribute start relative to the begining of the dnafrag (genomic coords).
  Returntype : int
  Exceptions : returns undef if no ref.seq_region_start
  Caller     : object::methodname

=cut

sub seq_region_start {
	my ($self, $seq_region_start) = @_;
	
	if(defined($seq_region_start)) {
		$self->{'seq_region_start'} = $seq_region_start;
	} else {
		$self->{'seq_region_start'} = $self->slice->start + $self->{'start'} - 1;
	}
	return $self->{'seq_region_start'};
}


=head2 seq_region_end

  Arg [1]    : (optional) int $seq_region_end
  Example    : $seq_region_end = $constrained_element->seq_region_end
  Example    : $constrained_element->seq_region_end($seq_region_end);
  Description: Getter/Setter for the attribute end relative to the begining of the dnafrag (genomic coords).
  Returntype : int
  Exceptions : returns undef if no ref.seq_region_end
  Caller     : object::methodname

=cut

sub seq_region_end {
	my ($self, $seq_region_end) = @_;
	
	if(defined($seq_region_end)) {
		$self->{'seq_region_end'} = $seq_region_end;
	} else {
		$self->{'seq_region_end'} = $self->slice->start + $self->{'end'} - 1;
	}
	return $self->{'seq_region_end'};
}



=head2 strand

  Arg [1]    : (optional) int $stand$
  Example    : $end = $constrained_element->strand;
  Example    : $constrained_element->end($strand);
  Description: Getter/Setter for the attribute genomic_align strand.
  Returntype : int
  Exceptions : returns undef if no ref.strand
  Caller     : object::methodname

=cut

sub strand {
  my ($self, $strand) = @_;

  if (defined($strand)) {
    $self->{'strand'} = $strand;
  }

  return $self->{'strand'};
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

  Arg [1]    : Optional flags for formatting displayed MSA  
  Example    : my $out = Bio::AlignIO->newFh(-fh=>\*STDOUT, -format=> "clustalw");
	       my $cons = $ce_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
               foreach my $constrained_element(@{ $cons }) {
			my $simple_align = $constrained_element->get_SimpleAlign("uc");
			print $out $simple_align;
	       }
  Description: Rebuilds the constrained element alignment
  Returntype : Bio::SimpleAlign object
  Exceptions : throw if you can not get a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object from the constrained element
  Caller     : object::methodname

=cut

sub get_SimpleAlign {
	my ($self, @flags) = @_;

	my $mlss_adaptor = $self->adaptor->db->get_MethodLinkSpeciesSet;

	my $cons_eles_mlss = $mlss_adaptor->fetch_by_dbID($self->method_link_species_set_id());

	if (defined($cons_eles_mlss)) {
		throw("$cons_eles_mlss is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
		unless ($cons_eles_mlss->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
	} else {
		throw("unable to get a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object from this constrained element");
	}

	my $msa_mlss_id = $cons_eles_mlss->get_value_for_tag("msa_mlss_id"); # The mlss_id of the alignments from which the constrained elements were generated

	my $msa_mlss = $mlss_adaptor->fetch_by_dbID( $msa_mlss_id );
	
	# setting the flags
	my $skip_empty_GenomicAligns = 1;
	my $uc = 0;
	my $translated = 0;

	for my $flag ( @flags ) {
		$uc = 1 if ($flag =~ /^uc$/i);
		$translated = 1 if ($flag =~ /^translated$/i);
	}		

	my $genomic_align_block_adaptor = $self->adaptor->db->get_GenomicAlignBlock;
	# Slice::sub_Slice only allows coordinates that are inside the query slice
	# We need to trim the coordinates here (which would get trimmed anyway by restrict_between_reference_positions())
	my $start = $self->start;
	$start = 1 if $start < 1;
	my $end = $self->end;
	$end = $self->slice->length if $end > $self->slice->length;
	my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
		$msa_mlss, $self->slice->sub_Slice($start, $end, $self->slice->strand));

	my $sa = Bio::SimpleAlign->new();
        $sa->missing_char('.'); # only useful for Nexus files

	warn "should be only one genomic_align_block associated with each constrained element\n" if @$gabs > 1;

	my $this_genomic_align_block = $gabs->[0];
	my $reference_genomic_align = $this_genomic_align_block->reference_genomic_align();

	my $restricted_gab = $this_genomic_align_block->restrict_between_reference_positions(
		($self->slice->start + $start - 1),
		($self->slice->start + $end - 1),
		$reference_genomic_align,
		$skip_empty_GenomicAligns);
#        print "dbID: ", $this_genomic_align_block->dbID, ". ";
	foreach my $genomic_align( @{ $restricted_gab->get_all_GenomicAligns } ) {
		my $alignSeq = $genomic_align->aligned_sequence;
		my $loc_seq = Bio::LocatableSeq->new(
			-SEQ    => $uc ? uc $alignSeq : lc $alignSeq,
			-START  => $genomic_align->dnafrag_start,
			#-END    => $genomic_align->dnafrag_end,
			-ID     => $genomic_align->dnafrag->genome_db->name . "/" . $genomic_align->dnafrag->name,
			-STRAND => $genomic_align->dnafrag_strand);
                # Avoid warning in BioPerl about len(seq) != end-start+1
                $loc_seq->{end} = $genomic_align->dnafrag_end;

                $sa->add_seq($loc_seq);
	}
	return $sa;
}

=head2 summary_as_hash

  Example       : $constrained_summary = $constrained_element->summary_as_hash();
  Description   : Retrieves a textual summary of this ConstrainedElement object.
	              Sadly not descended from Feature, so certain attributes must be explicitly requested
  Returns       : hashref of descriptive strings

=cut

sub summary_as_hash {
  my $self = shift;
  my $summary_ref;
  $summary_ref->{'ID'} = $self->dbID;
  $summary_ref->{'start'} = $self->seq_region_start;
  $summary_ref->{'end'} = $self->seq_region_end;
  $summary_ref->{'strand'} = $self->strand;
  $summary_ref->{'seq_region_name'} = $self->slice->seq_region_name;
  $summary_ref->{'score'} = $self->score;
  return $summary_ref;
}


=head2 get_all_overlapping_exons

  Arg  1        : (optional) list of Bio::EnsEMBL::Gene and/or Bio::EnsEMBL::Transcript and/or Bio::EnsEMBL::Compara::GenomeDB
                  objects eg ce->get_all_exons($human_gene1, $human_gene2, $cow_transcript1);
  Examples      : my $CEs = $cons_ele_a->fetch_all_by_MethodLinkSpeciesSet_Slice($cons_ele_mlss, $species_slice);
                  foreach my $constrained_element( @{ $CEs }) {
                #1   foreach my $exon(@{ $constrained_element->get_all_exons() }){                # will return all exons based on the $species_slice only
                #2   foreach my $exon(@{ $constrained_element->get_all_exons($human_gene1) }){    # same as #1 but will filter out all exons 
                                                                                                  # not associated with $human_gene1
                #3   foreach my $exon(@{ $constrained_element->get_all_exons($horse_genomeDB) }){ # will return horse specific exons (if  
                                                                                                  # there is horse sequence in the cons_ele) 
                    print $exon->stable_id, "\n";
                   }
                  }
  Description   : Will return a listref of Bio::EnsEMBL::Exon objects which overlap the constrained element (CE)
                  if Gene and/or Transcript objects are provided as arguments, only overlapping exons associated with these features
                  will be returned (see #2). 
                  If no arguments are provided, exons overlapping the CE slice will be returned (the CE must have a slice in this case - see #1)
                  If one or more genome_db objects are provided - exons overlapping the region(s) in the CE from these species will be returned (if any exist)
  Returns       : listref of Bio::EnsEMBL::Exon objects or an empty listref if there are no overlapping exons
  Exceptions    : if the constrained element objects have no associated Slice object (ie. only if they were obtained 
                  from the adaptor using the method fetch_by_dbID then at least one parameter (gene, transcript or genomeDB object) 
                  must be provided, otherwise throw

=cut

sub get_all_overlapping_exons {
 my $self = shift;
 my @params = @_;

 my (%genomes, %exon_stable_ids, @exons);
  
 my $dnafrag_a = $self->adaptor->db->get_DnaFrag;
 my $genome_db_a = $self->adaptor->db->get_GenomeDB;

 if(@params){
  foreach my $param(@params){
   if(ref $param eq "Bio::EnsEMBL::Gene" || ref $param eq "Bio::EnsEMBL::Transcript"){
     foreach my $feature_exon(@{ $param->get_all_Exons }){
      $exon_stable_ids{ $feature_exon->stable_id }++; # get the stable ids for the feature exons, if any
     }
     my $genome_db = $genome_db_a->fetch_by_Slice( $param->feature_Slice );
     $genomes{ $genome_db->name } = undef; 
   } elsif (ref $param eq "Bio::EnsEMBL::Compara::GenomeDB"){
     $genomes{ $param->name } = undef;
   } else { throw("incorrect object type in parameter list"); }
  }
  foreach my $alignment_seg( @{ $self->alignment_segments } ){
   if(exists( $genomes{ $alignment_seg->[4] } )) { 
    my $species = $alignment_seg->[4];
    push( @{ $genomes{ $species } }, $alignment_seg);
   }
  }
 } elsif($self->reference_dnafrag_id) { # must have been fetched by a slice/dnafrag_region method 
    my $dnafrag_id = $self->reference_dnafrag_id;
    my $dnafrag = $dnafrag_a->fetch_by_dbID($dnafrag_id);
    my $species = $dnafrag->genome_db->name;
    push( @{ $genomes{ "$species" } }, [ $dnafrag_id, 
                                       $self->seq_region_start, 
                                       $self->seq_region_end,
                                       $self->strand,
                                       ] );
 } else {
    throw("need to supply a reference species genome_db, gene or a transcript object");
 } 

 foreach my $genome (keys %genomes){
  foreach my $seg (@{ $genomes{ $genome } }){
   my($dbID, $from, $to, $strand) = @$seg;
   my $align_seg_slice = $dnafrag_a->fetch_by_dbID( $dbID )->slice->sub_Slice( $from, $to, $strand );
   foreach my $align_seg_exon( @{ $align_seg_slice->get_all_Exons } ){
    if(keys %exon_stable_ids){
     push(@exons, $align_seg_exon) if( exists($exon_stable_ids{ $align_seg_exon->stable_id }) );
    } else {
     push(@exons, $align_seg_exon);
    }
   }
  }
 }
 return \@exons;
}


=head2 get_all_overlapping_regulatory_motifs

  Arg  1        : (optional) Bio::EnsEMBL::Compara::GenomeDB object (if CEs were not retrieved using a slice-based method
  Examples      : my $CEs = $cons_ele_a->fetch_all_by_MethodLinkSpeciesSet_Slice($cons_ele_mlss, $species_slice);
                  foreach my $ce( @{ $CEs }) {
                   print $ce->dbID, "\n";
                   foreach my $rm(@{ $constrained_element->get_all_overlapping_regulatory_motifs }){
                    print $rm->display_label, "\n";
                   }
                  }
  Description   : will return a listref of Bio::EnsEMBL::Funcgen::MotifFeature objects which overlap the constrained element (CE)
  Returns       : listref of Bio::EnsEMBL::Funcgen::MotifFeature objects or an empty listref if there are no overlapping motifs
  Exceptions    : throw if the constrained element objects have no associated Slice object AND no genome_db object was provided as a parameter

=cut

sub get_all_overlapping_regulatory_motifs {
 my $self = shift;
 my ($genome_db) = @_;

 my ($species, @ce_coords, @reg_motif);
 
 if($genome_db){
  $species = $genome_db->name;
  foreach my $alignment_seg( @{ $self->alignment_segments } ){
   if($alignment_seg->[4] eq "$species"){
    push(@ce_coords, $alignment_seg);
   }
  }
 } elsif(my $dnafrag_id = $self->reference_dnafrag_id){
  $species = $self->adaptor->db->get_DnaFrag->fetch_by_dbID( $dnafrag_id )->genome_db->name;
  push(@ce_coords, [ $dnafrag_id, $self->seq_region_start, $self->seq_region_end, $self->strand ]);
 } else {
  throw("need to supply a reference species genome_db or the constrained element must be derived from a slice");
 }
 my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'funcgen');
 return [] unless $dba;
   my $regfeat_a = $dba->get_RegulatoryFeature;
   my $dnafrag_a = $self->adaptor->db->get_DnaFrag;
   foreach my $ce_region(@ce_coords){
    my($dnafrag_id, $from, $to, $strand) = @$ce_region;
    my $slice = $dnafrag_a->fetch_by_dbID( $dnafrag_id )->slice->sub_Slice( $from, $to, $strand );
    foreach my $reg_feature( @{ $regfeat_a->fetch_all_by_Slice($slice) } ){
     foreach my $motif( @{ $reg_feature->regulatory_attributes('motif') } ){
      push(@reg_motif, $motif);
     }
    }
   }
 return \@reg_motif;
} 


=head2 toString

  Example    : print $member->toString();
  Description: used for debugging, returns a string with the key descriptive
               elements of this member
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub toString {
    my $self = shift;
    my $str = sprintf('ConstrainedElement dbID=%s', $self->dbID || '?');
    $str .= sprintf(' (%s)', $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->method_link_species_set_id)->name) if $self->method_link_species_set_id;
    $str .= ' score='.$self->score if defined $self->score;
    $str .= ' p_value='.$self->p_value if defined $self->p_value;
    my $dnafrag = $self->adaptor->db->get_DnaFragAdaptor->fetch_by_dbID($self->reference_dnafrag_id);
    $str .= sprintf(' %s:%d-%d%s', $dnafrag->name, $self->seq_region_start, $self->seq_region_end, ($self->strand < 0 ? '(-1)' : ''));
    return $str;
}


1;
