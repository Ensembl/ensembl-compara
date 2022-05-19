=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::StrainTable;

use strict;

use List::Util qw(max min);

use Bio::EnsEMBL::Variation::Utils::Config qw(%ATTRIBS);
use Bio::EnsEMBL::Variation::Utils::Constants qw(%VARIATION_CLASSES);
use Bio::EnsEMBL::Variation::Utils::VariationEffect qw($UPSTREAM_DISTANCE $DOWNSTREAM_DISTANCE);
use EnsEMBL::Web::Utils::FormatText qw(coltab);
use EnsEMBL::Web::NewTable::NewTable;

use Bio::EnsEMBL::Variation::Utils::VariationEffect;
use Bio::EnsEMBL::Variation::DBSQL::StrainSliceAdaptor;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub consequence_type {
  my $self = shift;
  my $vf   = shift;
  
  my $var_styles = $self->hub->species_defs->colour('variation');
  my $colourmap  = $self->hub->colourmap;

  my $oc = $vf->most_severe_OverlapConsequence;

  my $hex = $var_styles->{lc $oc->SO_term} ? 
              $colourmap->hex_by_name($var_styles->{lc $oc->SO_term}->{'default'}) :
              $colourmap->hex_by_name($var_styles->{'default'}->{'default'});
  return coltab($oc->label, $hex, $oc->description);
}

sub table_content {
  my ($self,$callback) = @_;

  my $hub    = $self->hub;
  my $object = $self->object;
  my $slice  = $object->slice;
     $slice  = $slice->invert if $hub->param('strand') == -1;

  return "Not slice" if (!$slice);

  # Population and Samples
  my $pop_adaptor = $hub->get_adaptor('get_PopulationAdaptor', 'variation');
  my $pop = $pop_adaptor->fetch_by_name('Mouse Genomes Project');

  my $samples = $pop->get_all_Samples;
  my @sorted_samples = sort { $a->name <=> $b->name} @$samples;

  return $self->variation_table($callback,$slice,$pop,\@sorted_samples);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
  my $threshold = 100001;

  my $r = $self->param('r');
  $r =~ /^(.*):(\d+)-(\d+)$/;
  my ($chr,$s,$e) = ($1,$2,$3);
  my $ss = int(($s+$e)/2);
  my $ee = $ss+50000;
  $ss -= 50000;
  my $rr = "$chr:$ss-$ee";
  my $centre_url = $hub->url({
    r => $rr,
  });
  return $self->_warning('Region too large',qq(<p>The region selected is too large to display in this view - use the navigation above to zoom in or <a href="$centre_url">click here to zoom into $rr</a>...</p>)) if $object->length > $threshold;

  my $slice = $object->slice;
     $slice = $slice->invert if $hub->param('strand') == -1;
  my $html;


  return "Not slice" if (!$slice);

  # Population and Samples
  my $pop_adaptor = $hub->get_adaptor('get_PopulationAdaptor', 'variation');
  my $pop = $pop_adaptor->fetch_by_name('Mouse Genomes Project');

  my $samples = $pop->get_all_Samples;
  my @sorted_samples = sort { $a->name <=> $b->name} @$samples;

  my $table = $self->make_table($slice,\@sorted_samples);

  $html .= $table->render($hub,$self);

  return $html;
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

sub make_table {
  my ($self,$slice,$samples) = @_;

  my $hub      = $self->hub;
  my $glossary = $hub->glossary_lookup;

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);

  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

  my @exclude;
  my @columns = ({
      _key => 'ID', _type => 'string no_filter',
      label => "Variant ID",
      width => 2,
      helptip => 'Variant identifier',
      link_url => {
        type   => 'Variation',
        action => 'Explore',
        vf     => ["vf"],
        v      => undef # remove the 'v' param from the links if already present
      }
    },{
      _key => 'vf', _type => 'numeric unshowable no_filter'
    },{
      _key => 'location', _type => 'position unshowable no_filter',
      label => 'Location', sort_for => 'chr',
      state_filter_ephemeral => 1,
    },{
      _key => 'chr', _type => 'string no_filter',
      label => 'Chr: bp',
      width => 1.75,
      helptip => $glossary->{'Chr:bp'},
    },{
      _key => 'class', _type => 'iconic', label => 'Class',
      helptip => $glossary->{'Class'},
      filter_keymeta_enum => 1,
      filter_maybe_blank => 1,
      filter_sorted => 1,
      primary => 1,
    },{
      _key => 'snptype', _type => 'iconic', label => "Conseq. Type",
      filter_label => 'Consequences',
      filter_sorted => 1,
      width => 1.5,
      helptip => 'Consequence type',
      sort_down_first => 1,
      filter_keymeta_enum => 1,
      primary => 2,
    },{
      _key => 'Alleles', _type => 'string no_filter no_sort',
      label => "Alle\fles",
      helptip => 'Variant Reference/Alternative nucleotides',
      toggle_separator => '/',
      toggle_maxlen => 20,
      toggle_highlight_column => 'ref_al',
    },{
      _key => 'ref_al', _type => 'string no_filter no_sort',
      label => "Ref.",
      helptip => 'Reference nucleotide(s)',
      toggle_separator => '/',
      toggle_maxlen => 20,
      toggle_highlight_column => 'ref_al',
    });

  my @sample_cols;
  foreach my $sample (@$samples) {
    my $sample_label = $sample->name;
       $sample_label =~ s/^MGP://;
    push (@sample_cols,
    {
      _key    => lc($sample->name).'_strain'  , _type => 'string no_filter no_sort',
      label   => $sample_label,
      helptip => $sample->name,
      toggle_diagonal => 1,
      width => 0.5,
      recolour => { A => 'green', C => 'blue', G => '#ff9000', T => 'red' }
    });
  }
  push @columns,(sort { $a->{'_key'} cmp $b->{'_key'} } @sample_cols);

  $table->add_columns(\@columns,\@exclude);

  $self->class_classes($table);
  $self->snptype_classes($table,$self->hub);

  $table->add_phase("taster",'taster',[0,50]);
  $table->add_phase("full",'full');

  return $table;
}

sub variation_table {
  my ($self,$callback,$slice,$pop,$samples) = @_;
  my $hub = $self->hub;
  my $num = 0;

  # create some URLs - quicker than calling the url method for every variant
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Summary',
    vf     => undef,
    v      => undef,
  });

  my $var_styles = $hub->species_defs->colour('variation');
  my $sga = $hub->get_adaptor('get_SampleGenotypeAdaptor', 'variation');
  my $default_allele = '.';

  my $vf_adaptor = $hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');
  my $vfs = $vf_adaptor->fetch_all_by_Slice($slice);  

  ROWS: foreach my $vf (@$vfs) {

    my $var      = $vf->variation;  
    my $var_name = $vf->variation_name;
    my $type     = $self->consequence_type($vf);

    next if $callback->free_wheel();

    my ($chr, $start, $end) = ($vf->seq_region_name,$vf->seq_region_start,$vf->seq_region_end);
    my $ref_allele = $vf->feature_Slice->seq;

### TODO: add reference ###

    my %list_of_sample_genotypes;

    foreach my $sample (@$samples) {
      my $sample_name = $sample->name;
      my $sample_genotypes = $sga->fetch_all_by_Variation($var,$sample);
      if ($sample_genotypes && $sample_genotypes->[0]) {
        $list_of_sample_genotypes{$sample_name} = $sample_genotypes->[0];
      }
    }

    next if (!%list_of_sample_genotypes);

    my $row = {
              ID       => $var_name,
              vf       => $vf->dbID,
              class    => $vf->var_class,
              snptype  => $type,
              Alleles  => $vf->allele_string,
              ref_al   => $ref_allele,
              chr      => "$chr:" . ($start > $end ? " between $end & $start" : "$start".($start == $end ? '' : "-$end")),
              location => "$chr:".($start>$end?$end:$start),
            };
    foreach my $sample (@$samples) {
      my $sample_name = $sample->name;
      
      unless ($list_of_sample_genotypes{$sample_name}) {
        $row->{lc($sample_name).'_strain'} = qq{<div style="text-align:center">$default_allele</div>};
        next;
      }

      my $sample_genotype = $list_of_sample_genotypes{$sample_name};
      my $genotype = $sample_genotype->genotype;
      my $sample_allele;
      if (scalar(@$genotype) == 2 && $genotype->[0] eq $genotype->[1]) {
        $sample_allele = $genotype->[0];
      }
      else {
        $sample_allele = $sample_genotype->genotype_string;
      }

      if ($sample_allele eq $ref_allele) {
        $sample_allele = '|';#$default_allele;
      }
      $row->{lc($sample_name).'_strain'} = $sample_allele;
    }
    $callback->add_row($row);
    last ROWS if $callback->stand_down;
  }
}

sub class_classes {
  my ($self,$table) = @_;

  my $classes_col = $table->column('class');
  $classes_col->filter_add_baked('somatic','Only Somatic','Only somatic variant classes');
  $classes_col->filter_add_baked('not_somatic','Not Somatic','Exclude somatic variant classes');
  my $i = 0;
  foreach my $term (qw(display_term somatic_display_term)) {
    foreach my $class (values %VARIATION_CLASSES) {
      $classes_col->icon_order($class->{$term},$i++);
      if($term eq 'somatic_display_term') {
        $classes_col->filter_bake_into($class->{$term},'somatic');
      } else {
        $classes_col->filter_bake_into($class->{$term},'not_somatic');
      }
    }
  }
}

1;
