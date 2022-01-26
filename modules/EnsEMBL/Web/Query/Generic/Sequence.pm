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

package EnsEMBL::Web::Query::Generic::Sequence;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Query::Generic::Base);

sub fixup_transcript {
  my ($self,$key,$sk,$tk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->stable_id if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    #$data->{"__orig_$key"} = $data->{$key};
    my $ad = $self->source('Adaptors');
    if($data->{$key}) {
      $data->{$key} =
        $ad->transcript_by_stableid($data->{$sk},$data->{$tk},$data->{$key});
    }
  }
}

sub loop_transcripts {
  my ($self,$args,$subpart) = @_;

  my $all = $self->source('Adaptors')->
              transcript_adaptor($args->{'species'},$args->{'type'})->fetch_all;
  my @out;
  foreach my $t (@$all) {
#    next unless $t->stable_id eq 'ENST00000380152';
    next if ($subpart->{'transcript'}||$t->stable_id) ne $t->stable_id;
    my %out = %$args;
    $out{'species'} = $args->{'species'};
    $out{'type'} = $args->{'type'};
    $out{'transcript'} = $t->stable_id;
    $out{'__name'} = $t->stable_id;
    push @out,\%out;
  }
  return \@out;
}


1;
