=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::HomologAlignment;

use strict;

use Bio::AlignIO;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $cdb          = shift || $hub->param('cdb') || 'compara';

  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $gene_id      = $self->object->stable_id;
  my $second_gene  = $hub->param('g1');
  my $seq          = $hub->param('seq');
  my $text_format  = $hub->param('text_format');
  my $database     = $hub->database($cdb);
  my $qm           = $database->get_GeneMemberAdaptor->fetch_by_stable_id($gene_id);
  my ($homologies, $html, %skipped);
  
  eval {
    $homologies = $database->get_HomologyAdaptor->fetch_all_by_Member($qm);
  };
  warn $@ if $@;
 
  my ($match_type, %desc_mapping);
  
  if ($hub->action eq 'Compara_Ortholog') {
    $match_type = 'Orthologue';
    %desc_mapping = (
      ortholog_one2one          => '1 to 1 orthologue',
      apparent_ortholog_one2one => '1 to 1 orthologue (apparent)',
      ortholog_one2many         => '1 to many orthologue',
      ortholog_many2many        => 'many to many orthologue',
      possible_ortholog         => 'possible orthologue',
    );
  }
  else {
    $match_type = 'Paralogue';
    %desc_mapping = (
      within_species_paralog    => 'paralogue (within species)',
      putative_gene_split       => 'putative gene split',
      contiguous_gene_split     => 'contiguous gene split',
    );
  }
 
  my $homology_types = EnsEMBL::Web::Constants::HOMOLOGY_TYPES;
  
  foreach my $homology (@{$homologies}) {

    ## filter out non-required types
    my $homology_desc  = $homology_types->{$homology->{'_description'}} || $homology->{'_description'};
    next unless $desc_mapping{$homology_desc};      

    my $sa;
    
    eval {
      if($seq eq 'cDNA') {
        $sa = $homology->get_SimpleAlign(-SEQ_TYPE => 'cds');
      } else {
        $sa = $homology->get_SimpleAlign;
      }
    };
    warn $@ if $@;
    
    if ($sa) {
      my $data = [];
      my $flag = !$second_gene;
      
      foreach my $peptide (@{$homology->get_all_Members}) {
        
        my $gene = $peptide->gene_member;
        $flag = 1 if $gene->stable_id eq $second_gene;
        
        my $member_species = ucfirst $peptide->genome_db->name;
        my $location       = sprintf '%s:%d-%d', $gene->dnafrag->name, $gene->dnafrag_start, $gene->dnafrag_end;
        
        if (!$second_gene && $member_species ne $species && $hub->param('species_' . lc $member_species) eq 'off') {
          $flag = 0;
          $skipped{$species_defs->species_label($member_species)}++;
          next;
        }
        
        if ($gene->stable_id eq $gene_id) {
          push @$data, [
            $species_defs->get_config($member_species, 'SPECIES_SCIENTIFIC_NAME'),
            $gene->stable_id,
            $peptide->stable_id,
            sprintf('%d aa', $peptide->seq_length),
            sprintf('%d %%', $peptide->perc_id),
            sprintf('%d %%', $peptide->perc_cov),
            $location,
          ]; 
        } else {
          push @$data, [
            $species_defs->get_config($member_species, 'SPECIES_SCIENTIFIC_NAME') || $species_defs->species_label($member_species),
            sprintf('<a href="%s">%s</a>',
              $hub->url({ species => $member_species, type => 'Gene', action => 'Summary', g => $gene->stable_id, r => undef }),
              $gene->stable_id
            ),
            sprintf('<a href="%s">%s</a>',
              $hub->url({ species => $member_species, type => 'Transcript', action => 'ProteinSummary', peptide => $peptide->stable_id, __clear => 1 }),
              $peptide->stable_id
            ),
            sprintf('%d aa', $peptide->seq_length),
            sprintf('%d %%', $peptide->perc_id),
            sprintf('%d %%', $peptide->perc_cov),
            sprintf('<a href="%s">%s</a>',
              $hub->url({ species => $member_species, type => 'Location', action => 'View', g => $gene->stable_id, r => $location, t => undef }),
              $location
            )
          ];
        }
      }
      
      next unless $flag;
      
      my $homology_desc_mapped = $desc_mapping{$homology_desc} ? $desc_mapping{$homology_desc} : 
                                 $homology_desc ? $homology_desc : 'no description';

      $html .= "<h2>$match_type type: $homology_desc_mapped</h2>";
      
      my $ss = $self->new_table([
          { title => 'Species',          width => '15%' },
          { title => 'Gene ID',          width => '15%' },
          { title => 'Peptide ID',       width => '15%' },
          { title => 'Peptide length',   width => '10%' },
          { title => '% identity',       width => '10%' },
          { title => '% coverage',       width => '10%' },
          { title => 'Genomic location', width => '25%' }
        ],
        $data
      );
      
      $html .= $ss->render;

      my $alignio = Bio::AlignIO->newFh(
        -fh     => IO::String->new(my $var),
        -format => $self->renderer_type($text_format)
      );
      
      print $alignio $sa;
      
      $html .= "<pre>$var</pre>";
    }
  }
  
  if (scalar keys %skipped) {
    my $count;
    $count += $_ for values %skipped;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", map "$_ ($skipped{$_})", sort keys %skipped
      )
    );
  }
  
  return $html;
}        

sub renderer_type {
  my $self = shift;
  my $K    = shift;
  my %T    = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
  return $T{$K} ? $K : EnsEMBL::Web::Constants::SIMPLEALIGN_DEFAULT;
}

1;

