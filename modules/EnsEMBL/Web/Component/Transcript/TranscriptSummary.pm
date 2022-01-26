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

package EnsEMBL::Web::Component::Transcript::TranscriptSummary;

use strict;
use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::Utils::FormatText qw(get_glossary_entry helptip glossary_helptip);

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
  my $table        = $self->new_twocol;
  my $species_defs = $hub->species_defs;
  my $sp           = $species_defs->SPECIES_DISPLAY_NAME;
  my $transcript   = $object->Obj;
  my $translation  = $transcript->translation;
  my $db           = $object->get_db;
  my $exons        = @{$transcript->get_all_Exons};
  my $coding_exons = @{$transcript->get_all_translateable_Exons};
  my $basepairs    = $self->thousandify($transcript->seq->length);
  my $residues     = $translation ? $self->thousandify($translation->length) : 0;
  my @CCDS         = @{$transcript->get_all_DBLinks('CCDS')};
  my @Uniprot      = @{$transcript->get_all_DBLinks('Uniprot/SWISSPROT')};
  my ($tsl)        = @{$transcript->get_all_Attributes('TSL')};
  my $incomplete;
  foreach my $attrib_type (qw(CDS_start_NF CDS_end_NF)){
    if (my @attribs = @{$transcript->get_all_Attributes($attrib_type)}) {
      $incomplete->{$attrib_type}=1;
    }
  }
  my $html         = "<strong>Exons:</strong> $exons, <strong>Coding exons:</strong> $coding_exons, <strong>Transcript length:</strong> $basepairs bps,";
  $html           .= " <strong>Translation length:</strong> $residues residues" if $residues;

  $table->add_row('Statistics', $html);

  ## add CCDS info
  if (scalar @CCDS) {
    my %T = map { $_->primary_id => 1 } @CCDS;
    @CCDS = sort keys %T;
    $table->add_row('CCDS', sprintf('<p>This transcript is a member of the %s CCDS set: %s</p>', $sp, join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS));
  }
  ## add Uniprot info
  if (scalar @Uniprot) {
    my %T = map { $_->primary_id => 1 } @Uniprot;
    @Uniprot = sort keys %T;
    $table->add_row('Uniprot', sprintf('<p>This transcript corresponds to the following Uniprot identifiers: %s</p>', join ', ', map $hub->get_ExtURL_link($_, 'Uniprot/SWISSPROT', $_), @Uniprot));
  }

  ## add TSL info
  if ($tsl && ($tsl = $tsl->value)) {
    my $key = $tsl =~ s/^tsl([^\s]+).*$/TSL:$1/gr;
    $table->add_row('Transcript Support Level (TSL)', sprintf('<span class="ts_flag">%s</span>', helptip($key, get_glossary_entry($hub, $key).get_glossary_entry($hub, 'TSL'))));
  }

  # add incomplete CDS info
  if ($incomplete) {
    $table->add_row('Incomplete CDS', sprintf('<span class="ts_flag">%s</span>',$self->get_CDS_text($incomplete)));
  }

  $table->add_row('Version', $object->stable_id_version);

  ## add some Vega info
  if ($db eq 'vega') {
    my $class   = $object->transcript_class;
    my $version = $object->version;
    my $c_date  = $object->created_date;
    my $m_date  = $object->mod_date;
    my $author  = $object->get_author_name;
    my $remarks = $object->retrieve_remarks;

    $table->add_row('Class', qq{<p>$class [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external" class="constant">Definition</a>]</p>});
    $table->add_row('Version &amp; date', qq{<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>});
    $table->add_row('Author', "This transcript was annotated by $author");

    if (@$remarks) {
      my $text;

      foreach my $rem (@$remarks) {
        next unless $rem;  # ignore remarks with a value of 0
        $text .= "<p>$rem</p>";
      }

      $table->add_row('Remarks', $text) if $text;
    }
  } else { ## type for core genes
    my $type = $object->transcript_type;
    $table->add_row('Type', $type) if $type;
  }
  ## add prediction method
  my $label = 'Annotation Method';
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

  ## Hack for broken links 
  my $regex = '/info/genome/genebuild/genome_annotation';
  if ($text =~ m#$regex#) {
    (my $new_page = $regex) =~ s#genome_annotation#index#;
    my $abs_link = 'https://www.ensembl.org'.$new_page;
    $text =~ s#$regex#$abs_link#g;
  }

  $table->add_row($label, $text);

  ## add frameshift introns info
  my $frameshift_introns = $object->get_frameshift_introns;

  $table->add_row('Frameshift introns', glossary_helptip($self->hub, 'Frameshift introns', 'Frameshift intron') . " occur at intron number(s)  $frameshift_introns.") if $frameshift_introns;


  ## add trans-spliced transcript info
  my $trans_spliced_transcript_info = $object->get_trans_spliced_transcript_info;
  $table->add_row('Trans-spliced' , sprintf('This is a %s transcript', helptip('trans-spliced', $trans_spliced_transcript_info->description))) if $trans_spliced_transcript_info;


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

    # print the populations for each rsid
    foreach my $id (keys %unique) {
      my $population_string = join ', ', keys %{$unique{$id}};
      my $link = $hub->url({
        type    => 'Variation',
        action  => 'Summary',
        v       => $id,
      });

      my $id_link = qq{<a href="$link">$id</a>};

      if ($code eq 'StopLost') {
        $description = "This transcript has a variant, $id_link, that causes a stop codon to be lost in at least 10% of HapMap or 1000 Genome population(s) $population_string.";
      } elsif ($code eq 'StopGained') {
        $description = "This transcript has a variant, $id_link, that causes a stop codon to be gained in at least 10% of HapMap or 1000 Genome population(s) $population_string.";
      }
      $codons .= "$description<br />";
    }
  }

  $table->add_row('Stop codons', $codons) if $codons =~ /^\w/;

  if ($translation && $translation->dbID) {
    my $missing_evidence_attribs = $translation->get_all_Attributes('NoEvidence') || [];

    if (@$missing_evidence_attribs) {
      my $description = lcfirst $missing_evidence_attribs->[0]->description;
      my $string = join ', ', map $_->value, @$missing_evidence_attribs;
      $table->add_row('Evidence Removed', "The following $description: $string");
    }
  }

  ## add alternative transcript info
  my $alt_trans = $self->_matches('alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS', 'show_version');
  $table->add_row('Alternative transcripts', $alt_trans) if $alt_trans;

  my $cv_terms = $object->get_cv_terms;
  if (@$cv_terms) {
    my $first = shift @$cv_terms;
    my $text = qq(<p>$first [<a href="/info/website/glossary.html" class="constant">Definitions</a>]</p>);
    foreach my $next (@$cv_terms) {
      $text .= "<p>$next</p>";
    }
    $table->add_row('Annotation Attributes', $text) if $text;;
  }

  ## add gencode basic info
  $table->add_row('GENCODE basic gene', qq(This transcript is a member of the <a href="/Help/Glossary?id=500" class="popup">Gencode basic</a> gene set.)) if(@{$transcript->get_all_Attributes('gencode_basic')});

  return $table->render;
}

1;
