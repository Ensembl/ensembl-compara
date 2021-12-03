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

package EnsEMBL::Web::Component::Location::NavigateHomology;

### Module to replace part of the former SyntenyView, in this case 
### the 'navigate homology' links

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $object         = $self->object;
  my $chromosome     = $object->chromosome;
  my $chromosome_end = $chromosome->end;
  my $start          = $object->seq_region_start;
  my $end            = $object->seq_region_end;
  my $img_url        = $self->img_url.'16/';

  ## Don't show this component if the slice covers or exceeds the whole chromosome!
  return if $chromosome->length < 1e6 || ($hub->param('r') =~ /:/ && $start < 2 && $end > ($chromosome_end - 1));
  
  my $other_species  = $hub->otherspecies;
  my $max_len        = $end < 1e6 ? $end : 1e6;
  my $seq_region_end = $hub->param('r') =~ /:/ ? $object->seq_region_end : $max_len;
  my $chr            = $object->seq_region_name; 

  ## Check we have a chromosome-like assembly 
  my $coordAdaptor   = $hub->get_adaptor('get_CoordSystemAdaptor');
  my %coord_system   = map {$_->name => $_->name} @{$coordAdaptor->fetch_all};
  my $cs_type        = $coord_system{'chromosome'} || $coord_system{'group'} || $coord_system{'primary_assembly'};;
  return unless $cs_type;

  my $sliceAdaptor   = $hub->get_adaptor('get_SliceAdaptor');
  my $max_index      = 15;
  my $upstream       = $sliceAdaptor->fetch_by_region($cs_type, $chr, 1, $start - 1 );
  my $downstream     = $sliceAdaptor->fetch_by_region($cs_type, $chr, $seq_region_end + 1, $chromosome_end );
  my @up_genes       = $upstream ?   reverse @{$object->get_synteny_local_genes($upstream)} : ();
  my @down_genes     = $downstream ? @{$object->get_synteny_local_genes($downstream)}       : ();
  my $up_count       = @up_genes;
  my $down_count     = @down_genes;
  my ($up_link, $down_link, $gene_text);
  
  if ($up_count) {
    my @up_sample;
    
    for (my $i = 0; $i < $max_index; $i++) {
      next if !$up_genes[$i];
      push @up_sample, $up_genes[$i];
    }
    
    $up_count  = @up_sample;
    $gene_text = $up_count > 1 ? 'genes' : 'gene';
    
    my $up_start  = @up_sample ? $up_sample[-1]->start  : 0;
    my $up_end    = @up_sample ? $up_sample[0]->end : 0;

    $up_link = sprintf('
      <a href="%s" class="constant"><img src="%sback2.png" alt="&lt;&lt;" style="vertical-align:middle" /> %s upstream %s</a>',
      $hub->url({ type => 'Location', action => 'Synteny', otherspecies => $other_species, r => "$chr:$up_start-$up_end" }), $img_url, $up_count, $gene_text
    );
  } else {
    $up_link = 'No upstream homologues';
  }
  
  if ($down_count) {
    my @down_sample;
    
    for (my $j = 0; $j < $max_index; $j++) {
      next if !$down_genes[$j];
      push @down_sample, $down_genes[$j];
    }
    
    $down_count = @down_sample;
    $gene_text  = $down_count > 1 ? 'genes' : 'gene';
    
    my $down_start = @down_sample ? $down_sample[0]->start + $seq_region_end : 0;
    $down_start    = -$down_start if $down_start < 0;
    my $down_end   = @down_sample ? $down_sample[-1]->end + $seq_region_end : 0;
 
    $down_link = sprintf('
      <a href="%s" class="constant">%s downstream %s <img src="%sforward2.png" alt="&gt; &gt;" style="vertical-align:middle" /></a>',
      $hub->url({ type => 'Location', action => 'Synteny', otherspecies => $other_species, r => "$chr:$down_start-$down_end" }), $down_count, $gene_text, $img_url
    );
  } else {
    $down_link = 'No downstream homologues';
  }

  my $centre_content = 'Navigate homology';
  if ($hub->param('g')) {
    my $gene = $hub->core_object('gene');
    my $padding = 1000000;
    my $start = $gene->seq_region_start - $padding > 0 ? $gene->seq_region_start - $padding : 0;
    my $end   = $gene->seq_region_end   + $padding < $chromosome_end 
                  ? $gene->seq_region_end + $padding : $chromosome_end;
    my $gene_neighbourhood = sprintf('%s:%d-%d', $chr, $start, $end);

    $centre_content = sprintf('<a href="%s" class="constant">%s</a>', $hub->url({ type => 'Location', action => 'Synteny', otherspecies => $other_species, r => $gene_neighbourhood }), 'Centre on gene '.$gene->Obj->external_name);
  }

  return qq{
    <div class="navbar clear">
      <table class="homology" style="width:100%">
        <tr>
          <td class="left" style="padding:0px 2em; vertical-align:middle;">$up_link</td>
          <td class="center" style="padding:0px 2em; vertical-align:middle">$centre_content</td>
          <td class="right" style="padding:0px 2em; vertical-align:middle;">$down_link</td>
        </tr>
      </table>
    </div>
  } if($self->html_format);
}

1;
