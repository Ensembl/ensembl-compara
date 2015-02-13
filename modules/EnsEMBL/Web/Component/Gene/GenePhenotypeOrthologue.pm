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
  );
  
  my %orthologue_list;
  my %skipped;
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      my $species = $_;
      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$species}}};
    }
  }
  
  my @rows;

  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next unless $hub->species_defs->get_config($species, 'databases')->{'DATABASE_VARIATION'};
    
    my $pfa = $hub->get_adaptor('get_PhenotypeFeatureAdaptor', 'variation', $species);
    my $sp = $species;
       $sp =~ tr/ /_/;
    my $species_label = join('<br />(', split /\s*\(/, $species_defs->species_label($sp));

    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      my %entries;

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

      foreach my $pf(@{$pfa->fetch_all_by_object_id($stable_id, 'Gene')}) {
        
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

        $entries{$phen}{$source} = 1;
      }

      # Avoid row duplications
      foreach my $phe (keys(%entries)) {
        foreach my $src (keys(%{$entries{$phe}})) {
          push @rows, {
            species => $species_label,
            gene => $gene,
            phenotype => $phe,
            source => $src
          };
        }
      }

    }
  }
  if (scalar @rows) { 
    $html .= '<h2>Phenotypes associated with the gene orthologues in other species</h2>'.
      $self->new_table([ 
        { key => 'phenotype', align => 'left', title => 'Phenotype', sort => 'html' },
        { key => 'source',    align => 'left', title => 'Source'                    },
        { key => 'species',   align => 'left', title => 'Species'                   },
        { key => 'gene',      align => 'left', title => 'Gene'                      },
      ], \@rows, { data_table => 'no_col_toggle', exportable => 1 })->render if @rows;
  }
  else {
    $html .= '<p>No phenotypes associated with gene orthologues in other species.</p>';
  }
  return $html;
}


1;
