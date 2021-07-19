=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Annotation::Variations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

use EnsEMBL::Web::PureHub;

sub annotate {
  my ($self, $config, $slice_data, $markup, $seq, $ph,$real_sequence) = @_;
  my $name   = $slice_data->{'name'};
  my $slice  = $slice_data->{'slice'};

  my $sequence = $real_sequence->legacy;
  return unless $ph->database($config->{'species'},'variation');
  my $strand = $slice->strand;
  my $focus  = $name eq ($config->{'species'}||'') ? $config->{'focus_variant'} : undef;
  my $snps   = [];
  my $u_snps = {};
  my $adaptor;
  my $vf_adaptor = $ph->get_adaptor($config->{'species'},'variation','get_VariationFeatureAdaptor');
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
  my @ordered_snps = map $_->[3], sort { $a->[0] <=> $b->[0] || $b->[1] <=> $a->[1] || $b->[2] <=> $a->[2] } map [ (($_->dbID||0) == ($focus||-1)), $_->length, $_->most_severe_OverlapConsequence->rank, $_ ], @$snps;

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

    my $url = {
      species => $config->{'ref_slice_name'} ? $config->{'species'} : $name,
      type    => 'Variation',
      action  => 'Explore',
      v       => $variation_name,
      vf      => $dbID,
      vdb     => 'variation'
    };

    my $link = {
      label => "$snp_start: $variation_name",
      url => $url,
    };

    (my $ambiguity = $config->{'ambiguity'} ? ($_->ambig_code($strand)||'') : '') =~ s/-//g;

    for ($s..$e) {
      # Don't mark up variations when the secondary strain is the same as the sequence.
      # $sequence->[-1] is the current secondary strain, as it is the last element pushed onto the array
      # uncomment last part to enable showing ALL variants on ref strain (might want to add as an opt later)

      next if defined $config->{'match_display'} && ($sequence->[$_]{'letter'} =~ /[\.\|~]/i or $sequence->[$_]{'match'});

      $markup->{'variants'}{$_}{'focus'}     = 1 if $config->{'focus_variant'} && $config->{'focus_variant'} eq $dbID;
      $markup->{'variants'}{$_}{'type'}      = $snp_type;
      $markup->{'variants'}{$_}{'ambiguity'} = $ambiguity;
      $markup->{'variants'}{$_}{'alleles'}  .= ($markup->{'variants'}{$_}{'alleles'} ? "\n" : '') . $allele_string;

      unshift @{$markup->{'variants'}{$_}{'links'}}, $link if $_ == $s;
      my $factorytype = $config->{'factorytype'} || 'Location';

      $markup->{'variants'}{$_}{'href'} ||= {
        species => $config->{'ref_slice_name'} ? $config->{'species'} : $name,
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => $factorytype,
        v => undef,
      };

      if($dbID) {
        push @{$markup->{'variants'}{$_}{'href'}{'vf'}}, $dbID;
      } else {
        push @{$markup->{'variants'}{$_}{'href'}{'v'}},  $variation_name;
      }
    }

    $config->{'focus_position'} = [ $s..$e ] if ($dbID||"\r") eq ($config->{'focus_variant'}||"\n");
  }
}

1;
