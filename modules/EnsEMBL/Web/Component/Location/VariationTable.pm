=head1 LICENSE

Copyright [2018-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::VariationTable;

use strict;

use List::Util qw(max min);

use Bio::EnsEMBL::Variation::Utils::Config qw(%ATTRIBS);
use Bio::EnsEMBL::Variation::Utils::Constants qw(%VARIATION_CLASSES);
use EnsEMBL::Web::NewTable::NewTable;

use Bio::EnsEMBL::Variation::Utils::VariationEffect;

use Scalar::Util qw(looks_like_number);

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub table_content {
  my ($self,$callback) = @_;

  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('location');
  my $slice  = $object->slice;

  return $self->variation_table($callback,$slice);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object_type = $self->hub->type;
  my $object      = $self->object || $hub->core_object('location');
  my $slice       = $object->slice;
  my $max_slice_length = 1000000 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);

  my $html  = '';
  
  if ($slice->length > $max_slice_length + 1) {
    my $warning_content = "The region selected is too long for this display (more than ".$self->thousandify($max_slice_length)." nt). Please use a shorter region or use  <a href=\"/biomart/martview/\">BioMart</a>";
    $html .= $self->_warning( "Selected region is too long", $warning_content); 
  }
  else {
    my $table = $self->make_table($slice);
    $html .= $table->render($hub,$self);
  }
  return $html;
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
  if ($clinsig_col) {
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
}


sub snptype_classes {
  my ($self,$table,$hub) = @_;

  my $species_defs = $hub->species_defs;
  my $var_styles   = $species_defs->colour('variation');
  my %all_cons     = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $column = $table->column('snptype');
  $column->filter_add_baked('lof','PTV','Select all protein truncating variant types');
  $column->filter_add_baked('lof_missense','PTV & Missense','Select all protein truncating and missense variant types');
  $column->filter_add_baked('exon','Only Exonic','Select exon and splice region variant types');
  $column->filter_add_bakefoot('PTV = Protein Truncating Variant');
  my @lof = qw(stop_gained frameshift_variant splice_donor_variant splice_acceptor_variant);
  foreach my $con (values(%all_cons)) {
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
  my ($self,$slice) = @_;

  my $hub      = $self->hub;
  my $glossary = $hub->glossary_lookup;

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);
  
  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

  my @exclude;
  push @exclude,'gmaf','gmaf_freq','gmaf_allele','clinsig','clinvar_id' unless $hub->species eq 'Homo_sapiens';


  my @columns = ({
    _key => 'ID', _type => 'string no_filter',
    label => "Variant ID",
    width => 1,
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
    label => 'Chr: bp',
    width => 1.5,
    helptip => $glossary->{'Chr:bp'},
  },{
    _key => 'Alleles', _type => 'string no_filter no_sort',
    label => "Alle\fles",
    helptip => 'Alternative nucleotides',
    toggle_separator => '/',
    toggle_maxlen => 20,
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
    _key => 'class', _type => 'iconic', label => 'Class',
    helptip => $glossary->{'Class'},
    filter_keymeta_enum => 1,
    filter_maybe_blank => 1,
    filter_sorted => 1,
    primary => 2,
  },{
    _key => 'Source', _type => 'iconic', label => "Sour\fce",
    helptip => $glossary->{'Source'},
    filter_maybe_blank => 1,
  },{
    _key => 'status', _type => 'iconic', label => "Evid\fence",
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
    primary => 3,
  },{
    _key => 'clinvar', _type => 'iconic', label => "ClinVar ID",
    helptip => 'ClinVar Identifier',
  },{
    _key => 'snptype', _type => 'iconic', label => "Consequence",
    filter_label => 'Consequences',
    filter_sorted => 1,
    width => 1.5,
    helptip => 'Most severe Consequence',
    sort_down_first => 1,
    filter_keymeta_enum => 1,
    primary => 4,
  },{
    _key => 'phen_filter', _type => 'iconic unshowable',
    filter_maybe_blank => 1,
    filter_label => 'Phenotypes',
    filter_sorted => 1
  },{
    _key => 'phen', _type => 'iconic no_filter', label => "Phenotype",
    helptip => 'Phenotype/Trait/Disease',
    filter_maybe_blank => 1,
    filter_label => 'Phenotypes',
    filter_sorted => 1,
  });

  $table->add_columns(\@columns,\@exclude);

  $self->evidence_classes($table);
  $self->clinsig_classes($table);
  $self->class_classes($table);
  $self->snptype_classes($table,$hub);

  my $region = $slice->seq_region_name;
  my $start  = $slice->seq_region_start;
  my $end    = $slice->seq_region_end;

  if($start && $end) {
    my $loc_col = $table->column('location');
    $loc_col->filter_seq_range($region,[$start,$end]);
    $loc_col->filter_fixed(1);
  }

  return $table;
}

sub variation_table {
  my ($self,$callback,$slice) = @_;
  my $hub         = $self->hub;
  my $show_scores = $hub->param('show_scores');
  my $num = 0;

  # create some URLs - quicker than calling the url method for every variant
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Summary',
    vf     => undef,
    v      => undef,
  });

  my $var_styles = $hub->species_defs->colour('variation');
  
  my $vfs = $self->_get_variation_features($slice);

  my $chr = $slice->seq_region_name;

  
  foreach my $vf (@$vfs) {
    next if $callback->free_wheel();

    if (1) {
      my $row;

      my $variation_name = $vf->variation_name;
      my $vf_dbID = $vf->dbID;
      $row->{'ID'} = $variation_name;
      my $source = $vf->source_name;
      $row->{'Source'} = $source;

      unless($callback->phase eq 'outline') {
        my $evidences     = $vf->get_all_evidence_values || [];
        my $clin_sigs     = $vf->get_all_clinical_significance_states || [];
        my $var_class     = $vf->var_class;
        my $allele_string = $vf->allele_string;
        my $consequence   = $vf->display_consequence('label');
       

        my ($start, $end) = ($vf->seq_region_start,$vf->seq_region_end);

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
      
        my $phen = ['-'];
        my @phen_filter = ();      

        my $clinvar_ids   = ['-'];
        my @clinvar_links = ();  

        if (grep { $_ =~ /Phenotype_or_Disease/i } @$evidences) {
          my $pfs = $self->_get_phenotype_features($vf->variation);
          $phen = $self->_get_phenotype_descriptions($pfs);
          $clinvar_ids = $self->_get_clinvar_ids($pfs);

          foreach my $phe (@$phen) {
            $phe = 'No data' if ($phe eq '-');
            push(@phen_filter,$phe);
          }
        }
 
        my $more_row = {
              vf           => $vf_dbID,
              class        => $var_class,
              Alleles      => $allele_string,
              Ambiguity    => $vf->ambig_code,
              gmaf         => $gmaf || '-',
              gmaf_freq    => $gmaf_freq || '',
              gmaf_allele  => $gmaf_allele,
              status       => $status,
              clinsig      => $clin_sig,
              clinvar      => join('; ',@$clinvar_ids),
              clinvar_link => join('; ',@clinvar_links),
              chr          => "$chr:" . ($start > $end ? " between $end & $start" : "$start".($start == $end ? '' : "-$end")),
              location     => "$chr:".($start>$end?$end:$start),
              phen         => join('; ',@$phen),
              phen_filter  => join('~',@phen_filter),
              snptype      => $consequence,
        };
        $row = { %$row, %$more_row };
      }
      $num++;
      $callback->add_row($row);
      last if $callback->stand_down;
    }
  }
}

sub _get_variation_features {
  my $self  = shift;
  my $slice = shift;

  if(!exists($self->{_variation_features})) {
    my $vfa = $self->hub->get_adaptor('get_VariationFeatureAdaptor', 'variation');

    my @vfs = sort { $a->seq_region_start <=> $b->seq_region_start} (@{ $vfa->fetch_all_by_Slice($slice) }, @{ $vfa->fetch_all_somatic_by_Slice($slice) });
    $self->{_variation_features} = \@vfs;    
  }

  return $self->{_variation_features};
}

sub _get_phenotype_features {
  my $self = shift;
  my $var  = shift;

  my $pfa = $self->hub->get_adaptor('get_PhenotypeFeatureAdaptor', 'variation');
  return $var->get_all_PhenotypeFeatures;
}

sub _get_phenotype_descriptions {
  my $self = shift;
  my $pfs  = shift;

  my %descriptions = map { $_->phenotype_description() => 1} @{$pfs};
  my @descs = sort {$a cmp $b} keys(%descriptions);

  return \@descs;
}

sub _get_clinvar_ids {
  my $self = shift;
  my $pfs  = shift;

  my @pfs_clinvar = grep { $_->source_name eq 'ClinVar' } @{$pfs};
  my %clinvar_ids = map { $_->external_id => 1}  @pfs_clinvar;
  my @ids = sort {$a cmp $b} keys(%clinvar_ids);

  return \@ids;
}

1;
