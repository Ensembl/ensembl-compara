=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;

use EnsEMBL::Web::TextSequence::View::FlankingSequence;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Variation);

sub initialize_new {
  my $self              = shift;
  my $hub               = $self->hub;
  my $object            = $self->object || $hub->core_object('variation');
  my $vf                = $hub->param('vf');

  my $type = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);

  my $flanking          = $hub->param('select_sequence') || $vc->get('select_sequence');
  my $flank_size        = $hub->param('flank_size') || $vc->get('flank_size');
  my @flank             = $flanking eq 'both' ? ($flank_size, $flank_size) : $flanking eq 'up' ? ($flank_size) : (undef, $flank_size);
  my $v                 = $object->selected_variation_feature_mapping;
  my $variation_feature = $object->get_selected_variation_feature;
  my $variation_string  = $variation_feature->ambig_code || '[' . $variation_feature->allele_string . ']';
  my $chr_end           = $variation_feature->slice->seq_region_Slice->end;
  my $slice_start       = $v->{'start'} - $flank[0] > 1        ? $v->{'start'} - $flank[0] : 1;
  my $slice_end         = $v->{'end'}   + $flank[1] > $chr_end ? $chr_end                  : $v->{'end'} + $flank[1];

  my $slice_adaptor     = $hub->get_adaptor('get_SliceAdaptor');
  my @order             = $v->{'strand'} == 1 ? qw(up var down) : qw(down var up);
  my @sequence;
  
  my %slices = (
    var  => $slice_adaptor->fetch_by_region(undef, $v->{'Chr'}, $v->{'start'}, $v->{'end'}, $v->{'strand'}),
    up   => $flank[0] ? $slice_adaptor->fetch_by_region(undef, $v->{'Chr'}, $slice_start, $v->{'start'} - 1, $v->{'strand'}) : undef,
    down => $flank[1] ? $slice_adaptor->fetch_by_region(undef, $v->{'Chr'}, $v->{'end'} + 1, $slice_end,     $v->{'strand'}) : undef
  );
 
  my $config = {
    display_width  => $hub->param('display_width') || $vc->get('display_width'),
    species        => $hub->species,
    snp_display    => $hub->param('snp_display') || $vc->get('snp_display'),
    hide_long_snps => $hub->param('hide_long_snps') || $vc->get('hide_long_snps'),
    hide_rare_snps => $hub->param('hide_rare_snps') || $vc->get('hide_rare_snps'),
    v              => $hub->param('v'),
    focus_variant  => $vf,
    failed_variant => 1,
    ambiguity      => 1,
    length         => $flank[0] + $flank[1] + length $variation_string,
  };
  
  my $seq = $self->view->new_sequence;
  foreach (grep $slices{$_}, @order) {
    my $seq2;
    
    if ($_ eq 'var') {
      my $seq = [ map {{ letter => $_, class => 'var ' }} split '', $variation_string ];
      $seq2 = $self->view->new_sequence('nowhere');
      $seq2->legacy($seq);
    } else {
      my $slice  = $slices{$_};
      my $markup = {};
      my $seq    = [ map {{ letter => $_ }} split '', $slice->seq ];
      $seq2 = $self->view->new_sequence('nowhere');
      $seq2->legacy($seq);
 
      if ($config->{'snp_display'} eq 'on') {
        $self->set_variation_filter($config);
        $self->set_variations($config, { name => $config->{'species'}, slice => $slice }, $markup);
        $self->view->markup([$seq2],[$markup],$config);
      }
    }
    
    push @sequence, $seq2;
  }
 
  # XXX horrible hack
  $seq->legacy([map { @{$_->legacy} } @sequence]);
 
  return ([ $seq ], $config);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this variant', $object->not_unique_location) if $object->not_unique_location;
  
  my ($sequence, $config) = $self->initialize;
 
  my $html; 
  my $hub           = $self->hub;
  my $variation     = $object->Obj;
  my $align_quality = $object->get_selected_variation_feature->flank_match;

  # check if the flanking sequences match the reference sequence
  if (defined $align_quality && $align_quality < 1) {
    my $source_link = $hub->get_ExtURL_link('here', uc $variation->source_name, "$config->{'v'}#submission");
       $source_link =~ s/%23/#/;
       
    $html .= $self->_warning('Alignment quality', "
      The longest flanking sequence submitted to dbSNP for this variant doesn't match the reference sequence displayed below.<br />
      For more information about the submitted sequences, please click on the dbSNP link $source_link.
    ", 'auto');
  }
  
  $html .= $self->build_sequence($sequence, $config);

  my $desc = '';
  $desc = $self->describe_filter($config) unless $self->param('follow');
  return $self->_info('Flanking sequence', qq{ 
    The sequence below is from the <b>reference genome</b> flanking the variant location.
    The variant is shown in <u style="color:red;font-weight:bold">red</u> text.
    Neighbouring variants are shown with highlighted letters and ambiguity codes.<br />
    To change the display of the flanking sequence (e.g. hide the other variants, change the length of the flanking sequence), 
    use the "<b>Configure this page</b>" link on the left.
  }, 'auto') . $desc . $html;
}

sub export_options { return {'action' => 'FlankingSeq'}; }

sub get_export_data {
  my $self = shift;
  return $self->initialize;
}

sub initialize_export_new {
  my $self = shift;
  return $self->initialize_new;
}

sub make_view {
  my ($self) = @_; 

  return EnsEMBL::Web::TextSequence::View::FlankingSequence->new(
    $self->hub
  );  
}

1;
