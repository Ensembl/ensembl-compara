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

package EnsEMBL::Web::Component::Gene::HomologAlignment;

use strict;

use Bio::AlignIO;
use Bio::EnsEMBL::Compara::Homology;
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
  my (%skipped, $html);

  my $is_ncrna       = ($self->object->Obj->biotype =~ /RNA/);
  my $gene_product   = $is_ncrna ? 'Transcript' : 'Peptide';
  my $unit           = $is_ncrna ? 'nt' : 'aa';
  my $identity_title = '% identity'.(!$is_ncrna ? " ($seq)" : '');

  my $homologies = $self->get_homologies($cdb);

  # Remove the homologies with hidden species
  foreach my $homology (@{$homologies}) {

    my $compara_seq_type = $seq eq 'cDNA' ? 'cds' : undef;
    $homology->update_alignment_stats($compara_seq_type);
    my $sa;
    
    eval {
      $sa = $homology->get_SimpleAlign(-SEQ_TYPE => $compara_seq_type);
    };
    warn $@ if $@;
    
    if ($sa) {
      my $data = [];
      my $flag = !$second_gene;
      
      my $lookup = $species_defs->prodnames_to_urls_lookup;
      my $pan_lookup = $hub->species_defs->multi_val('PAN_COMPARA_LOOKUP') || {};
      foreach my $peptide (@{$homology->get_all_Members}) {
        my $gene = $peptide->gene_member;
        $flag = 1 if $gene->stable_id eq $second_gene; 

        my $prodname          = $peptide->genome_db->name;
        my $member_species    = $lookup->{$prodname};
        my $external_species  = $member_species ? 0 : 1;
        $member_species       ||= $pan_lookup->{$prodname}{'species_url'};
        my $label             = $external_species ? $pan_lookup->{$prodname}{'display_name'} : $species_defs->species_label($member_species);
        my $location       = sprintf '%s:%d-%d', $gene->dnafrag->name, $gene->dnafrag_start, $gene->dnafrag_end;
       
        if (!$second_gene && $member_species ne $species && $hub->param('species_' .$prodname) eq 'off') {
          $flag = 0;
          $skipped{$label}++;
          next;
        }

        if ($gene->stable_id eq $gene_id) {
          push @$data, [
            $label,
            $gene->stable_id,
            $peptide->stable_id,
            sprintf('%d %s', $peptide->seq_length, $unit),
            sprintf('%d %%', $peptide->perc_id),
            sprintf('%d %%', $peptide->perc_cov),
            $location,
          ]; 
        } else {
          my $division  = $pan_lookup->{$peptide->genome_db->name}{'division'};
          my $site      = '';
          if ($division) {
            $division = 'www' if $division eq 'vertebrates';
            $site     =  sprintf('https://%s.ensembl.org', $division);
          }
          push @$data, [
            $label,
            sprintf('<a href="%s%s">%s</a>',
              $site,
              $hub->url({ species => $member_species, type => 'Gene', action => 'Summary', g => $gene->stable_id, r => undef }),
              $gene->stable_id
            ),
            sprintf('<a href="%s%s">%s</a>',
              $site,
              $hub->url({ species => $member_species, type => 'Transcript', action => 'ProteinSummary', peptide => $peptide->stable_id, __clear => 1 }),
              $peptide->stable_id
            ),
            sprintf('%d %s', $peptide->seq_length, $unit),
            sprintf('%d %%', $peptide->perc_id),
            sprintf('%d %%', $peptide->perc_cov),
            sprintf('<a href="%s%s">%s</a>',
              $site,
              $hub->url({ species => $member_species, type => 'Location', action => 'View', g => $gene->stable_id, r => $location, t => undef }),
              $location
            )
          ];
        }
      }
     
      next unless $flag;
 
      my $homology_desc_mapped = $Bio::EnsEMBL::Compara::Homology::PLAIN_TEXT_DESCRIPTIONS{$homology->{'_description'}} || $homology->{'_description'} || 'no description';

      $html .= "<h2>Type: $homology_desc_mapped</h2>";
      
      my $ss = $self->new_table([
          { title => 'Species',          width => '20%' },
          { title => 'Gene ID',          width => '15%' },
          { title => "$gene_product ID",       width => '15%' },
          { title => "$gene_product length",   width => '10%' },
          { title => $identity_title,    width => '10%' },
          { title => '% coverage',       width => '10%' },
          { title => 'Genomic location', width => '20%' }
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

sub get_homologies {
  my $self         = shift;
  my $hub          = $self->hub;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $object       = $self->object || $hub->core_object('gene');
  my $gene_id      = $object->stable_id;

  my $database     = $hub->database($cdb);
  my $args         = {'stable_id' => $gene_id, 'cdb' => $cdb};
  my $qm           = $self->object->get_compara_Member($args);
  my $homologies;
  my $ok_homologies = [];
  my $action        = $hub->param('data_action') || $hub->action;
  my $homology_method_link = 'ENSEMBL_PARALOGUES';
  if ( $action =~ /Compara_Ortholog/ ) { $homology_method_link='ENSEMBL_ORTHOLOGUES'; }
  elsif ( $action =~ /Compara_Homoeolog/ ) { $homology_method_link='ENSEMBL_HOMOEOLOGUES'; }
  
  eval {
    $homologies = $database->get_HomologyAdaptor->fetch_all_by_Member($qm, -METHOD_LINK_TYPE => $homology_method_link);
  };
  warn $@ if $@;
 
  return $homologies;
}

sub renderer_type {
  my $self = shift;
  my $K    = shift;
  my %T    = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
  return $T{$K} ? $K : EnsEMBL::Web::Constants::SIMPLEALIGN_DEFAULT;
}

sub export_options { return {'action' => 'Homologs'}; }

sub get_export_data {
## Get data for export
  my ($self, $type) = @_;
  my $hub = $self->hub;

  ## Fetch explicitly, as we're probably coming from a DataExport URL
  my $homologies = $self->get_homologies;
  my $second_gene   = $hub->param('g1');
  my $data          = [];

  HOMOLOGY:
  foreach my $homology (@{$homologies}) {

    if ($type && $type eq 'genetree') {
      my $cdb = $hub->param('cdb') || 'compara';
      foreach my $homology (@{$homologies}) {
        foreach my $peptide (@{$homology->get_all_Members}) {
          next unless $peptide->gene_member->stable_id eq $second_gene;
          push @$data, $homology; 
          last HOMOLOGY;
        }
      }
    }
    else { ## ...or get alignment
      my $seq = $hub->param('align');
      my $sa;
    
      eval {
        if($seq eq 'cDNA') {
          $sa = $homology->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1, -SEQ_TYPE => 'cds');
        } else {
          $sa = $homology->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1);
        }
      };
      warn $@ if $@;

      if ($sa) {
        foreach my $peptide (@{$homology->get_all_Members}) {
          my $gene = $peptide->gene_member;
          if (!$second_gene || $second_gene eq $gene->stable_id) {
            push @$data, $sa;
            last HOMOLOGY if $second_gene;
          }
        }
      }
    }
  }
  return $data;
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;
  my $gene    =  $self->object->Obj;

  my $dxr  = $gene->can('display_xref') ? $gene->display_xref : undef;
  my $name = $dxr ? $dxr->display_id : $gene->stable_id;

  my $params  = {
                  'type'        => 'DataExport', 
                  'action'      => 'Homologs', 
                  'data_type'   => 'Gene', 
                  'component'   => 'HomologAlignment', 
                  'data_action' => $hub->action,
                  'gene_name'   => $name, 
                  'align'       => $hub->param('seq') || 'protein',
                  'g1'          => $hub->param('g1'),
                  'hom_id'      => $hub->param('hom_id'),
                  'cdb'         => $hub->function =~ /pan_compara/ ? 'compara_pan_ensembl' : 'compara',
                };

  return {
    'url'     => $hub->url($params),
    'caption' => 'Download homology',
    'class'   => 'export',
    'modal'   => 1
  };
}


1;

