=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  );

  $table->add_columns( { key => 'ucsc',   title => 'UCSC', align => 'center', sort => 'html', help => 'View publication data in USCS website' }) if $self->hub->species eq 'Homo_sapiens';
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
      if ($pf->study->external_reference =~ /^pubmed\/(\d+)/) {
        $pf_publication{$1}{$pf->phenotype->description} = 1;
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
    my $export_phenotypes = '';
    if (%pf_publication) {
      $has_phen_asso = defined $cit->pmid() ? ($pf_publication{$cit->pmid()} ? 1 : 0) : 0;
      if ($has_phen_asso == 1) {
        $column_flags{'phen_asso'} = 1 if (!$column_flags{'phen_asso'});
        
        $phenotypes = "'".join("'; '",keys(%{$pf_publication{$cit->pmid}}))."'";
        $export_phenotypes = join(";",keys(%{$pf_publication{$cit->pmid}}));
      }
    }

    my $has_phenotype_html = qq{
      <span class="hidden export">$export_phenotypes</span>
      <a class="_ht" href="$url" title="This variant has significant associated phenotype(s) in this paper: $phenotypes">
        <img src="/i/val/var_phenotype_data_small.png" style="border-radius:5px;border:1px solid #000" alt="Phenotype"/>
      </a>
    };

    my $row = {
	  year   => $cit->year(),
	  pmid   => defined $cit->pmid() ? $hub->get_ExtURL_link($cit->pmid(), "PUBMED", $cit->pmid()) : undef,
          phen   => $has_phen_asso == 1 ? $has_phenotype_html : '',
	  title  => $cit->title(),
	  author => $cit->authors(),
	  text   => defined $cit->pmcid() ? $hub->get_ExtURL_link($cit->pmcid(), "EPMC", $cit->pmcid()) : undef,
	  ucsc   => defined $cit->ucsc_id() ? "<a class=\"_ht\" href=\"" . $ucsc_url . $object->name() ."&pubsFilterExtId=". $cit->ucsc_id() . "\" title=\"View in UCSC\"><img src=\"/i/val/ucsc_logo_small.png\" style=\"border-radius:5px;border:1px solid #000;padding:1px;background-color:#FFF\" alt=\"View\" /><span class=\"hidden export\">" . $ucsc_url . $object->name() ."&pubsFilterExtId=". $cit->ucsc_id() . "</span></a>" : undef 
    };
 
    push @data_rows, $row;

  } 

  return \@data_rows, \%column_flags;
}


1;
