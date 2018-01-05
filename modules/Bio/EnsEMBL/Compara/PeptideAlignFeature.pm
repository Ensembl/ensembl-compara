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

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::Utils::Cigars;

#se overload '<=>' => "sort_by_score_evalue_and_pid";   # named method

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


sub create_homology
{
  my $self = shift;

  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;

  my $cigar_line = $self->cigar_line;
  $cigar_line =~ s/I/M/g;
  $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::collapse_cigar(Bio::EnsEMBL::Compara::Utils::Cigars::expand_cigar($cigar_line));
  $self->query_member->cigar_line($cigar_line);

  $cigar_line = $self->cigar_line;
  $cigar_line =~ s/D/M/g;
  $cigar_line =~ s/I/D/g;
  $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::collapse_cigar(Bio::EnsEMBL::Compara::Utils::Cigars::expand_cigar($cigar_line));
  $self->hit_member->cigar_line($cigar_line);

  $homology->add_Member($self->query_member);
  $homology->add_Member($self->hit_member);
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
