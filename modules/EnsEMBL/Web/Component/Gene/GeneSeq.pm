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

package EnsEMBL::Web::Component::Gene::GeneSeq;

use strict;

use parent qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Gene);

use EnsEMBL::Web::TextSequence::View::GeneSeq;

sub _init { $_[0]->SUPER::_init(500); }

sub get_object {
  my $self = shift;
  my $hub  = $self->hub;
  return $hub->param('lrg') ? $hub->core_object('LRG') : $hub->core_object('gene');
}

sub initialize_new {
  my ($self, $slice, $start, $end, $adorn) = @_;
  my $hub    = $self->hub;
  my $object = $self->get_object;

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);

  my $config = {
    display_width   => $hub->param('display_width') || $vc->get('display_width'),
    site_type       => ucfirst(lc $hub->species_defs->ENSEMBL_SITETYPE) || 'Ensembl',
    gene_name       => $object->Obj->can('external_name') && $object->Obj->external_name ? $object->Obj->external_name : $object->stable_id,
    species         => $hub->species,
    sub_slice_start => $start,
    sub_slice_end   => $end,
    ambiguity       => 1,
    variants_as_n   => scalar $self->param('variants_as_n'),
  };

  for (qw(exon_display exon_ori snp_display line_numbering title_display)) {
    my $param = $hub->param($_) || $vc->get($_);
    $config->{$_} = $param;
  }
  
  $config->{'exon_features'} = $object->Obj->get_all_Exons;
  $config->{'slices'}        = [{ slice => $slice, name => $config->{'species'} }];
  $config->{'number'} = 1 if $config->{'line_numbering'} ne 'off';

  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config,$adorn);
  $self->view->markup($sequence,$markup,$config);

  return ($sequence, $config);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $slice     = $self->object->slice;
  my $length    = $slice->length;
  my $species   = $hub->species;
  my $type      = $hub->type;
  my $site_type = ucfirst(lc $hub->species_defs->ENSEMBL_SITETYPE) || 'Ensembl';
  my $html      = '';

  if ($length >= $self->{'subslice_length'}) {
    $html .= '<div class="_adornment_key adornment-key"></div>';
    $html .= $self->chunked_content($length, $self->{'subslice_length'}, { length => $length, name => $slice->name });
  } else {
    $html .= '<div class="_adornment_key adornment-key"></div>';
    $html .= $self->content_sub_slice($slice); # Direct call if the sequence length is short enough
  }

  return $html;
}

sub content_sub_slice {
  my ($self, $slice) = @_;
  my $hub    = $self->hub;
  my $start  = $hub->param('subslice_start');
  my $end    = $hub->param('subslice_end');
  my $length = $hub->param('length');
  my $follow = $hub->param('follow');
  
  $self->view->output($self->view->output->subslicer);
  $slice ||= $self->object->slice;
  $slice   = $slice->sub_Slice($start, $end) if $start && $end;
 
  my $adorn = $hub->param('adorn') || 'none'; 
  my ($sequence, $config) = $self->initialize_new($slice, $start, $end,$adorn);

  my $template;
  $template = $self->describe_filter($config) unless $follow;
  if ($end && $end == $length) {
    $template .= '<pre class="text_sequence">%s</pre>';
  } elsif ($start && $end) {
    $template .= sprintf '<pre class="text_sequence" style="margin:0">%s%%s</pre>', $start == 1 ? '&gt;' . $hub->param('name') . "\n" : '';
  } else {
    $template .= '<pre class="text_sequence"><span class="_seq">&gt;' . $slice->name . "\n</span>%s</pre>";
  }
  
  $template .= '<p class="invisible">.</p>';
  $self->view->output->template($template);

  return $self->build_sequence($sequence,$config,1);
}

sub export_options { return {'action' => 'GeneSeq'}; }

sub get_export_data {
## Get data for export
  my $self = shift;
  ## Fetch gene explicitly, as we're probably coming from a DataExport URL
  my $gene = $self->get_object;
  return unless $gene;
  my @transcripts = @{$gene->get_all_transcripts||[]};
  return map {$_->Obj} @transcripts;
}

sub initialize_export {
  my $self = shift;
  my $gene = $self->get_object;
  return $self->initialize($gene->slice);
}

sub make_view {
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View::GeneSeq->new(
    $self->hub
  );
}

1;
