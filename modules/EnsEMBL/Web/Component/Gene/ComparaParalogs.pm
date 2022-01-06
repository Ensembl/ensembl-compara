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

package EnsEMBL::Web::Component::Gene::ComparaParalogs;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::FormatText qw(helptip glossary_helptip);

use base qw(EnsEMBL::Web::Component::Gene);

our %button_set = ('download' => 1, 'view' => 0);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $availability   = $self->object->availability;
  my $cdb            = shift || $hub->param('cdb') || 'compara';
  my $is_ncrna       = ($self->object->Obj->biotype =~ /RNA/);
  my %paralogue_list = %{$self->object->get_homology_matches('ENSEMBL_PARALOGUES', 'paralog|gene_split', undef, $cdb)};

  return '<p>No paralogues have been identified for this gene</p>' unless keys %paralogue_list;

  my %paralogue_map       = qw(SEED BRH PIP RHS);
  my %cached_lca_desc     = ();
  my $alignview           = 0;
  my $lookup              = { 'Paralogues (same species)' => 'Within species paralogues (within species paralogs)' };

  my $columns = [
    { key => 'Type',                align => 'left', width => '10%', sort => 'html'          },
    { key => 'Ancestral taxonomy',  align => 'left', width => '10%', sort => 'html'          },
    { key => 'identifier',          align => 'left', width => '15%', sort => 'html', title => $self->html_format ? 'Ensembl identifier &amp; gene name' : 'Ensembl identifier'},    
    { key => 'Compare',             align => 'left', width => '10%', sort => 'none'          },
    { key => 'Location',            align => 'left', width => '20%', sort => 'position_html' },
    { key => 'Target %id',          align => 'left', width => '5%',  sort => 'numeric', help => "Percentage of the paralogous sequence matching the query sequence" },
    { key => 'Query %id',           align => 'left', width => '5%',  sort => 'numeric', help => "Percentage of the query sequence matching the sequence of the paralogue" },
  ];
  
  my @rows;
 
  my $lookup = $hub->species_defs->prodnames_to_urls_lookup; 
  foreach my $species (sort keys %paralogue_list) {
    foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}) {
      my $paralogue = $paralogue_list{$species}{$stable_id};
      
      my $description = encode_entities($paralogue->{'description'});
         $description = 'No description' if $description eq 'NULL';
      
      if ($description =~ s/\[\w+:([-\w\/]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description .= '[' . $hub->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc). ']' if $acc;
      }
      
      my @external = (qq{<span class="small">$description</span>});
      unshift @external, $paralogue->{'display_id'} if $paralogue->{'display_id'};
      my $paralogue_desc              = $paralogue_map{$paralogue->{'homology_desc'}} || $paralogue->{'homology_desc'};
      my $paralogue_dnds_ratio        = $paralogue->{'homology_dnds_ratio'}           || '&nbsp;';
      my $species_tree_node           = $paralogue->{'species_tree_node'};
      my $spp = $paralogue->{'spp'};
      
      my $link_url = $hub->url({
        action => 'Summary',
        g => $stable_id,
        r => undef
      });
      
      my $location_link = $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $paralogue->{'location'},
        g      => $stable_id
      });
      
      # Need to have one white space character after the anchor tag to make sure there will be a space between the stable ID and gene symbol in the generated CSV file (for download)
      my $id_info = qq{<p class="space-below"><a href="$link_url">$stable_id</a>&nbsp;</p>} . join '<br />', @external;

      my @seq_region_split_array = split(/:/, $paralogue->{'location'});
      my $paralogue_seq_region = $seq_region_split_array[0];

      my $links = ($availability->{'has_pairwise_alignments'}) ?
        sprintf (
        '<ul class="compact"><li class="first"><a href="%s" class="notext">Region Comparison</a></li>',
        $hub->url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp . '--' . $paralogue_seq_region,
          r      => undef,
          config => 'opt_join_genes_bottom=on',
        })
      ) : '';
      
      my ($target, $query);
      
      if ($paralogue_desc ne 'DWGA') {          
        my $align_url = $hub->url({
            action   => 'Compara_Paralog', 
            function => "Alignment". ($cdb=~/pan/ ? '_pan_compara' : ''),, 
            hom_id   => $paralogue->{'dbID'},
            g1       => $stable_id
        });

        if ($is_ncrna) {
          $links .= sprintf '<li><a href="%s" class="notext">Alignment</a></li>', $align_url;
        } else {
          $links .= sprintf '<li><a href="%s" class="notext">Alignment (protein)</a></li>', $align_url;
          $links .= sprintf '<li><a href="%s" class="notext">Alignment (cDNA)</a></li>', $align_url.';seq=cDNA';
        }
        
        ($target, $query) = ($paralogue->{'target_perc_id'}, $paralogue->{'query_perc_id'});
        $alignview = 1;
      }

      $links .= '</ul>';

      my $ancestral_taxonomy;
      my $lca_desc;
      if (not $species_tree_node) {
        $ancestral_taxonomy = '&nbsp;';
        # nothing to do
      } elsif (exists $cached_lca_desc{$species_tree_node->node_id}) {
        ($ancestral_taxonomy, $lca_desc) = @{$cached_lca_desc{$species_tree_node->node_id}};
      } elsif ($species_tree_node->is_leaf) {
        $ancestral_taxonomy = $hub->species_defs->species_label($lookup->{$species_tree_node->genome_db->name});
      } else {
        $ancestral_taxonomy = species_tree_node_label($species_tree_node);
        my ($c0, $c1) = @{$species_tree_node->children()};
        my $other_side = scalar(@{$c0->find_leaves_by_field('genome_db_id', $paralogue->{'homologue'}->genome_db_id)}) ? $c1 : $c0;
        $lca_desc = "Last common ancestor with " . species_tree_node_label($other_side);
        $cached_lca_desc{$species_tree_node->node_id} = [$ancestral_taxonomy, $lca_desc];
      }
      
      push @rows, {
        'Type'                => glossary_helptip($hub, ucfirst $paralogue_desc, $lookup->{ucfirst $paralogue_desc}),
        'Ancestral taxonomy'  => helptip($ancestral_taxonomy, $lca_desc),
        'identifier'          => $self->html_format ? $id_info : $stable_id,
        'Compare'             => $self->html_format ? qq(<span class="small">$links</span>) : '',
        'Location'            => qq(<a href="$location_link">$paralogue->{'location'}</a>),
        'Target %id'          => sprintf('%.2f&nbsp;%%', $target),
        'Query %id'           => sprintf('%.2f&nbsp;%%', $query),
      };
    }
  }
  
  my $table = $self->new_table($columns, \@rows, { data_table => 1 });
  my $html;
  
  if ($alignview && keys %paralogue_list) {
    $button_set{'view'} = 1;
  }
 
  $html .= $table->render;
 
  return $html;
}

sub export_options { return {'action' => 'Paralogs'}; }

sub get_export_data {
## Get data for export
  my ($self, $flag) = @_;
  my $hub          = $self->hub;
  my $object       = $self->object || $hub->core_object('gene');

  if ($flag eq 'sequence') {
    return $object->get_homologue_alignments('compara', 'ENSEMBL_PARALOGUES');
  }
  else {
    my $cdb = $flag || $hub->param('cdb') || 'compara';
    my ($homologies) = $object->get_homologies('ENSEMBL_PARALOGUES', 'paralog|gene_split', undef, $cdb);
    return $homologies;
  }
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;
  my @buttons;

  if ($button_set{'download'}) {

    my $gene    =  $self->object->Obj;

    my $dxr  = $gene->can('display_xref') ? $gene->display_xref : undef;
    my $name = $dxr ? $dxr->display_id : $gene->stable_id;

    my $params  = {
                  'type'        => 'DataExport',
                  'action'      => 'Paralogs',
                  'data_type'   => 'Gene',
                  'component'   => 'ComparaParalogs',
                  'data_action' => $hub->action,
                  'gene_name'   => $name,
                };

    ## Add any species settings
    my $compara_spp = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'COMPARA_SPECIES'};
    foreach (grep { /^species_/ } $hub->param) {
      (my $key = $_) =~ s/species_//;
      next unless $compara_spp->{$key};
      $params->{$_} = $hub->param($_);
    }

    push @buttons, {
                    'url'     => $hub->url($params),
                    'caption' => 'Download paralogues',
                    'class'   => 'export',
                    'modal'   => 1
                    };
  }

  return @buttons;
}


# Helper functions

sub species_tree_node_label {
    my $species_tree_node = shift;
    my $taxon_alias = $species_tree_node->get_common_name();
    my $scientific_name = $species_tree_node->get_scientific_name();
    if ($taxon_alias) {
        return sprintf('%s (%s)', $taxon_alias, $scientific_name);
    } else {
        return $scientific_name;
    }
}

1;

