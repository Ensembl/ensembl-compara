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

package EnsEMBL::Web::Component::Transcript::ProteinSeq;

use strict;

use EnsEMBL::Web::TextSequence::View::Transcript::ProteinSeq;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

use EnsEMBL::Web::TextSequence::Annotation::Protein::Exons;
use EnsEMBL::Web::TextSequence::Annotation::Protein::Variations;
use EnsEMBL::Web::TextSequence::Annotation::Protein::Sequence;

sub get_sequence_data {
  my ($self, $translation, $config) = @_;
  my $object   = $self->object || $self->hub->core_object('transcript');
  my $pep_seq  = $translation->Obj->seq;
  
  my $hub   = $self->hub;
  my $type  = $hub->param('data_type') || $hub->type;
  my $vc    = $self->view_config($type);

  $config->{'slices'} = [{ seq => $pep_seq }];
  $config->{'length'} = length $pep_seq;
  $config->{'peptide_splice_sites'} = $object->peptide_splice_sites;
  $config->{'exons_case'} = ($hub->param('exons_case') eq 'on' || $vc->get('exons_case') eq 'on') ? 1 : 0;
  $config->{'object'} = $object;
  $config->{'translation'} = $translation;
  
  $config->{'length'} = length $pep_seq;
 
  # XXX didn't call set_variation_filter before

  return $self->SUPER::get_sequence_data($config->{'slices'},$config);
}

sub initialize_new {
  my ($self, $translation) = @_;
  my $hub         = $self->hub;
  my @consequence = $hub->param('consequence_filter');
  my @evidence    = $hub->param('evidence_filter');
  
  my $config = {
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    transcript      => 1,
  };
  
  for (qw(exons snp_display number hide_long_snps)) {
    $config->{$_} = $hub->param($_) =~ /yes|on/ ? 1 : 0;
  }
  $config->{'hide_rare_snps'} = $hub->param('hide_rare_snps');
  delete $config->{'hide_rare_snps'} if $config->{'hide_rare_snps'} eq 'off';
  $config->{'hidden_sources'}     = [$self->param('hidden_sources')];
  if ($config->{'snp_display'} ne 'off') {
    $config->{'consequence_filter'} = { map { $_ => 1 } @consequence } if join('', @consequence) ne 'off';
    $config->{'evidence_filter'}    = { map { $_ => 1 } @evidence    } if join('', @evidence) ne 'off';
  }
  
  my ($sequence, $markup) = $self->get_sequence_data($translation, $config);
  $self->view->markup($sequence,$markup,$config);
  
  return ($sequence, $config);
}

sub content {
  my $self        = shift;
  my $translation = $self->object->translation_object;
  
  return $self->non_coding_error unless $translation;
  
  my ($sequence, $config) = $self->initialize_new($translation);

  return $self->describe_filter($config).$self->build_sequence($sequence, $config);
}

sub export_options { return {'action' => 'Protein'}; }

sub initialize_export_new {
  my $self = shift;
  my $hub = $self->hub;
  my $vc = $hub->get_viewconfig({component => 'ProteinSeq', type => 'Transcript', cache => 1});
  my $transcript = $self->object || $hub->core_object('transcript');
  return $self->initialize_new($transcript->translation_object);
}

sub make_view {
  my $self = shift;

  return EnsEMBL::Web::TextSequence::View::Transcript::ProteinSeq->new(@_);
}

1;
