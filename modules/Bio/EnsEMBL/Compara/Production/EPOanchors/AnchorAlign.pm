=head1 NAME - Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Ensembl-dev mailing list <ensembl-dev@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign;

use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception;

sub new {
    my($class, @args) = @_;

    my $self = {};
    bless $self,$class;

    ## First lines are for backward compatibility, middle one is for both versions and
    ## last ones are for the new schema
    my ($adaptor, $dbID, $method_link_species_set, $method_link_species_set_id, $anchor_id,
        $dnafrag, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand,
        $score, $num_of_organisms, $num_of_sequences, $anchor_status) =
      rearrange([qw(
          ADAPTOR DBID METHOD_LINK_SPECIES_SET METHOD_LINK_SPECIES_SET_ID ANCHOR_ID
          DNAFRAG DNAFRAG_ID DNAFRAG_START DNAFRAG_END DNAFRAG_STRAND
          SCORE NUM_OF_ORGANISMS NUM_OF_SEQUENCES ANCHOR_STATUS)], @args);

    $self->adaptor($adaptor) if (defined($adaptor));
    $self->dbID($dbID) if (defined($dbID));
    $self->method_link_species_set($method_link_species_set) if (defined($method_link_species_set));
    $self->method_link_species_set_id($method_link_species_set_id) if (defined($method_link_species_set_id));
    $self->anchor_id($anchor_id) if (defined($anchor_id));
    $self->dnafrag($dnafrag) if (defined($dnafrag));
    $self->dnafrag_id($dnafrag_id) if (defined($dnafrag_id));
    $self->dnafrag_start($dnafrag_start) if (defined($dnafrag_start));
    $self->dnafrag_end($dnafrag_end) if (defined($dnafrag_end));
    $self->dnafrag_strand($dnafrag_strand) if (defined($dnafrag_strand));
    $self->score($score) if (defined($score));
    $self->num_of_organisms($num_of_organisms) if (defined($num_of_organisms));
    $self->num_of_sequences($num_of_sequences) if (defined($num_of_sequences));
    $self->anchor_status($anchor_status) if (defined($anchor_status));
    return $self;
}

sub adaptor {
  my $self = shift;
  if (@_) {
    $self->{_adaptor} = shift;
  }
  return $self->{_adaptor};
}

sub dbID {
  my $self = shift;
  if (@_) {
    $self->{_dbID} = shift;
  }
  return $self->{_dbID};
}

sub method_link_species_set {
  my $self = shift;
  if (@_) {
    $self->{_method_link_species_set} = shift;
  }
  return $self->{_method_link_species_set};
}

sub method_link_species_set_id {
  my $self = shift;
  if (@_) {
    $self->{_method_link_species_set_id} = shift;
  }
  if (!defined($self->{_method_link_species_set_id}) and defined($self->{_method_link_species_set})) {
    $self->{_method_link_species_set_id} = $self->{_method_link_species_set}->dbID;
  }
  return $self->{_method_link_species_set_id};
}

sub anchor_id {
  my $self = shift;
  if (@_) {
    $self->{_anchor_id} = shift;
  }
  return $self->{_anchor_id};
}

sub dnafrag {
  my $self = shift;
  if (@_) {
    $self->{_dnafrag} = shift;
  } elsif (!$self->{_dnafrag} and $self->{_dnafrag_id} and $self->{_adaptor}) {
    $self->{_dnafrag} = $self->{_adaptor}->db->get_DnaFragAdaptor->fetch_by_dbID($self->{_dnafrag_id});
  }
  return $self->{_dnafrag};
}

sub dnafrag_id {
  my $self = shift;
  if (@_) {
    $self->{_dnafrag_id} = shift;
  }
  if (!defined($self->{_dnafrag_id}) and defined($self->{_dnafrag})) {
    $self->{_dnafrag_id} = $self->{_dnafrag}->dbID;
  }
  return $self->{_dnafrag_id};
}

sub dnafrag_start {
  my $self = shift;
  if (@_) {
    $self->{_dnafrag_start} = shift;
  }
  return $self->{_dnafrag_start};
}

sub dnafrag_end {
  my $self = shift;
  if (@_) {
    $self->{_dnafrag_end} = shift;
  }
  return $self->{_dnafrag_end};
}

sub dnafrag_strand {
  my $self = shift;
  if (@_) {
    $self->{_dnafrag_strand} = shift;
  }
  return $self->{_dnafrag_strand};
}

sub score {
  my $self = shift;
  if (@_) {
    $self->{_score} = shift;
  }
  return $self->{_score};
}

sub num_of_organisms {
  my $self = shift;
  if (@_) {
    $self->{_num_of_organisms} = shift;
  }
  return $self->{_num_of_organisms};
}

sub num_of_sequences {
  my $self = shift;
  if (@_) {
    $self->{_num_of_sequences} = shift;
  }
  return $self->{_num_of_sequences};
}

sub anchor_status {
  my $self = shift;
  if (@_) {
	$self->{_anchor_status} = shift;
  }
  return $self->{_anchor_status};
}

sub seq {
  my $self = shift;
  return $self->{'_seq'} if ($self->{'_seq'});

  my $seq = $self->dnafrag->slice()->subseq($self->{'_dnafrag_start'},
      $self->{'_dnafrag_end'}, $self->{'_dnafrag_strand'});
  $self->{'_seq'} = $seq;

  return $self->{'_seq'};
}

1;
