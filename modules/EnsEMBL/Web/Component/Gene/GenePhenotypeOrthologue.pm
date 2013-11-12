# $Id$

package EnsEMBL::Web::Component::Gene::GenePhenotypeOrthologue;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $phenotype    = $hub->param('sub_table');
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  
  my $html = '';
  
  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
    $object->get_homology_matches('ENSEMBL_PARALOGUES', 'possible_ortholog', undef, $cdb)
  );
  
  my %orthologue_list;
  my %skipped;
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      my $species = $_;
      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$_}}};
    }
  }
  
  my @rows;
  
  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next unless $hub->species_defs->get_config($species, 'databases')->{'DATABASE_VARIATION'};
    
    my $pfa = $hub->get_adaptor('get_PhenotypeFeatureAdaptor', 'variation', $species);
    my $sp = $species;
    $sp =~ tr/ /_/;
    
    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      
      foreach my $pf(@{$pfa->fetch_all_by_object_id($stable_id, 'Gene')}) {
        
        # gene
        my $gene_link = $hub->url({
          species => $species,
          action  => 'Summary',
          g       => $stable_id,
          __clear => 1
        });
        my $gene = sprintf(
          '<a href="%s">%s</a><br/><span class="small">%s</span>',
          $gene_link,
          $stable_id,
          $orthologue->{display_id}
        );
        
        # phenotype
        my $phen_link = $hub->url({
          species => $species,
          type    => 'Phenotype',
          action  => 'Locations',
          ph      => $pf->phenotype->dbID,
          __clear => 1
        });
        my $phen = sprintf(
          '<a href="%s">%s</a>',
          $phen_link,
          $pf->phenotype->description,
          $pf->source
        );
        
        # source
        my $source = $pf->source;
        my $ext_id = $pf->external_id;
        my $tax = $species_defs->get_config($species, 'TAXONOMY_ID');
      
        if($ext_id && $source) {
          $source = $hub->get_ExtURL_link($source, $source, { ID => $ext_id, TAX => $tax});
        }
        
        push @rows, {
          species => join('<br />(', split /\s*\(/, $species_defs->species_label($sp)),
          gene => $gene,
          phenotype => $phen,
          source => $source
        };
      }
    }
  }
  
  $html = '<h2>Phenotypes associated with the gene orthologues in other species</h2>'.
    $self->new_table([ 
      { key => 'species',    align => 'left', title => 'Species'        },
      { key => 'gene', align => 'left', title => 'Gene'     },
      { key => 'phenotype', align => 'left', title => 'Phenotype'     },
      { key => 'source', align => 'left', title => 'Source'     },
    ], \@rows, { data_table => 'no_col_toggle', exportable => 1 })->render if @rows;
  
  return $html;
}


1;
