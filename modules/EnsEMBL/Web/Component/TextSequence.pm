# $Id$

package EnsEMBL::Web::Component::TextSequence;

use strict;

use URI::Escape qw(uri_unescape);
use HTTP::Request;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

use Sanger::Graphics::ColourMap;

use EnsEMBL::Web::Document::Renderer::Assembler;
use EnsEMBL::Web::Fake;

use base qw(EnsEMBL::Web::Component);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new(@_);
  
  $self->{'key_types'}  = [qw(codons conservation population resequencing align_change)];
  $self->{'key_params'} = [qw(gene_name gene_exon_type alignment_numbering match_display)];
  
  return $self;
}

sub colour_map { return $_[0]->{'colour_map'} ||= new Sanger::Graphics::ColourMap; }

# Used by Compara_Alignments, Gene::GeneSeq and Location::SequenceAlignment
sub get_sequence_data {
  my $self = shift;
  my ($slices, $config) = @_;
  
  my $object = $self->object;
  my @sequence;
  my @markup;
  my $population;
  
  if ($config->{'snp_display'}) {
    my $filter = $object->param('population_filter');
    
    if ($filter && $filter ne 'off') {
      $population = $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter);
      $config->{'min_frequency'} = $object->param('min_frequency');
      $config->{'population_filter'} = $filter;
    }
  }
  
  foreach my $sl (@$slices) {
    my $mk    = {};
    my $slice = $sl->{'slice'};
    my $name  = $sl->{'name'};
    my $seq   = uc($sl->{'seq'} || $slice->seq(1));
    
    my ($slice_start, $slice_end, $slice_length, $slice_strand) = ($slice->start, $slice->end, $slice->length, $slice->strand);
    
    $config->{'length'} ||= $slice_length;
    
    if ($config->{'match_display'}) {
      if ($name eq $config->{'ref_slice_name'}) {
        push @sequence, [ map {{ letter => $_ }} @{$config->{'ref_slice_seq'}} ];
      } else {
        my $i = 0;
        my @cmp_seq = map {{ letter => ($config->{'ref_slice_seq'}->[$i++] eq $_ ? '.' : $_) }} split //, $seq;

        while ($seq =~ m/([^~]+)/g) {
          my $reseq_length = length $1;
          my $reseq_end    = pos $seq;
          
          $mk->{'comparisons'}->{$reseq_end-$_}->{'resequencing'} = 1 for 1..$reseq_length;
        }
        
        push @sequence, \@cmp_seq;
      }
    } else {
      push @sequence, [ map {{ letter => $_ }} split //, $seq ];
    }
    
    if ($config->{'region_change_display'} && $name ne $config->{'species'}) {
      my $s = 0;
      
      # We don't want to mark the very end of the sequence, so don't loop for the last element in the array
      for (0..scalar(@{$sl->{'underlying_slices'}})-2) {
        my $end_region   = $sl->{'underlying_slices'}->[$_];
        my $start_region = $sl->{'underlying_slices'}->[$_+1];
        
        $s += length $end_region->seq(1);
        
        $mk->{'region_change'}->{$s-1} = $end_region->name   . ' END';
        $mk->{'region_change'}->{$s}   = $start_region->name . ' START';

        for ($s-1..$s) {
          $mk->{'region_change'}->{$_} = "GAP $1" if $mk->{'region_change'}->{$_} =~ /.*gap.* (\w+)/;
        }
      }
    }
    
    # Markup inserts on comparisons
    if ($config->{'align'}) {
      while ($seq =~  m/(\-+)[\w\s]/g) {
        my $ins_length = length $1;
        my $ins_end    = pos($seq) - 1;
        
        $mk->{'comparisons'}->{$ins_end-$_}->{'insert'} = "$ins_length bp" for 1..$ins_length;
      }
    }
    
    # Get variations
    if ($config->{'snp_display'}) {
      my $snps   = [];
      my $u_snps = {};
      
      eval {
        $snps = $population ? $slice->get_all_VariationFeatures_by_Population($population, $config->{'min_frequency'}) : $slice->get_all_VariationFeatures(1);
      };
      
      if (scalar @$snps) {
        foreach my $u_slice (@{$sl->{'underlying_slices'}||[]}) {
          next if $u_slice->seq_region_name eq 'GAP';
          
          if (!$u_slice->adaptor) {
            my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($name, $config->{'db'}, 'slice');
            $u_slice->adaptor($slice_adaptor);
          }
          
          eval {
            map { $u_snps->{$_->variation_name} = $_ } @{$u_slice->get_all_VariationFeatures};
          };
        }
      }
      
      # Put 1bp snps second, so that they will overwrite the markup of other variations in the same location
      my @ordered_snps = map $_->[1], sort { $a->[0] <=> $b->[0] } map [ $_->end == $_->start ? 1 : 0, $_ ], @$snps;
      
      foreach (@ordered_snps) {
        #my $snp_type       = 'snp';
        my $snp_type       = $_->can('display_consequence') ? lc $_->display_consequence : 'snp';
        my $variation_name = $_->variation_name;
        my $var_class      = $_->can('var_class') ? $_->var_class : $_->can('variation') && $_->variation ? $_->variation->var_class : '';
        my $dbID           = $_->dbID;
        my $start          = $_->start;
        my $end            = $_->end;
        my $alleles        = $_->allele_string;
        
        # If gene is reverse strand we need to reverse parts of allele, i.e AGT/- should become TGA/-
        if ($slice_strand < 0) {
          my @al = split /\//, $alleles;
          
          $alleles  = '';
          $alleles .= reverse($_) . '/' for @al;
          $alleles  =~ s/\/$//;
        }
      
        # If the variation is on reverse strand, flip the bases
        $alleles =~ tr/ACGTacgt/TGCAtgca/ if $_->strand < 0;
        
        # Use the variation from the underlying slice if we have it.
        my $snp = scalar keys %$u_snps ? $u_snps->{$variation_name} : $_;
        
        # Co-ordinates relative to the region - used to determine if the variation is an insert or delete
        my $seq_region_start = $snp->seq_region_start;
        my $seq_region_end   = $snp->seq_region_end;
        
        # If it's a mapped slice, get the coordinates for the variation based on the reference slice
        if ($config->{'mapper'}) {
          # Constrain region to the limits of the reference slice
          $start = $seq_region_start < $config->{'ref_slice_start'} ? $config->{'ref_slice_start'} : $seq_region_start;
          $end   = $seq_region_end   > $config->{'ref_slice_end'}   ? $config->{'ref_slice_end'}   : $seq_region_end;
          
          my $func            = $seq_region_start > $seq_region_end ? 'map_indel' : 'map_coordinates';
          my ($mapped_coords) = $config->{'mapper'}->$func($snp->seq_region_name, $start, $end, $snp->seq_region_strand, 'ref_slice');
          
          # map_indel will fail if the strain slice is the same as the reference slice, and there's currently no way to check if this is the case beforehand. Stupid API.
          ($mapped_coords) = $config->{'mapper'}->map_coordinates($snp->seq_region_name, $start, $end, $snp->seq_region_strand, 'ref_slice') if $func eq 'map_indel' && !$mapped_coords;
          
          $start = $mapped_coords->start;
          $end   = $mapped_coords->end;
        }
        
        # Co-ordinates relative to the sequence - used to mark up the variation's position
        my $s = $start - 1;
        my $e = $end   - 1;
        
        # Co-ordinates to be used in link text - will use $start or $seq_region_start depending on line numbering style
        my ($snp_start, $snp_end);
        
        if ($config->{'line_numbering'} eq 'slice') {
          $snp_start = $seq_region_start;
          $snp_end   = $seq_region_end;
        } else {
          $snp_start = $start;
          $snp_end   = $end;
        }
        
        if ($var_class eq 'in-del' && $snp_type eq 'snp') {
          if ($seq_region_start > $seq_region_end) {
            $snp_type = 'insert';
            
            # Neither of the following if statements are guaranteed by $seq_region_start > $seq_region_end.
            # It is possible to have inserts for compara alignments which fall in gaps in the sequence, where $s <= $e,
            # and $snp_start only equals $s if $config->{'line_numbering'} is not 'slice';
            $snp_start = $snp_end if $snp_start > $snp_end;
            ($s, $e)   = ($e, $s) if $s > $e;
          } else {
            $snp_type = 'delete';
          }
        }
        
        # Add the sub slice start where necessary - makes the label for the variation show the correct position relative to the sequence
        $snp_start += $config->{'sub_slice_start'} - 1 if $config->{'sub_slice_start'} && $config->{'line_numbering'} ne 'slice';
        
        # Add the chromosome number for the link text if we're doing species comparisons or resequencing.
        $snp_start = $snp->seq_region_name . ":$snp_start" if scalar keys %$u_snps && $config->{'line_numbering'} eq 'slice';
        
        my $url = $object->_url({
          species => $config->{'ref_slice_name'} ? $config->{'species'} : $name,
          type    => 'Variation',
          action  => 'Summary',
          v       => $variation_name,
          vf      => $dbID,
          vdb     => 'variation'
        });
        
        my $link_text = qq{ <a href="$url">$snp_start: $variation_name $alleles</a>;};
        
        for ($s..$e) {
          # Don't mark up variations when the secondary strain is the same as the sequence.
          # $sequence[-1] is the current secondary strain, as it is the last element pushed onto the array
          next if defined $config->{'match_display'} && $sequence[-1]->[$_]->{'letter'} =~ /[\.~$sequence[0]->[$_]->{'letter'}]/;
          
          $mk->{'variations'}->{$_}->{'type'}     = $snp_type;
          $mk->{'variations'}->{$_}->{'alleles'} .= ($mk->{'variations'}->{$_}->{'alleles'} ? '; ' : '') . $alleles;
          
          unshift @{$mk->{'variations'}->{$_}->{'link_text'}}, $link_text if $_ == $s;

          $mk->{'variations'}->{$_}->{'href'} ||= {
            species => $config->{'ref_slice_name'} ? $config->{'species'} : $name,
            type        => 'Zmenu',
            action      => 'TextSequence',
            factorytype => 'Location'
          };
          
          push @{$mk->{'variations'}->{$_}->{'href'}->{'v'}},  $variation_name;
          push @{$mk->{'variations'}->{$_}->{'href'}->{'vf'}}, $dbID;
        }
      }
    }
    
    # Get exons
    if ($config->{'exon_display'}) {
      my $exontype = $config->{'exon_display'};
      my @exons;
      
      if ($exontype eq 'Ab-initio') {
        @exons = grep { $_->seq_region_start <= $slice_end && $_->seq_region_end >= $slice_start } map @{$_->get_all_Exons}, @{$slice->get_all_PredictionTranscripts};
      } elsif ($exontype eq 'vega' || $exontype eq 'est') {
        @exons = map @{$_->get_all_Exons}, @{$slice->get_all_Genes('', $exontype)};
      } else {
        @exons = map @{$_->get_all_Exons}, @{$slice->get_all_Genes};
      }
      
      # Values of parameter should not be fwd and rev - this is confusing.
      if ($config->{'exon_ori'} eq 'fwd') {
        @exons = grep { $_->strand > 0 } @exons; # Only exons in same orientation 
      } elsif ($config->{'exon_ori'} eq 'rev') {
        @exons = grep { $_->strand < 0 } @exons; # Only exons in opposite orientation
      }
      
      my @all_exons = map [ $config->{'comparison'} ? 'compara' : 'other', $_ ], @exons;
      
      if ($config->{'exon_features'}) {
        push @all_exons, [ 'gene', $_ ] for @{$config->{'exon_features'}};
        
        if ($config->{'exon_features'} && $config->{'exon_features'}->[0] && $config->{'exon_features'}->[0]->isa('Bio::EnsEMBL::Exon')) {
          $config->{'gene_exon_type'} = 'exons';
        } else {
          $config->{'gene_exon_type'} = 'features';
        }
      }
      
      foreach (@all_exons) {
        my $type = $_->[0];
        my $exon = $_->[1];
        
        next unless $exon->seq_region_start && $exon->seq_region_end;
        
        my $start = $exon->start - ($type eq 'gene' ? $slice_start : 1);
        my $end   = $exon->end   - ($type eq 'gene' ? $slice_start : 1);
        my $id    = $exon->can('stable_id') ? $exon->stable_id : '';
        
        ($start, $end) = ($slice_length - $end - 1, $slice_length - $start - 1) if $type eq 'gene' && $slice_strand < 0 && $exon->strand < 0;
        
        next if $end < 0 || $start >= $slice_length;
        
        $start = 0 if $start < 0;
        $end   = $slice_length - 1 if $end >= $slice_length;
        
        for ($start..$end) {          
          push @{$mk->{'exons'}->{$_}->{'type'}}, $type;          
          $mk->{'exons'}->{$_}->{'id'} .= ($mk->{'exons'}->{$_}->{'id'} ? '; ' : '') . $id unless $mk->{'exons'}->{$_}->{'id'} =~ /$id/;
        }
      }
    }
    
    # Get codons
    if ($config->{'codons_display'}) {
      my @transcripts = map @{$_->get_all_Transcripts}, @{$slice->get_all_Genes};
      
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
        foreach my $t (grep { $_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
          next unless defined $t->translation;
          
          my @codons;
          
          # FIXME: all_end_codon_mappings sometimes returns $_ as undefined for small subslices. This eval stops the error, but the codon will still be missing.
          # Awaiting a fix from the compara team.
          eval {
            push @codons, map {{ start => $_->start, end => $_->end, label => 'START' }} @{$t->translation->all_start_codon_mappings || []}; # START codons
            push @codons, map {{ start => $_->start, end => $_->end, label => 'STOP'  }} @{$t->translation->all_end_codon_mappings   || []}; # STOP codons
          };
          
          my $id = $t->stable_id;
         
          foreach my $c (@codons) {
            my ($start, $end) = ($c->{'start'}, $c->{'end'});
            
            # FIXME: Temporary hack until compara team can sort this out
            $start = $start - 2 * ($slice_start - 1);
            $end   = $end   - 2 * ($slice_start - 1);
            
            next if $end < 1 || $start > $slice_length;
            
            $start = 1 unless $start > 0;
            $end   = $slice_length unless $end < $slice_length;
            
            $mk->{'codons'}->{$_}->{'label'} .= ($mk->{'codons'}->{$_}->{'label'} ? '; ' : '') . "$c->{'label'}($id)" for $start-1..$end-1;
          }
        }
      } else { # Normal Slice
        foreach my $t (grep { $_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
          my ($start, $stop, $id, $strand) = ($t->coding_region_start, $t->coding_region_end, $t->stable_id, $t->strand);
          
          # START codons
          if ($start >= 1) {
            my $label = ($strand == 1 ? 'START' : 'STOP') . "($id)";
            $mk->{'codons'}->{$_}->{'label'} .= ($mk->{'codons'}->{$_}->{'label'} ? '; ' : '') . $label for $start-1..$start+1;
          }
          
          # STOP codons
          if ($stop <= $slice_length) {
            my $label = ($strand == 1 ? 'STOP' : 'START') . "($id)";
            $mk->{'codons'}->{$_}->{'label'} .= ($mk->{'codons'}->{$_}->{'label'} ? '; ' : '') . $label for $stop-3..$stop-1;
          }
        }
      }
    }
    
    push @markup, $mk;
  }
  
  return (\@sequence, \@markup);
}

sub markup_exons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;
  
  my (%exon_types, $exon, $type, $s, $seq);
  my $i = 0;
  
  my $class = {
    exon0   => 'e0',
    exon1   => 'e1',
    exon2   => 'e2',
    other   => 'eo',
    gene    => 'eg',
    compara => 'e2'
  };
  
  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort { $a <=> $b } keys %{$data->{'exons'}}) {
      $exon = $data->{'exons'}->{$_};
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $exon->{'id'} if $config->{'title_display'};
      
      foreach $type (@{$exon->{'type'}}) {
        $seq->[$_]->{'class'} .= "$class->{$type} " unless $seq->[$_]->{'class'} =~ /\b$class->{$type}\b/;
        $exon_types{$type} = 1;
      }
    }
    
    $i++;
  }
  
  $config->{'key'}->{'exons'}->{$_} = 1 for keys %exon_types;
}

sub markup_codons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($class, $seq);
  my $i = 0;

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort { $a <=> $b } keys %{$data->{'codons'}}) {
      $class = $data->{'codons'}->{$_}->{'class'} || 'co';
      
      $seq->[$_]->{'class'} .= "$class ";
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $data->{'codons'}->{$_}->{'label'} if $config->{'title_display'};
      
      if ($class eq 'cu') {
        $config->{'key'}->{'utr'} = 1;
      } else {
        $config->{'key'}->{'codons'}->{$class} = 1;
      }
    }
    
    $i++;
  }
}

sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($snps, $inserts, $deletes, $seq, $variation, $ambiguity);
  my $object = $self->object;
  my $i = 0;
  
  my $class = {
    snp    => 'sn',
    insert => 'si',
    delete => 'sd'
  };

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'variations'}}) {
      $variation  = $data->{'variations'}->{$_};
      ($ambiguity = ambiguity_code($variation->{'alleles'}) || undef) =~ s/-//g;

      $seq->[$_]->{'letter'} = $ambiguity if $ambiguity;
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $variation->{'alleles'} if $config->{'title_display'};
      $seq->[$_]->{'class'} .= ($class->{$variation->{'type'}} || $variation->{'type'}) . ' ';
      $seq->[$_]->{'href'}   = $object->_url($variation->{'href'});
      $seq->[$_]->{'post'}   = join '', @{$variation->{'link_text'}} if $config->{'snp_display'} eq 'snp_link' && $variation->{'link_text'};

      $snps    = 1 if $variation->{'type'} eq 'snp';
      $inserts = 1 if $variation->{'type'} =~ /insert/;
      $deletes = 1 if $variation->{'type'} eq 'delete';
      
      $config->{'key'}->{'variations'}->{$variation->{'type'}} = 1;
    }
    
    $i++;
  }
}

sub markup_comparisons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;
  
  my $name_length = length($config->{'ref_slice_name'} || $config->{'species'});
  my $max_length  = $name_length;
  my $padding     = '';
  my $i           = 0;
  my ($species, $length, $length_diff, $pad, $seq, $comparison);
  
  foreach (@{$config->{'slices'}}) {
    $species = $_->{'display_name'} || $_->{'name'};
    
    push (@{$config->{'seq_order'}}, $species);
    
    next if $species eq $config->{'species'};
    
    $length      = length $species;
    $length_diff = $length - $name_length;

    if ($length > $max_length) {
      $max_length = $length;
      $padding    = ' ' x $length_diff;
    }
  }
  
  foreach (@{$config->{'seq_order'}}) {
    $pad = ' ' x ($max_length - length $_);
    $config->{'padded_species'}->{$_} = $_ . $pad;
  }
  
  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'comparisons'}}) {
      $comparison = $data->{'comparisons'}->{$_};
      
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $comparison->{'insert'} if $comparison->{'insert'} && $config->{'title_display'};
      $seq->[$_]->{'class'} .= 'res ' if $comparison->{'resequencing'};
    }
    
    $i++;
  }
  
  $config->{'v_space'} = "\n";
}

sub markup_conservation {
  my $self = shift;
  my ($sequence, $config) = @_;

  # Regions where more than 50% of bps match considered "conserved"
  my $cons_threshold = int((scalar(@$sequence) + 1) / 2);
  
  my $conserved = 0;
  
  for my $i (0..$config->{'length'}-1) {
    my %cons;
    map $cons{$_->[$i]->{'letter'}}++, @$sequence;
    
    my $c = join '', grep { $_ !~ /~|[-.N]/ && $cons{$_} > $cons_threshold } keys %cons;
    
    foreach (@$sequence) {
      next unless $_->[$i]->{'letter'} eq $c;
      
      $_->[$i]->{'class'} .= 'con ';
      $conserved = 1;
    }
  }
  
  $config->{'key'}->{'conservation'} = 1 if $conserved;
}

sub markup_line_numbers {
  my $self = shift;
  my ($sequence, $config) = @_;
 
  # Keep track of which element of $sequence we are looking at
  my $n = 0;

  # If we only have only one species, $config->{'seq_order'} won't exist yet (it's created in markup_comparisons)
  $config->{'seq_order'} = [ $config->{'species'} ] unless $config->{'seq_order'};
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $slice       = $sl->{'slice'};
    my $seq         = $sequence->[$n];
    my $align_slice = 0;
    my @numbering;
    
    if ($config->{'line_numbering'} eq 'slice') {
      my $start_pos = 0;
      
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
       $align_slice = 1;
      
        # Get the data for all underlying slices
        foreach (@{$sl->{'underlying_slices'}}) {
          my $ostrand            = $_->strand;
          my $sl_start           = $_->start;
          my $sl_end             = $_->end;
          my $sl_seq_region_name = $_->seq_region_name;
          my $sl_seq             = $_->seq;
          my $end_pos            = $start_pos + length ($sl_seq) - 1;
          
          if ($sl_seq_region_name ne 'GAP') {
            push @numbering, {
              dir       => $ostrand,
              start_pos => $start_pos,
              end_pos   => $end_pos,
              start     => $ostrand > 0 ? $sl_start : $sl_end,
              end       => $ostrand > 0 ? $sl_end   : $sl_start,
              label     => $sl_seq_region_name . ':'
            };
            
            # Padding to go before the label
            $config->{'padding'}->{'pre_number'} = length $sl_seq_region_name if length $sl_seq_region_name > $config->{'padding'}->{'pre_number'};
          }
          
          $start_pos += length $sl_seq;
        }
      } else {
        # Get the data for the slice
        my $ostrand     = $slice->strand;
        my $slice_start = $slice->start;
        my $slice_end   = $slice->end;
        
        @numbering = ({ 
          dir   => $ostrand,
          start => $ostrand > 0 ? $slice_start : $slice_end,
          end   => $ostrand > 0 ? $slice_end   : $slice_start,
          label => $slice->seq_region_name . ':'
        });
      }
    } else {
      # Line numbers are relative to the sequence (start at 1)
      @numbering = ({ 
        dir   => 1,  
        start => $config->{'sub_slice_start'} || 1,
        end   => $config->{'sub_slice_end'}   || $config->{'length'},
        label => ''
      });
    }
    
    my $data = shift @numbering unless $config->{'numbering'} && !$config->{'numbering'}->[$n];
    
    my $s = 0;
    my $e = $config->{'display_width'} - 1;
    
    my $row_start = $data->{'start'};
    my ($start, $end);
    
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = $config->{'length'} + $config->{'display_width'};
    
    while ($e < $loop_end) {
      my $shift = 0; # To check if we've got a new element from @numbering
      
      $start = '';
      $end   = '';
      
      # Comparison species
      if ($align_slice) {
        # Build a segment containing the current line of sequence
        my $segment = substr $slice->{'seq'}, $s, $config->{'display_width'};
        (my $seq_length_seg = $segment) =~ s/\.//g;
        my $seq_length = length $seq_length_seg; # The length of the sequence which does not consist of a .
    
        my $first_bp_pos = 0; # Position of first letter character
        my $last_bp_pos  = 0; # Position of last letter character

        if ($segment =~ /\w/) {
          $segment      =~ /(^\W*).*\b(\W*$)/;
          $first_bp_pos = 1 + length $1 unless length($1) == length $segment;
          $last_bp_pos  = $2 ? length($segment) - length($2) : length $segment;
        }
        
        my $old_label = '';
        
        # Get the data from the next slice if we have passed the end of the current one
        while (scalar @numbering && $e >= $numbering[0]->{'start_pos'}) {          
          $old_label ||= $data->{'label'} if ($data->{'end_pos'} > $s); # Only get the old label for the first new slice - the one at the start of the line
          $shift = 1;

          $data = shift @numbering;
          $data->{'old_label'} = $old_label;
          
          # Only set $row_start if the line begins with a .
          # If it does not, the previous slice ends mid-line, so we just carry on with it's start number
          $row_start = $data->{'start'} if $segment =~ /^\./;
        }
        
        if ($seq_length && $last_bp_pos) {
          # This is NOT necessarily the same as $end + $data->{'dir'}, as bits of sequence could be hidden
          (undef, $row_start) = $slice->get_original_seq_region_position($s + $first_bp_pos);
          
          $start = $row_start;

          # For AlignSlice display the position of the last meaningful bp
          (undef, $end) = $slice->get_original_seq_region_position($e + 1 + $last_bp_pos - $config->{'display_width'});
        }

        $s = $e + 1;
      } elsif ($config->{'numbering'}) { # Transcript sequence
        my $seq_length = 0;
        my $segment = '';
        
        # Build a segment containing the current line of sequence        
        for ($s..$e) {
          # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
          if ($seq->[$_]) {
            $seq_length++ if $seq->[$_]->{'letter'} =~ /\w/;
            $segment .= $seq->[$_]->{'letter'};
          }
        }
        
        # Reference sequence starting with N or NN means the transcript begins mid-codon, so reduce the sequence length accordingly.
        $seq_length -= length $1 if $segment =~ /^(N+)\w/;
        
        $end = $e < $config->{'length'} ? $row_start + $seq_length - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start if $seq_length;
        
        # If the line starts -- or -= it is at the end of a protein section, so take one off the line number
        $start-- if $start > $data->{'start'} && $segment =~ /^-\W/;
        
        # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
        $row_start = $end + $data->{'dir'} if $start && $end;
        
        # Remove the line number if the sequence doesn't start at the beginning of the line
        $start = '' if $segment =~ /^(\.|N+\w)/;
        
        $s = $e + 1;
      } else { # Single species
        $end = $e < $config->{'length'} ? $row_start + ($data->{'dir'} * $config->{'display_width'}) - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start;
                
        # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
        $row_start = $end + $data->{'dir'} if $end;
      }
      
      my $label      = $start && $config->{'comparison'} ? $data->{'label'} : '';
      my $post_label = $shift && $label && $data->{'old_label'} ? $label : '';
      $label         = $data->{'old_label'} if $post_label;
      
      push @{$config->{'line_numbers'}->{$n}}, { start => $start, end => $end, label => $label, post_label => $post_label };

      # Increase padding amount if required
      $config->{'padding'}->{'number'} = length $start if length $start > $config->{'padding'}->{'number'};
      
      $e += $config->{'display_width'};
    }
    
    $n++;
  }
  
  $config->{'padding'}->{'pre_number'}++ if $config->{'padding'}->{'pre_number'}; # Compensate for the : after the label
 
  $config->{'alignment_numbering'} = 1 if $config->{'line_numbering'} eq 'slice' && $config->{'align'};
}

sub build_sequence {
  my $self = shift;
  my ($sequence, $config) = @_;
  
  my $line_numbers = $config->{'line_numbers'};
  my $s = 0;
  my $html; 
  my @output;
  
  # Temporary patch because Firefox doesn't copy/paste anything but inline styles
  # If we remove this patch, look at version 1.79 for the correct code to revert to
  my %class_to_style = %{$self->class_to_style};
  my $single_line    = scalar @{$sequence->[0]} <= $config->{'display_width'}; # Only one line of sequence to display
  
  foreach my $lines (@$sequence) {
    my ($row, $pre, $post, $count, $i);
    
    my %current  = ( tag => 'span', class=> '', title => '', href => '' );
    my %previous = ( tag => 'span', class=> '', title => '', href => '' );
    my %new_line = ( tag => 'span', class=> '', title => '', href => '' );
    
    foreach my $seq (@$lines) {
      $previous{$_} = $current{$_} for keys %current;
      
      $current{'title'} = $seq->{'title'}  ? qq{title="$seq->{'title'}"} : '';
      $current{'href'}  = $seq->{'href'}   ? qq{href="$seq->{'href'}"}  : '';;
      $current{'tag'}   = $current{'href'} ? 'a class="sequence_info"' : 'span';
      
      if ($seq->{'class'}) {
        $current{'class'} = $seq->{'class'};
        chomp $current{'class'};
        
        if ($config->{'maintain_colour'} && $previous{'class'} =~ /\b(e\w)\b/ && $current{'class'} !~ /\b(e\w)\b/) {
          $current{'class'} .= " $1";
        }
      } elsif ($config->{'maintain_colour'} && $previous{'class'} =~ /\b(e\w)\b/) {
        $current{'class'} = $1;
      } else {
        $current{'class'} = '';
      }
      
      $post .= $seq->{'post'};
      
      my $style;
      
      if ($current{'class'}) {
        my %style_hash;
        
        foreach (sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } split / /, $current{'class'}) {
          my $st = $class_to_style{$_}->[1];
          map $style_hash{$_} = $st->{$_}, keys %$st;
        }
        
        $style = sprintf 'style="%s"', join ';', map "$_:$style_hash{$_}", keys %style_hash;
      }
      
      if ($i == 0) {
        $row .= "<$current{'tag'} $style $current{'title'} $current{'href'}>";
      } elsif ($current{'href'}) {
        $row .= "</$previous{'tag'}><$current{'tag'} $style $current{'title'} $current{'href'}>" if $current{'href'} ne $previous{'href'};
      } elsif ($current{'class'} ne $previous{'class'} || $current{'title'} ne $previous{'title'}) {
        $row .= "</$previous{'tag'}><$current{'tag'} $style $current{'title'}>";
      }
      
      $row .= $seq->{'letter'};
      
      $count++;
      $i++;
      
      (my $close_tag = $current{'tag'}) =~ s/(\w+).*/$1/;
      
      if ($count == $config->{'display_width'} || $i == scalar @$lines) {
        if ($i == $config->{'display_width'} || $single_line) {
          $row = "$row</$close_tag>";
        } else {
          my $new_line_style;
          
          if ($new_line{'class'} eq $current{'class'}) {
            $new_line_style = $style;
          } elsif ($new_line{'class'}) {
            my %style_hash;
            
            foreach (sort { $class_to_style{$a}->[0] <=> $class_to_style{$b}->[0] } split / /, $new_line{'class'}) {
              my $st = $class_to_style{$_}->[1];
              map $style_hash{$_} = $st->{$_}, keys %$st;
            }
            
            $new_line_style = sprintf 'style="%s"', join ';', map "$_:$style_hash{$_}", keys %style_hash;
          }
          
          $row = "<$new_line{'tag'} $new_line_style $new_line{'title'} $new_line{'href'}>$row</$close_tag>";
        }
        
        if ($config->{'comparison'}) {
          if (scalar keys %{$config->{'padded_species'}}) {
            $pre = $config->{'padded_species'}->{$config->{'seq_order'}->[$s]} || $config->{'species'};
          } else {
            $pre = $config->{'species'};
          }
          
          $pre .= '  ';
        }
        
        push @{$output[$s]}, { line => $row, length => $count, pre => $pre, post => $post };
        
        $new_line{$_} = $current{$_} for keys %current;
        $count        = 0;
        $row          = '';
        $pre          = '';
        $post         = '';
      }
    }
    
    $s++;
  }

  my $length = $output[0] ? scalar @{$output[0]} - 1 : 0;
  
  for my $x (0..$length) {
    my $y = 0;
    
    foreach (@output) {
      my $line = $_->[$x]->{'line'};
      my $num  = shift @{$line_numbers->{$y}};
      
      if ($config->{'number'}) {
        my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $num->{'label'});
        my $pad2 = ' ' x ($config->{'padding'}->{'number'}     - length $num->{'start'});

        $line = $config->{'h_space'} . sprintf('%6s ', "$pad1$num->{'label'}$pad2$num->{'start'}") . $line;
      }
      
      $line .= ' ' x ($config->{'display_width'} - $_->[$x]->{'length'}) if $x == $length && ($config->{'end_number'} || $_->[$x]->{'post'});
      
      if ($config->{'end_number'}) {
        my $n    = $num->{'post_label'} || $num->{'label'};
        my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $n);
        my $pad2 = ' ' x ($config->{'padding'}->{'number'}     - length $num->{'end'});

        $line .= $config->{'h_space'} . sprintf ' %6s', "$pad1$n$pad2$num->{'end'}";
      }
      
      $line = "$_->[$x]->{'pre'}$line" if $_->[$x]->{'pre'};
      $line .= $_->[$x]->{'post'}      if $_->[$x]->{'post'};
      $html .= "$line\n";
      
      $y++;
    }
    
    $html .= $config->{'v_space'};
  }
  
  $config->{'html_template'} ||= qq{<pre class="text_sequence">%s</pre><p class="invisible">.</p>};  
  $config->{'html_template'} = sprintf $config->{'html_template'}, $html;
  
  if ($config->{'sub_slice_start'}) {
    my $partial_key;
    $partial_key->{$_} = $config->{$_} for grep $config->{$_},          @{$self->{'key_params'}};
    $partial_key->{$_} = 1             for grep $config->{'key'}->{$_}, @{$self->{'key_types'}};
    
    foreach my $type (grep $config->{'key'}->{$_}, qw(exons variations)) {
      $partial_key->{$type}->{$_} = 1 for keys %{$config->{'key'}->{$type}};
    }
    
    $config->{'html_template'} .= sprintf '<div class="sequence_key_json hidden">%s</div>', $self->jsonify($partial_key) if $partial_key;
  }
  
  return $config->{'html_template'} . sprintf '<input type="hidden" class="panel_type" value="TextSequence" name="panel_type_%s" />', $self->id;
}

# When displaying a very large sequence we can break it up into smaller sections and render each of them much more quickly
sub chunked_content {
  my $self = shift;
  my ($total_length, $chunk_length, $base_url) = @_;

  my $object = $self->object;

  my $i        = 1;
  my $j        = $chunk_length;
  my $end      = (int ($total_length / $j)) * $j; # Find the final position covered by regular chunking - we will add the remainer once we get past this point.
  my $renderer = ($ENV{'ENSEMBL_AJAX_VALUE'} eq 'enabled') ? undef : new EnsEMBL::Web::Document::Renderer::Assembler(session => $object->get_session);
  my ($url, $html);
  
  # The display is split into a managable number of sub slices, which will be processed in parallel by requests
  while ($j <= $total_length) {
    $url = qq{$base_url;subslice_start=$i;subslice_end=$j};

    if ($renderer) {
      map { $url .= ";$_=" . $object->param($_) } $object->param;

      $renderer->print(new HTTP::Request('GET', $object->species_defs->ENSEMBL_BASE_URL . $url));
    } else {
      $html .= qq{<div class="ajax"><input type="hidden" class="ajax_load" value="$url" /></div>};
    }

    last if $j == $total_length;

    $i  = $j + 1;
    $j += $chunk_length;
    $j  = $total_length if $j > $end;
  }

  if ($renderer) {
    $renderer->process;
    $html = $renderer->content;
  }

  return $html;
}

sub class_to_style {
  my $self = shift;
  
  if (!$self->{'class_to_style'}) {
    my $colourmap    = $self->colour_map;
    my $species_defs = $self->object->species_defs;
    my $styles       = $species_defs->colour('sequence_markup');
    my $var_styles   = $species_defs->colour('variation');
    my $i            = 1;
    
    my %class_to_style = (
      con  => [ $i++, { 'background-color' => "#$styles->{'SEQ_CONSERVATION'}->{'default'}" } ],
      dif  => [ $i++, { 'background-color' => "#$styles->{'SEQ_DIFFERENCE'}->{'default'}" } ],
      res  => [ $i++, { 'color' => "#$styles->{'SEQ_RESEQEUNCING'}->{'default'}" } ],
      e0   => [ $i++, { 'color' => "#$styles->{'SEQ_EXON0'}->{'default'}" } ],
      e1   => [ $i++, { 'color' => "#$styles->{'SEQ_EXON1'}->{'default'}" } ],
      e2   => [ $i++, { 'color' => "#$styles->{'SEQ_EXON2'}->{'default'}" } ],
      eu   => [ $i++, { 'color' => "#$styles->{'SEQ_EXONUTR'}->{'default'}" } ],
      ef   => [ $i++, { 'color' => "#$styles->{'SEQ_EXONFLANK'}->{'default'}" } ],
      eo   => [ $i++, { 'background-color' => "#$styles->{'SEQ_EXONOTHER'}->{'default'}" } ],
      eg   => [ $i++, { 'color' => "#$styles->{'SEQ_EXONGENE'}->{'default'}", 'font-weight' => "bold" } ],
      c0   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODONC0'}->{'default'}" } ],
      c1   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODONC1'}->{'default'}" } ],
      cu   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODONUTR'}->{'default'}" } ],
      co   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODON'}->{'default'}" } ],
      sn   => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNP'}->{'default'}" } ],      
      si   => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNPINSERT'}->{'default'}" } ],
      sd   => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNPDELETE'}->{'default'}" } ],   
      snt  => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNP_TR'}->{'default'}" } ],
      syn  => [ $i++, { 'background-color' => "#$styles->{'SEQ_SYN'}->{'default'}" } ],
      snu  => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNP_TR_UTR'}->{'default'}" } ],
      siu  => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNPINSERT_TR_UTR'}->{'default'}" } ],
      sdu  => [ $i++, { 'background-color' => "#$styles->{'SEQ_SNPDELETE_TR_UTR'}->{'default'}" } ],
      sf   => [ $i++, { 'background-color' => "#$styles->{'SEQ_FRAMESHIFT'}->{'default'}" } ],
      aa   => [ $i++, { 'color' => "#$styles->{'SEQ_AMINOACID'}->{'default'}" } ],
      var  => [ $i++, { 'color' => "#$styles->{'SEQ_MAIN_SNP'}->{'default'}" } ],
      end  => [ $i++, { 'background-color' => "#$styles->{'SEQ_REGION_CHANGE'}->{'default'}", 'color' => "#$styles->{'SEQ_REGION_CHANGE'}->{'label'}" } ],
      bold => [ $i++, { 'font-weight' => 'bold' } ]
    );
    
    foreach (keys %$var_styles) {
      my $style = { 'background-color' => '#' . $colourmap->hex_by_name($var_styles->{$_}->{'default'}) };
      
      $style->{'color'} = '#' . $colourmap->hex_by_name($var_styles->{$_}->{'label'}) if $var_styles->{$_}->{'label'};
      
      $class_to_style{$_} = [ $i++, $style ];
    }
    
    $self->{'class_to_style'} = \%class_to_style;
  }
  
  return $self->{'class_to_style'};
}

sub content_key {
  my $self   = shift;
  my $config = shift || {};
  
  my $object = $self->object;
  
  $config->{'site_type'} = ucfirst(lc $object->species_defs->ENSEMBL_SITETYPE) || 'Ensembl';
  
  for (@{$self->{'key_params'}}, qw(exon_display population_filter min_frequency)) {
    $config->{$_} = $object->param($_) unless $object->param($_) eq 'off';
  }
  
  $config->{'key'}->{$_} = $object->param($_) for @{$self->{'key_types'}};
  
  for my $p (grep $object->param($_), qw(exons variations)) {
    $config->{'key'}->{$p}->{$_} = 1 for $object->param($p);
  }

  return $self->get_key($config);
}

sub get_key {
  my ($self, $config, $k) = @_;
  
  my $object         = $self->object;
  my $class_to_style = $self->class_to_style;
  my $var_styles     = $object->species_defs->colour('variation');
  my $image_config   = $object->get_imageconfig('text_seq_legend');
    
  my $exon_type;
  $exon_type = $config->{'exon_display'} unless $config->{'exon_display'} eq 'selected';
  $exon_type = $config->{'site_type'} if $exon_type eq 'core' || !$exon_type;
  $exon_type = ucfirst $exon_type;
  
  my %key = (
    utr          => { class => 'cu',  text => 'UTR'                          },
    conservation => { class => 'con', text => 'Conserved regions'            },
    difference   => { class => 'dif', text => 'Differs from primary species' },
    align_change => { class => 'end', text => 'Start/end of aligned region'  },
    codons       => {
      co => { class => 'co', text => 'START/STOP codons'  },
      c0 => { class => 'c0', text => 'Alternating codons' },
      c1 => { class => 'c1', text => 'Alternating codons' },
    },
    exons       => {
      exon0   => { class => 'e0', text => 'Alternating exons'                                  },
      exon1   => { class => 'e1', text => 'Alternating exons'                                  },
      exon2   => { class => 'e2', text => 'Residue overlap splice site'                        },
      gene    => { class => 'eg', text => "$config->{'gene_name'} $config->{'gene_exon_type'}" },
      other   => { class => 'eo', text => "$exon_type exons"                                   },
      compara => { class => 'e2', text => "$exon_type exons"                                   }
    }
  );
  
  %key = (%key, %$k) if $k;
  
  foreach my $type (keys %key) {
    if ($key{$type}{'class'}) {
      my $style = $class_to_style->{$key{$type}{'class'}}->[1];
      
      $key{$type}{'default'} = $style->{'background-color'};
      $key{$type}{'label'}   = $style->{'color'};
    } else {
      foreach (values %{$key{$type}}) {
        my $style = $class_to_style->{$_->{'class'}}->[1];
        
        $_->{'default'} = $style->{'background-color'};
        $_->{'label'}   = $style->{'color'};
      }
    }
  }
  
  map $key{'variations'}{$_} = $var_styles->{$_}, keys %$var_styles;
  
  foreach my $type (keys %{$config->{'key'}}) {
    if (ref $config->{'key'}->{$type} eq 'HASH') {
      $image_config->{'legend'}->{$type}->{$_} = $key{$type}{$_} for grep $config->{'key'}->{$type}->{$_}, keys %{$config->{'key'}->{$type}};
    } elsif ($config->{'key'}->{$type}) {
      $image_config->{'legend'}->{$type} = $key{$type};
    }
  }
  
  $image_config->image_width(650);
  $image_config->{'no_panel_type'} = 1;
  
  my $key_html;
  $key_html .= sprintf '<li>Displaying variations for %s with a minimum frequency of %s</li>', $config->{'population_filter'}, $config->{'min_frequency'} if $config->{'population_filter'};
  $key_html .= '<li>Conserved regions are where >50&#37; of bases in alignments match</li>'                                                               if $config->{'key'}->{'conservation'};
  $key_html .= '<li>For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line</li>'     if $config->{'alignment_numbering'};
  $key_html .= '<li><code>&middot;&nbsp;&nbsp;&nbsp;</code>Basepairs in secondary strains matching the reference strain are replaced with dots</li>'      if $config->{'match_display'};
  $key_html .= '<li><code>~&nbsp;&nbsp;</code>No resequencing coverage at this position</li>'                                                             if $config->{'resequencing'};
  $key_html  = "<ul>$key_html</ul>" if $key_html;
  
  return '<h4>Key</h4>' . $self->new_image(new EnsEMBL::Web::Fake({}), $image_config)->render . $key_html;
}

1;
