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

package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
  
use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

use EnsEMBL::Web::TextSequence::View::Transcript;

use EnsEMBL::Web::TextSequence::Annotation::Exons;

use List::Util qw(max);

sub get_sequence_data {
  my ($self, $object, $config,$adorn) = @_;

  my %qconfig;
  $qconfig{$_} = $config->{$_}
      for(qw(hide_long_snps utr codons hide_rare_snps translation
             exons rna snp_display coding_seq));
  my $hub = $self->hub;
  my $data = $hub->get_query('Sequence::Transcript')->go($self,{
    species => $config->{'species'},
    type => $object->get_db,
    transcript => $object->Obj,
    config => $config,
    adorn => $adorn,
    conseq_filter => [$hub->param('consequence_filter')],
    config => \%qconfig,
  });
  return map { $data->[0]{$_} } qw(sequence markup names length);
}

sub get_sequence_data_new {
  my ($self, $object, $config,$adorn) = @_;

  my %qconfig;
  $qconfig{$_} = $config->{$_}
      for(qw(hide_long_snps utr codons hide_rare_snps translation
             exons rna snp_display coding_seq));
  my $hub = $self->hub;
  my $data = $hub->get_query('Sequence::Transcript')->go($self,{
    species => $config->{'species'},
    type => $object->get_db,
    transcript => $object->Obj,
    config => $config,
    adorn => $adorn,
    conseq_filter => [$hub->param('consequence_filter')],
    config => \%qconfig,
  });
  my ($sequence,$markup,$names,$length) = map { $data->[0]{$_} } qw(sequence markup names length);
 
  $config->{'names'} = $names;
  $config->{'length'} = $length;
 
  # XXX hack
  my @seqs;
  foreach my $s (@$sequence) {
    my $s2 = $self->view->new_sequence;
    $s2->legacy($s);
    push @seqs,$s2;
  }
  return (\@seqs,$markup,$names,$length);
}


sub initialize_new {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('transcript');

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);
 
  my $adorn = $hub->param('adorn') || 'none';
 
  my $config = { 
    species         => $hub->species,
    transcript      => 1,
  };
 
  $config->{'display_width'} = $hub->param('display_width') || $vc->get('display_width'); 
  $config->{$_} = ($hub->param($_) eq 'on' || $vc->get($_) eq 'on') ? 1 : 0 for qw(exons exons_case codons coding_seq translation rna snp_display utr hide_long_snps hide_rare_snps);
  $config->{'codons'}      = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
 
  if ($hub->param('line_numbering') ne 'off') {
    $config->{'line_numbering'} = 'on';
    $config->{'number'}         = 1;
  }
  
  $self->set_variation_filter($config);
  
  my $view = $self->view($config);
  
  my ($sequences, $markup,$names,$length) = $self->get_sequence_data_new($object, $config, $adorn);

  # XXX hack to set principal
  $sequences->[1]->principal(1) if @$sequences>1 and $config->{'snp_display'};

  $self->view->markup_new($sequences,$markup,$config);

  $view->legend->expect('variants') if ($config->{'snp_display'}||'off') ne 'off';

  return ($sequences, $config);
}

sub content {
  my $self = shift;
  my ($sequences, $config) = $self->initialize_new;

  return $self->build_sequence_new($sequences, $config);
}

sub export_options { return {'action' => 'Transcript'}; }

sub initialize_export_new {
  my $self = shift;
  my $hub = $self->hub;
  my ($sequence, $config) = $self->initialize_new;
  return ($sequence, $config);
}

sub make_view {
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View::Transcript->new(
    $self->hub
  );
}

1;
