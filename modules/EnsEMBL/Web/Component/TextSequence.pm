=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::TextSequence;

use strict;
no warnings 'uninitialized';

use RTF::Writer;

use EnsEMBL::Web::Fake;
use EnsEMBL::Web::Utils::RandomString qw(random_string);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Draw::Utils::ColourMap;
use EnsEMBL::Web::TextSequence::View;

use EnsEMBL::Web::TextSequence::Annotation::Sequence;
use EnsEMBL::Web::TextSequence::Annotation::Exons;
use EnsEMBL::Web::TextSequence::Annotation::Codons;
use EnsEMBL::Web::TextSequence::Annotation::Variations;
use EnsEMBL::Web::TextSequence::Annotation::Alignments;

use base qw(EnsEMBL::Web::Component::Shared);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new(@_);
  
  $self->{'key_types'}         = [qw(codons conservation population resequencing align_change)];
  $self->{'key_params'}        = [qw(gene_name gene_exon_type alignment_numbering match_display)];
  
  my $view = $self->view;

  my $adorn = $self->hub->param('adorn') || 'none';
  if($adorn eq 'only') { $view->phase(2); }
  elsif($adorn eq 'none') { $view->phase(1); }

  return $self;
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;

  return if ($hub->action eq 'Sequence_Protein' && !$self->object->Obj->translation);

  return unless $self->can('export_options');

  my $options = $self->export_options || {};

  return unless $options->{'action'};

  my @namespace = split('::', ref($self));
  my $params  = {'type' => 'DataExport', 'action' => $options->{'action'}, 'data_type' => $self->hub->type, 'component' => $namespace[-1]};
  foreach (@{$options->{'params'} || []}) {
    $params->{$_} = $self->param($_);
  }

  
  if ($options->{'action'} =~ /Align/ && ($hub->param('need_target_slice_table') || !$hub->param('align'))) {
    return {
      'url'       => undef, 
      'caption'   => $options->{'caption'} || 'Download sequence',
      'class'     => 'export',
      'disabled'  => 1,
    };
  }
  else {
    return {
      'url'     => $hub->url($params),
      'caption' => $options->{'caption'} || 'Download sequence',
      'class'   => 'export',
      'modal'   => 1
    };
  }
}

sub _init {
  my ($self, $subslice_length) = @_;
  $self->cacheable(1);
  $self->ajaxable(1);

  my $type  = $self->hub->param('data_type') || $self->hub->type;
  my $vc    = $self->view_config($type);
  
  if ($subslice_length) {
    my $hub = $self->hub;
    $self->{'subslice_length'} = $hub->param('force') || $subslice_length * $self->param('display_width');
  }
}

# Used in subclasses
sub too_rare_snp {
  my ($self,$vf,$config) = @_;

  return 0 unless $config->{'hide_rare_snps'} and $config->{'hide_rare_snps'} ne 'off';
  my $val = abs $config->{'hide_rare_snps'};
  my $mul = ($config->{'hide_rare_snps'}<0)?-1:1;
  return ($mul>0) unless $vf->minor_allele_frequency;
  return ($vf->minor_allele_frequency - $val)*$mul < 0;
}

# Used by Compara_Alignments, Gene::GeneSeq and Location::SequenceAlignment
sub get_sequence_data {
  my ($self, $slices, $config, $adorn) = @_;
  my $hub      = $self->hub;
  my $sequence = [];
  my @markup;
 
  $self->set_variation_filter($config) if $config->{'snp_display'} ne 'off';
  
  $config->{'length'} ||= $slices->[0]{'slice'}->length;

  my $view = $self->view;
  $view->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Sequence->new);
  $view->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Alignments->new) if $config->{'align'};
  $view->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Variations->new([0,2])) if $config->{'snp_display'} ne 'off';
  $view->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Exons->new) if $config->{'exon_display'} ne 'off';
  $view->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Codons->new) if $config->{'codons_display'};
 
  foreach my $sl (@$slices) {
    my $mk  = {};    
    my $seq = $sl->{'seq'} || $sl->{'slice'}->seq(1);
    $view->annotate($config,$sl,$mk,$seq,$sequence);
    push @markup, $mk;
  }
  
  return ($sequence, \@markup);
}

sub set_sequence {
  my ($self, $config, $sequence, $markup, $seq, $name) = @_;
  
  if ($config->{'match_display'}) {
    if ($name eq $config->{'ref_slice_name'}) {
      push @$sequence, [ map {{ letter => $_ }} @{$config->{'ref_slice_seq'}} ];
    } else {
      my $i       = 0;
      my @cmp_seq = map {{ letter => ($config->{'ref_slice_seq'}[$i++] eq $_ ? '|' : ($config->{'ref_slice_seq'}[$i-1] eq uc($_) ? '.' : $_)) }} split '', $seq;

      while ($seq =~ m/([^~]+)/g) {
        my $reseq_length = length $1;
        my $reseq_end    = pos $seq;
        
        $markup->{'comparisons'}{$reseq_end - $_}{'resequencing'} = 1 for 1..$reseq_length;
      }
      
      push @$sequence, \@cmp_seq;
    }
  } else {
    push @$sequence, [ map {{ letter => $_ }} split '', $seq ];
  }
}

sub set_alignments {
  my ($self, $config, $slice_data, $markup, $seq) = @_;
  
  if ($config->{'region_change_display'} && $slice_data->{'name'} ne $config->{'species'}) {
    my $s = 0;
    
    # We don't want to mark the very end of the sequence, so don't loop for the last element in the array
    for (0..scalar(@{$slice_data->{'underlying_slices'}}) - 2) {
      my $end_region   = $slice_data->{'underlying_slices'}[$_];
      my $start_region = $slice_data->{'underlying_slices'}[$_+1];
      
      $s += length $end_region->seq(1);
      
      $markup->{'region_change'}{$s-1} = $end_region->name   . ' END';
      $markup->{'region_change'}{$s}   = $start_region->name . ' START';

      for ($s-1..$s) {
        $markup->{'region_change'}{$_} = "GAP $1" if $markup->{'region_change'}{$_} =~ /.*gap.* (\w+)/;
      }
    }
  }
  
  while ($seq =~  m/(\-+)[\w\s]/g) {
    my $ins_length = length $1;
    my $ins_end    = pos($seq) - 1;
    
    $markup->{'comparisons'}{$ins_end - $_}{'insert'} = "$ins_length bp" for 1..$ins_length;
  }
}

sub set_variation_filter {
  my ($self, $config) = @_;
  my $hub = $self->hub;
  
  my @consequence       = $self->param('consequence_filter');
  my $pop_filter        = $self->param('population_filter');
  my %consequence_types = map { $_ => 1 } @consequence if join('', @consequence) ne 'off';
  
  if (%consequence_types) {
    $config->{'consequence_types'}  = \%consequence_types;
    $config->{'consequence_filter'} = \@consequence;
  }
  
  if ($pop_filter && $pop_filter ne 'off') {
    $config->{'population'}        = $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($pop_filter);
    $config->{'min_frequency'}     = $self->param('min_frequency');
    $config->{'population_filter'} = $pop_filter;
  }
  
  $config->{'snp_length_filter'} = 10; # Max length of VariationFeatures to be displayed
  $config->{'hide_long_snps'} = $self->param('hide_long_snps') eq 'yes';
  $config->{'hide_rare_snps'} = $self->param('hide_rare_snps');
}

sub set_variations {
  my ($self, $config, $slice_data, $markup, $sequence, $focus_snp_only) = @_;
  my $hub    = $self->hub;
  my $name   = $slice_data->{'name'};
  my $slice  = $slice_data->{'slice'};
  
  my $species = $slice->can('genome_db') ? ucfirst($slice->genome_db->name) : $hub->species;
  return unless $hub->database('variation', $species);
  my $strand = $slice->strand;
  my $focus  = $name eq $config->{'species'} ? $config->{'focus_variant'} : undef;
  my $snps   = [];
  my $u_snps = {};
  my $adaptor;
  my $vf_adaptor = $hub->database('variation')->get_VariationFeatureAdaptor;
  if ($focus_snp_only) {
    push @$snps, $focus_snp_only;
  } else {
    eval {
      # NOTE: currently we can't filter by both population and consequence type, since the API doesn't support it.
      # This isn't a problem, however, since filtering by population is disabled for now anyway.
      if ($config->{'population'}) {
        $snps = $vf_adaptor->fetch_all_by_Slice_Population($slice_data->{'slice'}, $config->{'population'}, $config->{'min_frequency'});
      }
      elsif ($config->{'hide_rare_snps'} && $config->{'hide_rare_snps'} ne 'off') {
        $snps = $vf_adaptor->fetch_all_with_maf_by_Slice($slice_data->{'slice'},abs $config->{'hide_rare_snps'},$config->{'hide_rare_snps'}>0);
      }
      else {
        my @snps_list = (@{$slice_data->{'slice'}->get_all_VariationFeatures($config->{'consequence_filter'}, 1)},
                         @{$slice_data->{'slice'}->get_all_somatic_VariationFeatures($config->{'consequence_filter'}, 1)});
        $snps = \@snps_list;
      }
    };
  }
  return unless scalar @$snps;
  
  foreach my $u_slice (@{$slice_data->{'underlying_slices'} || []}) {
    next if $u_slice->seq_region_name eq 'GAP';
      
    if (!$u_slice->adaptor) {
      my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($name, $config->{'db'}, 'slice');
      $u_slice->adaptor($slice_adaptor);
    }
      
    eval {
      map { $u_snps->{$_->variation_name} = $_ } @{$vf_adaptor->fetch_all_by_Slice($u_slice)};
    };
  }

  $snps = [ grep $_->length <= $config->{'snp_length_filter'} || $config->{'focus_variant'} && $config->{'focus_variant'} eq $_->dbID, @$snps ] if $config->{'hide_long_snps'};

  # order variations descending by worst consequence rank so that the 'worst' variation will overwrite the markup of other variations in the same location
  # Also prioritize shorter variations over longer ones so they don't get hidden
  # Prioritize focus (from the URL) variations over all others 
  my @ordered_snps = map $_->[3], sort { $a->[0] <=> $b->[0] || $b->[1] <=> $a->[1] || $b->[2] <=> $a->[2] } map [ $_->dbID == $focus, $_->length, $_->most_severe_OverlapConsequence->rank, $_ ], @$snps;

  foreach (@ordered_snps) {
    my $dbID = $_->dbID;
    if (!$dbID && $_->isa('Bio::EnsEMBL::Variation::AlleleFeature')) {
      $dbID = $_->variation_feature->dbID;
    }
    my $failed = $_->variation ? $_->variation->is_failed : 0;

    my $variation_name = $_->variation_name;
    my $var_class      = $_->can('var_class') ? $_->var_class : $_->can('variation') && $_->variation ? $_->variation->var_class : '';
    my $start          = $_->start;
    my $end            = $_->end;
    my $allele_string  = $_->allele_string(undef, $strand);
    my $snp_type       = $_->can('display_consequence') ? lc $_->display_consequence : 'snp';
       $snp_type       = lc [ grep $config->{'consequence_types'}{$_}, @{$_->consequence_type} ]->[0] if $config->{'consequence_types'};
       $snp_type       = 'failed' if $failed;
    my $ambigcode;

    if ($config->{'variation_sequence'}) {
      my $url = $hub->url({ species => $name, r => undef, vf => $dbID, v => undef });
      
      $ambigcode = $var_class =~ /in-?del|insertion|deletion/ ? '*' : $_->ambig_code;
      $ambigcode = $variation_name eq $config->{'v'} ? $ambigcode : qq{<a href="$url">$ambigcode</a>} if $ambigcode;
    }
    
    # Use the variation from the underlying slice if we have it.
    my $snp = (scalar keys %$u_snps && $u_snps->{$variation_name}) ? $u_snps->{$variation_name} : $_;
    
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
    
    if ($var_class =~ /in-?del|insertion/ && $seq_region_start > $seq_region_end) {
      # Neither of the following if statements are guaranteed by $seq_region_start > $seq_region_end.
      # It is possible to have inserts for compara alignments which fall in gaps in the sequence, where $s <= $e,
      # and $snp_start only equals $s if $config->{'line_numbering'} is not 'slice';
      $snp_start = $snp_end if $snp_start > $snp_end;
      ($s, $e)   = ($e, $s) if $s > $e;
    }
    
    $s = 0 if $s < 0;
    $e = $config->{'length'} if $e > $config->{'length'};
    $e ||= $s;
    
    # Add the sub slice start where necessary - makes the label for the variation show the correct position relative to the sequence
    $snp_start += $config->{'sub_slice_start'} - 1 if $config->{'sub_slice_start'} && $config->{'line_numbering'} ne 'slice';
    
    # Add the chromosome number for the link text if we're doing species comparisons or resequencing.
    $snp_start = $snp->seq_region_name . ":$snp_start" if scalar keys %$u_snps && $config->{'line_numbering'} eq 'slice';
    
    my $url = $hub->url({
      species => $config->{'ref_slice_name'} ? $config->{'species'} : $name,
      type    => 'Variation',
      action  => 'Explore',
      v       => $variation_name,
      vf      => $dbID,
      vdb     => 'variation'
    });

    my $link_text  = qq{ <a href="$url">$snp_start: $variation_name</a>;};
    (my $ambiguity = $config->{'ambiguity'} ? $_->ambig_code($strand) : '') =~ s/-//g;

    for ($s..$e) {
      # Don't mark up variations when the secondary strain is the same as the sequence.
      # $sequence->[-1] is the current secondary strain, as it is the last element pushed onto the array
      # uncomment last part to enable showing ALL variants on ref strain (might want to add as an opt later)
      next if defined $config->{'match_display'} && $sequence->[-1][$_]{'letter'} =~ /[\.\|~$sequence->[0][$_]{'letter'}]/i;# && scalar @$sequence > 1;

      $markup->{'variants'}{$_}{'focus'}     = 1 if $config->{'focus_variant'} && $config->{'focus_variant'} eq $dbID;
      $markup->{'variants'}{$_}{'type'}      = $snp_type;
      $markup->{'variants'}{$_}{'ambiguity'} = $ambiguity;
      $markup->{'variants'}{$_}{'alleles'}  .= ($markup->{'variants'}{$_}{'alleles'} ? "\n" : '') . $allele_string;
      
      unshift @{$markup->{'variants'}{$_}{'link_text'}}, $link_text if $_ == $s;

      $markup->{'variants'}{$_}{'href'} ||= {
        species => $config->{'ref_slice_name'} ? $config->{'species'} : $name,
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location',
        v => undef,
      };

      if($dbID) {
        push @{$markup->{'variants'}{$_}{'href'}{'vf'}}, $dbID;
      } else {
        push @{$markup->{'variants'}{$_}{'href'}{'v'}},  $variation_name;
      }
      
      $sequence->[$_] = $ambigcode if $config->{'variation_sequence'} && $ambigcode;
    }
    
    $config->{'focus_position'} = [ $s..$e ] if $dbID eq $config->{'focus_variant'};
  }
}

sub markup_exons {
  my ($self, $sequence, $markup, $config) = @_;
  my $i = 0;
  my (%exon_types, $exon, $type, $s, $seq);
  
  my $class = {
    exon0   => 'e0',
    exon1   => 'e1',
    exon2   => 'e2',
    eu      => 'eu',
    intron  => 'ei',
    other   => 'eo',
    gene    => 'eg',
    compara => 'e2',
  };

  if ($config->{'exons_case'}) {
    $class->{'exon1'} = 'el';
  }
 
  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort { $a <=> $b } keys %{$data->{'exons'}}) {
      $exon = $data->{'exons'}{$_};
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $exon->{'id'} if ($config->{'title_display'}||'off') ne 'off';
      
      foreach $type (@{$exon->{'type'}}) {
        $seq->[$_]{'class'} .= "$class->{$type} " unless $seq->[$_]{'class'} =~ /\b$class->{$type}\b/;
        $exon_types{$type} = 1;
      }
    }
    
    $i++;
  }
  
  $config->{'key'}{'exons'}{$_} = 1 for keys %exon_types;
}

sub markup_codons {
  my ($self, $sequence, $markup, $config) = @_;
  my $i = 0;
  my ($class, $seq);

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort { $a <=> $b } keys %{$data->{'codons'}}) {
      $class = $data->{'codons'}{$_}{'class'} || 'co';
      
      $seq->[$_]{'class'} .= "$class ";
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $data->{'codons'}{$_}{'label'} if ($config->{'title_display'}||'off') ne 'off';
      
      if ($class eq 'cu') {
        $config->{'key'}{'other'}{'utr'} = 1;
      } else {
        $config->{'key'}{'codons'}{$class} = 1;
      }
    }
    
    $i++;
  }
}

sub markup_variation {
  my ($self, $sequence, $markup, $config) = @_;
  my $hub = $self->hub;
  my $i   = 0;
  my ($seq, $variation);
  
  my $class = {
    snp    => 'sn',
    insert => 'si',
    delete => 'sd'
  };
  
  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort { $a <=> $b } keys %{$data->{'variants'}}) {
      $variation = $data->{'variants'}{$_};
      
      $seq->[$_]{'letter'} = $variation->{'ambiguity'} if $variation->{'ambiguity'};
      $seq->[$_]{'new_letter'} = $variation->{'ambiguity'} if $variation->{'ambiguity'};
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $variation->{'alleles'} if ($config->{'title_display'}||'off') ne 'off';
      $seq->[$_]{'class'} .= ($class->{$variation->{'type'}} || $variation->{'type'}) . ' ';
      $seq->[$_]{'class'} .= 'bold ' if $variation->{'align'};
      $seq->[$_]{'class'} .= 'var '  if $variation->{'focus'};
      $seq->[$_]{'href'}   = $hub->url($variation->{'href'}) if $variation->{'href'};
      my $new_post  = join '', @{$variation->{'link_text'}} if $config->{'snp_display'} eq 'snp_link' && $variation->{'link_text'};
      $seq->[$_]{'new_post'} = $new_post if $new_post ne $seq->[$_]{'post'};
      $seq->[$_]{'post'} = $new_post;
      
      $config->{'key'}{'variants'}{$variation->{'type'}} = 1 if $variation->{'type'} && !$variation->{'focus'};
    }
    
    $i++;
  }
}

sub markup_comparisons {
  my ($self, $sequence, $markup, $config) = @_;
  my $i          = 0;
  my ($seq, $comparison);

  my $view = $self->view;

  foreach my $data (@$markup) {
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'comparisons'}}) {
      $comparison = $data->{'comparisons'}{$_};
      
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $comparison->{'insert'} if $comparison->{'insert'} && ($config->{'title_display'}||'off') ne 'off';
    }
    
    $i++;
  }
}

sub markup_conservation {
  my ($self, $sequence, $config) = @_;
  my $cons_threshold = int((scalar(@$sequence) + 1) / 2); # Regions where more than 50% of bps match considered "conserved"
  my $conserved      = 0;
  
  for my $i (0..$config->{'length'} - 1) {
    my %cons;
    map $cons{$_->[$i]{'letter'}}++, @$sequence;
    
    my $c = join '', grep { $_ !~ /~|[-.N]/ && $cons{$_} > $cons_threshold } keys %cons;
    
    foreach (@$sequence) {
      next unless $_->[$i]{'letter'} eq $c;
      
      $_->[$i]{'class'} .= 'con ';
      $conserved = 1;
    }
  }
  
  $config->{'key'}{'other'}{'conservation'} = 1 if $conserved;
}

sub markup_line_numbers {
  my ($self, $sequence, $config) = @_;
  my $n = 0; # Keep track of which element of $sequence we are looking at
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $slice       = $sl->{'slice'};
    my $seq         = $sequence->[$n];
    my $align_slice = 0;
    my @numbering;
    
    if (!$slice) {
      @numbering = ({});
    } elsif ($config->{'line_numbering'} eq 'slice') {
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
            $config->{'padding'}{'pre_number'} = length $sl_seq_region_name if length $sl_seq_region_name > $config->{'padding'}{'pre_number'};
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
    
    my $data      = shift @numbering;
    my $s         = 0;
    my $e         = $config->{'display_width'} - 1;
    my $row_start = $data->{'start'};
    my $loop_end  = $config->{'length'} + $config->{'display_width'}; # One line longer than the sequence so we get the last line's numbers generated in the loop
    my ($start, $end);
    
    while ($e < $loop_end) {
      my $shift = 0; # To check if we've got a new element from @numbering
         $start = '';
         $end   = '';
      
      # Comparison species
      if ($align_slice) {
        # Build a segment containing the current line of sequence
        my $segment        = substr $slice->{'seq'}, $s, $config->{'display_width'};
        my $seq_length_seg = $segment =~ s/\.//rg;
        my $seq_length     = length $seq_length_seg; # The length of the sequence which does not consist of a .
        my $first_bp_pos   = 0; # Position of first letter character
        my $last_bp_pos    = 0; # Position of last letter character
        my $old_label      = '';
        
        if ($segment =~ /\w/) {
          $segment      =~ /(^\W*).*\b(\W*$)/;
          $first_bp_pos = 1 + length $1 unless length($1) == length $segment;
          $last_bp_pos  = $2 ? length($segment) - length($2) : length $segment;
        }
        
        # Get the data from the next slice if we have passed the end of the current one
        while (scalar @numbering && $e >= $numbering[0]{'start_pos'}) {          
          $old_label ||= $data->{'label'} if ($data->{'end_pos'} > $s); # Only get the old label for the first new slice - the one at the start of the line
          $shift       = 1;
          $data        = shift @numbering;
          
          $data->{'old_label'} = $old_label;
          
          # Only set $row_start if the line begins with a .
          # If it does not, the previous slice ends mid-line, so we just carry on with it's start number
          $row_start = $data->{'start'} if $segment =~ /^\./;
        }
        
        if ($seq_length && $last_bp_pos) {
          (undef, $row_start) = $slice->get_original_seq_region_position($s + $first_bp_pos); # This is NOT necessarily the same as $end + $data->{'dir'}, as bits of sequence could be hidden
          (undef, $end)       = $slice->get_original_seq_region_position($e + 1 + $last_bp_pos - $config->{'display_width'}); # For AlignSlice display the position of the last meaningful bp
          
          $start = $row_start;
        }

        $s = $e + 1;
      } else { # Single species
        $end       = $e < $config->{'length'} ? $row_start + ($data->{'dir'} * $config->{'display_width'}) - $data->{'dir'} : $data->{'end'};
        $start     = $row_start;
        $row_start = $end + $data->{'dir'} if $end; # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
      }
      
      my $label      = $start && $config->{'comparison'} ? $data->{'label'} : '';
      my $post_label = $shift && $label && $data->{'old_label'} ? $label : '';
         $label      = $data->{'old_label'} if $post_label;
      
      push @{$config->{'line_numbers'}{$n}}, { start => $start, end => $end || undef, label => $label, post_label => $post_label };
      
      # Increase padding amount if required
      $config->{'padding'}{'number'} = length $start if length $start > $config->{'padding'}{'number'};
      
      $e += $config->{'display_width'};
    }
    
    $n++;
  }
  
  $config->{'padding'}{'pre_number'}++ if $config->{'padding'}{'pre_number'}; # Compensate for the : after the label
 
  $config->{'alignment_numbering'} = 1 if $config->{'line_numbering'} eq 'slice' && $config->{'align'};
}

sub make_view { # For IoC: override me if you want to
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View->new(
    $self->hub
  );
}

sub view {
  my ($self) = @_;

  return ($self->{'view'} ||= $self->make_view);
}

sub build_sequence {
  my ($self, $sequence, $config, $exclude_key) = @_;
  my $line_numbers   = $config->{'line_numbers'};

  my $view = $self->view;
  $view->width($config->{'display_width'});

  $view->transfer_data($sequence,$config);

  $view->legend->final if $view->phase == 2;
  $view->legend->compute_legend($self->hub,$config);

  $view->output->more($self->hub->apache_handle->unparsed_uri) if $view->phase==1;
  my $out = $self->view->output->build_output($config,$line_numbers,@{$self->view->sequences}>1,$self->id);
  $view->reset;
  return $out;
}

# When displaying a very large sequence we can break it up into smaller sections and render each of them much more quickly
sub chunked_content {
  my ($self, $total_length, $chunk_length, $url_params, $teaser) = @_;
  my $hub = $self->hub;
  my $i   = 1;
  my $j   = $chunk_length;
  my $end = (int ($total_length / $j)) * $j; # Find the final position covered by regular chunking - we will add the remainer once we get past this point.
  my $url = $self->ajax_url('sub_slice', { %$url_params, update_panel => 1 });
  my $html;
  my $display_width = $self->param('display_width') || 0;
  my $id = $self->id;

  if ($teaser) {
    $html .= qq{<div class="ajax" id="partial_alignment"><input type="hidden" class="ajax_load" value="$url;subslice_start=$i;subslice_end=$display_width" /></div>};
  }
  else {
    # The display is split into a managable number of sub slices, which will be processed in parallel by requests
    while ($j <= $total_length) {
      $html .= qq{<div class="ajax"><input type="hidden" class="ajax_load" value="$url;subslice_start=$i;subslice_end=$j" /></div>};

      last if $j == $total_length;

      $i  = $j + 1;
      $j += $chunk_length;
      $j  = $total_length if $j > $end;
    }    
  }
  $html .= '<div id="full_alignment"></div></div>';
  return $html;
}

1;
