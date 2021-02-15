=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Locus

=head1 DESCRIPTION

Locus is a base object that represents a segment of a DnaFrag.

=head1 SYNOPSIS

Attributes:
  - dnafrag() (and dnafrag_id())
  - dnafrag_start()
  - dnafrag_end()
  - dnafrag_strand()

Links to other objects:
  - genome_db()
  - get_Slice()

Locus is not supposed to be instantiated directly, but should
only be used as a base class.
Adaptor / object methods that require coordinates will usually
ask for a Locus parameter.

Locus can still be created on the fly this way:

 my $locus = Bio::EnsEMBL::Compara::Locus->new(
    -dnafrag_id => 1234,
    -dnafrag_start => 56,
    -dnafrag_end => 78,
 );

=head1 OBJECT ATTRIBUTES

=over

=item dnafrag_id

dbID of the Bio::EnsEMBL::Compara::DnaFrag object.

=item dnafrag

Bio::EnsEMBL::Compara::DnaFrag object corresponding to dnafrag_id

=item dnafrag_start

The start of the Locus on the DnaFrag.

=item dnafrag_end

The end of the Locus on the DnaFrag.

=item dnafrag_strand

The strand of the Locus, on the DnaFrag.

=back

=cut

package Bio::EnsEMBL::Compara::Locus;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:all);

use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);


=head2 new

  Arg [-DNAFRAG]
              : (opt.) Bio::EnsEMBL::Compara::DnaFrag $dnafrag
                the genomic sequence object to which this object refers to
  Arg [-DNAFRAG_ID]
              : (opt.) int $dnafrag_id
                the database internal ID for the $dnafrag
  Arg [-DNAFRAG_START]
              : (opt.) int $dnafrag_start
                the starting position of this Locus within its corresponding $dnafrag
  Arg [-DNAFRAG_END]
              : (opt.) int $dnafrag_end
                the ending position of this Locus within its corresponding $dnafrag
  Arg [-DNAFRAG_STRAND]
              : (opt.) int $dnafrag_strand (only 1 or -1)
                defines in which strand of its corresponding $dnafrag this Locus is
  Description : Object constructor.
  Returntype  : Bio::EnsEMBL::Compara::Locus object
  Exceptions  : none
  Caller      : general

=cut

sub new {
  my ($caller, @args) = @_;
  my $class = ref($caller) || $caller;
  my $self = bless {}, $class;

  if (scalar @args) {
    #do this explicitly.
    my ($dnafrag, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = rearrange([qw(DNAFRAG DNAFRAG_ID DNAFRAG_START DNAFRAG_END DNAFRAG_STRAND)], @args);

    $self->dnafrag($dnafrag) if (defined($dnafrag));
    $dnafrag_id && $self->dnafrag_id($dnafrag_id);
    $dnafrag_start && $self->dnafrag_start($dnafrag_start);
    $dnafrag_end && $self->dnafrag_end($dnafrag_end);
    $dnafrag_strand && $self->dnafrag_strand($dnafrag_strand);
  }

  return $self;
}


=head2 expand_Locus

  Arg [1]     : int size (optional)
                The desired number of flanking basepairs around the locus.
                The size may also be provided as a percentage of the locus
                size such as 200% or 80.5%. In this case, $size represents
                the new size, e.g. 100% gives no context and 200% gives 50%
                of the size of the locus on either side of the locus
  Example     : my $seq_flanking = $gene_member->expand_Locus('500%')->get_sequence();
  Description : Creates a copy of this Locus with an expanded size
  Returntype  : Bio::EnsEMBL::Compara::Locus object
  Exceptions  : none
  Caller      : general

=cut

sub expand_Locus {
    my ($self, $size) = @_;

    ## Size may be given as a percentage of the length of the locus
    ## Size = 100% gives no context
    ## Size = 200% gives context - 50% the size of the locus either side of locus
    my $length = $self->length;
    $size = int(($1-100) * $length / 200) if $size =~ /([\d+\.]+)%/;

    my $start = $self->dnafrag_start - $size;
    my $end   = $self->dnafrag_end   + $size;

    $start    = 1                      if $start < 1;
    $end      = $self->dnafrag->length if $end   > $self->dnafrag->length;

    my $hash = {
        'dnafrag'           => $self->dnafrag,
        'dnafrag_id'        => $self->dnafrag->dbID,
        'dnafrag_start'     => $start,
        'dnafrag_end'       => $end,
        'dnafrag_strand'    => $self->dnafrag_strand,
    };
    return bless $hash, 'Bio::EnsEMBL::Compara::Locus';
}


=head2 dnafrag

  Arg [1]     : (optional) Bio::EnsEMBL::Compara::DnaFrag object
  Example     : $dnafrag = $locus->dnafrag;
  Description : Getter/setter for the Bio::EnsEMBL::Compara::DnaFrag object
                corresponding to this Bio::EnsEMBL::Compara::Locus object.
                If no argument is given, the dnafrag is not defined but
                both the dnafrag_id and the adaptor are, it tries
                to fetch the data using the dnafrag_id
  Returntype  : Bio::EnsEMBL::Compara::Dnafrag object
  Exceptions  : thrown if $dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag
                object or if $dnafrag does not match a previously defined
                dnafrag_id

=cut

sub dnafrag {
  my ($self, $dnafrag) = @_;

  if (defined($dnafrag)) {
    assert_ref($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', 'dnafrag');
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
               Bio::EnsEMBL::Compara::DnaFrag object or the database using the dnafrag_id
               of the Bio::EnsEMBL::Compara::Locus object.
               Use 0 as argument to clear this attribute.
  Returntype : integer
  Exceptions : thrown if $dnafrag_id does not match a previously defined
               dnafrag
  Status     : Stable

=cut

sub dnafrag_id {
  my ($self, $dnafrag_id) = @_;

  if (defined($dnafrag_id)) {
    assert_integer($dnafrag_id);
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
    } else {
      $self->_lazy_getter_setter('dnafrag_id');
    }
  }

  return $self->{'dnafrag_id'};
}


=head2 _lazy_getter_setter

  Arg [1]    : string $field
  Arg [2]    : scalar $val
  Description: Generic getter/Setter for the attribute $field. In $val is not given, the
               attribute $field is not defined, but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the dbID
  Returntype : scalar
  Exceptions : none
  Caller     : internal

=cut

sub _lazy_getter_setter {
  my ($self, $field, @args) = @_;

  if (@args) {
     $self->{$field} = $args[0];

   } elsif (not defined($self->{$field})) {
    if (defined($self->{'dbID'}) and defined($self->{'adaptor'}) and $self->{'adaptor'}->can('retrieve_all_direct_attributes')) {
      # Try to get the values from the database using the dbID of the Bio::EnsEMBL::Compara::Locus object
      $self->adaptor->retrieve_all_direct_attributes($self);
    }
  }

  return $self->{$field};
}


=head2 dnafrag_start

  Arg [1]    : integer $dnafrag_start
  Example    : $dnafrag_start = $genomic_align->dnafrag_start;
  Example    : $genomic_align->dnafrag_start(1233354);
  Description: Getter/Setter for the attribute dnafrag_start. If no argument is given, the
               dnafrag_start is not defined but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the dbID
  Returntype : integer
  Exceptions : none
  Status     : Stable

=cut

sub dnafrag_start {
  my $obj = shift;

  assert_integer($_[0]) if( @_ and defined($_[0]) );
  return $obj->_lazy_getter_setter('dnafrag_start', @_);
}


=head2 dnafrag_end

  Arg [1]    : integer $dnafrag_end
  Example    : $dnafrag_end = $genomic_align->dnafrag_end;
  Example    : $genomic_align->dnafrag_end(1235320);
  Description: Getter/Setter for the attribute dnafrag_end. If no argument is given, the
               dnafrag_end is not defined but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the dbID
  Returntype : integer
  Exceptions : none
  Status     : Stable

=cut

sub dnafrag_end {
  my $obj = shift;

  assert_integer($_[0]) if( @_ and defined($_[0]) );
  return $obj->_lazy_getter_setter('dnafrag_end', @_);
}


=head2 dnafrag_strand

  Arg [1]    : integer $dnafrag_strand (1 or -1)
  Example    : $dnafrag_strand = $genomic_align->dnafrag_strand;
  Example    : $genomic_align->dnafrag_strand(1);
  Description: Getter/Setter for the attribute dnafrag_strand. If no argument is given, the
               dnafrag_strand is not defined but both the dbID and the adaptor are, it tries
               to fetch and set all the direct attributes from the database using the dbID
  Returntype : integer
  Exceptions : none
  Status     : Stable

=cut

sub dnafrag_strand {
  my $obj = shift;

  assert_strand($_[0]) if( @_ and defined($_[0]) );
  return $obj->_lazy_getter_setter('dnafrag_strand', @_);
}


=head2 length

  Example     : $length = $dnafragregion->length;
  Description : Returns the lenght of this Locus
  Returntype  : integer
  Exceptions  : none

=cut

sub length {
    my ($self) = @_;

    return $self->dnafrag_end - $self->dnafrag_start + 1;
}


=head2 get_Slice

  Example    : $slice = $genomic_align->get_Slice();
  Description: creates and returns a Bio::EnsEMBL::Slice which corresponds to
               this Bio::EnsEMBL::Compara::GenomicAlign
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : return -undef- if slice cannot be created (this is likely to
               happen if the Registry is misconfigured)
  Status     : Stable

=cut

sub get_Slice {
  my ($self) = @_;

  if (my $dnafrag = $self->dnafrag) {
    my $slice = $dnafrag->slice;
    return undef if (!defined($slice));

    $slice = $slice->sub_Slice(
                $self->dnafrag_start,
                $self->dnafrag_end,
                $self->dnafrag_strand
            );

    return $slice;
  }
  return undef;
}


=head2 get_sequence

  Arg[1]      : (optional) String $mask
  Example     : $anchor_align->get_sequence('soft');
  Description : Return the sequence of this genomic location. If possible, the sequence will
                be read from an indexed Fasta file; otherwise from the core database.
                Masking can be requested with the $mask parameter: undef, 'soft' or 'hard'
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_sequence {
    my $self = shift;
    my $mask = shift;

    my $seq;
    # Only reference dnafrags are dumped
    if ($self->dnafrag->is_reference && (my $faidx_helper = $self->genome_db->get_faidx_helper($mask))) {
        # Sequence names in the Fasta file are expected to be dnafrag_ids;
        # Coordinates are 0-based
        $seq = $faidx_helper->get_sequence2_no_length($self->dnafrag_id, $self->dnafrag_start-1, $self->dnafrag_end-1);
        die "sequence length doesn't match !" if CORE::length($seq) != ($self->dnafrag_end-$self->dnafrag_start+1);
        reverse_comp(\$seq) if $self->dnafrag_strand < 0;
    } else {
        $self->genome_db->db_adaptor->dbc->prevent_disconnect( sub {
            if ($mask) {
                if ($mask =~ /^soft/i) {
                    $seq = $self->get_Slice()->get_repeatmasked_seq(undef, 1)->seq;
                } elsif ($mask =~ /^hard/i) {
                    $seq = $self->get_Slice()->get_repeatmasked_seq()->seq;
                } else {
                    throw("Unknown masking option '$mask'");
                }
            } else {
                $seq = $self->get_Slice()->seq;
            }
        });
    }

    return $seq;
}


=head2 genome_db

  Arg [1]    : (optional) Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $genome_db = $genomic_align->genome_db;
  Example    : $genomic_align->genome_db($genome_db);
  Description: Getter/Setter for the attribute genome_db of
               the dnafrag. This method is a short cut for
               $genomic_align->dnafrag->genome_db()
  Returntype : Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions : thrown if $genomic_align->dnafrag is not
               defined and cannot be fetched from other
               sources.
  Status     : Stable

=cut

sub genome_db {
  my ($self, $genome_db) = @_;

  if (defined($genome_db)) {
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');
    my $dnafrag = $self->dnafrag();
    if (!$dnafrag) {
      throw("Cannot set genome_db if dnafrag does not exist");
    } else {
      $dnafrag->genome_db($genome_db);
    }
  }

  if ($self->dnafrag) {
    return $self->dnafrag->genome_db;
  }

  return undef;
}


=head2 toString

  Example     : $locus->toString();
  Description : Returns a description of this object as a string
  Returntype  : String
  Exceptions  : none
  Caller      : general

=cut

sub toString {
    my $self = shift;
    return sprintf('%s:%s:%s-%s%s',
        $self->dnafrag->genome_db->name,
        $self->dnafrag->name,
        $self->dnafrag_start,
        $self->dnafrag_end,
        $self->dnafrag_strand < 0 ? '(-1)' : '',
    );
}

1;
