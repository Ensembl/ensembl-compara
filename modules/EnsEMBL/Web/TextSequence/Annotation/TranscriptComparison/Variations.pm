package EnsEMBL::Web::TextSequence::Annotation::TranscriptComparison::Variations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation::Variations);

sub annotate {
  my ($self, $config, $slice_data, $markup, $seq, $ph,$real_sequence) = @_;

  my $sequence = $real_sequence->legacy;
  # XXX should have per-rope switchable Annotation
  return if($slice_data->{'type'} eq 'gene');
  my $slice = $slice_data->{'slice'};
  my $transcript = $slice_data->{'transcript'};

  my $vardb = $ph->database($config->{'species'},'variation');
  return unless $vardb;
  my $vf_adaptor = $vardb->get_VariationFeatureAdaptor;
  my $variation_features = $config->{'population'} ? $vf_adaptor->fetch_all_by_Slice_Population($slice, $config->{'population'}, $config->{'min_frequency'}) : $vf_adaptor->fetch_all_by_Slice($slice);
  my @transcript_variations = @{$ph->get_adaptor($config->{'species'},'variation','get_TranscriptVariationAdaptor')->fetch_all_by_VariationFeatures($variation_features, [ $transcript ])};
  @transcript_variations = grep $_->variation_feature->length <= $config->{'snp_length_filter'}, @transcript_variations if $config->{'hide_long_snps'};
  @transcript_variations = grep { !$self->too_rare_snp($_->variation_feature,$config) } @transcript_variations;
  my $length                = scalar(@{$sequence}) - 1;
  my $transcript_id         = $transcript->stable_id;
  my $strand                = $transcript->strand;
  my (%href, %class);
  
  foreach my $transcript_variation (map $_->[2], sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } map [ $_->variation_feature->length, $_->most_severe_OverlapConsequence->rank, $_ ], @transcript_variations) {
    my $consequence = $config->{'consequence_filter'} ? lc [ grep $config->{'consequence_filter'}{$_}, @{$transcript_variation->consequence_type} ]->[0] : undef;
    
    next if ($config->{'consequence_filter'} && !$consequence);
    my $vf            = $transcript_variation->variation_feature;
    next if $self->hidden_source($vf,$config);
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
       
    $config->{'key'}{'variants'}{$consequence} = 1;
       
    for ($start..$end) {
      next if $sequence->[$_]{'letter'} eq '-';
        
      $markup->{'variants'}{$_}{'type'}     = $consequence;
      $markup->{'variants'}{$_}{'alleles'} .= ($markup->{'variants'}{$_}{'alleles'} ? "\n" : '') . $allele_string;
      $markup->{'variants'}{$_}{'href'}   ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location',
        _transcript => $transcript_id,
      };  

      push @{$markup->{'variants'}{$_}{'href'}{'v'}},  $name;
      push @{$markup->{'variants'}{$_}{'href'}{'vf'}}, $dbID;
    }
  }
}

1;
 
