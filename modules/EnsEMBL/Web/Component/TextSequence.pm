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

use List::MoreUtils qw(any);

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

# XXX hack!
sub initialize {
  my ($self, $slice, $start, $end, $adorn) = @_;
  
  my ($sequence,$config) = $self->initialize_new($slice,$start,$end,$adorn);
  my @out = map { $_->legacy } @$sequence;
  return (\@out, $config);
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;

  return if ($hub->action eq 'Sequence_Protein' && !$self->object->Obj->translation);

  return unless $self->can('export_options');

  my $options = $self->export_options || {};

  return unless $options->{'action'};

  my @namespace = split('::', ref($self));
  my $params  = {
    'type' => 'DataExport',
    'action' => $options->{'action'},
    'data_type' => $self->hub->type,
    'component' => $namespace[-1]
  };
  foreach (@{$options->{'params'} || []}) {
    if (ref($_) eq 'ARRAY') {
      $params->{$_->[0]} = $_->[1];
    }
    else {
      $params->{$_} = $self->param($_);
    }

  }

  
  if ($options->{'action'} =~ /Align/ && ($hub->param('need_target_slice_table') || !$hub->get_alignment_id)) {
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

sub hidden_source {
  my ($self,$v,$config) = @_;

  return any { $v->variation->source_name eq $_ } @{$config->{'hidden_sources'}||[]};
}

sub get_sequence_data {
  my ($self, $slices, $config) = @_;
  my $hub      = $self->hub;
  my @markup;
 
  $self->set_variation_filter($config) if $config->{'snp_display'} ne 'off';
  
  $config->{'length'} ||= $slices->[0]{'slice'}->length;

  my $view = $self->view;
  $view->set_annotations($config);
 
  $view->prepare_ropes($config,$slices); 
  die "No ropes!" unless @{$view->sequences};
  my @sequences = @{$view->sequences};
  foreach my $sl (@$slices) {
    my $sequence = shift @sequences;
    my $mk  = {};    
    my $seq = $sl->{'seq'} || $sl->{'slice'}->seq(1);
    $view->annotate($config,$sl,$mk,$seq,$sequence);
    push @markup, $mk;
  }
 
  return ([@{$view->sequences}], \@markup);
}

sub set_variation_filter {
  my ($self, $config) = @_;
  my $hub = $self->hub;
  
  my @consequence       = $self->param('consequence_filter');
  my @evidence          = $self->param('evidence_filter');
  my $pop_filter        = $self->param('population_filter');
  my %consequence_types = map { $_ => 1 } @consequence if join('', @consequence) ne 'off';

  if (%consequence_types) {
    $config->{'consequence_types'}  = \%consequence_types;
    $config->{'consequence_filter'} = \@consequence;
  }

  if (@evidence && join('', @evidence) ne 'off') {
    $config->{'evidence_filter'} = \@evidence;
  }
  
  if ($pop_filter && $pop_filter ne 'off') {
    $config->{'population'}        = $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($pop_filter);
    $config->{'min_frequency'}     = $self->param('min_frequency');
    $config->{'population_filter'} = $pop_filter;
  }
  
  $config->{'snp_length_filter'} = 10; # Max length of VariationFeatures to be displayed
  $config->{'hide_long_snps'} = $self->param('hide_long_snps') eq 'yes';
  $config->{'hide_rare_snps'} = $self->param('hide_rare_snps');
  $config->{'hidden_sources'} = [$self->param('hidden_sources')];
}

sub describe_filter {
  my ($self,$config) = @_;

  my $blurb = qq(
    Filters have been applied to this sequence. If you no longer wish to
    use these filters, use "Configure this page" to remove them.
  );
  my @filters;
  # Hidden sources
  my %hs = map { $_ => 1 } @{$config->{'hidden_sources'}||[]};
  delete $hs{'_all'} if exists $hs{'_all'};
  delete $hs{''} if exists $hs{''};
  if(%hs) {
    push @filters,"Hide variants from sources: ".join(', ',sort keys %hs);
  }
  # Hidden consequence types
  my $cf = $config->{'consequence_filter'};
  $cf = [ keys %$cf ] if ref($cf) eq 'HASH';
  my %cf = map { $_ => 1 } @{$cf||[]};
  delete $cf{'off'} if exists $cf{'off'};
  delete $cf{''} if exists $cf{''};
  if(%cf) {
    push @filters,"Only showing variants with consequence types: ".
      join(', ',sort keys %cf);
  }

  # Hidden evidence status
  my $ef = $config->{'evidence_filter'};
  $ef = [ keys %$ef ] if ref($ef) eq 'HASH';
  my %ef = map { $_ => 1 } @{$ef||[]};
  delete $ef{'off'} if exists $ef{'off'};
  delete $ef{''} if exists $ef{''};
  if(%ef) {
    push @filters,"Only showing variants with evidence status: ".
      join(', ',sort keys %ef);
  }

  return '' unless @filters;
  $blurb .= "<ul>".join('',map { "<li>$_</li>" } @filters)."</ul>";
  return $self->_info('Filters applied',$blurb);
}

sub set_variations {
  my ($self, $config, $slice_data, $markup, $sequence, $focus_snp_only) = @_;
  my $hub    = $self->hub;
  my $name   = $slice_data->{'name'};
  my $slice  = $slice_data->{'slice'};
  
  my $species = $slice->can('genome_db') ? $hub->species_defs->production_name_mapping($slice->genome_db->name) : $hub->species;
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

    # Evidence filter
    my %ef = map { $_ ? ($_ => 1) : () } @{$config->{'evidence_filter'}};
    delete $ef{'off'} if exists $ef{'off'};
    if(%ef) {
      my @filtered_snps;
      foreach my $snp (@$snps) {
        my $evidence = $snp->get_all_evidence_values;
        if (grep $ef{$_}, @$evidence) {
          push @filtered_snps, $snp;
        }
      }
      $snps = \@filtered_snps;
    }
  }
  return unless scalar @$snps;

  $snps = [ grep { !$self->hidden_source($_,$config) } @$snps ];
 
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

  $snps = [ grep $_->length <= $config->{'snp_length_filter'} || $config->{'focus_variant'} && $config->{'focus_variant'} eq $_->dbID, @$snps ] if ($config->{'hide_long_snps'}||'off') ne 'off';

  # order variations descending by worst consequence rank so that the 'worst' variation will overwrite the markup of other variations in the same location
  # Also prioritize shorter variations over longer ones so they don't get hidden
  # Prioritize focus (from the URL) variations over all others 
  my @ordered_snps = map $_->[3], sort { $a->[0] <=> $b->[0] || $b->[1] <=> $a->[1] || $b->[2] <=> $a->[2] } map [ ($_->dbID||0) == ($focus||-1), $_->length, $_->most_severe_OverlapConsequence->rank, $_ ], @$snps;

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

sub make_view { # For IoC: override me if you want to
  my ($self,$hub) = @_;

  return EnsEMBL::Web::TextSequence::View->new($hub);
}

sub view {
  my ($self) = @_;

  return ($self->{'view'} ||= $self->make_view($self->hub));
}

sub build_sequence {
  my ($self, $sequences, $config, $exclude_key) = @_;
  my $line_numbers   = $config->{'line_numbers'};

  my $view = $self->view;
  $view->width($config->{'display_width'});

  $view->transfer_data_new($config);

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
  my $align = $hub->get_alignment_id;

  my $follow = 0;
  if ($teaser) {
    $html .= qq{<div class="ajax" id="partial_alignment"><input type="hidden" class="ajax_load" value="$url;align=$align;subslice_start=$i;subslice_end=$display_width;follow=$follow" /></div>};
  }
  else {
    # The display is split into a managable number of sub slices, which will be processed in parallel by requests
    while ($j <= $total_length) {
      $html .= qq{<div class="ajax"><input type="hidden" class="ajax_load" value="$url;subslice_start=$i;subslice_end=$j;follow=$follow" /></div>};

      last if $j == $total_length;

      $i  = $j + 1;
      $j += $chunk_length;
      $j  = $total_length if $j > $end;
      $follow = 1;
    }    
  }
  $html .= '<div id="full_alignment"></div></div>';
  return $html;
}

1;
