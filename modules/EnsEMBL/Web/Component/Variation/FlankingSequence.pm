# $Id$

package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;

use base qw(EnsEMBL::Web::Component::Variation EnsEMBL::Web::Component::TextSequence);

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  
  my $hub               = $self->hub;
  my $variation         = $object->Obj;
  my $vf                = $hub->param('vf');
  my $flanking          = $hub->param('select_sequence') || 'both';
  my $flank_size        = $hub->param('flank_size') || 400;
  my @flank             = $flanking eq 'both' ? ($flank_size, $flank_size) : $flanking eq 'up' ? ($flank_size) : (undef, $flank_size);
  my %mappings          = %{$object->variation_feature_mapping}; 
  my $v                 = keys %mappings == 1 ? [ values %mappings ]->[0] : $mappings{$vf};
  my $variation_feature = $variation->get_VariationFeature_by_dbID($vf);
  my $align_quality     = $variation_feature->flank_match;
  my $chr_end           = $variation_feature->slice->end;
  my $slice_start       = $v->{'start'} - $flank[0] > 1        ? $v->{'start'} - $flank[0] : 1;
  my $slice_end         = $v->{'end'}   + $flank[1] > $chr_end ? $chr_end                  : $v->{'end'} + $flank[1];
  my $slice             = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region(undef, $v->{'Chr'}, $slice_start, $slice_end, $v->{'strand'});
  my @sequence          = [ map {{ letter => $_ }} split '', $slice->seq ];
  my @markup            = ({});
  my $html;
  
  my $config = {
    display_width  => $hub->param('display_width') || 60,
    species        => $hub->species,
    snp_display    => $hub->param('snp_display') eq 'no' ? 0 : 1,
    v              => $hub->param('v'),
    focus_variant  => $vf,
    failed_variant => 1,
    ambiguity      => 1,
    length         => $slice->length,
  };
  
  # check if the flanking sequences match the reference sequence
  if (defined $align_quality && $align_quality < 1) {
    my $source_link = $hub->get_ExtURL_link('here', uc($variation->source), "$config->{'v'}#submission");
       $source_link =~ s/%23/#/;
       
    $html .= $self->_warning('Alignment quality', "
      The longest flanking sequence submitted to dbSNP for this variant doesn't match the reference sequence displayed below.<br />
      For more information about the submitted sequences, please click on the dbSNP link $source_link.
    ", 'auto');
  }
  
  # The variation_feature has coords relative to the whole chromosome.
  # If snp_display is off, we only want to display this feature, so hack its start and end to be relative
  # to the slice, so that it can be used in the parent module (all variations there are relative to the slice)
  $variation_feature->$_($variation_feature->$_ - $slice->start + 1) for qw(start end);
  
  $self->set_variations($config, { name => $config->{'species'}, slice => $slice }, $markup[0], undef, $config->{'snp_display'} ? undef : $variation_feature);
  $self->markup_variation(\@sequence, \@markup, $config); 
  
  $html .= $self->tool_buttons($slice->seq, $config->{'species'});
  $html .= sprintf '<div class="sequence_key">%s</div>', $self->get_key($config);
  $html .= $self->build_sequence(\@sequence, $config);
  
  return $self->_info('Flanking sequence', qq{ 
    The sequence below is from the <b>reference genome</b> flanking the variant location.
    The variant is shown in <u style="color:red;font-weight:bold">red</u> text.
    Neighbouring variants are shown with highlighted letters and ambiguity codes.<br />
    To change the display of the flanking sequence (e.g. hide the other variants, change the length of the flanking sequence), 
    use the "<b>Configure this page</b>" link on the left.
  }, 'auto') . $html;
}

1;
