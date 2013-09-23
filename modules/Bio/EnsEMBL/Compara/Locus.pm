=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::Locus

=head1 DESCRIPTION

Locus is a base object that represents a segment of a DnaFrag.

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

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::Locus;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;


=head2 new

  Arg         : possible keys:
                DNAFRAG_ID, DNAFRAG_START, DNAFRAG_END, DNAFRAG_STRAND
  Example     : none
  Description : Object constructor.
  Returntype  : Bio::EnsEMBL::Compara::Locus object
  Exceptions  : none
  Caller      : general

=cut

sub new {
  my ($class, @args) = @_;
  my $self = bless {}, $class;

  if (scalar @args) {
    #do this explicitly.
    my ($dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = rearrange([qw(DNAFRAG_ID DNAFRAG_START DNAFRAG_END DNAFRAG_STRAND)], @args);

    $dnafrag_id && $self->dnafrag_id($dnafrag_id);
    $dnafrag_start && $self->dnafrag_start($dnafrag_start);
    $dnafrag_end && $self->dnafrag_end($dnafrag_end);
    $dnafrag_strand && $self->dnafrag_strand($dnafrag_strand);
  }

  return $self;
}


=head2 new_fast

  Arg 1       : hash reference $hashref
  Example     : none
  Description : This is an ultra fast constructor which requires knowledge of
                the objects internals to be used.
  Returntype  : Bio::EnsEMBL::Compara::Locus object
  Exceptions  : none
  Caller      : general

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}


=head2 dnafrag_id

  Arg 1       : (optional) integer $dnafrag_id
  Example     : my $dnafrag_id = $dnafrag->dnafrag_id;
  Description : Getter/setter for the dnafrag_id attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_id {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_id'} = $value;
  }

  return $obj->{'dnafrag_id'};
}


=head2 dnafrag_start

  Arg 1       : (optional) integer $dnafrag_start
  Example     : my $dnafrag_start = $dnafrag->dnafrag_start;
  Description : Getter/setter for the dnafrag_start attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_start {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_start'} = $value;
  }

  return $obj->{'dnafrag_start'};
}


=head2 dnafrag_end

  Arg 1       : (optional) integer $dnafrag_end
  Example     : my $dnafrag_end = $dnafrag->dnafrag_end;
  Description : Getter/setter for the dnafrag_end attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_end {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_end'} = $value;
  }

  return $obj->{'dnafrag_end'};
}


=head2 dnafrag_strand

  Arg 1       : (optional) integer $dnafrag_strand
  Example     : my $dnafrag_strand = $dnafrag->dnafrag_strand;
  Description : Getter/setter for the dnafrag_strand attribute
  Returntype  : integer (1 or -1)
  Exceptions  : none
  Caller      : general

=cut

sub dnafrag_strand {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dnafrag_strand'} = $value;
  }

  return $obj->{'dnafrag_strand'};
}


=head2 dnafrag

  Arg 1       : (optional) Bio::EnsEMBL::Compara::DnaFrag object
  Example     : $dnafrag = $locus->dnafrag;
  Description : Getter/setter for the Bio::EnsEMBL::Compara::DnaFrag object
                corresponding to this Bio::EnsEMBL::Compara::Locus object.
  Returntype  : Bio::EnsEMBL::Compara::Dnafrag object
  Exceptions  : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
                coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
                cannot be retrieved and returns undef.
  Caller      : $object->methodname

=cut

sub dnafrag {
  my ($self) = shift @_;

  if (@_) {
    $self->{'_dnafrag'} = shift @_;
  } elsif (!defined $self->{'_dnafrag'}) {
    if (!defined($self->dnafrag_id)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::DnaFrag object without dbID";
      return undef;
    }
    my $dfa = $self->adaptor->db->get_DnaFragAdaptor;
    if (!defined($dfa)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor";
      return undef;
    }
    $self->{'_dnafrag'} = $dfa->fetch_by_dbID($self->dnafrag_id);
  }
  return $self->{'_dnafrag'};
}


=head2 slice

  Arg 1       : -none-
  Example     : $slice = $locus->slice;
  Description : Returns the Bio::EnsEMBL::Slice object corresponding to this
                Bio::EnsEMBL::Compara::DnaFrag object.
  Returntype  : Bio::EnsEMBL::Slice object
  Exceptions  : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
                coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
                cannot be retrieved and returns undef.
  Caller      : $object->methodname

=cut

sub slice {
  my ($self) = @_;

  unless (defined $self->{'_slice'}) {
    if (!defined($self->dnafrag->genome_db)) {
      warn "Cannot get the Bio::EnsEMBL::Compara::GenomeDB object corresponding to [".$self."]";
      return undef;
    }
    if (!defined($self->dnafrag->coord_system_name)) {
      warn "Cannot get the coord_system_name corresponding to [".$self."]";
      return undef;
    }
    if (!defined($self->dnafrag->name)) {
      warn "Cannot get the name corresponding to [".$self."]";
      return undef;
    }
    my $dba = $self->dnafrag->genome_db->db_adaptor;
    if (!defined($dba)) {
      warn "Cannot get the Bio::EnsEMBL::DBSQL::DBAdaptor corresponding to [".$self->dnafrag->genome_db."]";
      return undef;
    }
    $self->{'_slice'} = $dba->get_SliceAdaptor->fetch_by_region($self->dnafrag->coord_system_name, $self->dnafrag->name,$self->dnafrag_start, $self->dnafrag_end, $self->dnafrag_strand);
  }

  return $self->{'_slice'};
}


=head2 genome_db

  Arg 1       : -none-
  Example     : $genome_db = $locus->genome_db;
  Description : Returns the Bio::EnsEMBL::Compara::GenomeDB object corresponding to this
                Bio::EnsEMBL::Compara::Locus object. This method is a shortcut
                for $locis->dnafrag->genome_db
  Returntype  : Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions  : return undef if no dnafrag can be found for this Locus object.
                See dnafrag method elsewhere in this document.
  Caller      : $object->methodname

=cut

sub genome_db {
  my ($self) = @_;

  if ($self->dnafrag) {
    return $self->dnafrag->genome_db;
  }

  return undef;
}


1;
