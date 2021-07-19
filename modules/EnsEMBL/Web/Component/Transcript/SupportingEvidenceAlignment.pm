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

package EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment;

use strict;

use parent qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;

  my $order = [qw(external_record transcript_details exon_info exon_coords e_alignment t_alignment)];

  return $self->make_twocol($order);
}

sub get_data {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object || $hub->core_object('transcript');
  my $transcript   = $object->Obj;
  my $tsi          = $object->stable_id;
  my $hit_id       = $object->param('sequence');
  my $exon_id      = $object->param('exon');
  my $hit_db_name  = $object->get_sf_hit_db_name($hit_id);
  my $trans_length = $transcript->length;
  my $e_count      = scalar @{$transcript->get_all_Exons};
  my $translation  = $transcript->translation;
  my ($cds_aa_length, $cds_length);

  my $data = {};

  # get external sequence and type (DNA or PEP) - refseq try with and without version
  my $query_db = '';
  my $ext_seq = '';
  my $ext_seq_length = 0;
  my @hit_ids = ($hit_id);
  $query_db   = $hit_db_name;

  if ($hit_db_name =~ /^RefSeq/) {
    $query_db = 'RefSeq';
    $hit_id   =~ s/\.\d+//;
    push @hit_ids, $hit_id;
  } elsif ($hit_db_name eq 'Uniprot/Varsplic') {
    $hit_id =~ /(\w+)-\d+/; # hack - strip off isoform version for uniprot
    push @hit_ids, $1;
  }

  my $strand_mismatch;

  foreach my $id (@hit_ids) {
    if (my $hit_object = $object->get_hit($id)) {
      my $hit_strand = $hit_object->strand * $hit_object->hstrand ;
      $strand_mismatch = $hit_strand != $transcript->strand ? 1 : 0;
      my $rec = $hub->get_ext_seq(uc $query_db, {'id' => $id, 'strand_mismatch' => $strand_mismatch, 'translation' => 1});

      if ($rec->{'sequence'}) {
        $ext_seq        = $rec->{'sequence'};
        $ext_seq_length = $rec->{'length'};
        $hit_id         = $id;
        last;
      }
    }

    # munge hit name for the display
    if ($hit_db_name =~ /^RefSeq/) {
      $ext_seq =~ s/\w+\|\d+\|ref\|//;
      $ext_seq =~ s/\|.+//m;
    }

    $ext_seq =~ s/ .+$//m; # remove anything after a space in description
  }

  # working with DNA or PEP?
  my $seq_type = $object->determine_sequence_type($ext_seq);
  my $label    = $seq_type eq 'PEP' ? 'aa' : 'bp';
  $data->{'external_record'} = {'label' => 'External record'};

  if ($ext_seq) {
    #Uniprot can't deal with versions in accessions
    if ($hit_db_name =~ /^Uniprot/){
      $hit_id =~ s/(\w*)\.\d+/$1/;
    }
    my $hit_url = $hub->get_ExtURL_link($hit_id, $hit_db_name, $hit_id);
    my $txt = "$hit_url ($hit_db_name)";
    $txt   .= ", length = $ext_seq_length $label" if $ext_seq_length;
    $data->{'external_record'}{'content'} = $txt;
  }
  else {
    if ($hit_db_name) {
      $data->{'external_record'}{'content'} = "Unable to fetch sequence for $hit_id ($hit_db_name) at this time.";
    }
    else {
      $data->{'external_record'}{'content'} = "Unable to fetch sequence for $hit_id at this time.";
    }
  }

  if ($seq_type eq 'PEP' && $translation) {
    $cds_aa_length = $translation->length;
    $cds_length    = " Translation length: $cds_aa_length aa";
  }

  $data->{'transcript_details'} = {'label' => 'Transcript details', 'content' => "Exons: $e_count. Length: $trans_length bp.$cds_length"};

  # exon alignment (if exon ID is in the URL)
  if ($exon_id) {
    my $exon;

    # get cached exon off the transcript
    foreach my $e (@{$transcript->get_all_Exons}) {
      if ($e->stable_id eq $exon_id) {
        $exon = $e;
        last;
      }
    }

    # get exon sequence
    my ($e_sequence, $e_sequence_length) = @{$object->get_int_seq($exon, $seq_type, $transcript)||[]};

    # get position of exon in the transcript
    my $cdna_start = $exon->cdna_start($transcript);
    my $cdna_end   = $exon->cdna_end($transcript);

    # length of exon in the CDS
    my $e_length      = $exon->length;
    my $e_length_text = "Length: $e_length bp";

    ## position of exon in the translation
    my $exon_cds_pos;

    if ($seq_type eq 'PEP' && $translation) {
      # postions of everything we need in cDNA coords
      my $tl_start  = $exon->cdna_coding_start($transcript);
      my $tl_end    = $exon->cdna_coding_end($transcript);
      my $cds_start = $transcript->cdna_coding_start;
      my $cds_end   = $transcript->cdna_coding_end;

      if ($tl_start && $tl_end) {
        my $start = int(($tl_start - $cds_start) / 3  + 1);
        my $end   = int(($tl_end   - $cds_start) / 3) + 1;
        $end     -= 1 if ($tl_end == $cds_end); # need to take off one since the stop codon is included

        $e_length_text .= " ($e_sequence_length aa)";
        $exon_cds_pos   = "<p>CDS: $start-$end aa</p>";
      } else {
        $exon_cds_pos = "<p>Exon is not coding</p>";
      }
    }

    $data->{'exon_info'} = {'label' => 'Exon Information', 'content' => "<p>$exon_id</p><p>$e_length_text</p>"};
    $data->{'exon_coords'} = {'label' => 'Exon coordinates', 'content' => "<p>Transcript: $cdna_start-$cdna_end bp</p><p>$exon_cds_pos</p>"};
    $data->{'e_alignment'} = {'label' => 'Exon alignment'};

    if ($ext_seq) {
      if (!$e_sequence && $seq_type eq 'PEP') {
        $data->{'e_alignment'}{'content'} = "Unable to fetch translation for $exon_id from the $hit_db_name database at this time.";
      }
      else {
        # get exon alignment
        my $alignment = $object->get_alignment($ext_seq, $e_sequence, $seq_type);
        $alignment =~ s/$hit_id/$hit_id .' (reverse complement)'/e if $strand_mismatch;
        $data->{'e_alignment'}{'content'} = $alignment; 
        $data->{'e_alignment'}{'raw'} = 1;
        $hub->param('has_e_alignment', 'yes');
      }
    }
    else {
      $data->{'e_alignment'}{'content'} = "Unable to show alignment";
    }
  }

  my $type   = $seq_type eq 'PEP' ? 'Translation' : 'Transcript';
  $data->{'t_alignment'} = {'label' => "$type alignment"};
  $hub->param('align_type', $type);
  if ($ext_seq) {
    # get transcript sequence
    my $trans_sequence = $object->get_int_seq($transcript, $seq_type)->[0];
    if (!$trans_sequence && $seq_type eq 'PEP') {
      $data->{'t_alignment'}{'content'} = "Unable to retrieve translation for $tsi";
    } else {
      # get transcript alignment
      my $alignment = $object->get_alignment($ext_seq, $trans_sequence, $seq_type);
      $alignment =~ s/$hit_id/$hit_id .' (reverse complement)'/e if $strand_mismatch;
      $data->{'t_alignment'}{'content'} = $alignment; 
      $data->{'t_alignment'}{'raw'} = 1;
      $hub->param('has_t_alignment', 'yes');
    }
  }
  else {
    $data->{'t_alignment'}{'content'} = "Unable to show alignment";
  }

  return $data;
}

sub export_options  { return {'action' => 'Emboss'}; }

sub get_export_data {
## Get data for export
  my $self = shift;
  my $data = $self->get_data;
  my @fields = qw(e_alignment t_alignment);
  my $output = [];
  foreach (@fields) {
    next unless $data->{$_}{'raw'}; ## actual output, not an error message
    push @$output, $data->{$_}{'content'};
  }
  return $output;
}

sub buttons {
  my $self = shift;
  my $hub = $self->hub;
  return unless ($hub->param('has_e_alignment') && $hub->param('has_t_alignment'));
  my $params  = {
                  'type'        => 'DataExport',
                  'action'      => 'Emboss',
                  'data_type'   => 'Transcript',
                  'component'   => 'SupportingEvidenceAlignment',
                  'sequence'    => $hub->param('sequence'),
                  'exon'        => $hub->param('exon'), 
                  'align_type'  => lc($hub->param('align_type')),
                  'has_e_alignment' => $hub->param('has_e_alignment'), 
                  'has_t_alignment' => $hub->param('has_t_alignment'), 
              };
  my $plural = ($hub->param('e_alignment') && $hub->param('t_alignment')) ? 's' : '';
  return {
    'url'     => $hub->url($params),
    'caption' => "Download alignment$plural",
    'class'   => 'export',
    'modal'   => 1
  };
}


1;

