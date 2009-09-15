package EnsEMBL::Web::Component::Gene::ComparaParalogs;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my %paralogue_list = %{$object->get_homology_matches('ENSEMBL_PARALOGUES', 'paralog|gene_split', 'between_species_paralog')};
  
  return '<p>No paralogues have been identified for this gene</p>' unless keys %paralogue_list;
  
  my %paralogue_map = qw(SEED BRH PIP RHS);
  my $alignview = 0;
  
  my $html = '
    <p>The following gene(s) have been identified as putative paralogues (within species):</p>
    <table>
      <tr>
        <th>Taxonomy Level</th><th>Gene identifier</th>
      </tr>';
  
  foreach my $species (sort keys %paralogue_list) {
    foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}) {
      my $paralogue = $paralogue_list{$species}{$stable_id};
      
      my $description = $paralogue->{'description'};
         $description = 'No description' if $description eq 'NULL';
         
      my $paralogue_desc = $paralogue_map{$paralogue->{'homology_desc'}} || $paralogue->{'homology_desc'};
      my $paralogue_subtype = $paralogue->{'homology_subtype'} || '&nbsp;';
      my $paralogue_dnds_ratio = $paralogue->{'homology_dnds_ratio'} || '&nbsp;';
      (my $spp = $paralogue->{'spp'}) =~ tr/ /_/;
      
      my $link = $object->_url({
        g => $stable_id,
        r => undef
      });
      
      my $extra = sprintf (
        '<span class="small">[<a href="%s">Multi-species comp.</a>]</span> ',
        $object->_url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp
        })
      );
      
      my $extra2;
      
      if ($paralogue_desc ne 'DWGA') {          
        $extra .= sprintf(
          '<span class="small">[<a href="%s">Align</a>]</span>', 
          $object->_url({
            action   => 'Compara_Paralog', 
            function => 'Alignment', 
            g1       => $stable_id
          })
        );
        
        $extra2 = qq{<br /><span class="small">[Target %id: $paralogue->{'target_perc_id'}; Query %id: $paralogue->{'query_perc_id'}]</span>};
        $alignview = 1;
      }
      
      if ($description =~ s/\[\w+:([-\w\/]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description .= '[' . $object->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc). ']' if $acc;
      }
      
      $html .= qq{
        <tr>
          <td>$paralogue_subtype<br>$paralogue_desc</td>
          <td>
            <a href="$link">$stable_id</a> ($paralogue->{'display_id'}) $extra<br />
            <span class="small">$description</span>$extra2
          </td>
        </tr>
      };
    }
  }
  
  $html .= '</table>';
  
  if ($alignview && keys %paralogue_list) {
    $html .= sprintf(
      '<p><a href="%s">View sequence alignments of all homologues</a>.</p>', 
      $object->_url({ action => 'Compara_Paralog', function => 'Alignment' })
    );
  }
  
  return $html;
}

1;

