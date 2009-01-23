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
          -score => 56.2,
          -p_value => 1.203e-6,
          -dnafrags => [ [$dnafrag1_id, $dnafrag1_start, $dnafrag1_end], [$dnafrag2_id, $dnafrag2_start, $dnafrag2_end], ... ],
	  -taxonomic_level => "eutherian mammals",
      );

GET / SET VALUES
  $constrained_element->adaptor($constrained_element_adaptor);
  $constrained_element->method_link_species_set_id($method_link_species_set_id);
  $constrained_element->score(56.2);
  $constrained_element->p_value(5.62e-9);
  $constrained_element->taxonomic_level("eutherian mammals");
  $constrained_element->dnafrags([ [$dnafrag_id, $dnafrag_start, $dnafrag_end ], ... ]);
  $constrained_element->slice($slice);
  $constrained_element->slice_start($slice_start);
  $constrained_element->slice_end($slice_end);

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

=item slice_start

corresponds to a slice.slice_start

=item slice_end

corresponds to a slice.slice_end

=item dnafrags

listref of listrefs which contain 3 strings (dnafrag.dnafrag_id, 
dnafrag.dnafrag_start, dnafrag.dnafrag_end) 

=back

=head1 AUTHOR

Stephen Fitzgerald (ensembl-compara@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

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

  Arg [-CONSTRAINED_ELEMENT_ID] : int $constrained_element_id (the database ID for 
					the constrained element block for this object)
  Arg [-ADAPTOR]
              : (opt.) Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor $adaptor
                (the adaptor for connecting to the database)
  Arg [-METHOD_LINK_SPECIES_SET_ID]
              : int $mlss_id (the database internal ID for the $mlss)
  Arg [-SCORE]
              : float $score (the score of this alignment)
  Arg [-DNAFRAGS]
              : listref of 3 values or a listref of listrefs which each contain 3 values 
		( $dnafrag_id, $dnafrag_start, $dnafrag_end ) ie.
		[ [ $dnafrag_id, $dnafrag_start, $dnafrag_end ], ... ]
  Arg [-P_VALUE]
              : (opt.) string $p_value (the p_value of this constrained element)
  Arg [-TAXONOMIC_LEVEL]
              : (opt.) string $taxonomic_level (the taxonomic level of the alignments from which the 
		constrained element was derived)
  Arg [-SLICE]
	     : (opt.) Bio::EnsEMBL::Slice object
  Arg [-SLICE_START]
	     : (opt.) int Bio::EnsEMBL::Slice->start.
  Arg [-SLICE_END]
	     : (opt.) int Bio::EnsEMBL::Slice->end
  Example    : my $constrained_element =
                   new Bio::EnsEMBL::Compara::ConstrainedElement(
                       -adaptor => $adaptor,
                       -method_link_species_set_id => $method_link_species_set_id,
                       -score => 28.2,
                       -dnafrags => [ [ 2039123, 108441, 108461 ] ],
                       -p_value => 5.023e-6,
                       -taxonomic_level => "eutherian mammals",
		       -slice => $slice_obj,
		       -slice_start => $slice_obj->start,
		       -slice_end => $slice_obj->end,
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
    
  my ($adaptor, $constrained_element_id, $alignment_segments, 
	$method_link_species_set_id, $score, $p_value, 
	$taxonomic_level, $slice, $start, $end, $reference_dnafrag_id) = 
    rearrange([qw(
        ADAPTOR CONSTRAINED_ELEMENT_ID ALIGNMENT_SEGMENTS 
  METHOD_LINK_SPECIES_SET_ID SCORE P_VALUE TAXONOMIC_LEVEL
  SLICE START END REFERENCE_DNAFRAG_ID
	)],
            @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->constrained_element_id($constrained_element_id) 
	if (defined ($constrained_element_id));
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


=head2 constrained_element_id 

  Arg [1]    : integer $constrained_element_id
  Example    : my $dbID = $constrained_element->constrained_element_id();
  Example    : $constrained_element->constrained_element_id(2);
  Description: Getter/Setter for the attribute constrained_element_id 
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub constrained_element_id {
  my ($self, $constrained_element_id) = @_;

  if (defined($constrained_element_id)) {
    $self->{'constrained_element_id'} = $constrained_element_id;
  }

  return $self->{'constrained_element_id'};
}


=head2 p_value 

  Arg [1]    : float $p_value
  Example    : my $dbID = $constrained_element->p_value();
  Example    : $constrained_element->p_value(12);
  Description: Getter/Setter for the attribute p_value
  Returntype : float 
  Exceptions : none
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
  Exceptions : none
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
  Exceptions : none
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
  Exceptions : none
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
 
  Arg [1]    : listref $alignment_segments [ [ $dnafrag_id, $start, $end ], .. ]
  Example    : my $alignment_segments = $constrained_element->alignment_segments();
               $constrained_element->alignment_segments($alignment_segments);
  Description: Getter/Setter for the attribute alignment_segments 
  Returntype : listref  
  Exceptions : none
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
  Exceptions : returns undef if no ref. slice
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
  Exceptions : returns undef if no ref. slice
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
  Exceptions : returns undef if no ref. slice
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
  Example    : $end = $constrained_element->reference_dnafrag_id;
  Example    : $constrained_element->end($reference_dnafrag_id);
  Description: Getter/Setter for the attribute end.
  Returntype : int
  Exceptions : returns undef if no ref. slice
  Caller     : object::methodname

=cut

sub reference_dnafrag_id {
  my ($self, $reference_dnafrag_id) = @_;

  if (defined($reference_dnafrag_id)) {
    $self->{'reference_dnafrag_id'} = $reference_dnafrag_id;
  }

  return $self->{'reference_dnafrag_id'};
}

1;
