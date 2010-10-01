# $Id$

package EnsEMBL::Web::Component::Gene::ComparaParalogs;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

use EnsEMBL::Web::Document::SpreadSheet;

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $cdb            = shift || $hub->param('cdb') || 'compara';
  my %paralogue_list = %{$self->object->get_homology_matches('ENSEMBL_PARALOGUES', 'paralog|gene_split', 'possible_ortholog', $cdb)};
  
  return '<p>No paralogues have been identified for this gene</p>' unless keys %paralogue_list;
  
  my %paralogue_map = qw(SEED BRH PIP RHS);
  my $alignview     = 0;
  
  my $columns = [
    { key => 'Taxonomy Level',  align => 'left', width => '10%', sort => 'html'          },
    { key => 'Type',            align => 'left', width => '10%', sort => 'string'        },
    { key => 'Gene identifier', align => 'left', width => '20%', sort => 'html'          },
    { key => 'Location',        align => 'left', width => '20%', sort => 'position_html' },
    { key => 'Target %id',      align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'Query %id',       align => 'left', width => '5%',  sort => 'numeric'       },
    { key => 'External ref.',   align => 'left', width => '30%', sort => 'none'          }
  ];
  
  my @rows;
  
  foreach my $species (sort keys %paralogue_list) {
    foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}) {
      my $paralogue = $paralogue_list{$species}{$stable_id};
      
      my $description = $paralogue->{'description'};
         $description = 'No description' if $description eq 'NULL';
         
      my $paralogue_desc              = $paralogue_map{$paralogue->{'homology_desc'}} || $paralogue->{'homology_desc'};
      my $paralogue_subtype           = $paralogue->{'homology_subtype'}              || '&nbsp;';
      my $paralogue_dnds_ratio        = $paralogue->{'homology_dnds_ratio'}           || '&nbsp;';
      (my $spp = $paralogue->{'spp'}) =~ tr/ /_/;
      
      my $link = $hub->url({
        g => $stable_id,
        r => undef
      });
      
      my $location_link = $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $paralogue->{'location'},
        g      => $stable_id
      });
      
      my $links = sprintf (
        '<a href="%s">Multi-location view</a>',
        $hub->url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => undef
        })
      );
      
      my ($target, $query);
      
      if ($paralogue_desc ne 'DWGA') {          
        $links .= sprintf(
          '<br /><a href="%s">Alignment</a>', 
          $hub->url({
            action   => 'Compara_Paralog', 
            function => 'Alignment', 
            g1       => $stable_id
          })
        );
        
        ($target, $query) = ($paralogue->{'target_perc_id'}, $paralogue->{'query_perc_id'});
        $alignview = 1;
      }
      
      if ($description =~ s/\[\w+:([-\w\/]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description .= '[' . $hub->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc). ']' if $acc;
      }
      
      my @external = qq{<span class="small">$description</span>};
      unshift @external, $paralogue->{'display_id'} if $paralogue->{'display_id'};
      
      push @rows, {
        'Taxonomy Level'  => $paralogue_subtype,
        'Type'            => ucfirst $paralogue_desc,
        'Gene identifier' => qq{<a href="$link">$stable_id</a><br /><span class="small">$links</span>},
        'Location'        => qq{<a href="$location_link">$paralogue->{'location'}</a>},
        'Target %id'      => $target,
        'Query %id'       => $query,
        'External ref.'   => join('<br />', @external)
      };
    }
  }
  
  my $table = new EnsEMBL::Web::Document::SpreadSheet($columns, \@rows, { data_table => 1 });
  my $html  = '<p>The following gene(s) have been identified as putative paralogues (within species):</p>' . $table->render;
  
  if ($alignview && keys %paralogue_list) {
    $html .= sprintf(
      '<p><a href="%s">View sequence alignments of all homologues</a>.</p>', 
      $hub->url({ action => 'Compara_Paralog', function => 'Alignment' })
    );
  }
  
  return $html;
}

1;

