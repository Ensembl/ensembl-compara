package EnsEMBL::Web::Component::Location::ChromosomeStats;

### Module to replace part of the former MapView, in this case 
### displaying the stats for an individual chromosome 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable( 0 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;

  my $chr_name = $object->seq_region_name;
  my $label = "Chromosome $chr_name";

  my @orderlist = (
    'Length (bps)',
    'known protein_coding Gene Count',
    'novel protein_coding Gene Count',
    'pseudogene Gene Count',
    'miRNA Gene Count',
    'ncRNA Gene Count',
    'rRNA Gene Count',
    'snRNA Gene Count',
    'snoRNA Gene Count',
    'tRNA Gene Count',
    'misc_RNA Gene Count',
    'SNP Count',
    'Number of fingerprint contigs',
    'Number of clones selected for sequencing',
    'Number of clones sent for sequencing',
    'Number of accessioned sequence clones',
    'Number of finished sequence clones',
    'Total number of sequencing clones',
    'Raw percentage of map covered by sequence clones',
  );
  my $html = qq(
<h3>Chromosome Statistics</h3>
<table class="ss tint">);
  my ($stats, %chr_stats, $bg);
  my $chr = $object->Obj->{'slice'};
  foreach my $attrib (@{$chr->get_all_Attributes}) {
    $chr_stats{$attrib->name} += $attrib->value;
  }
  $chr_stats{'Length (bps)'} = ($object->seq_region_name eq 'ALL') ? $chr->max_chr_length : $chr->seq_region_length ;

  for my $stat (@orderlist){
    my $value = $object->thousandify( $chr_stats{$stat} );
    next if !$value;
    $stat = 'Estimated length (bps)' if $stat eq 'Length (bps)' && $object->species_defs->NO_SEQUENCE;
    $stat =~ s/Raw p/P/;
    $stat =~ s/protein_coding/Protein-coding/;
    $stat =~ s/_/ /g;
    $stat =~ s/ Count$/s/;
    $stat = ucfirst($stat) unless $stat =~ /^[a-z]+RNA/;
  
    $bg = $stats % 2 != 0 ? 'bg1' : 'bg2';
    $html .= qq(<tr class="$bg"><td><strong>$stat:</strong></td>
                <td style="text-align:right">$value</td>
                </tr>);
    $stats++;
  }
  unless ($stats) {
    $html .= qq(<tr><td><strong>Could not load chromosome stats</strong><td></tr>);
  }
  $html .= qq(  </table>
  );

  return $html;
}

1;
