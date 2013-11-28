=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::ExtIndex;
use POSIX;


#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $trans = $object->Obj;
  my $tsi = $object->stable_id;
  my $hit_id = $object->param('sequence');
  my $ext_db = $object->param('extdb');

  #get external sequence and type (DNA or PEP)
  my ($ext_seq, $len) = @{$self->hub->get_ext_seq( $hit_id, $ext_db) || []};
  $ext_seq = '' unless ($ext_seq =~ /^>/);

  $ext_seq =~ s /^ //mg; #remove white space from the beginning of each line of sequence
  my $seq_type = $object->determine_sequence_type( $ext_seq );

  #get transcript sequence
  my $trans_sequence = $object->get_int_seq($trans,$seq_type)->[0];

  #get transcript alignment
  my $html;
  if ($ext_seq) {
    my $trans_alignment = $object->get_alignment( $ext_seq, $trans_sequence, $seq_type );
    if ($seq_type eq 'PEP') {
      $html =  qq(<p>Alignment between external feature $hit_id and translation of transcript $tsi</p><p><pre>$trans_alignment</pre></p>);
    }
    else {
      $html = qq(<p>Alignment between external feature $hit_id and transcript $tsi</p><p><pre>$trans_alignment</pre></p>);
    }
  }
  else {
    $html = qq(<p>Unable to retrieve sequence for $hit_id from external service $ext_db. Please try again later.</p>);
  }
  return $html;
}		

1;

