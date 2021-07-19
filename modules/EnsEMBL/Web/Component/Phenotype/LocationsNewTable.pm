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

package EnsEMBL::Web::Component::Phenotype::LocationsNewTable;



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
    # /!\ Rewrite the warning /!\
    return $self->_warning("Parameter missing!", "'oa' or 'ph'");
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

  my %type_colour = ( 'Variant'            => '#22A',
                      'Gene'               => '#A22',
                      'Structural Variant' => '#2A2',
                      'QTL'                => '#d91bf7',
                      'default'            => '#026a7c'
                    );

  ROWS: foreach my $pf (@{$pfs}) {
    next if $callback->free_wheel();

    unless($callback->phase eq 'outline') {
      
      my $feat_type = $pf->type;
        
      next if ($feat_type eq 'SupportingStructuralVariation');

      my $feat_type_width = 55;
      if ($feat_type eq 'Variation') {
        $feat_type = 'Variant';
      } elsif ($feat_type eq 'StructuralVariation') {
        $feat_type = 'Structural Variant';
        $feat_type_width = 110;
      }
      my $feat_type_colour = ($type_colour{$feat_type}) ? $type_colour{$feat_type} : $type_colour{'default'};

      my $pf_name     = $pf->object_id;
      my $region      = $pf->seq_region_name;
      my $start       = $pf->seq_region_start;
      my $end         = $pf->seq_region_end;
      my $strand      = $pf->seq_region_strand;
      my $phe_desc    = $pf->phenotype_description; 
      my $study_xref  = ($pf->study) ? $pf->study->external_reference : undef;
      my $external_id = ($pf->external_id) ? $pf->external_id : undef;
      my $attribs     = $pf->get_all_attributes;
      my $source      = $pf->source_name;  
      my $source_url  = $self->source_url($pf_name, $source, $external_id, $attribs->{'xref_id'}, $pf);

      my @reported_genes = split(/,/,$pf->associated_gene);

      my @assoc_gene_links;
      # preparing the URL for all the associated genes and ignoring duplicate one
      foreach my $id (@reported_genes) {
        $id =~ s/\s//g;
        next if $id =~ /intergenic|pseudogene/i || $id eq 'NR';
      
        my $gene_label = $id;

        if (!$gene_ids{$id}) {
          foreach my $gene (@{$gene_ad->fetch_all_by_external_name($id) || []}) {
            $gene_ids{$id} = $gene->description;
          }
        }

        if ($gene_ids{$id}) {
          $gene_label = sprintf(
            '<a href="%s" title="%s">%s</a>',
            $hub->url({ type => 'Gene', action => 'Summary', g => $id }),
            $gene_ids{$id},
            $id
          );
        }
        push @assoc_gene_links, $gene_label;
      }

      my $row = {
           names            => $self->pf_link($pf,$feat_type,$pf->phenotype_id),
           name_id          => ($pf->type eq 'Gene') ? $self->object->get_gene_display_label($pf_name) : $pf_name, 
           loc              => "$region:" . ($start > $end ? " between $end & $start" : "$start".($start == $end ? '' : "-$end"))." (".$strand.")",
           location         => "$region:".($start>$end?$end:$start),
           feat_type        => sprintf('<div style="border-radius:5px;text-align:center;width:100%;max-width:%ipx;color:#FFF;background-color:%s">%s</div>', 
                                       $feat_type_width, $feat_type_colour, $feat_type),
           feat_type_string => $feat_type,
           genes            => join(', ', @assoc_gene_links) || '-',
           phe_source       => $source_url,
           p_source         => $source,
           phe_study        => $self->study_url($study_xref),
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
    _key => 'names', _type => 'string no_filter',
    label => "Name(s)",
    width => 1,
  },{
    _key => 'name_id', _type => 'string unshowable no_filter',
    sort_for => 'names',
  },{
    _key => 'feat_type', _type => 'iconic no_filter',
    label => "Type",
    width => 0.7,
  },{
    _key => 'feat_type_string', _type => 'iconic unshowable',
    sort_for => 'feat_type',
    filter_label => 'Feature type',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 1,
  },{
    _key => 'loc', _type => 'string no_filter',
    label => 'Genomic location (strand)',
    helptip => $glossary->{'Chr:bp'},
    width => 1.4,
  },{
    _key => 'location', _type => 'position unshowable no_filter',
    label => 'Location', 
    sort_for => 'loc',
  },{
    _key => 'genes', _type => 'string no_filter',
    label => "Reported gene(s)",
    helptip => 'Gene(s) reported in the study/paper',
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
    _key => 'phe_source', _type => 'iconic no_filter',
    label => 'Annotation source',
    helptip => 'Project or database reporting the association',
  },{
    _key => 'p_source', _type => 'iconic unshowable',
    sort_for => 'phe_source',
    filter_label => 'Annotation source',
    filter_keymeta_enum => 1,
    filter_sorted => 1,
    primary => 2,
  },{
    _key => 'phe_study', _type => 'string no_filter',
    label => 'Study',
    helptip => 'Link to the pubmed article or other source showing the association',
    width => 0.8,
  });

  $table->add_columns(\@columns,\@exclude);

  $self->feature_type_classes($table);

  return $table;
}


sub feature_type_classes {
  my ($self,$table) = @_;

  my @ftypes = ('Variant', 'Structural Variant', 'Gene', 'QTL');

  my $classes_col = $table->column('feat_type');
  my $i = 0;
  foreach my $type (@ftypes) {
    $classes_col->icon_order($type,$i++);
  }
}

sub pf_link {
  my $self = shift;
  my $feature = shift;
  my $type = shift;
  my $ph_id = shift;

  my $link;
  my $pf_name = $feature->object_id;

  if ($type eq 'QTL') {
    my $source = $feature->source_name;
    $source =~ s/ /\_/g;
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $self->hub->species)));

    $link = $self->hub->get_ExtURL_link(
      $pf_name,
      $source,
      { ID => $pf_name, SP => $species}
    );
  }

  # link to gene or variation page
  else {
    # work out the ID param (e.g. v, g, sv)
    # TODO - get these from Controller::OBJECT_PARAMS (controller should be made accessible via Hub)
    my $id_param = $type;
    $id_param =~ s/[a-z]//g;
    $id_param = lc($id_param);

    my $display_label = '';
    my $extra_label   = '';
    if ($type eq 'Gene') {
      $display_label = $self->object->get_gene_display_label($pf_name);
      $extra_label   = '<br /><span class="small" style="white-space:nowrap;"><b>ID: </b>'.$pf_name."</span>";

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

    $link = sprintf('<a href="%s">%s</a>%s', $self->hub->url($params), $display_label, $extra_label);
  }

  return $link;
}


##cross reference to phenotype entries
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

sub source_url {
  my ($self, $obj_name, $source, $ext_id, $ext_ref_id, $pf) = @_;

  my $hub = $self->hub();

  my $source_uc = uc $source;
     $source_uc =~ s/\s/_/g;

  if ($source eq 'Animal QTLdb') {
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $hub->species)));

    return $hub->get_ExtURL_link(
      $source,
      $source_uc,
      { ID => $obj_name, SP => $species}
    );
  }
  if ($source eq 'GOA') {
    return $hub->get_ExtURL_link(
      $source,
      'QUICK_GO_IMP',
      { ID => $ext_id, PR_ID => $ext_ref_id}
    );
  }
  if ($source_uc eq 'RGD') {
    return $source if (!$ext_id);
    return $hub->get_ExtURL_link(
      $source,
      $source_uc.'_SEARCH',
      { ID => $ext_id }
    );
  }
  if ($source_uc eq 'ZFIN') {
    my $phe = $pf->phenotype->description;
       $phe =~ s/,//g;
    return $hub->get_ExtURL_link(
      $source,
      $source_uc.'_SEARCH',
      { ID => $phe }
    );
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

  return $source if $url eq "";

  return qq{<a rel="external" href="$url">$label</a>};
}

sub study_url {
  my ($self, $xref) = @_;

  my $html;

  my $link;
  if ($xref =~ /(pubmed|PMID)/) {
    foreach my $pmid (split(',',$xref)) {
      my $id = $pmid;
         $id =~ s/pubmed\///;
         $id =~ s/PMID://;
      $link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
      $link =~ s/###ID###/$id/;
      $pmid =~ s/\//:/g;
      $pmid =~ s/pubmed/PMID/;
      $html .= qq{<a rel="external" href="$link">$pmid</a>; };
    }
  }
  elsif ($xref =~ /^MIM\:/) {
  foreach my $mim (split /\,\s*/, $xref) {
      my $id = (split /\:/, $mim)[-1];
      my $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', $id);
      $link .= ', '.$sub_link;
      $link =~ s/^\, //g;
    }
    $html .= "$link; ";
  }
  else {
    $html .= "$xref; ";
  }
  $html =~ s/;\s$//;
  $html = '-' if (!$html || $html eq '');

  return $html;
}

1;

