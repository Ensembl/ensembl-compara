# $Id$

package EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $transcript   = $object->Obj;
  my $tsi          = $object->stable_id;
  my $hit_id       = $object->param('sequence');
  my $exon_id      = $object->param('exon');
  my $hit_db_name  = $object->get_sf_hit_db_name($hit_id);
  my $trans_length = $transcript->length;
  my $e_count      = scalar @{$transcript->get_all_Exons};
  my $translation  = $transcript->translation;
  my $table        = $self->new_twocol;
  my ($cds_aa_length, $cds_length, $e_alignment, $html);

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
      my $rec = $hub->get_ext_seq($id, uc $query_db, $strand_mismatch);

      if ($rec->[0]) {
        if ($rec->[0] =~ /^>/) {
          $ext_seq        = $rec->[0];
          $ext_seq_length = $rec->[1];
        }
      }

      if ($ext_seq) {
        $hit_id = $id;
        last;
      }
    }

    # munge hit name for the display
    if ($hit_db_name =~ /^RefSeq/) {
      $ext_seq =~ s/\w+\|\d+\|ref\|//;
      $ext_seq =~ s/\|.+//m;
    }

    $ext_seq =~ s/ .+$//m if $hit_db_name =~ /Uniprot/i;
    $ext_seq =~ s /^ //mg; # remove white space from the beginning of each line of sequence
  }

  # working with DNA or PEP?
  my $seq_type = $object->determine_sequence_type($ext_seq);
  my $label    = $seq_type eq 'PEP' ? 'aa' : 'bp';

  if ($ext_seq) {
    my $hit_url = $hub->get_ExtURL_link($hit_id, $hit_db_name, $hit_id);
    my $txt = "$hit_url ($hit_db_name)";
    $txt   .= ", length = $ext_seq_length $label" if $ext_seq_length;
    $table->add_row('External record', "$txt", 1);
  } else {
    $table->add_row('External record', "<p>Unable to retrieve sequence for $hit_id</p>", 1);
  }

  if ($seq_type eq 'PEP' && $translation) {
    $cds_aa_length = $translation->length;
    $cds_length    = " Translation length: $cds_aa_length aa";
  }

  $table->add_row('Transcript details', "<p>Exons: $e_count. Length: $trans_length bp.$cds_length</p>", 1);

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

    $table->add_row('Exon Information', "<p>$exon_id</p><p>$e_length_text</p>", 1);
    $table->add_row('Exon coordinates', "Transcript: $cdna_start-$cdna_end bp</p>$exon_cds_pos", 1);

    if ($ext_seq) {
      if (!$e_sequence && $seq_type eq 'PEP') {
        $table->add_row('Exon alignment:', "Unable to retrieve translation for $exon_id", 1);
        $html .= $table->render;
      }
      else {
        # get exon alignment
        my $e_alignment = $object->get_alignment($ext_seq, $e_sequence, $seq_type);
        $e_alignment =~ s/$hit_id/$hit_id .' (reverse complement)'/e if $strand_mismatch;

        $table->add_row('Exon alignment:', '', 1);
        $html .= $table->render;
        $html .= "<p><br /><pre>$e_alignment</pre></p>";
      }
    }
    else {
      $table->add_row('Exon alignment:', "Unable to show alignment", 1);
      $html .= $table->render;
    }
  }
  else {
    $html .= $table->render;
  }

  my $type   = $seq_type eq 'PEP' ? 'Translation' : 'Transcript';
  my $table2 = $self->new_twocol;
  if ($ext_seq) {
    # get transcript sequence
    my $trans_sequence = $object->get_int_seq($transcript, $seq_type)->[0];
    if (!$trans_sequence && $seq_type eq 'PEP') {
      $table2->add_row("$type alignment:", "Unable to retrieve translation for $tsi", 1);
      $html .= $table2->render;
    } else {
      # get transcript alignment
      my $trans_alignment = $object->get_alignment($ext_seq, $trans_sequence, $seq_type);
      $trans_alignment =~ s/$hit_id/$hit_id .' (reverse complement)'/e if $strand_mismatch;
      $table2->add_row("$type alignment:", '', 1);
      $html .= $table2->render;
      $html .= "<p><br /><br /><pre>$trans_alignment</pre></p>";
    }
  }
  else {
    $table2->add_row("$type alignment:", "Unable to show alignment", 1);
    $html .= $table2->render;
  }
  return $html;
}
1;

