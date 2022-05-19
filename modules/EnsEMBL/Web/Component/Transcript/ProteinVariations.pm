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

package EnsEMBL::Web::Component::Transcript::ProteinVariations;

use strict;

use Bio::EnsEMBL::Variation::Utils::Config qw(%ATTRIBS);
use Bio::EnsEMBL::Variation::Utils::Constants qw(%VARIATION_CLASSES);
use EnsEMBL::Web::NewTable::NewTable;
use EnsEMBL::Web::Utils::Variation qw(predictions_classes classify_sift_polyphen classify_score_prediction);

use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;

  my $table = $self->make_table();

  my $html = $table->render($self->hub,$self);

  return $html;
}

sub table_content {
  my ($self,$callback) = @_;
  my $hub = $self->hub;
  my $object = $self->object;
   
  return $self->non_coding_error unless $object->translation_object;

  my $var_styles  = $hub->species_defs->colour('variation');
  my $colourmap   = $hub->colourmap;
  my $glossary    = $hub->glossary_lookup;
  my $show_scores = $hub->param('show_scores');

  ROWS: foreach my $var (sort { $a->{'position'} <=> $b->{'position'} } @{$object->variation_data}) {
    next if $callback->free_wheel();

    unless($callback->phase eq 'outline') {  

      my $var_url = $hub->url({ type => 'Variation', action => 'Summary', v => $var->{'snp_id'}, vf => $var->{'vdbid'}, vdb => 'variation' }); 

      my $codons = $var->{'codons'} || '-';
      my $codons_variant_position;

      if ($codons ne '-') {
        if (length($codons)>8) {
          $codons =~ s/([ACGT])/<b>$1<\/b>/g;
          $codons =~ tr/acgt/ACGT/;
          $codons = $self->trim_large_string($codons,'codons_'.$var->{'snp_id'},8);
        }
        else {
          # Get the position of the highlighted base
          $codons =~ /([ATGC])/;
          $codons_variant_position = $+[0];
          $codons =~ tr/acgt/ACGT/;
        }
      }

      my $allele = $var->{'allele'};
      my $tva    = $var->{'tva'};
      my $var_allele = $tva->variation_feature_seq;

      # Evidence status
      my $evidences = $var->{'vf'}->get_all_evidence_values || [];
      my $status = join('~',@$evidences);
      #my $status = $self->render_evidence_status($evidences);

      # Check allele size (for display issues)
      if (length($allele)>10 && $allele !~ /^(COSMIC|HGMD)/) {
        $allele = $self->trim_large_allele_string($allele,'allele_'.$var->{'snp_id'},10);
      }
      # $allele =~ s/$var_allele/<b>$var_allele<\/b>/ if $allele =~ /\//;
    
      # consequence type
      my $type = $self->new_consequence_type($tva);    

      # SIFT, PolyPhen-2 and other prediction tools
      my $sifts = classify_sift_polyphen($tva->sift_prediction,$tva->sift_score);
      my $polys = classify_sift_polyphen($tva->polyphen_prediction, $tva->polyphen_score);
      my $cadds = classify_score_prediction($tva->cadd_prediction, $tva->cadd_score);
      my $revels = classify_score_prediction($tva->dbnsfp_revel_prediction, $tva->dbnsfp_revel_score);
      my $meta_lrs = classify_score_prediction($tva->dbnsfp_meta_lr_prediction, $tva->dbnsfp_meta_lr_score);
      my $mutation_assessors = classify_score_prediction($tva->dbnsfp_mutation_assessor_prediction, $tva->dbnsfp_mutation_assessor_score);

      my $row = {
        vf      => $var->{'vf'}->dbID,
        res     => $var->{'position'},
        ID      => $var->{'snp_id'},
        snptype => $type,
        source  => $var->{'snp_source'}->name,
        status  => $status,
        allele  => $allele,
        vf_allele => $var_allele,
        ambig   => $var->{'ambigcode'} || '-',
        alt     => $var->{'pep_snp'} || '-',
        codons  => $codons,
        codons_variant_position => join('', $codons_variant_position),
        sift_sort  => $sifts->[0],
        sift_class => $sifts->[1],
        sift_value => $sifts->[2],
        polyphen_sort  => $polys->[0],
        polyphen_class => $polys->[1],
        polyphen_value => $polys->[2],
        cadd_sort  => $cadds->[0],
        cadd_class => $cadds->[1],
        cadd_value => $cadds->[2],
        revel_sort  => $revels->[0],
        revel_class => $revels->[1],
        revel_value => $revels->[2],
        meta_lr_sort  => $meta_lrs->[0],
        meta_lr_class => $meta_lrs->[1],
        meta_lr_value => $meta_lrs->[2],
        mutation_assessor_sort  => $mutation_assessors->[0],
        mutation_assessor_class => $mutation_assessors->[1],
        mutation_assessor_value => $mutation_assessors->[2],
      };
      $callback->add_row($row);
      last ROWS if $callback->stand_down;
    }
  } 
}

sub make_table {
  my $self = shift;

  my $hub      = $self->hub;
  my $glossary = $hub->glossary_lookup;

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);

  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

#  my $is_lrg = $self->isa('EnsEMBL::Web::Component::LRG::VariationTable');

  my @exclude;
  push @exclude,'sift_sort','sift_class','sift_value' unless $sd->{'SIFT'};
  unless($hub->species eq 'Homo_sapiens') {
    push @exclude,'polyphen_sort','polyphen_class','polyphen_value', 'cadd_sort', 'cadd_class', 'cadd_value', 'revel_sort', 'revel_class', 'revel_value', 'meta_lr_sort', 'meta_lr_class', 'meta_lr_value', 'mutation_assessor_sort', 'mutation_assessor_class', 'mutation_assessor_value';
  }

  my @columns = ({
    _key => 'res', _type => 'numeric no_filter',
    label => "Residue",
    width => 1,
    helptip => 'Residue number on the protein sequence'
  },{
    _key => 'ID', _type => 'string no_filter',
    label => "Variant ID",
    width => 2,
    helptip => 'Variant identifier',
    link_url => {
      type   => 'Variation',
     action => 'Summary',
      vf     => ["vf"],
      v      => undef # remove the 'v' param from the links if already present
    }
  },{
    _key => 'vf', _type => 'numeric no_filter unshowable'
  },{
    _key => 'snptype', _type => 'iconic', label => "Conseq. Type",
    filter_label => 'Consequences',
    filter_sorted => 1,
    width => 1.5,
    helptip => 'Consequence type',
    sort_down_first => 1,
    filter_keymeta_enum => 1,
    primary => 3,
  },{
    _key => 'source', _type => 'iconic', label => "Sour\fce",
    width => 1.25,
    helptip => $glossary->{'Source'},
    filter_label => 'Source',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 4,
  },{
    _key => 'status', _type => 'iconic', label => "Evid\fence",
    width => 1.5,
    helptip => $glossary->{'Evidence status (variant)'},
    filter_keymeta_enum => 1,
    filter_maybe_blank => 1,
    filter_sorted => 1,
    primary => 5,
  },{
    _key => 'vf_allele', _type => 'string no_filter unshowable',
  },{
    _key => 'allele', _type => 'string no_filter no_sort',
    label => "Alle\fles",
    helptip => 'Alternative nucleotides',
    toggle_separator => '/',
    toggle_maxlen => 20,
    toggle_highlight_column => 'vf_allele',
    toggle_highlight_over => 2
  },{
    _key => 'ambig', _type => 'string no_filter', 
    label => "Ambig. code",
    helptip => 'IUPAC nucleotide ambiguity code'
  },{
    _key => 'alt', _type => 'string no_filter',
    label => "Residues",
    helptip => 'Resulting amino acid(s)'
  },{
    _key => 'codons_variant_position', _type => 'string no_filter unshowable',
    label => "Codons Variant Position"
  },{
    _key => 'codons', _type => 'string no_filter',
    label => "Codons",
    helptip => 'Resulting codon(s), with the allele(s) displayed in bold',
    toggle_separator => ', ',
    toggle_highlight_position => 'true',
    toggle_highlight_column => 'codons_variant_position'
  },{
    _key => 'sift_sort', _type => 'numeric no_filter unshowable',
    sort_for => 'sift_value',
    sort_down_first => 1,
  },{
    _key => 'sift_class', _type => 'iconic no_filter unshowable',
  },{
    _key => 'sift_value', _type => 'numeric',
    label => "SI\aFT",
    helptip => $glossary->{'SIFT'},
    filter_range => [0,1],
    filter_fixed => 1,
    filter_blank_button => 1,
    primary => 1,
  },{
    _key => 'polyphen_sort', _type => 'numeric no_filter unshowable',
  sort_for => 'polyphen_value',
  },{
    _key => 'polyphen_class', _type => 'iconic no_filter unshowable',
  },{
    _key => 'polyphen_value', _type => 'numeric',
    label => "Poly\fPhen",
    helptip => $glossary->{'PolyPhen'},
    filter_range => [0,1],
    filter_fixed => 1,
    filter_blank_button => 1,
    primary => 2,
  },{
    _key => 'cadd_sort', _type => 'numeric no_filter unshowable',
    sort_for => 'cadd_value',
  },{
    _key => 'cadd_class', _type => 'iconic no_filter unshowable',
  },{
    _key => 'cadd_value', _type => 'numeric',
    label => "CADD",
    helptip => $glossary->{'CADD'},
    filter_range => [0,100],
    filter_fixed => 1,
    filter_blank_button => 1,
  },{
    _key => 'revel_sort', _type => 'numeric no_filter unshowable',
    sort_for => 'revel_value',
  },{
    _key => 'revel_class', _type => 'iconic no_filter unshowable',
  },{
    _key => 'revel_value', _type => 'numeric',
    label => "REVEL",
    helptip => $glossary->{'REVEL'},
    filter_range => [0,1],
    filter_fixed => 1,
    filter_blank_button => 1,
  },{
    _key => 'meta_lr_sort', _type => 'numeric no_filter unshowable',
    sort_for => 'meta_lr_value',
  },{
    _key => 'meta_lr_class', _type => 'iconic no_filter unshowable',
  },{
    _key => 'meta_lr_value', _type => 'numeric',
    label => "MetaLR",
    helptip => $glossary->{'MetaLR'},
    filter_range => [0,1],
    filter_fixed => 1,
    filter_blank_button => 1,
  },{
    _key => 'mutation_assessor_sort', _type => 'numeric no_filter unshowable',
    sort_for => 'mutation_assessor_value',
  },{
    _key => 'mutation_assessor_class', _type => 'iconic no_filter unshowable',
  },{
    _key => 'mutation_assessor_value', _type => 'numeric',
    label => "Mutation Assessor",
    helptip => $glossary->{'MutationAssessor'},
    filter_range => [0,1],
    filter_fixed => 1,
    filter_blank_button => 1,
  }
);

  $table->add_columns(\@columns,\@exclude);

  $self->evidence_classes($table);
  $self->snptype_classes($table,$self->hub);
  $self->sift_poly_classes($table);
  
  return $table;
}

sub evidence_classes {
  my ($self,$table) = @_;

  my @evidence_order = reverse @{$ATTRIBS{'evidence'}};
  my %evidence_key;
  $evidence_key{$_} = "B".lc $_ for(@evidence_order);
  $evidence_key{'1000Genomes'} = "A0001";
  $evidence_key{'HapMap'}      = "A0002";
  @evidence_order =
    sort { $evidence_key{$a} cmp $evidence_key{$b} } @evidence_order;

  my %evidence_order;
  $evidence_order{$evidence_order[$_]} = $_ for(0..$#evidence_order);

  my $evidence_col = $table->column('status');
  foreach my $ev (keys %evidence_order) {
    my $evidence_label = $ev;
    $evidence_label =~ s/_/ /g;
    $evidence_col->icon_url($ev,sprintf("%s/val/evidence_%s.png",$self->img_url,$ev));
    $evidence_col->icon_helptip($ev,$evidence_label);
    $evidence_col->icon_export($ev,$evidence_label);
    $evidence_col->icon_order($ev,$evidence_order{$ev});
  }
}

sub snptype_classes {
  my ($self,$table,$hub) = @_;

  my $species_defs = $hub->species_defs;
  my $var_styles   = $species_defs->colour('variation');
  my @all_cons     = grep $_->feature_class =~ /transcript/i, values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $column = $table->column('snptype');
  $column->filter_add_baked('lof','PTV','Select all protein truncating variant types');
  $column->filter_add_baked('lof_missense','PTV & Missense','Select all protein truncating and missense variant types');
  $column->filter_add_baked('exon','Only Exonic','Select exon and splice region variant types');
  $column->filter_add_bakefoot('PTV = Protein Truncating Variant');
  my @lof = qw(stop_gained frameshift_variant splice_donor_variant
               splice_acceptor_variant);
  foreach my $con (@all_cons) {
    next if $con->SO_accession =~ /x/i;
    my $so_term = lc $con->SO_term;
    my $colour = $var_styles->{$so_term||'default'}->{'default'};
    $column->icon_export($con->label,$con->label);
    $column->icon_order($con->label,$con->rank);
    $column->icon_helptip($con->label,$con->description);
    $column->icon_coltab($con->label,$colour);
    if(grep { $_ eq $so_term } @lof) {
      $column->filter_bake_into($con->label,'lof');
      $column->filter_bake_into($con->label,'lof_missense');
    }
    if($so_term eq 'missense_variant') {
      $column->filter_bake_into($con->label,'lof_missense');
    }
    if($con->rank < 18) { # TODO: specify this properly
      $column->filter_bake_into($con->label,'exon');
    }
  }
}

sub sift_poly_classes {
  my ($self,$table) = @_;

  my $sp_classes = predictions_classes; 

  foreach my $column_name (qw(sift polyphen cadd revel meta_lr mutation_assessor)) {
    my $value_column = $table->column("${column_name}_value");
    my $class_column = $table->column("${column_name}_class");
    next unless $value_column and $class_column;
    $value_column->editorial_type('lozenge');
    $value_column->editorial_source("${column_name}_class");
    foreach my $pred (keys %$sp_classes) {
      $value_column->editorial_cssclass($pred,"score_$sp_classes->{$pred}");
      $value_column->editorial_helptip($pred,$pred);
    }
    # TODO: make decorators accessible to filters. Complexity is that
    # many decorators (including these) are multi-column.
    my $lozenge = qq(<div class="score score_%s score_example">%s</div>);
    my $left = { sift => 'bad', polyphen => 'good', cadd => 'good', revel => 'good', meta_lr => 'good', mutation_assessor => 'good'}->{$column_name};
    my $right = { sift => 'good', polyphen => 'bad', cadd => 'bad', revel => 'bad', meta_lr => 'bad', 'mutation_assessor' => 'bad'}->{$column_name};
    $value_column->filter_endpoint_markup(0,sprintf($lozenge,$left,"0"));
    $value_column->filter_endpoint_markup(1,sprintf($lozenge,$right,"1"));
    my $slider_class =
      { sift => 'redgreen', polyphen => 'greenred', cadd => 'greenred', revel => 'greenred', meta_lr => 'greenred', mutation_assessor => 'greenred' }->{$column_name};
    $value_column->filter_slider_class("newtable_slider_$slider_class");
  }

  sub new_consequence_type {
    my $self        = shift;
    my $tva         = shift;
    my $most_severe = shift;

    my $overlap_consequences = ($most_severe) ? [$tva->most_severe_OverlapConsequence] || [] : $tva->get_all_OverlapConsequences || [];

    # Sort by rank, with only one copy per consequence type
    my @consequences = sort {$a->rank <=> $b->rank} (values %{{map {$_->label => $_} @{$overlap_consequences}}});
  
    my @type;
    foreach my $c (@consequences) {
      push @type,$c->label;
    }
    return join('~',@type);
  }
}

1;

