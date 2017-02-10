=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

    my $alignment = $object->get_alignment($ext_seq->{'sequence'}, $trans_seq, $seq_type);

    $data->{'description'}{'content'} = $seq_type eq 'PEP'
      ? qq(Alignment between external feature $hit_id and translation of transcript $tsi)
      : qq(Alignment between external feature $hit_id and transcript $tsi);
    $data->{'alignment'}{'content'} = $self->_munge_alignment($alignment, $tsi, $hit_id);
    $data->{'alignment'}{'raw'} = 1;
  }
  else {
    $self->mcacheable(0);
    $data->{'description'}{'content'} = qq(Unable to retrieve sequence for $hit_id from external service $ext_db. $ext_seq->{'error'});
  }

  return $data;
}

sub _munge_alignment {
## Fix identifiers that have been truncated by WISE 2.4
  my ($self, $alignment, $tsi, $hit_id) = @_;
  return '' unless $alignment;

  my $munged;
  my $line_count  = 0;
  my $codon_count = 1;
  my $col_1_width = length($tsi) > length($hit_id) ? length($tsi) : length($hit_id);
  $col_1_width   += 2;
  my $col_2_width = 5;
  my $col_3_width;
  my $col_1_pattern = '%-0'.$col_1_width.'s'; 
  my $col_2_pattern = '%-0'.$col_2_width.'s';

  foreach my $line (split(/\n/, $alignment)) {
    if ($line =~ /\w+/) {
      if ($line =~ /^\s+(\w+)/) {
        ## Just sequence
        $munged .= (' ' x ($col_1_width + $col_2_width)).$1."\n";
      }
      else {
        ## Identifier plus sequence
        my ($id, $seq) = split(/\s+/, $line);

        ## Add the correct identifier
        my $identifier = ($line_count % 3 == 0) ? $tsi : $hit_id;
        $munged .= sprintf $col_1_pattern, $identifier;

        ## Now add codon number
        $codon_count += length($seq) if $line_count > 0 && ($line_count % 3 == 0);
        $munged .= sprintf $col_2_pattern, $codon_count;

        ## Finally add sequence
        $munged .= $seq."\n"; 
      }
      $line_count++; ## Only count lines with content
    }
    else {
      ## blank line
      $munged .= "\n";
    }
  }

  return $munged;
}

1;
