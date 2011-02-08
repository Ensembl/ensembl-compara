# $Id$

package EnsEMBL::Web::Component::Transcript::TranscriptSummary;

use strict;

use EnsEMBL::Web::Document::HTML::TwoCol;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $hub          = $self->hub;
  my $table        = new EnsEMBL::Web::Document::HTML::TwoCol;
  my $species_defs = $hub->species_defs;
  my $sp           = $species_defs->DISPLAY_NAME;
  my $transcript   = $object->Obj;
  my $translation  = $transcript->translation;
  my $db           = $object->get_db;
  my $exons        = @{$transcript->get_all_Exons};
  my $basepairs    = $self->thousandify($transcript->seq->length);
  my $residues     = $translation ? $self->thousandify($translation->length) : 0;
  my @CCDS         = grep $_->dbname eq 'CCDS', @{$transcript->get_all_DBLinks};
  my $html         = "<strong>Exons:</strong> $exons <strong>Transcript length:</strong> $basepairs bps";
  $html           .= "<strong>Translation length:</strong> $residues residues" if $residues;
  
  $table->add_row('Statistics', "<p>$html</p>", 1);

  ## add CCDS info
  if (scalar @CCDS) {
    my %T = map { $_->primary_id => 1 } @CCDS;
    @CCDS = sort keys %T;
    $table->add_row('CCDS', sprintf('<p>This transcript is a member of the %s CCDS set: %s</p>', $sp, join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS), 1);
  }

  ## add some Vega info
  if ($db eq 'vega') {
    my $class   = $object->transcript_class;
    my $version = $object->version;
    my $c_date  = $object->created_date;
    my $m_date  = $object->mod_date;
    my $author  = $object->get_author_name;
    my $remarks = $object->retrieve_remarks;
    
    $table->add_row('Class', qq{<p>$class [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>}, 1);
    $table->add_row('Version &amp; date', qq{<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>}, 1);
    $table->add_row('Author', "This transcript was annotated by $author");
    
    if (@$remarks) {
      my $text;
      
      foreach my $rem (@$remarks) {
        next unless $rem;  # ignore remarks with a value of 0
        $text .= "<p>$rem</p>";
      }
      
      $table->add_row('Remarks', $text, 1);
    }
  } else { ## type for core genes
    my $type = $object->transcript_type;
    $table->add_row('Type', $type) if $type;
  }
  ## add prediction method
  my $label = ($db eq 'vega' || $species_defs->ENSEMBL_SITETYPE eq 'Vega' ? 'Curation' : 'Prediction') . ' Method';
  my $text  = "No $label defined in database";
  
  eval {
    if ($transcript && $transcript->can('analysis') && $transcript->analysis && $transcript->analysis->description) {
      $text = $transcript->analysis->description;
    } elsif ($object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description) {
      $text = $object->gene->analysis->description;
    } else {
      my $logic_name = $transcript->can('analysis') && $transcript->analysis ? $transcript->analysis->logic_name : '';
      
      if ($logic_name) {
        my $confkey = 'ENSEMBL_PREDICTION_TEXT_' . uc $logic_name;
        $text       = '<strong>FROM CONFIG:</strong> ' . $species_defs->$confkey;
      }
      
      if (!$text) {
        my $confkey = 'ENSEMBL_PREDICTION_TEXT_' . uc $db;
        $text       = '<strong>FROM DEFAULT CONFIG:</strong> ' . $species_defs->$confkey;
      }
    }
  };
  
  $table->add_row($label, $text, 1);

  ## add frameshift introns info
  my $frameshift_introns = $object->get_frameshift_introns;
  
  $table->add_row('Frameshift introns', '<p>' . $self->glossary_mouseover('Frameshift intron', 'Frameshift introns') . " occur at intron number(s)  $frameshift_introns.</p>", 1) if $frameshift_introns;

  ## add stop gained/lost variation info
  my @attrib_codes = qw(StopLost StopGained);
  my $codons;
  
  foreach my $code (@attrib_codes) {
    my $transcript_attribs = $transcript->get_all_Attributes($code);
    my $description;

    #find which populations are affected by each snp (rsid)
    my %unique;
    
    foreach my $transc_att (@$transcript_attribs) {
      my ($rsid, $pop) = split /,/, $transc_att->value;
      $unique{$rsid}{$pop} = 1;
    }
    
    # print the popukations for each rsid
    foreach my $id (keys %unique) {
      my $population_string = join ', ', keys %{$unique{$id}};
      
      my $link = $hub->url({
        type    => 'Variation',
        action  => 'Summary',
        v       => $id,
      });
      
      my $id_link = qq{<a href="$link">$id</a>}; 
      
      if ($code eq 'StopLost') {
        $description = "This transcript has a variant, $id_link, that causes a stop codon to be lost in at least 10% of HapMap population(s) $population_string.";
      } elsif ($code eq 'StopGained') {
        $description = "This transcript has a variant, $id_link, that causes a stop codon to be gained in at least 10% of HapMap population(s) $population_string.";
      }
      
      $codons .= "$description<br />";
    }
  }
  
  $table->add_row('Stop codons', "<p>$codons</p>", 1) if $codons =~ /^\w/;

  if ($translation && $translation->dbID) {
    my $missing_evidence_attribs = $translation->get_all_Attributes('NoEvidence') || [];
    
    if (@$missing_evidence_attribs) {
      my $description = lcfirst $missing_evidence_attribs->[0]->description;
      my $string = join ', ', map $_->value, @$missing_evidence_attribs;
      
      $table->add_row('Evidence Removed', "<p>The following $description: $string</p>", 1);
    }
  }

  ## add alternative transcript info
  my $temp = $self->_matches('alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS');
  
  $table->add_row('Alternative transcripts', "<p>$temp</p>", 1) if $temp;

  return $table->render;
}

1;

