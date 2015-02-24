=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::TranscriptComparison;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Gene);

sub _init { $_[0]->SUPER::_init(100); }

sub initialize {
  my ($self, $start, $end) = @_;
  my $hub         = $self->hub;
  my @consequence = $hub->param('consequence_filter');
  
  my $config = {
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    v_space         => "\n",
    comparison      => 1,
    exon_display    => 1,
    sub_slice_start => $start,
    sub_slice_end   => $end
  };

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);

  for (qw(exons_only snp_display title_display line_numbering hide_long_snps)) {
    $config->{$_} = $hub->param($_) unless ($hub->param($_) eq 'off' || $vc->get($_) eq 'off');
  }
  
  $config->{'snp_display'}        = 0 unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if $config->{'snp_display'} && scalar(@consequence) && join('', @consequence) ne 'off';
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'}     = 1;
  }
  
  my ($sequence, $markup) = $self->get_sequence_data($config);

  $self->markup_exons($sequence, $markup, $config);
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_comparisons($sequence, $markup, $config);
  $self->markup_line_numbers($sequence, $config)       if $config->{'line_numbering'};
  
  return ($sequence, $config);
}

sub content {
  my $self   = shift;
  my $slice  = $self->object->slice; # Object for this section is the slice
  my $length = $slice->length;
  my $html   = '';

  if (!$self->hub->param('t1')) {
    $html = $self->_info(
      'No transcripts selected',
      sprintf(
        'You must select transcripts using the "Select transcripts" button from menu on the left hand side of this page, or by clicking <a href="%s" class="modal_link" rel="modal_select_transcripts">here</a>.',
        $self->view_config->extra_tabs->[1]
      )
    ); 
  } elsif ($length >= $self->{'subslice_length'}) {
    $html .= '<div class="_adornment_key adornment-key"></div>' . $self->chunked_content($length, $self->{'subslice_length'}, { length => $length });
  } else {
    $html .= $self->content_sub_slice; # Direct call if the sequence length is short enough
  }
  
  return $html;
}

sub content_sub_slice {
  my $self   = shift;
  my $hub    = $self->hub;
  my $start  = $hub->param('subslice_start');
  my $end    = $hub->param('subslice_end');
  my $length = $hub->param('length');
  
  my ($sequence, $config) = $self->initialize($start, $end);
  
  if ($end && $end == $length) {
    $config->{'html_template'} = '<pre class="text_sequence">%s</pre>';
  } elsif ($start && $end) {
    $config->{'html_template'} = '<pre class="text_sequence" style="margin:0">%s</pre>';
  } else {
    $config->{'html_template'} = '<pre class="text_sequence">%s</pre>';
  }
  
  $config->{'html_template'} .= '<p class="invisible">.</p>';
  $self->id('');
  
  return $self->build_sequence($sequence, $config,1);
}

sub selected_transcripts {
  my $self = shift;
  return map { $_ => $self->hub->param($_) } grep /^(t\d+)$/, $self->hub->param;
}

sub export_options {
  my $self      = shift;
  my %selected  = $self->selected_transcripts;
  my @t_params  = keys %selected;

  return {
    'params'  => \@t_params,
    'action'  => 'TranscriptComparison'
  };
}

sub initialize_export {
  my $self = shift;
  my $hub  = $self->hub;
  my $vc = $hub->get_viewconfig('TranscriptComparison', 'Gene');
  my @params = qw(sscon snp_display flanking line_numbering);
  foreach (@params) {
    $hub->param($_, $vc->get($_));
  }
  return $self->initialize;
}

sub get_export_data {
  my $self = shift;
  my $hub  = $self->hub;
  ## Fetch gene explicitly, as we're probably coming from a DataExport URL
  my $gene = $self->hub->core_object('gene');
  return unless $gene;
  my %selected       = reverse $self->selected_transcripts; 
  my @transcripts;
  foreach (@{$gene->Obj->get_all_Transcripts}) {
    push @transcripts, $_ if $selected{$_->stable_id};
  }
  return @transcripts;
}

sub get_sequence_data {
  my ($self, $config) = @_;
  my $hub            = $self->hub;
  my $object         = $self->object || $hub->core_object('gene');
  my $gene           = $object->Obj;
  my $gene_name      = $gene->external_name;
  my $subslice_start = $config->{'sub_slice_start'};
  my $subslice_end   = $config->{'sub_slice_end'};
  my $slice          = $object->slice;
     $slice          = $slice->sub_Slice($subslice_start, $subslice_end) if $subslice_start && $subslice_end;
  my $start          = $slice->start;
  my $length         = $slice->length;
  my $strand         = $slice->strand;
  my @gene_seq       = split '', $slice->seq;
  my %selected       = map { $hub->param("t$_") => $_ } grep s/^t(\d+)$/$1/, $hub->param;
  my @transcripts    = map { $selected{$_->stable_id} ? [ $selected{$_->stable_id}, $_ ] : () } @{$gene->get_all_Transcripts};
  my @sequence       = ([ map {{ letter => $_ }} @gene_seq ]);
  my @markup         = ({'exons' => { map { $_ => {'type' => ['gene']} } 0..$#gene_seq } });
  
  push @{$config->{'slices'}}, { slice => $slice, name => $gene_name || $gene->stable_id };
  
  $_-- for grep $_, $subslice_start, $subslice_end;
  
  foreach my $transcript (map $_->[1], sort { $a->[0] <=> $b->[0] } @transcripts) {
    my $transcript_id   = $transcript->stable_id;
    my $transcript_name = $transcript->external_name || $transcript_id;
       $transcript_name = $transcript_id if $transcript_name eq $gene_name;
    my @exons           = @{$transcript->get_all_Exons};
    my @seq             = map {{ letter => $_ }} @gene_seq;
    my $type            = 'exon1';
    my $mk              = {};
    
    my ($crs, $cre, $transcript_start) = map $_ - $start, $transcript->coding_region_start, $transcript->coding_region_end, $transcript->start;
    my ($first_exon, $last_exon)       = map $exons[$_]->stable_id, 0, -1;
    
    if ($strand == -1) {
      $_ = $length - $_ - 1, for $crs, $cre;
      ($crs, $cre) = ($cre, $crs);
    }
    
    $crs--;
    
    for my $exon (@exons) {
      my $exon_id = $exon->stable_id;
      my ($s, $e) = map $_ - $start, $exon->start, $exon->end;

      my $utr_type = $exon->coding_region_start($transcript) ? 'eu' : 'exon0'; # if coding_region_start returns unded, it a non-coding exon

      if ($strand == -1) {
        $_ = $length - $_ - 1, for $s, $e;
        ($s, $e) = ($e, $s);
      }
      
      if ($subslice_start || $subslice_end) {        
        if ($e < 0 || $s > $subslice_end) {
          if (!$config->{'exons_only'} && (($exon_id eq $first_exon && $s > $subslice_end) || ($exon_id eq $last_exon && $e < 0))) {
            $seq[$_]{'letter'} = '-' for 0..$#seq;
          }
          
          next;
        }
        
        $s = 0           if $s < 0;
        $e = $length - 1 if $e >= $length;
      }
      
      if (!$config->{'exons_only'}) {
        if ($exon_id eq $first_exon && $s) {
          $seq[$_]{'letter'} = '-' for 0..$s-1;
        } elsif ($exon_id eq $last_exon) {
          $seq[$_]{'letter'} = '-' for $e+1..$#seq;
        }
      }
      
      if ($exon->phase == -1) {
        $type = $utr_type;
      } elsif ($exon->end_phase == -1) {
        $type = 'exon1';
      }
      
      for ($s..$e) {
        push @{$mk->{'exons'}{$_}{'type'}}, $type;
        $type = $type eq 'exon1' ? $utr_type : 'exon1' if $_ == $crs || $_ == $cre;
        
        $mk->{'exons'}{$_}{'id'} .= ($mk->{'exons'}{$_}{'id'} ? "\n" : '') . $exon_id unless $mk->{'exons'}{$_}{'id'} =~ /$exon_id/;
      }
    }
    
    if ($config->{'exons_only'}) {
      $seq[$_]{'letter'} = '-' for grep !$mk->{'exons'}{$_}, 0..$#seq;
    }

    # finally mark anything left as introns
    for (0..$#seq) {
      $mk->{'exons'}{$_}{'type'} ||= ['intron'];
    }

    $self->set_variations($config, $slice, $mk, $transcript, \@seq) if $config->{'snp_display'};
    
    push @sequence, \@seq;
    push @markup, $mk;
    push @{$config->{'slices'}}, {
      slice => $slice,
      name  => sprintf(
        '<a href="%s"%s>%s</a>',
        $hub->url({ type => 'Transcript', action => 'Summary', t => $transcript_id }),
        $transcript_id eq $transcript_name ? '' : qq{title="$transcript_id"},
        $transcript_name
      )
    };
  }
  
  $config->{'ref_slice_seq'} = $sequence[0];
  $config->{'length'}        = $length;
  
  return (\@sequence, \@markup);
}

sub set_variations {
  my ($self, $config, $slice, $markup, $transcript, $sequence) = @_;
  my $variation_features    = $config->{'population'} ? $slice->get_all_VariationFeatures_by_Population($config->{'population'}, $config->{'min_frequency'}) : $slice->get_all_VariationFeatures;
  my @transcript_variations = @{$self->hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation')->fetch_all_by_VariationFeatures($variation_features, [ $transcript ])};
     @transcript_variations = grep $_->variation_feature->length <= $self->{'snp_length_filter'}, @transcript_variations if $config->{'hide_long_snps'};
  my $length                = scalar @$sequence - 1;
  my $transcript_id         = $transcript->stable_id;
  my $strand                = $transcript->strand;
  my (%href, %class);
  
  foreach my $transcript_variation (map $_->[2], sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } map [ $_->variation_feature->length, $_->most_severe_OverlapConsequence->rank, $_ ], @transcript_variations) {
    my $consequence = $config->{'consequence_filter'} ? lc [ grep $config->{'consequence_filter'}{$_}, @{$transcript_variation->consequence_type} ]->[0] : undef;
    
    next if ($config->{'consequence_filter'} && !$consequence);
    my $vf            = $transcript_variation->variation_feature;
    my $name          = $vf->variation_name;
    my $allele_string = $vf->allele_string(undef, $strand);
    my $dbID          = $vf->dbID;
    my $start         = $vf->start - 1;
    my $end           = $vf->end   - 1;
    
    # Variation is an insert if start > end
    ($start, $end) = ($end, $start) if $start > $end;
    
    $start = 0 if $start < 0;
    $end   = $length if $end > $length;
    
    $consequence ||= lc $transcript_variation->display_consequence;
    
    $config->{'key'}{'variations'}{$consequence} = 1;
    
    for ($start..$end) {
      next if $sequence->[$_]{'letter'} eq '-';
      
      $markup->{'variations'}{$_}{'type'}     = $consequence;
      $markup->{'variations'}{$_}{'alleles'} .= ($markup->{'variations'}{$_}{'alleles'} ? "\n" : '') . $allele_string;
      $markup->{'variations'}{$_}{'href'}   ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location',
        _transcript => $transcript_id,
      };
      
      push @{$markup->{'variations'}{$_}{'href'}{'v'}},  $name;
      push @{$markup->{'variations'}{$_}{'href'}{'vf'}}, $dbID;
    }
  }
}

sub get_key {
  $_[1]->{'key'}{'exons/Introns'} = 1;
  $_[1]->{'key'}{'exons'} = 0;
  
  return shift->SUPER::get_key($_[0], {
    exons           => {},
    'exons/Introns' => {
      exon1           => { class => 'e1',     text => 'Translated sequence'  },
      eu              => { class => 'eu',     text => 'UTR'                  },
      intron          => { class => 'ei',     text => 'Intron'               },
      exon0           => { class => 'e0',     text => 'Non-coding exon'      },
      gene            => { class => 'eg',     text => 'Gene sequence'        },
    }
  }, $_[2]);
}

1;
