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

package EnsEMBL::Web::Component::VariationTable;

use strict;

use List::Util qw(max min);

use Bio::EnsEMBL::Variation::Utils::Config qw(%ATTRIBS);
use Bio::EnsEMBL::Variation::Utils::Constants qw(%VARIATION_CLASSES);
use Bio::EnsEMBL::Variation::Utils::VariationEffect qw($UPSTREAM_DISTANCE $DOWNSTREAM_DISTANCE);
use EnsEMBL::Web::NewTable::NewTable;

use Bio::EnsEMBL::Variation::Utils::VariationEffect;

use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);
use Scalar::Util qw(looks_like_number);

use base qw(EnsEMBL::Web::Component::Variation);

our $TV_MAX = 100000;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub new_consequence_type {
  my $self        = shift;
  my $tva         = shift;
  my $only_coding = shift;

  my $overlap_consequences = $tva->get_all_OverlapConsequences || [];

  # Sort by rank, with only one copy per consequence type
  my @consequences = sort {$a->rank <=> $b->rank} (values %{{map {$_->label => $_} @{$overlap_consequences}}});

  if ($only_coding) {
    @consequences = grep { $_->rank < 18 } @consequences;
  }

  my @type;
  foreach my $c (@consequences) {
    push @type,$c->label;
  }
  return join('~',@type);
}


sub table_content {
  my ($self,$callback) = @_;

  my $hub         = $self->hub;
  my $icontext    = $hub->param('context') || 100;
  my $gene_object = $self->configure($icontext,'ALL');
  my $object_type = $hub->type;
 
  my $transcript;
  $transcript = $hub->param('t') if $object_type eq 'Transcript';
  my $phase = $callback->phase;
  $transcript = $phase if $phase =~ s/^full-//;
  my @transcripts;
  if(defined $transcript) {
    @transcripts = ($gene_object->get_transcript_by_stable_id($transcript));
  } else {
    @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$gene_object->get_all_transcripts};
  }

  # get appropriate slice
  my $slice = $self->object->Obj->feature_Slice->expand(
    $Bio::EnsEMBL::Variation::Utils::VariationEffect::UPSTREAM_DISTANCE,
    $Bio::EnsEMBL::Variation::Utils::VariationEffect::DOWNSTREAM_DISTANCE
  );

  my $exonic_types = $self->get_exonic_type_classes;

  # Get the number of TranscriptVariations
  my $tv_count = 0;
  foreach my $transcript (@transcripts) {
    $tv_count += $self->_count_transcript_variations($transcript->Obj);
  }

  my $vfs = $self->_get_variation_features($slice, $tv_count, $exonic_types);

  return $self->variation_table($callback,'ALL',\@transcripts, $tv_count, $vfs);
}

sub content {
  my $self             = shift;
  my $hub              = $self->hub;
  my $object_type      = $hub->type;
  my $consequence_type = $hub->param('sub_table');
  my $icontext         = $hub->param('context') || 100;
  my $gene_object      = $self->configure($icontext, $consequence_type);
  my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$gene_object->get_all_transcripts};
  my $html;
  
  if ($object_type eq 'Transcript') {
    my $t = $hub->param('t');
    @transcripts = grep $_->stable_id eq $t, @transcripts;
  }

  my $thing = 'gene';
     $thing = 'transcript' if $object_type eq 'Transcript';
  
  my $slice = $self->object->Obj->feature_Slice->expand(
    $Bio::EnsEMBL::Variation::Utils::VariationEffect::UPSTREAM_DISTANCE,
    $Bio::EnsEMBL::Variation::Utils::VariationEffect::DOWNSTREAM_DISTANCE
  );

  # Get the number of TranscriptVariations
  my $tv_count = 0;
  foreach my $transcript (@transcripts) {
    $tv_count += $self->_count_transcript_variations($transcript->Obj);
  }

  my $only_exonic = 0;
  if ($tv_count > $TV_MAX ) {

    my $bm_prefix  = 'hsapiens_snp.default.snp';
    my $bm_prefix2 = 'hsapiens_snp.default.filters';

    my $biomart_link = $self->hub->species_defs->ENSEMBL_MART_ENABLED ? '/biomart/martview?VIRTUALSCHEMANAME=default'.
                       "&ATTRIBUTES=$bm_prefix.refsnp_id|$bm_prefix.refsnp_source|$bm_prefix.chr_name|$bm_prefix.chrom_start|$bm_prefix.chrom_end|".
                       "$bm_prefix.minor_allele_freq|$bm_prefix.minor_allele|$bm_prefix.clinical_significance|$bm_prefix.allele|".
                       "$bm_prefix.consequence_type_tv|$bm_prefix.consequence_allele_string|$bm_prefix.ensembl_peptide_allele|$bm_prefix.translation_start|".
                       "$bm_prefix.translation_end|$bm_prefix.polyphen_prediction|$bm_prefix.polyphen_score|".
                       "$bm_prefix.sift_prediction|$bm_prefix.sift_score|$bm_prefix.ensembl_transcript_stable_id|$bm_prefix.validated".
                       "&FILTERS=$bm_prefix2.chromosomal_region.&quot;".$slice->seq_region_name.":".$slice->start.":".$slice->end."&quot;".
                       '&VISIBLEPANEL=resultspanel' : '';

    my $vf_count = $self->_count_variation_features($slice);
    my $warning_content  = "There are ".$self->thousandify($vf_count)." variants for this $object_type, which is too many to display in this page, so <b>only exonic variants</b> are displayed.";
       $warning_content .= " Please use <a href=\"$biomart_link\">BioMart</a> to extract all data." if ($biomart_link ne '');
    $html .= $self->_warning( "Too much data to display", $warning_content);

    $only_exonic = 1;
  }
  else {
    $html .= $self->_hint('snp_table', 'Variant table', "This table shows known variants for this $thing. Use the 'Consequence Type' filter to view a subset of these.");
  }

  my $table = $self->make_table(\@transcripts, $only_exonic);

  $html .= $table->render($self->hub,$self);  

  return $html;
}

sub sift_poly_classes {
  my ($self,$table) = @_;

  my %sp_classes = %{$self->predictions_classes};

  foreach my $column_name (qw(sift polyphen cadd revel meta_lr mutation_assessor)) {
    my $value_column = $table->column("${column_name}_value");
    my $class_column = $table->column("${column_name}_class");
    next unless $value_column and $class_column;
    $value_column->editorial_type('lozenge');
    $value_column->editorial_source("${column_name}_class");
    foreach my $pred (keys %sp_classes) {
      $value_column->editorial_cssclass($pred,"score_$sp_classes{$pred}");
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
      { sift => 'redgreen', polyphen => 'greenred', cadd => 'greenred', revel => 'greenred', meta_lr => 'greenred', mutation_assessor => 'greenred'}->{$column_name};
    $value_column->filter_slider_class("newtable_slider_$slider_class");
  }
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

sub class_classes {
  my ($self,$table) = @_;

  my $classes_col = $table->column('class');
  $classes_col->filter_add_baked('somatic','Only Somatic','Only somatic variant classes');
  $classes_col->filter_add_baked('not_somatic','Not Somatic','Exclude somatic variant classes');
  my $i = 0;
  foreach my $term (qw(display_term somatic_display_term)) {
    foreach my $class (sort { ($a->{$term} !~ /SNP|SNV/ cmp $b->{$term} !~ /SNP|SNV/) || $a->{$term} cmp $b->{$term} } values %VARIATION_CLASSES) {
      next if ($class->{'type'} eq 'sv');

      $classes_col->icon_order($class->{$term},$i++);
      if($term eq 'somatic_display_term') {
        $classes_col->filter_bake_into($class->{$term},'somatic');
      } else {
        $classes_col->filter_bake_into($class->{$term},'not_somatic');
      }
    }
  }
}

sub clinsig_classes {
  my ($self,$table) = @_;
  
  # This order is a guess at the most useful and isn't strongly motivated.
  # Feel free to rearrange.
  my @clinsig_order = reverse qw(
    pathogenic protective likely-pathogenic risk-factor drug-response
    confers-sensitivity histocompatibility association likely-benign
    benign other not-provided uncertain-significance
  );
  my %clinsig_order;
  $clinsig_order{$clinsig_order[$_]} = $_ for(0..$#clinsig_order);

  my $clinsig_col = $table->column('clinsig');
  foreach my $cs_img (keys %clinsig_order) {
    my $cs = $cs_img;
    $cs =~ s/-/ /g;
    $clinsig_col->icon_url($cs,sprintf("%s/val/clinsig_%s.png",$self->img_url,$cs_img));
    $clinsig_col->icon_helptip($cs,$cs);
    $clinsig_col->icon_export($cs,$cs);
    $clinsig_col->icon_order($cs,$clinsig_order{$cs_img});
  }
  $clinsig_col->filter_maybe_blank(1);
}

sub snptype_classes {
  my ($self,$table,$hub,$only_exonic) = @_;

  my $species_defs = $hub->species_defs;
  my $var_styles   = $species_defs->colour('variation');
  my @all_cons     = grep $_->feature_class =~ /transcript/i, values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $column = $table->column('snptype');
  $column->filter_add_baked('lof','PTV','Select all protein truncating variant types');
  $column->filter_add_baked('lof_missense','PTV & Missense','Select all protein truncating and missense variant types');
  $column->filter_add_baked('exon','Only Exonic','Select exon and splice region variant types') if (!$only_exonic);
  $column->filter_add_bakefoot('PTV = Protein Truncating Variant');
  my @lof = qw(stop_gained frameshift_variant splice_donor_variant
               splice_acceptor_variant);
  foreach my $con (@all_cons) {
    next if $con->SO_accession =~ /x/i;
    next if ($only_exonic and $con->rank >= 18);
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
    if(!$only_exonic and $con->rank < 18) { # TODO: specify this properly
      $column->filter_bake_into($con->label,'exon');
    }
  }
}


sub get_exonic_type_classes {
  my $self = shift;

  my @all_cons = grep $_->feature_class =~ /transcript/i, values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my @exonic_types = map { $_->SO_term  } grep { $_->rank < 18 } @all_cons;

  return \@exonic_types;
}


sub make_table {
  my ($self,$transcripts,$only_exonic) = @_;

  my $hub      = $self->hub;
  my $glossary = $hub->glossary_lookup;

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);
  
  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

  my $is_lrg = $self->isa('EnsEMBL::Web::Component::LRG::VariationTable');

  my @exclude;
  push @exclude,'gmaf','gmaf_freq','gmaf_allele' unless $hub->species eq 'Homo_sapiens';
  push @exclude,'HGVS' unless $self->param('hgvs') eq 'on';
  if($is_lrg) {
    push @exclude,'Transcript';
  } else {
    push @exclude,'Submitters','LRGTranscript','LRG';
  }
  push @exclude,'sift_sort','sift_class','sift_value' unless $sd->{'SIFT'};
  unless($hub->species eq 'Homo_sapiens') {
    push @exclude,'polyphen_sort','polyphen_class','polyphen_value', 'cadd_sort', 'cadd_class', 'cadd_value', 'revel_sort', 'revel_class', 'revel_value', 'meta_lr_sort', 'meta_lr_class', 'meta_lr_value', 'mutation_assessor_sort', 'mutation_assessor_class', 'mutation_assessor_value';
  }
  push @exclude,'Transcript' if $hub->type eq 'Transcript';


  my @columns = ({
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
    _key => 'vf', _type => 'string unshowable no_filter'
  },{
    _key => 'location', _type => 'position unshowable',
    label => 'Location', sort_for => 'chr',
    state_filter_ephemeral => 1,
  },{
    _key => 'chr', _type => 'string no_filter',
    label => $is_lrg?'bp':'Chr: bp',
    width => 1.75,
    helptip => $glossary->{'Chr:bp'},
  },{
    _key => 'vf_allele', _type => 'string no_filter unshowable',
  },{
    _key => 'Alleles', _type => 'string no_filter no_sort',
    label => "Alle\fles",
    helptip => 'Alternative nucleotides',
    toggle_separator => '/',
    toggle_maxlen => 20,
    toggle_highlight_column => 'vf_allele',
    toggle_highlight_over => 2
  },{
    _key => 'gmaf_allele', _type => 'string no_filter unshowable',
  },{
    _key => 'gmaf_freq', _type => 'numeric unshowable',
    sort_for => 'gmaf',
    filter_label => 'Global MAF',
    filter_range => [0,0.5],
    filter_fixed => 1,
    filter_logarithmic => 1,
    primary => 1,
  },{
    _key => 'gmaf', _type => 'string no_filter', label => "Glo\fbal MAF",
    helptip => $glossary->{'Global MAF'},
    also_cols => 'gmaf_allele',
  },{
    _key => 'HGVS', _type => 'string no_filter', label => 'HGVS name(s)',
    width => 1.75
  },{
    _key => 'class', _type => 'iconic', label => 'Class',
    width => 2,
    helptip => $glossary->{'Class'},
    filter_keymeta_enum => 1,
    filter_maybe_blank => 1,
    filter_sorted => 1,
  },{
    _key => 'Source', _type => 'iconic', label => "Sour\fce",
    width => 1.25,
    helptip => $glossary->{'Source'},
    filter_maybe_blank => 1,
  },{
    _key => 'Submitters', _type => 'string no_filter',
    label => 'Submitters',
    width => 1.75
    # export_options => { split_newline => 2 },
  },{
    _key => 'status', _type => 'iconic', label => "Evid\fence",
    width => 1.5,
    helptip => $glossary->{'Evidence status (variant)'},
    filter_keymeta_enum => 1,
    filter_maybe_blank => 1,
    filter_sorted => 1,
  },{
    _key => 'clinsig', _type => 'iconic', label => "Clin. Sig.",
    helptip => 'Clinical significance',
    filter_label => 'Clinical Significance',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
  },{
    _key => 'snptype', _type => 'iconic', label => "Conseq. Type",
    filter_label => 'Consequences',
    filter_sorted => 1,
    width => 1.5,
    helptip => 'Consequence type',
    sort_down_first => 1,
    filter_keymeta_enum => 1,
    primary => 4,
  },{
    _key => 'aachange', _type => 'string no_filter no_sort', label => "AA",
    helptip => "Resulting amino acid(s)"
  },{
    _key => 'aacoord_sort', _type => 'integer unshowable',
    label => 'AA coord', sort_for => 'aacoord',
    filter_blank_button => 1,
    state_filter_ephemeral => 1,
  },{
    _key => 'aacoord', _type => 'string no_filter', label => "AA co\ford",
    helptip => 'Amino Acid Coordinates',
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
    primary => 2,
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
    primary => 3,
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
  },{
    _key => 'LRG', _type => 'string unshowable',
    label => "LRG",
  },{
    _key => 'Transcript', _type => 'iconic',
    width => 2,
    helptip => $glossary->{'Transcript'},
    link_url => {
      type   => 'Transcript',
      action => 'Summary',
      t => ["Transcript"] 
    },
    state_filter_ephemeral => 1,
   },{
    _key => 'LRGTranscript', _type => 'string',
    width => 2,
    helptip => $glossary->{'Transcript'},
    link_url => {
      type   => 'LRG',
      action => 'Summary',
      lrgt => ["LRGTranscript"],
      lrg => ["LRG"],
      __clear => 1
   }
  });

  $table->add_columns(\@columns,\@exclude);

  $self->evidence_classes($table);
  $self->clinsig_classes($table);
  $self->class_classes($table);
  $self->snptype_classes($table,$self->hub,$only_exonic);
  $self->sift_poly_classes($table);

  my (@lens,@starts,@ends,@seq);
  foreach my $t (@$transcripts) {
    my $p = $t->translation_object;
    push @lens,$p->length if $p;
    push @starts,$t->seq_region_start;
    push @ends,$t->seq_region_end;
    push @seq,$t->seq_region_name;
  }
  if(@lens) {
    my $aa_col = $table->column('aacoord_sort');
    $aa_col->filter_range([1,max(@lens)]);
    $aa_col->filter_fixed(1);
  }
  if(@starts && @ends) {
    my $loc_col = $table->column('location');
    $loc_col->filter_seq_range($seq[0],[min(@starts)-$UPSTREAM_DISTANCE,
                                        max(@ends)+$DOWNSTREAM_DISTANCE]);
    $loc_col->filter_fixed(1);
  }
  
  # Separate phase for each transcript speeds up gene variation table
   
  my $icontext         = $self->hub->param('context') || 100;
  my $gene_object      = $self->configure($icontext,'ALL');
  my $object_type      = $self->hub->type;
  my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$gene_object->get_all_transcripts};
  if ($object_type eq 'Transcript') {
    my $t = $hub->param('t');
    @transcripts = grep $_->stable_id eq $t, @transcripts;
  }

  $table->add_phase("taster",'taster',[0,50]);
  $table->add_phase("full-$_",'full') for(map { $_->stable_id } @transcripts);

  return $table;
}

sub variation_table {
  my ($self,$callback,$consequence_type, $transcripts, $tv_count, $vfs) = @_;
  my $hub         = $self->hub;
  my $show_scores = $hub->param('show_scores');
  my ($base_trans_url, $url_transcript_prefix, %handles);
  my $num = 0;

  # create some URLs - quicker than calling the url method for every variant
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Summary',
    vf     => undef,
    v      => undef,
  });

  # get appropriate slice
  my $slice = $self->object->Obj->feature_Slice->expand(
    $Bio::EnsEMBL::Variation::Utils::VariationEffect::UPSTREAM_DISTANCE,
    $Bio::EnsEMBL::Variation::Utils::VariationEffect::DOWNSTREAM_DISTANCE
  );

  my $var_styles = $hub->species_defs->colour('variation');

  my $exonic_types = $self->get_exonic_type_classes;

  my $tva = $hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation');

  if ($self->isa('EnsEMBL::Web::Component::LRG::VariationTable')) {
    my $gene_stable_id        = $transcripts->[0] && $transcripts->[0]->gene ? $transcripts->[0]->gene->stable_id : undef;
       $url_transcript_prefix = 'lrgt';
    
    my $vfa = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');

    my @var_ids;
    foreach my $transcript (@$transcripts) {
      # get TVs
      my $tvs = $self->_get_transcript_variations($transcript->Obj, $tv_count, $exonic_types);      
      foreach my $tv (@$tvs) {
        my $raw_id = $tv->{_variation_feature_id};

        my $vf = $vfs->{$raw_id};
        next unless $vf;
        push @var_ids,$vf->get_Variation_dbID();
      }
    }
    %handles = %{$vfa->_get_all_subsnp_handles_from_variation_ids(\@var_ids)};
  } else {
    $url_transcript_prefix = 't';
  }

  ROWS: foreach my $transcript (@$transcripts) {

    my $tr_id = $transcript ? $transcript->Obj->dbID : 0;

    my $tvs = $self->_get_transcript_variations($transcript->Obj, $tv_count, $exonic_types);

    my $transcript_stable_id = $transcript->stable_id;
    my $gene                 = $transcript->gene;
    my $lrg_correction = 0;
    my $lrg_strand = 0;
    if($self->isa('EnsEMBL::Web::Component::LRG::VariationTable')) {
      my $gs = $gene->slice->project("chromosome");
      foreach my $ps(@{$gs}) {
        $lrg_strand = $ps->to_Slice->strand;
        if($lrg_strand>0) {
          $lrg_correction = 1-$ps->to_Slice->start;
        } else {
          $lrg_correction = $ps->to_Slice->end+1;
        }
      }
    }
    my $chr = $transcript->seq_region_name;
    my @tv_sorted;
    foreach my $tv (@$tvs) {
      my $vf = $self->_get_vf_from_tv($tv, $vfs, $slice, $tv_count, $exonic_types);
      next unless $vf;

      push @tv_sorted,[$tv,$vf->seq_region_start];
    }
    @tv_sorted = map { $_->[0] } sort { $a->[1] <=> $b->[1] } @tv_sorted;

    foreach my $tv (@tv_sorted) {
      my $vf = $self->_get_vf_from_tv($tv, $vfs, $slice, $tv_count, $exonic_types);
      next unless $vf;

      my ($start, $end) = ($vf->seq_region_start,$vf->seq_region_end);
      if($lrg_strand) {
        $start = $start*$lrg_strand + $lrg_correction;
        $end = $end*$lrg_strand + $lrg_correction;
        ($start,$end) = ($end,$start) if $lrg_strand < 0;
      }

      my $tvas = $tv->get_all_alternate_TranscriptVariationAlleles;

      foreach my $tva (@$tvas) {
        next if $callback->free_wheel();
        # this isn't needed anymore, I don't think!!!
        # thought I'd leave this indented though to keep the diff neater
        if (1) {#$tva && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
          my $row;

          my $variation_name = $vf->variation_name;
          my $vf_dbID = $vf->dbID;
          $row->{'ID'} = $variation_name;
          my $source = $vf->source_name;
          $row->{'Source'} = $source;

          unless($callback->phase eq 'outline') {
            my $evidences            = $vf->get_all_evidence_values || [];
            my $clin_sigs            = $vf->get_all_clinical_significance_states || [];
            my $var_class            = $vf->var_class;
            my $translation_start    = $tv->translation_start;
            my $translation_end      = $tv->translation_end;
            my $aachange             = $translation_start ? $tva->pep_allele_string : '';
            my $aacoord              = $translation_start ? ($translation_start eq $translation_end ? $translation_start : "$translation_start-$translation_end") : '';
            my $aacoord_sort         = $translation_start ? $translation_start : '';
            my $trans_url            = ";$url_transcript_prefix=$transcript_stable_id";
            my $vf_allele            = $tva->variation_feature_seq;
            my $allele_string        = $vf->allele_string;
           
            # Reverse complement if it's a LRG table with a LRG mapping to the reverse strand
            if ($self->isa('EnsEMBL::Web::Component::LRG::VariationTable') && $lrg_strand == -1) {
              my @alleles = split('/',$allele_string);
              foreach my $l_allele (@alleles) {
                next if ($l_allele !~ /^[ATGCN]+$/);
                reverse_comp(\$l_allele);
              }
              $allele_string = join('/',@alleles);
            }
 
            # Sort out consequence type string
            my $only_coding = $tv_count > $TV_MAX ? 1 : 0;
            my $type = $self->new_consequence_type($tva, $only_coding);
            
            my $sifts = $self->classify_sift_polyphen($tva->sift_prediction, $tva->sift_score);
            my $polys = $self->classify_sift_polyphen($tva->polyphen_prediction, $tva->polyphen_score);
            my $cadds = $self->classify_score_prediction($tva->cadd_prediction, $tva->cadd_score);
            my $revels = $self->classify_score_prediction($tva->dbnsfp_revel_prediction, $tva->dbnsfp_revel_score);
            my $meta_lrs = $self->classify_score_prediction($tva->dbnsfp_meta_lr_prediction, $tva->dbnsfp_meta_lr_score);
            my $mutation_assessors = $self->classify_score_prediction($tva->dbnsfp_mutation_assessor_prediction, $tva->dbnsfp_mutation_assessor_score);
 
            # Adds LSDB/LRG sources
            if ($self->isa('EnsEMBL::Web::Component::LRG::VariationTable')) {
              my $var         = $vf->variation;
              my $syn_sources = $var->get_all_synonym_sources;
              
              foreach my $s_source (@$syn_sources) {
                next if $s_source !~ /LSDB|LRG/;
                
                my ($synonym) = $var->get_all_synonyms($s_source);
                  $source   .= ', ' . $hub->get_ExtURL_link($s_source, $s_source, $synonym);
              }
            }
            
            my $gmaf = $vf->minor_allele_frequency; # global maf
            my $gmaf_freq;
            my $gmaf_allele;
            if (defined $gmaf) {
              $gmaf_freq = $gmaf;
              $gmaf = ($gmaf < 0.001) ? '< 0.001' : sprintf("%.3f",$gmaf);
              $gmaf_allele = $vf->minor_allele;
            }

            my $status = join('~',@$evidences);
            my $clin_sig = join("~",@$clin_sigs);

            my $transcript_name = ($url_transcript_prefix eq 'lrgt') ? $transcript->Obj->external_name : $transcript->version ? $transcript_stable_id.".".$transcript->version : $transcript_stable_id;
          
            my $more_row = {
              vf         => $vf_dbID,
              class      => $var_class,
              Alleles    => $allele_string,
              vf_allele  => $vf_allele,
              Ambiguity  => $vf->ambig_code,
              gmaf       => $gmaf   || '-',
              gmaf_freq  => $gmaf_freq || '',
              gmaf_allele => $gmaf_allele,
              status     => $status,
              clinsig    => $clin_sig,
              chr        => "$chr:" . ($start > $end ? " between $end & $start" : "$start".($start == $end ? '' : "-$end")),
              location   => "$chr:".($start>$end?$end:$start),
              Submitters => %handles && defined($handles{$vf->{_variation_id}}) ? join(", ", @{$handles{$vf->{_variation_id}}}) : undef,
              snptype    => $type,
              Transcript => $transcript_name,
              LRGTranscript => $transcript_name,
              LRG        => $gene->stable_id,
              aachange   => $aachange,
              aacoord    => $aacoord,
              aacoord_sort => $aacoord_sort,
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
              HGVS       => $self->param('hgvs') eq 'on' ? ($self->get_hgvs($tva) || '-') : undef,
            };
            $row = { %$row, %$more_row };
          }
          $num++;
          $callback->add_row($row);
          last ROWS if $callback->stand_down;
        }
      }
    }
  }
}

sub _get_transcript_variations {
  my $self         = shift;
  my $tr           = shift;
  my $tv_count     = shift;
  my $exonic_types = shift;

  my $tr_id = $tr ? $tr->dbID : 0;
  my $cache = $self->{_transcript_variations} ||= {};

  if(!exists($cache->{$tr_id})) {

    my $slice = $tr->feature_Slice; 
    if ($tv_count <= $TV_MAX ) {
      $slice = $slice->expand(
        $Bio::EnsEMBL::Variation::Utils::VariationEffect::UPSTREAM_DISTANCE,
        $Bio::EnsEMBL::Variation::Utils::VariationEffect::DOWNSTREAM_DISTANCE
      );
    }
    my $vfs = $self->_get_variation_features($slice, $tv_count, $exonic_types);

    my $tva = $self->hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
    my @tvs = ();

    # deal with vfs with (from database) and without dbid (from vcf)
    my $have_vfs_with_id = 0;
    foreach my $vf(values %$vfs) {
      if(looks_like_number($vf->dbID)) {
        $have_vfs_with_id = 1;
      }
      else {
        push @tvs, @{$vf->get_all_TranscriptVariations([$tr])};
      }
    }
    
    if($have_vfs_with_id) {
      if ($tv_count > $TV_MAX ) {
        push @tvs, @{$tva->fetch_all_by_Transcripts_SO_terms([$tr],$exonic_types)};
        push @tvs, @{$tva->fetch_all_somatic_by_Transcripts_SO_terms([$tr],$exonic_types)};
      }
      else {     
        push @tvs, @{$tva->fetch_all_by_Transcripts([$tr])};
        push @tvs, @{$tva->fetch_all_somatic_by_Transcripts([$tr])};        
      }
    }

    $cache->{$tr_id} = \@tvs;
  }

  return $cache->{$tr_id};
}

sub _get_variation_features {
  my $self         = shift;
  my $slice        = shift;
  my $tv_count     = shift;
  my $exonic_types = shift;

  if(!exists($self->{_variation_features})) {
    my $vfa = $self->hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');
    if ($tv_count > $TV_MAX) {
      # No need to have the slice expanded to upstream/downstream
      $slice = $self->object->Obj->feature_Slice;
      $self->{_variation_features} = { map {$_->dbID => $_} (@{ $vfa->fetch_all_by_Slice_SO_terms($slice,$exonic_types) }, @{ $vfa->fetch_all_somatic_by_Slice_SO_terms($slice,$exonic_types) })}; 
    }
    else {
      $self->{_variation_features} = { map {$_->dbID => $_} (@{ $vfa->fetch_all_by_Slice($slice) }, @{ $vfa->fetch_all_somatic_by_Slice($slice) })};
    }
  }

  return $self->{_variation_features};
}

sub _count_variation_features {
  my $self  = shift;
  my $slice = shift;

  my $vfa = $self->hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');

  return $vfa->count_by_Slice_constraint($slice);
}

sub _count_transcript_variations {
  my $self = shift;
  my $tr   = shift;

  my $tva = $self->hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
  return $tva->count_all_by_Transcript($tr);
}

sub _get_vf_from_tv {
  my ($self, $tv, $vfs, $slice, $tv_count, $exonic_types) = @_;

  my $vf; 

  if(my $raw_id = $tv->{_variation_feature_id}) {
    $vfs ||= $self->_get_variation_features($slice, $tv_count, $exonic_types);
    $vf = $vfs->{$raw_id};
  }
  else {
    $vf = $tv->variation_feature;
  }

  return $vf;
}


sub configure {
  my ($self, $context, $consequence) = @_;
  my $object      = $self->object;
  my $object_type = $self->hub->type;
  my $extent      = $context eq 'FULL' ? 5000 : $context;
  my %cons        = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my %selected_so = map { $_ => 1 } defined $consequence && $consequence ne 'ALL' ? split /\,/, $consequence : (); # map the selected consequence type to SO terms
  my @so_terms    = keys %selected_so;
  my ($gene_object, $transcript_object);

  if ($object->isa('EnsEMBL::Web::Object::Gene')){ #|| $object->isa('EnsEMBL::Web::Object::LRG')){
    $gene_object = $object;
  } elsif ($object->isa('EnsEMBL::Web::Object::LRG')){
    my @genes   = @{$object->Obj->get_all_Genes('LRG_import')||[]};
    my $gene    = $genes[0];  
    my $factory = $self->builder->create_factory('Gene');
    
    $factory->createObjects($gene);
    
    $gene_object = $factory->object;
  } else {
    $transcript_object = $object;
    $gene_object       = $self->hub->core_object('gene');
  }
  
  $gene_object->get_gene_slices(
    undef,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'   ],
    [ 'transcripts', 'munged', $extent ]
  );
  
  return $gene_object;
}

sub get_hgvs {
  my ($self, $tva) = @_;
  my $hgvs_c = $tva->hgvs_transcript;
  my $hgvs_p = $tva->hgvs_protein;
  my $hgvs;

  if ($hgvs_c) {
    if (length $hgvs_c > 35) {
      my $display_hgvs_c  = substr($hgvs_c, 0, 35) . '...';
         $display_hgvs_c .= $self->trim_large_string($hgvs_c, 'hgvs_c_' . $tva->dbID);
         $hgvs_c          = $display_hgvs_c;
    }
    
    $hgvs .= $hgvs_c;
  }

  if ($hgvs_p) {
    if (length $hgvs_p > 35) {
      my $display_hgvs_p  = substr($hgvs_p, 0, 35) . '...';
         $display_hgvs_p .= $self->trim_large_string($hgvs_p, 'hgvs_p_'. $tva->dbID);
         $hgvs_p          = $display_hgvs_p;
    }
    
    $hgvs .= "<br />$hgvs_p";
  }
  
  return $hgvs;
}

sub memo_argument {
  my ($self) = @_;
  return {
    url => $self->hub->url
  };
}

1;
