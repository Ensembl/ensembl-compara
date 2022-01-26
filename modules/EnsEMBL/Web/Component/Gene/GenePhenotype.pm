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

package EnsEMBL::Web::Component::Gene::GenePhenotype;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $phenotype = $hub->param('sub_table');
  my $object    = $self->object;
  my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text) = $object->display_xref;

  # Gene phenotypes
  return $self->gene_phenotypes();
}

sub _inheritance { return $_[1]->{'inheritance_type'}; }  #overwritten in mobile plugins

sub gene_phenotypes {
  my $self             = shift;
  my $object           = $self->object;
  my $obj              = $object->Obj;
  my $hub              = $self->hub;
  my $species          = $hub->species_defs->SPECIES_DISPLAY_NAME;
  my $g_name           = $obj->stable_id;
  my $html;
  my (@rows, %list, $list_html);
  my $has_allelic = 0;  
  my $has_study   = 0;
  my $skip_phenotypes_link = "non_specified";
  my %phenotypes;

  return if($obj->isa('Bio::EnsEMBL::Compara::Family'));

  # add rows from Variation DB, PhenotypeFeature
  if ($hub->database('variation')) {
    my $pfa = $hub->database('variation')->get_PhenotypeFeatureAdaptor;
    
    # OMIA needs tax ID
    my $tax = $hub->species_defs->TAXONOMY_ID;
    if ($species =~ /^Mouse/) {
      my $features;
      foreach my $pf (@{$pfa->fetch_all_by_Gene($obj)}) {
        my $phe    = $pf->phenotype->description;
        my $phe_class = $pf->phenotype_class;
        my $ext_id = $pf->external_id;
        my $source = $pf->source_name;
        my $strain = $pf->strain;
        my $strain_name = encode_entities($strain->name);
        my $strain_gender = $strain->gender;
        my $allele_symbol = encode_entities($pf->allele_symbol);

        my $pmids   = '-';
        if ($pf->study) {
          $pmids = $self->add_study_links($pf->study->external_reference);
          $has_study = 1;
        }

        if ($ext_id) {
          my $source_uc = uc($source);
          if ($source_uc =~ /GOA/) {
            my $attribs = $pf->get_all_attributes;
            $source = $hub->get_ExtURL_link($source, 'QUICK_GO_IMP', { ID => $ext_id, PR_ID => $attribs->{'xref_id'}});
          } elsif($source_uc =~ /MGI/) {
            my $marker_accession_id = $pf->marker_accession_id;
            $source = $hub->get_ExtURL_link($source, $source_uc, { ID => $marker_accession_id, TAX => $tax});
          }
          else {
            $source = $hub->get_ExtURL_link($source, $source_uc, { ID => $ext_id, TAX => $tax});
          }
        }

        my $phe_url = sprintf(
            '<a href="%s" title="%s">%s</a>',
            $hub->url({
              type    => 'Phenotype',
              action  => 'Locations',
              ph      => $pf->phenotype->dbID
             }),
             'View associate loci',
             $phe
        );

        # display one row for phenotype associated with male and female strain
        my $key = join("\t", ($phe, $strain_name, $allele_symbol));
        $features->{$key}->{source} = $source;
        push @{$features->{$key}->{gender}}, $strain_gender;
        $features->{$key}->{url} = $phe_class eq $skip_phenotypes_link ? $phe : $phe_url;
        $features->{$key}->{pmid} = $pmids;
      }
      foreach my $key (sort keys %$features) {
        my ($phenotype, $strain_name, $allele_symbol) = split("\t", $key);
        push @rows, {
          source => $features->{$key}->{source},
          phenotype => $features->{$key}->{url},
          allele => $allele_symbol,
          strain => $strain_name .  " (" . join(', ', sort @{$features->{$key}->{gender}}) . ")",
          study => $features->{$key}->{pmid}
        };
      }
    } else {    
      foreach my $pf(@{$pfa->fetch_all_by_Gene($obj)}) {
        my $phe     = $pf->phenotype->description;
        my $phe_class = $pf->phenotype_class;
        my $source  = $pf->source_name;
        my $ext_id  = $pf->external_id;

        my $attribs = $pf->get_all_attributes;

        my $source_uc = uc $source;
           $source_uc =~ s/\s/_/g;
           $source_uc .= "_SEARCH" if ($source_uc =~ /^RGD$/);
           $source_uc .= "_ID"     if ($source_uc =~ /^ZFIN$/);

        my $source_url = "";
        if ($ext_id) {
          if ($source_uc =~ /GOA/) {
            $source_url = $hub->get_ExtURL_link($source, 'QUICK_GO_IMP', { ID => $ext_id, PR_ID => $attribs->{'xref_id'}});
          }
          else {  
            $source_url = $hub->get_ExtURL_link($source, $source_uc, { ID => $ext_id, TAX => $tax});
          }
        } else {
          $source_url = $hub->get_ExtURL_link($source, $source_uc);
        }
        $source_url = $source if ($source_url eq "" || !$source_url || $source_url =~ /\(ID\)/);
              
        $phenotypes{$phe} ||= { id => $pf->{'_phenotype_id'} };
        $phenotypes{$phe}{'source'}{$source_url} = 1;

        my $phe_url = sprintf(
          '<a href="%s" title="%s">%s</a>',
          $hub->url({
            type    => 'Phenotype',
            action  => 'Locations',
            ph      => $pf->phenotype->dbID
          }),
          'View associate loci',
          $phe
        );
        $phenotypes{$phe}{'url'} = $phe_class eq $skip_phenotypes_link? $phe : $phe_url;

        my $allelic_requirement = '-';
        if ($self->_inheritance($attribs)) {
          $phenotypes{$phe}{'allelic_requirement'}{$attribs->{'inheritance_type'}} = 1;
          $has_allelic = 1;
        }

        my $pmids   = '-';
        if ($pf->study) {
          $pmids = $self->add_study_links($pf->study->external_reference);
          foreach my $pmid (@$pmids) {
            $phenotypes{$phe}{'pmids'}{$pmid} = 1;
          }
          $has_study = 1;
        }
      }
      # Loop after each phenotype entry
      foreach my $phe (sort(keys(%phenotypes))) {
        my @pmids = keys(%{$phenotypes{$phe}{'pmids'}});
        my $study = (scalar(@pmids) != 0) ? $self->display_items_list($phenotypes{$phe}{'id'}.'pmids', 'Study links', 'Study links', \@pmids, \@pmids, 1) : '-';

        push @rows, {
          source    => join(', ', keys(%{$phenotypes{$phe}{'source'}})),
          phenotype => $phenotypes{$phe}{'url'},
          allelic   => ($phenotypes{$phe}{'allelic_requirement'}) ? join(', ', keys(%{$phenotypes{$phe}{'allelic_requirement'}})) : '-',
          study     => $study
        };
      }
    }
  }

  my $add_s = scalar @rows == 1 ? '' : 's';
  $html = qq{<a id="gene_phenotype"></a><h2>Phenotype$add_s, disease$add_s and trait$add_s associated with this gene $g_name</h2>};
  if (scalar @rows) {
    my @columns = (
      { key => 'phenotype', align => 'left', title => 'Phenotype, disease and trait' },
      { key => 'source',    align => 'left', title => 'Source'    }
    );

    if ($has_study == 1) {
      push @columns, { key => 'study', align => 'left', title => 'Study' , align => 'left', sort => 'html' };
    }
    if ($species eq 'Mouse') {
      push @columns, (
        { key => 'strain',    align => 'left', title => 'Strain'    },
        { key => 'allele',    align => 'left', title => 'Allele'    }
      );     
      $html .= $self->new_table(\@columns, \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 })->render;
    } else { 
      if ($has_allelic == 1) {
        push @columns, { key => 'allelic', align => 'left', title => 'Allelic requirement' , help => 'Allelic status associated with the disease (monoallelic, biallelic, etc)' };      
      }
      $html .= $self->new_table(\@columns, \@rows, { data_table => 'no_sort no_col_toggle', sorting => [ 'phenotype asc' ], exportable => 1 })->render;
    }
  }
  else {
    $html .= "<p>None found.</p>";
  }
  return $html;
}

sub add_study_links {
  my $self = shift;
  my $pmids  = shift;

  $pmids =~ s/ //g;

  my @pmids_list;
  my $epmc_link = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'EPMC_MED'};
  foreach my $pmid (split(',',$pmids)) {
    my $id = (split(':',$pmid))[1];
    my $link = $epmc_link;
       $link =~ s/###ID###/$id/;

    push @pmids_list, qq{<a rel="external" href="$link">$pmid</a>};
  }

  return \@pmids_list;
}

1;
