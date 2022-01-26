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

package EnsEMBL::Web::Component::Gene::TranscriptComparison;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Gene);

use EnsEMBL::Web::TextSequence::Annotation::TranscriptComparison::Sequence;
use EnsEMBL::Web::TextSequence::Annotation::TranscriptComparison::Exons;
use EnsEMBL::Web::TextSequence::Annotation::TranscriptComparison::Variations;
use EnsEMBL::Web::TextSequence::View::TranscriptComparison;

sub _init { $_[0]->SUPER::_init(100); }

sub initialize_new {
  my ($self, $start, $end) = @_;
  my $hub         = $self->hub;
  my @consequence = $self->param('consequence_filter');
  
  my $config = {
    display_width   => $self->param('display_width') || 60,
    species         => $hub->species,
    comparison      => 1,
    exon_display    => 1,
    sub_slice_start => $start,
    sub_slice_end   => $end
  };

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);
  my $adorn = $hub->param('adorn') || 'none';

  for (qw(exons_only snp_display title_display line_numbering hide_long_snps hide_rare_snps hidden_sources)) {
    $config->{$_} = $self->param($_) unless ($self->param($_) eq 'off');
  }
 
  $config->{'hidden_sources'} = [$self->param('hidden_sources')];
 
  $config->{'snp_display'}        = 0 unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if $config->{'snp_display'} && scalar(@consequence) && join('', @consequence) ne 'off';
  
  if ($config->{'line_numbering'}) {
    $config->{'number'}     = 1;
  }
  
  my ($sequence, $markup) = $self->get_sequence_data($config);
  $self->view->markup($sequence,$markup,$config);

  my $view = $self->view;

  my $view = $self->view($config);
  $view->legend->expect('variants') if ($config->{'snp_display'}||'off') ne 'off';
  
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
    $html .= '<div class="_adornment_key adornment-key"></div>' . $self->content_sub_slice; # Direct call if the sequence length is short enough
  }
  
  return $html;
}

sub content_sub_slice {
  my $self   = shift;
  my $hub    = $self->hub;
  my $start  = $hub->param('subslice_start');
  my $end    = $hub->param('subslice_end');
  my $length = $hub->param('length');

  $self->view->output($self->view->output->subslicer);

  my ($sequence, $config) = $self->initialize_new($start, $end);

  my $template;
  if ($end && $end == $length) {
    $template = '<pre class="text_sequence">%s</pre>';
  } elsif ($start && $end) {
    $template = '<pre class="text_sequence" style="margin:0">%s</pre>';
  } else {
    $template = '<pre class="text_sequence">%s</pre>';
  }
  
  $template .= '<p class="invisible">.</p>';

  $self->view->output->template($template);

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

sub initialize_export_new {
  my $self = shift;
  my $hub  = $self->hub;
  my $vc = $hub->get_viewconfig({component => 'TranscriptComparison', type => 'Gene', cache => 1});
  my @params = qw(sscon snp_display flanking line_numbering);
  foreach (@params) {
    $hub->param($_, $vc->get($_));
  }
  return $self->initialize_new;
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
  my $length         = $slice->length;
  my %selected       = map { $hub->param("t$_") => $_ } grep s/^t(\d+)$/$1/, $hub->param;
  my @transcripts    = map { $selected{$_->stable_id} ? [ $selected{$_->stable_id}, $_ ] : () } @{$gene->get_all_Transcripts};
 
  my @markup;
  $config->{'snp_length_filter'} = 10;
 
  push @{$config->{'slices'}}, { slice => $slice, name => $gene_name || $gene->stable_id, type => 'gene' };
  foreach my $transcript (map $_->[1], sort { $a->[0] <=> $b->[0] } @transcripts) {
    my $transcript_id   = $transcript->version ? $transcript->stable_id.".".$transcript->version : $transcript->stable_id;
    my $transcript_name = $transcript->external_name || $transcript_id;
       $transcript_name = $transcript_id if $transcript_name eq $gene_name;
    push @{$config->{'slices'}}, {
      slice => $slice,
      transcript => $transcript,
      name  => sprintf(
        '<a href="%s"%s>%s</a>',
        $hub->url({ type => 'Transcript', action => 'Summary', t => $transcript_id }),
        $transcript_id eq $transcript_name ? '' : qq{title="$transcript_id"},
        $transcript_name
      )
    };
  }
  my $view = $self->view;

  my ($sequences,$markup) = $self->SUPER::get_sequence_data($config->{'slices'},$config);
  
  my @sequences = @{$view->sequences};
  foreach my $sl (@{$config->{'slices'}}) {
    my $sequence = shift @sequences;
    $sequence->name($sl->{'display_name'} || $sl->{'name'});
  } 

  $config->{'ref_slice_seq'} = $view->sequences->[0]->legacy;

  return ($sequences,$markup);
}

sub make_view {
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View::TranscriptComparison->new(
    $self->hub
  );
}

1;
