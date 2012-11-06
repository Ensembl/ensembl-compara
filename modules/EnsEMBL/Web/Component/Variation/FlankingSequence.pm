# $Id$

package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Variation);

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
  my $variation_string  = $variation_feature->ambig_code || '[' . $variation_feature->allele_string . ']';
  my $align_quality     = $variation_feature->flank_match;
  my $chr_end           = $variation_feature->slice->end;
  my $slice_start       = $v->{'start'} - $flank[0] > 1        ? $v->{'start'} - $flank[0] : 1;
  my $slice_end         = $v->{'end'}   + $flank[1] > $chr_end ? $chr_end                  : $v->{'end'} + $flank[1];
  my $slice_adaptor     = $hub->get_adaptor('get_SliceAdaptor');
  my @order             = $v->{'strand'} == 1 ? qw(up var down) : qw(down var up);
  my (@sequence, $html);
  
  my %slices = (
    var  => $slice_adaptor->fetch_by_region(undef, $v->{'Chr'}, $v->{'start'}, $v->{'end'}, $v->{'strand'}),
    up   => $flank[0] ? $slice_adaptor->fetch_by_region(undef, $v->{'Chr'}, $slice_start, $v->{'start'} - 1, $v->{'strand'}) : undef,
    down => $flank[1] ? $slice_adaptor->fetch_by_region(undef, $v->{'Chr'}, $v->{'end'} + 1, $slice_end,     $v->{'strand'}) : undef
  );
  
  my $config = {
    display_width  => $hub->param('display_width') || 60,
    species        => $hub->species,
    snp_display    => $hub->param('snp_display') eq 'no' ? 0 : 1,
    v              => $hub->param('v'),
    focus_variant  => $vf,
    failed_variant => 1,
    ambiguity      => 1,
    length         => $flank[0] + $flank[1] + length $variation_string,
  };
  
  foreach (grep $slices{$_}, @order) {
    my $seq;
    
    if ($_ eq 'var') {
      $seq = [ map {{ letter => $_, class => 'var ' }} split '', $variation_string ];
    } else {
      my $slice  = $slices{$_};
      my $markup = {};
         $seq    = [ map {{ letter => $_ }} split '', $slice->seq ];
      
      if ($config->{'snp_display'}) {
        $self->set_variations($config, { name => $config->{'species'}, slice => $slice }, $markup);
        $self->markup_variation($seq, $markup, $config);
      }
    }
    
    push @sequence, @$seq;
  }
  
  # check if the flanking sequences match the reference sequence
  if (defined $align_quality && $align_quality < 1) {
    my $source_link = $hub->get_ExtURL_link('here', uc($variation->source), "$config->{'v'}#submission");
       $source_link =~ s/%23/#/;
       
    $html .= $self->_warning('Alignment quality', "
      The longest flanking sequence submitted to dbSNP for this variant doesn't match the reference sequence displayed below.<br />
      For more information about the submitted sequences, please click on the dbSNP link $source_link.
    ", 'auto');
  }
  
  $html .= $self->tool_buttons(join '', map $slices{$_} ? $slices{$_}->seq : (), @order, $config->{'species'});
  $html .= sprintf '<div class="sequence_key">%s</div>', $self->get_key($config);
  $html .= $self->build_sequence([ \@sequence ], $config);
  
  return $self->_info('Flanking sequence', qq{ 
    The sequence below is from the <b>reference genome</b> flanking the variant location.
    The variant is shown in <u style="color:red;font-weight:bold">red</u> text.
    Neighbouring variants are shown with highlighted letters and ambiguity codes.<br />
    To change the display of the flanking sequence (e.g. hide the other variants, change the length of the flanking sequence), 
    use the "<b>Configure this page</b>" link on the left.
  }, 'auto') . $html;
}

sub markup_variation {
  my ($self, $seq, $markup, $config) = @_;
  my $hub = $self->hub;
  my $variation;
  
  foreach (sort { $a <=> $b } keys %{$markup->{'variations'}}) {
    next unless $seq->[$_];
    
    $variation = $markup->{'variations'}{$_};
    
    $seq->[$_]{'letter'} = $variation->{'ambiguity'} if $variation->{'ambiguity'};
    $seq->[$_]{'class'} .= "$variation->{'type'} ";
    $seq->[$_]{'href'}   = $hub->url($variation->{'href'});
    
    $config->{'key'}{'variations'}{$variation->{'type'}} = 1 if $variation->{'type'} && !$variation->{'focus'};
  }
}

1;
