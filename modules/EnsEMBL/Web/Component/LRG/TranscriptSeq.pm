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

package EnsEMBL::Web::Component::LRG::TranscriptSeq;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript::TranscriptSeq);

sub _init {
  my $self = shift;
  $self->object($self->get_transcript); # Become like a transcript
  return $self->SUPER::_init;
}

sub object {
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'};
}

sub get_transcript {
	my $self        = shift;
	my $param       = $self->hub->param('lrgt');
  my $object      = $self->hub->core_object('LRG');
	my $transcripts = $object->get_all_transcripts;
  return $param ? grep $_->stable_id eq $param, @$transcripts : $transcripts->[0];
}

sub content {
  my $self = shift;
  my $external_name = $self->object->Obj->external_name;
  my $display_id = ($external_name && $external_name ne '') ? $external_name : $self->object->Obj->stable_id;
  return sprintf '<h2>Transcript ID: %s</h2>%s', $display_id, $self->SUPER::content;
}

sub get_export_data {
  my $self = shift;
  my ($t) = $self->get_transcript;
  return $t->Obj;
}

sub export_options { return {'action' => 'Transcript', 'params' => ['lrgt']}; }

1;
