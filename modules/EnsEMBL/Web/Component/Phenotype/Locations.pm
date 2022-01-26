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

package EnsEMBL::Web::Component::Phenotype::Locations;



use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::NewTable::NewTable;

use base qw(EnsEMBL::Web::Component::Phenotype);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $ph_id              = $hub->param('ph');
  my $ontology_accession = $hub->param('oa');
  my $error;

  if (!$ph_id && !$ontology_accession) {
    return $self->_warning("Parameter missing!", "The URL should contain the parameter 'oa' or 'ph'");
  }

  my $html;
  my $table = $self->make_table();

  $html .= $table->render($hub,$self);
  return $html;
}

sub table_content {
  my ($self,$callback) = @_;

  my $hub = $self->hub;

  my $ph_id              = $hub->param('ph');
  my $ontology_accession = $hub->param('oa');
 
  my $gene_ad = $hub->database('core')->get_adaptor('Gene');
  my $pf_ad   = $hub->database('variation')->get_adaptor('PhenotypeFeature');

  my (%gene_ids,$pfs);

  if ($ph_id) {
    $pfs = $pf_ad->fetch_all_by_phenotype_id_source_name($ph_id);
  }
  else {
    $pfs = $pf_ad->fetch_all_by_phenotype_accession_source($ontology_accession);
  }

  ROWS: foreach my $pf (@{$pfs}) {
    next if $callback->free_wheel();

    unless($callback->phase eq 'outline') {
      
      my $feat_type = $pf->type;
        
      next if ($feat_type eq 'SupportingStructuralVariation');

      if ($feat_type eq 'Variation') {
        $feat_type = 'Variant';
      } elsif ($feat_type eq 'StructuralVariation') {
        $feat_type = 'Structural Variant';
      }

      my $pf_name      = $pf->object_id;
      my $region       = $pf->seq_region_name;
      my $start        = $pf->seq_region_start;
      my $end          = $pf->seq_region_end;
      my $strand       = $pf->seq_region_strand;
      my $strand_label = ($strand == 1) ? '+' : '-';
      my $phe_desc     = $pf->phenotype_description; 
      my $study_xref   = ($pf->study) ? $pf->study->external_reference : undef;
      my $external_id  = ($pf->external_id) ? $pf->external_id : undef;
      my $attribs      = $pf->get_all_attributes;
      my $source       = $pf->source_name;  
      my ($source_text,$source_url) = $self->source_url($pf_name, $source, $external_id, $attribs, $pf);

      my @reported_genes = split(/,/,$pf->associated_gene);

      my @assoc_genes;
      # preparing the URL for all the associated genes and ignoring duplicate one
      foreach my $id (@reported_genes) {
        $id =~ s/\s//g;
        next if $id =~ /intergenic|pseudogene/i || $id eq 'NR';
      
        my $gene_label = [$id,undef,undef];

        if (!$gene_ids{$id}) {
          foreach my $gene (@{$gene_ad->fetch_all_by_external_name($id) || []}) {
            $gene_ids{$id} = $gene->description;
          }
        }

        if ($gene_ids{$id}) {
          $gene_label = [$id,$hub->url({ type => 'Gene', action => 'Summary', g => $id }),$gene_ids{$id}];
        }
        push @assoc_genes,$gene_label;
      }

      my $studies = $self->study_urls($study_xref);
      my ($name_id,$name_url,$name_extra) = $self->pf_link($pf,$pf->type,$pf->phenotype_id);

      # ClinVar specific data
      my $evidence_list;
      my $submitter_list = [];
      if ($source =~ /clinvar/i) {
        if ($attribs->{'MIM'}) {
          my @data = split(',',$attribs->{'MIM'});
          foreach my $ext_ref (@data) {
            push(@$studies, [$hub->get_ExtURL('OMIM', $ext_ref),'MIM:'.$ext_ref]);
          }
        }
        if ($attribs->{'pubmed_id'}) {
          my @data = split(',',$attribs->{'pubmed_id'});
          $evidence_list = $self->supporting_evidence_link(\@data, 'pubmed_id');
        }
        # Submitter data
        $submitter_list = $pf->submitter_names;
      }
 
      my @study_links    = map { $_->[0]||'' } @$studies;
      my @study_texts    = map { $_->[1]||'' } @$studies;
      my @evidence_texts = ($evidence_list) ? keys(%$evidence_list) : ();
      my @evidence_links = ($evidence_list) ? map { $evidence_list->{$_} } @evidence_texts : ();
      my @gene_texts     = map { $_->[0]||'' } @assoc_genes;
      my @gene_links     = map { $_->[1]||'' } @assoc_genes;
      my @gene_titles    = map { $_->[2]||'' } @assoc_genes;


      my $row = {
           name_id          => $name_id,
           name_link        => $name_url,
           name_extra       => $name_extra,
           location         => "$region:$start-$end$strand_label",
           feature_type     => $feat_type,
           phe_source       => $source_text,
           phe_link         => $source_url,
           study_links      => join("\r",'',@study_links),
           study_texts      => join("\r",'',@study_texts),
           study_submitter  => join(', ', $submitter_list ? @$submitter_list : ()),
           evidence_links   => join("\r",'',@evidence_links),
           evidence_texts   => join("\r",'',@evidence_texts),
           gene_links       => join("\r",'',@gene_links),
           gene_texts       => join("\r",'',@gene_texts),
           gene_titles      => join("\r",'',@gene_titles),
      };

      if (!$hub->param('ph')) {
        $row->{phe_desc} = $self->phenotype_url($phe_desc,$pf->phenotype_id);
        $row->{p_desc}   = $phe_desc;
      }

      $callback->add_row($row);
      last ROWS if $callback->stand_down;
    }
  }
}


sub make_table {
  my $self = shift;

  my $hub = $self->hub;
  my $glossary = $hub->glossary_lookup;

  my $table = EnsEMBL::Web::NewTable::NewTable->new($self);

  my $sd = $hub->species_defs->get_config($hub->species, 'databases')->{'DATABASE_VARIATION'};

  my @exclude;
  push @exclude,'phe_desc','p_desc' if $hub->param('ph');

  my @columns = ({
    _key => 'name_id', _type => 'string no_filter',
    url_column => 'name_link',
    extra_column => 'name_extra',
    label => "Name(s)",
  },{
    _key => 'name_link', _type => 'string no_filter unshowable',
    sort_for => 'names',
  },{
    _key => 'name_extra', _type => 'string no_filter unshowable',
    sort_for => 'names',
  },{
    _key => 'feature_type', _type => 'iconic',
    label => "Type",
    width => 0.7,
    sort_for => 'feat_type',
    filter_label => 'Feature type',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 1,
  },{
    _key => 'location', _type => 'position no_filter fancy_position',
    label => 'Location',
    sort_for => 'loc',
    label => 'Genomic location (strand)',
    helptip => $glossary->{'Chr:bp'}.' The symbol (+) corresponds to the forward strand and (-) corresponds to the reverse strand.',
    width => 1.4,
  },{
    _key => 'gene_links', _type => 'string no_filter unshowable',
  },{
    _key => 'gene_texts', _type => 'string no_filter',
    label => "Reported gene(s)",
    helptip => 'Gene(s) reported in the study/paper',
    url_column => 'gene_links',
    title_column => 'gene_titles',
  },{
    _key => 'gene_titles', _type => 'string no_filter unshowable',
  },{
    _key => 'phe_desc', _type => 'iconic no_filter',
    label => 'Phenotype/Disease/Trait',
    helptip => 'Phenotype, disease or trait association',
    width => 2,
  },{
    _key => 'p_desc', _type => 'iconic unshowable',
    sort_for => 'phe_desc',
    filter_label => 'Phenotype/Disease/Trait',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 3,
  },{ 
    _key => 'phe_link', _type => 'string no_filter unshowable',
    label => 'Annotation source',
    helptip => 'Project or database reporting the association',
  },{
    _key => 'phe_source', _type => 'iconic',
    label => 'Annotation source',
    helptip => 'Project or database reporting the association',
    url_rel => 'external',
    url_column => 'phe_link',
    filter_label => 'Annotation source',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 2,
  },{
    _key => 'study_submitter', _type => 'string no_filter',
    label => 'Submitter',
    helptip => 'Submitter reporting the association',
  },{
    _key => 'study_texts', _type => 'string no_filter',
    label => 'External reference',
    helptip => 'Link to the data source showing the association',
    url_column => 'study_links',
    url_rel => 'external',
    width => 0.8,
  },{
    _key => 'study_links', _type => 'string no_filter unshowable',
  },{
    _key => 'evidence_texts', _type => 'string no_filter',
    label => 'Supporting evidence',
    helptip => 'Link to the PubMed article describing the association',
    url_column => 'evidence_links',
    url_rel => 'external',
    width => 0.8,
  },{
    _key => 'evidence_links', _type => 'string no_filter unshowable',
  });

  $table->add_columns(\@columns,\@exclude);

  $self->feature_type_classes($table);

  return $table;
}


sub feature_type_classes {
  my ($self,$table) = @_;

  my @ftypes = ('Variant', 'Structural Variant', 'Gene', 'QTL');
  my %ftype_cols = (
    'Variant' => '#2222aa',
    'Structural Variant' => '#22aa22',
    'Gene' => '#aa2222',
    'QTL' => '#d91bf7'
  );

  my $classes_col = $table->column('feature_type');
  my $i = 0;
  foreach my $type (@ftypes) {
    $classes_col->icon_order($type,$i++);
    $classes_col->icon_coltab($type,$ftype_cols{$type});
  }
}

sub pf_link {
  my $self = shift;
  my $feature = shift;
  my $type = shift;
  my $ph_id = shift;

  my $hub = $self->hub;

  my $link;
  my $pf_name = $feature->object_id;
  my $pf_name_label = $pf_name;

  if ($type eq 'QTL') {
    my $source = $feature->source_name;
    $source =~ s/ /\_/g;
    $source .= '_SEARCH' if ($source eq 'RGD');

    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $hub->species)));

    return ($pf_name_label,$hub->get_ExtURL($source,{ ID => $pf_name, TYPE => $type, SP => $species}),undef);
  }

  # link to gene or variation page
  else {
    # work out the ID param (e.g. v, g, sv)
    # TODO - get these from Controller::OBJECT_PARAMS (controller should be made accessible via Hub)
    my $id_param = $type;
    $id_param =~ s/[a-z]//g;
    $id_param = lc($id_param);

    my $display_label = '';
    my $extra_id   = '';
    if ($type eq 'Gene') {
      $display_label = $self->object->get_gene_display_label($pf_name);
      $extra_id = $pf_name if ($display_label !~ /$pf_name/);

      # LRG
      if ($pf_name =~ /(LRG)_\d+$/) {
        $type = $1;
        $id_param = lc($type);
      }
    }
    else {
      $display_label = $pf_name;
    }

    my $params = {
      'type'      => $type,
      'action'    => 'Phenotype',
      'ph'        => $ph_id,
      $id_param   => $pf_name,
      __clear     => 1
    };
    return ($display_label,$hub->url($params),$extra_id);
  }
}

# Cross reference to phenotype entries
sub phenotype_url{
  my $self  = shift;
  my $pheno = shift;
  my $pid   = shift;

  my $params = {
      'type'      => 'Phenotype',
      'action'    => 'Locations',
      'ph'        => $pid,
      __clear     => 1
    };

  return sprintf('<a href="%s">%s</a>', $self->hub->url($params), $pheno);
}

# External link to the data association source
sub source_url {
  my ($self, $obj_name, $source, $ext_id, $attribs, $pf) = @_;

  my $hub = $self->hub();

  my $source_uc = uc $source;
     $source_uc =~ s/\s/_/g;

  my $ext_ref_id = $attribs->{'xref_id'};

  if ($source =~ /^animal.qtldb/i) {
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $hub->species)));
    return ($source,$hub->get_ExtURL(
      $source_uc,
      { ID => $obj_name, SP => $species}
    ));
  }
  if ($source eq 'GOA') {
    return ($source,$hub->get_ExtURL_link(
      'QUICK_GO_IMP',
      { ID => $ext_id, PR_ID => $ext_ref_id}
    ));
  }
  if ($source_uc eq 'MGI') {
    return ($source,$hub->get_ExtURL(
      $source_uc.'_MP',
      { ID => $ext_id }
    ));
  }
  if ($source_uc eq 'RGD') {
    $ext_id = $pf->object_id if (!$ext_id);
    return ($source,$hub->get_ExtURL(
      $source_uc.'_SEARCH',
      { ID => $ext_id, TYPE => $pf->type }
    ));
  }
  if ($source_uc eq 'ZFIN') {
    my $phe = $pf->phenotype->description;
       $phe =~ s/,//g;
    return ($source,$hub->get_ExtURL(
      $source_uc.'_SEARCH',
      { ID => $phe }
    ));
  }

  my $url   = $hub->species_defs->ENSEMBL_EXTERNAL_URLS->{$source_uc};
  my $label = $source;
  my $name;
  if ($url =~/ebi\.ac\.uk\/gwas/) {
    $name = $obj_name;
  }
  elsif ($url =~ /clinvar/) {
    $ext_id =~ /^(.+)\.\d+$/;
    $name = ($1) ? $1 : $ext_id;
  }
  elsif ($url =~ /omim/) {
    $name = "search?search=".($ext_id || $obj_name);
  } else {
    $name = $ext_id || $obj_name;
  }

  $url =~ s/###ID###/$name/;

  my $tax = $hub->species_defs->TAXONOMY_ID;
  $url =~ s/###TAX###/$tax/;

  return ($source,undef) if $url eq "";

  return ($label,$url);
}

sub study_urls {
  my ($self, $xref) = @_;

  my $html;

  my @links;
  my $link;
  if ($xref =~ /(pubmed|PMID)/) {
    $xref =~ s/\s+//g;
    foreach my $pmid (split(',',$xref)) {
      my $id = $pmid;
         $id =~ s/pubmed\///;
         $id =~ s/PMID://;
      $link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
      $link =~ s/###ID###/$id/;
      $pmid =~ s/\//:/g;
      $pmid =~ s/pubmed/PMID/;
      $html .= qq{<a rel="external" href="$link">$pmid</a>; };
      push @links,[$link,$pmid];
    }
  }
  elsif ($xref =~ /^MIM\:/) {
  foreach my $mim (split /\,\s*/, $xref) {
      my $id = (split /\:/, $mim)[-1];
      my $sub_url = $self->hub->get_ExtURL('OMIM', $id);
      push @links,[$sub_url,$mim];
    }
  }
  elsif($xref) {
    push @links,[undef,$xref] if ($xref ne 'NULL');
  }
  return \@links;
}

# Supporting evidence links
sub supporting_evidence_link {
  my ($self, $evidence_list, $type) = @_;
  my %evidence_with_url;

  if ($type =~ /^pubmed/i) {
    foreach my $evidence (@{$evidence_list}) {
      $evidence =~ s/\s+//g;
      my $link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
         $link =~ s/###ID###/$evidence/;
      my $label = "PMID:$evidence";
      $evidence_with_url{$label} = $link;
    }
  }

  return \%evidence_with_url;
}

1;

