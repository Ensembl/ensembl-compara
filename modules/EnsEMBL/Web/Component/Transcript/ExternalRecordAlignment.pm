=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Transcript::ExternalRecordAlignment;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self  = shift;

  my $order = [qw(description alignment)];

  return $self->make_twocol($order);
}

sub get_data {
  my $self      = shift;
  my $object    = $self->object;
  my $trans     = $object->Obj;
  my $tsi       = $object->stable_id;
  my $hit_id    = $object->param('sequence');
  my $ext_db    = $object->param('extdb');
  my $data      = {
                    'description' => {'label' => 'Description'},
                    'alignment'   => {'label' => 'EMBOSS output'},
                  };

  #get external sequence and type (DNA or PEP)
  my $ext_seq   = $self->hub->get_ext_seq($ext_db, {'id' => $hit_id, 'translation' => 1});

  if ($ext_seq->{'sequence'}) {
    my $seq_type  = $object->determine_sequence_type($ext_seq->{'sequence'});
    my $trans_seq = $object->get_int_seq($trans, $seq_type)->[0];
    my $alignment = $object->get_alignment($ext_seq->{'sequence'}, $trans_seq, $seq_type) || '';


    $data->{'description'}{'content'} = $seq_type eq 'PEP'
      ? qq(Alignment between external feature $hit_id and translation of transcript $tsi)
      : qq(Alignment between external feature $hit_id and transcript $tsi);
    $data->{'alignment'}{'content'} = $alignment;
    $data->{'alignment'}{'raw'} = 1;
  }
  else {
    $self->mcacheable(0);
    $data->{'description'}{'content'} = qq(Unable to retrieve sequence for $hit_id from external service $ext_db. $ext_seq->{'error'});
  }

  return $data;
}

1;
