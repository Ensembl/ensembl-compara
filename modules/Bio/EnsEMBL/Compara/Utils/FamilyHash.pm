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

use strict;
use warnings;

package Bio::EnsEMBL::Compara::Utils::FamilyHash;
use Data::Dumper;
use namespace::autoclean;
use Bio::EnsEMBL::Utils::Scalar qw(check_ref);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

sub convert {
  my ($caller, $fam, @args) = @_;
  my $self = bless {}, $caller;
  my ($member_source, $aligned, $no_seq, $seq_type, $cdna, $cigar_line, $prune_species, $prune_taxons) =
        rearrange([qw(MEMBER_SOURCE ALIGNED NO_SEQ SEQ_TYPE CIGAR_LINE )], @args);

  if (defined $aligned) {
      $self->aligned($aligned);
  }
  if (defined $cdna) {
      $self->cdna($cdna);
  }
  $self->no_seq($no_seq);
  $self->seq_type($seq_type);
  $self->cigar_line($cigar_line);
  $self->member_src($member_source);

  $self->{_cached_seq_aligns} = {};
=head
  if ($aligned) {
      my $aln = $fam->get_SimpleAlign(-SEQ_TYPE => ($self->cdna ? 'cds' : undef), -REMOVE_GAPS => 1);
      foreach my $seq ($aln->each_seq) {
          $self->{_cached_seq_aligns}->{$seq->display_id} = $seq->seq;
      }
  } else {
      delete $self->{_cached_seq_aligns};
  }
=cut
  return $self->_family_object_to_hash($fam);
}

sub member_src {
  my ($self, $member_source) = @_;
  if (defined ($member_source)) {
        $self->{_member_source} = $member_source;
    }
    return $self->{_member_source};
}

sub aligned {
    my ($self, $aligned) = @_;
    if (defined ($aligned)) {
        $self->{_aligned} = $aligned;
    }
    return $self->{_aligned};
}

sub no_seq {
    my ($self, $no_seq) = @_;
    if (defined ($no_seq)) {
        $self->{_no_seq} = $no_seq;
    }
    return $self->{_no_seq};
} 

sub seq_type {
    my ($self, $seq_type) = @_;
    if (defined ($seq_type)) {
        $self->{_seq_type} = $seq_type;
    }
    return $self->{_seq_type};
}

sub cdna {
    my ($self, $cdna) = @_;
    if (defined ($cdna)) {
        $self->{_cdna} = $cdna;
    }
    return $self->{_cdna};
}

sub cigar_line {
    my ($self, $cigar_line) = @_;
    if (defined ($cigar_line)) {
        $self->{_cigar_line} = $cigar_line;
    }
    return $self->{_cigar_line};
}

sub _family_object_to_hash {
  my ($self, $fam) = @_;
  my $hash = {
    type => 'family',
  };

  if($fam->can('stable_id')) {
    $hash->{id} = $fam->stable_id();
  }    

  # Bulk-load of all we need
  my $compara_dba = $fam->adaptor->db;
  my $members = $fam->get_all_Members;
  if (($self->{_member_source} eq 'all') || ($self->{_member_source} eq 'ensembl') ) { 
    $hash->{MEMBERS}{ENSEMBL_gene_members}={};
  }
  if ( ($self->{_member_source} eq 'all') || ($self->{_member_source} eq 'uniprot') ) {
    $hash->{MEMBERS}{UNIPROT_proteins}=[];
  }

  foreach my $this_member (@{$members}) {
    if  ( ($this_member->source_name() eq 'ENSEMBLPEP') and ( ($self->{_member_source} eq 'all') || ($self->{_member_source} eq 'ensembl') ) ){
      my $gene_mem_stable_id = $this_member->gene_member->stable_id();
      if (! defined $hash->{MEMBERS}{ENSEMBL_gene_members}{$gene_mem_stable_id} ){
        $hash->{MEMBERS}{ENSEMBL_gene_members}{$gene_mem_stable_id} = [];
      }
      my $temp_hash = {protein_stable_id => $this_member->stable_id() };
      if ($self->aligned) { 
        $temp_hash->{protein_alignment} = $this_member->alignment_string($self->seq_type);
      }
      elsif (!$self->no_seq) {
        $temp_hash->{seq} = $this_member->other_sequence($self->seq_type);
      }
      push @{ $hash->{MEMBERS}{ENSEMBL_gene_members}{$gene_mem_stable_id} }, $temp_hash;
    }

    if ( ($this_member->source_name() =~ /Uniprot/) and ( ($self->{_member_source} eq 'all') || ($self->{_member_source} eq 'uniprot') ) ) {

      my $temp_hash1 = {protein_stable_id => $this_member->stable_id() };
      if ($self->aligned) { 
        $temp_hash1->{protein_alignment} = $this_member->alignment_string($self->seq_type);
      }
      elsif (!$self->no_seq) {
        $temp_hash1->{seq} = $this_member->other_sequence($self->seq_type);
      }
      push @{ $hash->{MEMBERS}{UNIPROT_proteins} }, $temp_hash1;
    }
  }
  return $hash;
}
1;
