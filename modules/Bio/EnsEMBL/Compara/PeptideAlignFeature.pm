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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PeptideAlignFeature

=head1 SYNOPSIS

      # Get an $homology object somehow

      # For Homology PeptideAlignFeatures, you normally get 2 pafs,
      # one for each member used alternatively as query and database
      # (hit) in the blast run

      foreach my $paf (@{$pafs}) {
        print $paf->query_member->stable_id," ",$self->hit_member->stable_id," ",$paf->evalue,"\n";
      }

      # Other stuff in the object:
      # $paf->qstart
      # $paf->qend
      # $paf->hstart
      # $paf->hend
      # $paf->score
      # $paf->alignment_length
      # $paf->identical_matches
      # $paf->perc_ident
      # $paf->positive_matches
      # $paf->perc_pos
      # $paf->hit_rank
      # $paf->cigar_line

=head1 DESCRIPTION

Object that describes a blast hit between two proteins (seq_members)

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::PeptideAlignFeature;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Utils::Cigars;

#se overload '<=>' => "sort_by_score_evalue_and_pid";   # named method

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods

sub create_aligned_member {
    my $self = shift;

    # Create new superficial AlignedMembers to attach the homologies
    my $aligned_member_1 = Bio::EnsEMBL::Compara::AlignedMember->new(
        -stable_id => $self->query_member->gene_member->stable_id,
        -source_name => $self->query_member->gene_member->source_name,
        -genome_db_id => $self->query_genome_db_id,
    );
    my $aligned_member_2 = Bio::EnsEMBL::Compara::AlignedMember->new(
        -stable_id => $self->hit_member->gene_member->stable_id,
        -source_name => 'EXTERNALGENE',
        -genome_db_id => $self->hit_genome_db_id,
    );

    $aligned_member_1->gene_member($self->query_member->gene_member);
    $aligned_member_1->gene_member_id($self->query_member->gene_member->dbID);
    $aligned_member_1->seq_member_id($self->query_member_id);

    $aligned_member_2->gene_member($self->hit_member->gene_member);
    $aligned_member_2->gene_member_id($self->hit_member->gene_member->dbID);
    $aligned_member_2->seq_member_id($self->hit_member_id);

    # Assign cigar_line to each member
    my $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::collapse_cigar(Bio::EnsEMBL::Compara::Utils::Cigars::expand_cigar($self->cigar_line));
    $aligned_member_1->cigar_line($cigar_line);
    $aligned_member_2->cigar_line($cigar_line);

    # Reassign query_member and hit_member with AlignedMembers
    $self->query_member($aligned_member_1);
    $self->hit_member($aligned_member_2);

}

sub create_homology {
    my ($self, $type, $homology_mlss) = @_;

    # Create the homology object
    my $homology = new Bio::EnsEMBL::Compara::Homology;
    $homology->method_link_species_set($homology_mlss);

    # Ensure the members are Bio::EnsEMBL::Compara::AlignedMember objects
    unless (UNIVERSAL::isa($self->hit_member, 'Bio::EnsEMBL::Compara::AlignedMember')) {
        $self->create_aligned_member;
    }

    $homology->add_Member($self->query_member);
    $homology->add_Member($self->hit_member);
    $homology->description($type) if $type;
    $homology->is_tree_compliant(0);

    $homology->update_alignment_stats;

    return $homology;
}




##########################
#
# getter/setter methods
#
##########################

sub query_member {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::Member] not a [$arg]")
        unless($arg->isa('Bio::EnsEMBL::Compara::Member'));
    $self->{'_query_member'} = $arg;
  }
  return $self->{'_query_member'};
}

sub query_member_id {
  my $self = shift;
  $self->{'_query_member_id'} = shift if (@_);
  if ($self->{'_query_member_id'}) {
    return $self->{'_query_member_id'};
  } elsif ($self->{'_query_member'} and $self->{'_query_member'}->dbID) {
    return $self->{'_query_member'}->dbID;
  }
  return undef;
}

sub query_genome_db_id {
  my $self = shift;
  $self->{'_query_genome_db_id'} = shift if (@_);
  if ($self->{'_query_genome_db_id'}) {
    return $self->{'_query_genome_db_id'};
  } elsif ($self->{'_query_member'} and $self->{'_query_member'}->genome_db
      and $self->{'_query_member'}->genome_db->dbID) {
    return $self->{'_query_member'}->genome_db->dbID;
  }
  return undef;
}

sub hit_member {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::Member] not a [$arg]")
        unless($arg->isa('Bio::EnsEMBL::Compara::Member'));
    $self->{'_hit_member'} = $arg;
  }
  return $self->{'_hit_member'};
}

sub hit_member_id {
  my $self = shift;
  $self->{'_hit_member_id'} = shift if (@_);
  if ($self->{'_hit_member_id'}) {
    return $self->{'_hit_member_id'};
  } elsif ($self->{'_hit_member'} and $self->{'_hit_member'}->dbID) {
    return $self->{'_hit_member'}->dbID;
  }
  return undef;
}

sub hit_genome_db_id {
  my $self = shift;
  $self->{'_hit_genome_db_id'} = shift if (@_);
  if ($self->{'_hit_genome_db_id'}) {
    return $self->{'_hit_genome_db_id'};
  } elsif ($self->{'_hit_member'} and $self->{'_hit_member'}->genome_db
      and $self->{'_hit_member'}->genome_db->dbID) {
    return $self->{'_hit_member'}->genome_db->dbID;
  }
  return undef;
}

sub  qstart {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_qstart} = $arg;
  }
  return $self->{_qstart};
}

sub  hstart {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hstart} = $arg;
  }
  return $self->{_hstart};
}

sub  qend {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_qend} = $arg;
  }
  return $self->{_qend};
}

sub  qlength {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_qlength} = $arg;
  }
  return $self->{_qlength};
}

sub  hend {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hend} = $arg;
  }
  return $self->{_hend};
}

sub  hlength{
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hlength} = $arg;
  }
  return $self->{_hlength};
}

sub score{
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_score} = $arg;
  }
  return $self->{_score};
}

sub evalue {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_evalue} = $arg;
  }
  return $self->{_evalue};
}

sub perc_ident {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_perc_ident} = $arg;
  }
  return $self->{_perc_ident};
}

sub perc_pos {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_perc_pos} = $arg;
  }
  return $self->{_perc_pos};
}

sub identical_matches {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_identical_matches} = $arg;
    if(defined($self->alignment_length)) {
      $self->perc_ident(int($arg*100/$self->alignment_length));
    }
  }
  return $self->{_identical_matches};
}

sub positive_matches {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_positive_matches} = $arg;
    if(defined($self->alignment_length)) {
      $self->perc_pos(int($arg*100/$self->alignment_length));
    }
  }
  return $self->{_positive_matches};
}

sub alignment_length {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_alignment_length} = $arg;
  }
  return $self->{_alignment_length};
}

sub cigar_line {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_cigar_line} = $arg;
  }
  return $self->{_cigar_line};
}

sub hit_rank {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hit_rank} = $arg;
  }
  return $self->{_hit_rank};
}

sub rhit_dbID {
  my ( $self, $dbID ) = @_;
  $self->{'_rhit_dbID'} = $dbID if defined $dbID;
  return $self->{'_rhit_dbID'};
}

sub toString {
  my($self) = @_;

  unless(defined($self)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\thit_rank\n");
    return;
  }

  my $qm = $self->query_member;
  my $hm = $self->hit_member;
  my $dbID = $self->dbID;  $dbID = '' unless($dbID);

  my $header = "PAF(".$dbID.")";
  $header .= "(".$self->rhit_dbID.")" if($self->rhit_dbID);
  while(length($header)<17) { $header .= ' '; }

  my $qmem = sprintf("%s(%d,%d)(%s:%d)",
        $qm->stable_id, $self->qstart, $self->qend, $qm->dnafrag->name, $qm->dnafrag_start);
  my $hmem = sprintf("%s(%d,%d)(%s:%d)",
        $hm->stable_id, $self->hstart, $self->hend, $hm->dnafrag->name, $hm->dnafrag_start);
  while(length($qmem)<50) { $qmem .= ' '; }
  while(length($hmem)<50) { $hmem .= ' '; }


  my $desc_string = sprintf("%s%s%s%7.3f%7d%7d%7d%7d",
        $header, $qmem, $hmem,
        $self->score,
        $self->alignment_length,
        $self->perc_ident,
        $self->perc_pos,
        $self->hit_rank);

  return $desc_string;
}


1;
