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



package EnsEMBL::Web::Component::Variation::Publication;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  
  my $data = $object->get_citation_data;
  
  return $self->_info('No citation data is available') unless scalar @$data;
  
  my $html = ('<h3>' . $object->name() .' is mentioned in the following publications</h3>'); 

  my ($table_rows,  $column_flags) = $self->table_data($data);
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'year desc' ] });
   

  $table->add_columns(  
    { key => 'year',   title => 'Year',      align => 'left', sort => 'hidden_numeric', help => 'Year of publication'},
    { key => 'pmid',   title => 'PMID',      align => 'left', sort => 'html'          , help => 'PubMed Identifier'  }
  );

  if ($column_flags->{'phen_asso'}) {
    $table->add_columns({ key => 'phen', title => 'Phenotype', align => 'center', sort => 'hidden_string', help => 'Significant phenotype(s) association(s) to the variant found in the publication' });
  }

  $table->add_columns(
    { key => 'title',  title => 'Title',     align => 'left', sort => 'html'    },  
    { key => 'author', title => 'Author(s)', align => 'left', sort => 'html'    },
    { key => 'text',   title => 'Full text', align => 'left', sort => 'html'    },
    { key => 'source', title => 'Citation source', align => 'left', sort => 'html'    },
  );

  foreach my $row (@{$table_rows}){  $table->add_rows($row);}

  $html .=  $table->render;
  return $html;
};


sub table_data { 
  my ($self, $citation_data) = @_;
  
  my $hub        = $self->hub;
  my $object     = $self->object;

  my $ucsc_url = 'http://genome.ucsc.edu/cgi-bin/hgc?r=0&l=0&c=0&o=-1&t=0&g=pubsMarkerSnp&i='; ## TESTURL

  my @data_rows;
  my %column_flags; 

  # Find phenotype entry with the same publication
  my $pfs = $object->Obj->get_all_PhenotypeFeatures;
  my %pf_publication;
  foreach my $pf (@$pfs) {
    if ($pf->study && $pf->is_significant==1) {
      if ($pf->study->external_reference =~ /^(pubmed|PMID)\/|:(\d+)/) {
        $pf_publication{$2}{$pf->phenotype->description} = 1;
      }
    }
  }

  my $url = my $url = $hub->url({
    type   => 'Variation',
    action => 'Phenotype',
  });
                 
  foreach my $cit (@$citation_data) { 
    
    my $has_phen_asso = 0;
    my $phenotypes = '';
    my $phenotypes_helptip = '';
    my $export_phenotypes = '';
    if (%pf_publication) {
      $has_phen_asso = defined $cit->pmid() ? ($pf_publication{$cit->pmid()} ? 1 : 0) : 0;
      if ($has_phen_asso == 1) {
        $column_flags{'phen_asso'} = 1 if (!$column_flags{'phen_asso'});
        my $pheno_icon = qq(<a href="$url"><img src="/i/val/var_phenotype_data_small.png" style="border-radius:5px;border:1px solid #000" alt="Phenotype"/></a>); 
        $phenotypes  = qq{This variant has significant associated phenotype(s) in this paper:};
        $phenotypes .= '<ul><li>'.join('</li><li>',sort {$a cmp $b} keys(%{$pf_publication{$cit->pmid}})).'</li></ul>';
        $phenotypes_helptip = helptip($pheno_icon, $phenotypes);
        $export_phenotypes = join(";",keys(%{$pf_publication{$cit->pmid}}));
      }
    }

    my $has_phenotype_html = qq{
      <span class="hidden export">$export_phenotypes</span>
        $phenotypes_helptip
    };

    # Publication source
    my $list_sources = $cit->get_all_sources_by_Variation($object->vari);
    my $sources = join(',', sort @{$list_sources});

    my $row = {
	  year   => $cit->year(),
	  pmid   => defined $cit->pmid() ? $hub->get_ExtURL_link($cit->pmid(), "EPMC_MED", $cit->pmid()) : undef,
          phen   => $has_phen_asso == 1 ? $has_phenotype_html : '',
	  title  => $cit->title(),
	  author => $cit->authors(),
	  text   => defined $cit->pmcid() ? $hub->get_ExtURL_link($cit->pmcid(), "EPMC", $cit->pmcid()) : undef,
	  source => $sources,
    };
 
    push @data_rows, $row;

  } 

  return \@data_rows, \%column_flags;
}

1;
