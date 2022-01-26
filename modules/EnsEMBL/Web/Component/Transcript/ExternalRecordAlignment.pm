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
  my $tsv       = $object->stable_id.'.'.$object->version;
  my $psv       = $trans->translation->stable_id.'.'.$trans->translation->version;
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
    my $munged    = $seq_type eq 'PEP' ? $self->_munge_psw($alignment, $psv, $hit_id)
                                       : $self->_munge_matcher($alignment, $tsv, $hit_id);

    $data->{'description'}{'content'} = $seq_type eq 'PEP'
      ? qq(Alignment between external feature $hit_id and translation of transcript $tsv)
      : qq(Alignment between external feature $hit_id and transcript $tsv);
    $data->{'alignment'}{'content'} = $munged;
    $data->{'alignment'}{'raw'} = 1;
  }
  else {
    $self->mcacheable(0);
    $data->{'description'}{'content'} = qq(Unable to retrieve sequence for $hit_id from external service $ext_db. $ext_seq->{'error'});
  }

  return $data;
}

sub _munge_psw {
## Fix identifiers that have been truncated by WISE 2.4
  my ($self, $alignment, $psv, $hit_id) = @_;
  return '' unless $alignment;

  my $munged;
  my $line_count  = 0;
  my $codon_count = 1;
  my $col_1_width = length($psv) > length($hit_id) ? length($psv) : length($hit_id);
  $col_1_width   += 2;
  my $col_2_width = 5;
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
        my @line_parts = split(/\s+/, $line);
        # no matter how many intermediate elements a line contains, the identifier is always first and the sequence always last
        my $id = $line_parts[0];
        my $seq = $line_parts[-1];

        ## Add the correct identifier
        my $identifier = ($line_count % 3 == 0) ? $psv : $hit_id;
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

sub _munge_matcher {
## Fix identifiers that have been truncated by 
  my ($self, $alignment, $tsv, $hit_id) = @_;
  return '' unless $alignment;

  my $munged;
  my $line_count    = 0;
  my $col_1_width   = length($tsv) > length($hit_id) ? length($tsv) : length($hit_id);
  my $col_1_pattern = '%'.$col_1_width.'s'; 
  my $padding       = $col_1_width - 6;
  my $col_2_width;

  foreach my $line (split(/\n/, $alignment)) {
    if ($line eq '' || $line =~ /^\s+$/) {
      ## Blank line
      $munged .= "\n";
    }
    elsif ($line =~ /^#/) {
      ## Comment - need to fix identifiers
      if ($line =~ /^# ([1|2]): /) {
        my $number = $1;
        my $id = $number == 2 ? $hit_id : $tsv;
        $line = "# $number: $id";
      }
      $munged .= $line."\n";
    }
    elsif ($line =~ /\:{2}/ || $line !~ /[a-zA-Z]/) {
      ## Position/alignment row
      $munged .= (' ' x $padding).$line."\n";   
    }
    else {
      ## Identifier plus sequence
      $line =~ s/^\s+//;
      my ($id, $seq) = split(/\s+/, $line);

      ## Add the correct identifier
      my $identifier = ($line_count % 2 == 0) ? $tsv : $hit_id;
      $munged .= sprintf $col_1_pattern, $identifier;

      ## Finally add sequence
      $munged .= " $seq\n"; 
      $line_count++; ## Only count lines with content
    }
  }

  return $munged;
}

1;
