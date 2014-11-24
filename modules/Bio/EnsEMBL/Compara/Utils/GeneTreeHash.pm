=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::Utils::GeneTreeHash;

use namespace::autoclean;
use Bio::EnsEMBL::Utils::Scalar qw(check_ref);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

sub convert {
  my ($self, $tree, @args) = @_;

  my ($no_sequences, $aligned, $cdna, $species_common_name, $exon_boundaries, $gaps, $full_tax_info) = rearrange([qw(NO_SEQUENCES ALIGNED CDNA SPECIES_COMMON_NAME EXON_BOUNDARIES GAPS FULL_TAX_INFO)], @args);

  if (defined $no_sequences) {
      $self->no_sequences($no_sequences);
  }
  if (defined $aligned) {
      $self->aligned($aligned);
  }
  if (defined $cdna) {
      $self->cdna($cdna);
  }
  if (defined $species_common_name) {
      $self->species_common_name($species_common_name);
  }
  if (defined $exon_boundaries) {
      $self->exon_boundaries($exon_boundaries);
  }
  if (defined $gaps) {
      $self->gaps($gaps);
  }
  if (defined $full_tax_info) {
    $self->full_tax_info($full_tax_info);
  }

  return $self->_head_node($tree);
}

sub no_sequences {
    my ($self, $no_seq) = @_;
    if (defined ($no_seq)) {
        $self->{_no_sequences} = $no_seq;
    }
    return $self->{_no_sequences};
}

sub aligned {
    my ($self, $aligned) = @_;
    if (defined ($aligned)) {
        $self->{_aligned} = $aligned;
    }
    return $self->{_aligned};
}

sub cdna {
    my ($self, $cdna) = @_;
    if (defined ($cdna)) {
        $self->{_cdna} = $cdna;
    }
    return $self->{_cdna};
}

sub species_common_name {
    my ($self, $sp_flag) = @_;
    if (defined ($sp_flag)) {
        $self->{_species_common_name} = $sp_flag;
    }
    return $self->{_species_common_name};
}

sub exon_boundaries {
    my ($self, $exon_boundaries) = @_;
    if (defined ($exon_boundaries)) {
        $self->{_exon_boundaries} = $exon_boundaries;
    }
    return $self->{_exon_boundaries};
}

sub gaps {
    my ($self, $gaps) = @_;
    if (defined ($gaps)) {
        $self->{_gaps} = $gaps;
    }
    return $self->{_gaps};
}

sub full_tax_info {
  my ($self, $fti) = @_;
  if (defined ($fti)) {
    $self->{_full_tax_info} = $fti;
  }
  return $self->{_fti};
}

sub _head_node {
  my ($self, $tree) = @_;
  my $hash = {
    type => 'gene tree',
    rooted => 1,
  };

  if($tree->can('stable_id')) {
    $hash->{id} = $tree->stable_id();
  }

  $hash->{tree} = 
    $self->_recursive_conversion($tree->root());

  return $hash;
}

sub _recursive_conversion {
  my ($self, $tree) = @_;
  my $new_hash = $self->_convert_node($tree);
  if($tree->get_child_count()) {
    my @converted_children;
    foreach my $child (@{$tree->sorted_children()}) {
      my $converted_child = $self->_recursive_conversion($child);
      push(@converted_children, $converted_child);
    }
    $new_hash->{children} = \@converted_children;
  }
  return $new_hash;
}

sub _convert_node {
  my ($self, $node) = @_;
  my $hash;

  my $type  = $node->get_tagvalue('node_type');
  my $boot  = $node->get_tagvalue('bootstrap');
  my $dcs   = $node->duplication_confidence_score();
  my $tax   = $node->species_tree_node();

  $hash->{branch_length} = $node->distance_to_parent() + 0;
  if($tax) {
      my $taxon = $tax->taxon;
      $hash->{taxonomy} = { id => $tax->taxon_id + 0,
                            scientific_name => $tax->node_name,
                          };
      if ($self->full_tax_info()) {
	$hash->{taxonomy}{alias_name} = $taxon->ensembl_alias_name;
	$hash->{taxonomy}{timetree_mya} = $taxon->get_tagvalue('ensembl timetree mya') || 0 + 0;
      }
  }
  $hash->{confidence} = {};
  if ($boot) {
    $hash->{confidence}{boostrap} = $boot + 0;
  }
  if ($dcs) {
    $hash->{confidence}{duplication_confidence_score} = $dcs + 0;
  }
  if($type) { # && $type ~~ [qw/duplication dubious/]) {
    $hash->{events} = { type => $type };
  }


  # Gaps -- on members and internal nodes
  if ($self->gaps) {
      my $no_gap_blocks = [];

      my $cigar_line = check_ref ($node, 'Bio::EnsEMBL::Compara::GeneTreeMember')
          ? $node->cigar_line
              : $node->consensus_cigar_line;

      my @inters = split (/([MmDG])/, $cigar_line);
      my $ms = 0;
      my $box_start = 0;
      my $box_end = 0;
      while (@inters) {
          $ms = (shift (@inters) || 1);
          my $mtype = shift (@inters);
          $box_end = $box_start + $ms;
          if ($node->isa ('Bio::EnsEMBL::Compara::GeneTreeMember')) {
              if ($mtype eq 'M') {
                  push @$no_gap_blocks, {"start" => $box_start,
                                         "end" => $box_end,
                                         "type" => 'low'
                                        };
              }
          } else {
              if ($mtype eq 'M') {
                  push @$no_gap_blocks, {"start" => $box_start,
                                         "end" => $box_end,
                                         "type" => "high"
                                        }
              } elsif ($mtype eq 'm') {
                  push @$no_gap_blocks, {"start" => $box_start,
                                         "end" => $box_end,
                                         "type" => 'low'
                                        };
              }
          }

          $box_start = $box_end;
      }
      $hash->{no_gaps} = $no_gap_blocks;
  }

  if(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeMember')) {
    my $gene = $node->gene_member();

    # exon boundaries
    if ($self->exon_boundaries) {
        my $aligned_sequence_bounded_by_exon = $node->alignment_string('exon_bounded');
        my @bounded_exons = split ' ', $aligned_sequence_bounded_by_exon;
        pop @bounded_exons;

        my $aligned_exon_lengths = [ map length ($_), @bounded_exons ];

        my $aligned_exon_positions = [];
        my $exon_end;
        for my $exon_length (@$aligned_exon_lengths) {
            $exon_end += $exon_length;
            push @$aligned_exon_positions, $exon_end;
        }

        $hash->{exon_boundaries} = {
                                    num_exons => scalar @$aligned_exon_positions,
                                    positions => $aligned_exon_positions
                                   };
    }

    $hash->{id} = { source => "EnsEMBL", accession => $gene->stable_id() };

    my $genome_db = $node->genome_db();
    my $taxid = $genome_db->taxon_id();

    my $taxon = $genome_db->taxon;
    $hash->{taxonomy} = 
      { id => $taxid + 0,
        scientific_name => $taxon->scientific_name(),
      }
	if $taxid;

    if ($self->species_common_name) {
        $hash->{taxonomy}->{common_name} = $genome_db->taxon->ensembl_alias_name;
    }

    $hash->{sequence} = 
      { 
       # type     => 'protein', # are we sure we always have proteins?
       id       => [ { source => 'EnsEMBL', accession => $node->stable_id() } ],
       location => sprintf('%s:%d-%d',$gene->dnafrag()->name(), $gene->dnafrag_start(), $gene->dnafrag_end())
      };
    $hash->{sequence}->{name} = $node->display_label() if $node->display_label();

    unless($self->no_sequences()) {
        my $aligned = $self->aligned();
        my $mol_seq;
        if($aligned) {
            $mol_seq = ($self->cdna()) ? $node->alignment_string('cds') : $node->alignment_string();
        }
        else {
            $mol_seq = ($self->cdna()) ? $node->other_sequence('cds') : $node->sequence();
        }
        $hash->{sequence}->{mol_seq} = { is_aligned => $aligned + 0, seq => $mol_seq };
    }
}
  return $hash;
}

1;
