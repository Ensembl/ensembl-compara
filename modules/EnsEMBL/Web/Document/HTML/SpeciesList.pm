=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self          = shift;
  my $fragment      = shift eq 'fragment';
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $species_info  = $hub->get_species_info;
  my $labels        = $species_defs->TAXON_LABEL; ## sort out labels
  my $favourites    = $hub->get_favourite_species;
  my (@group_order, %label_check);
  
  my $html_before = '<div class="static_all_species clear">
  <form action="#">
    <h3>All genomes</h3>
    <p>';
  my $html = '
    <select name="species" class="dropdown_redirect">
      <option value="/">-- Select a species --</option>
  ';
  
  if (scalar @$favourites) {
    $html .= qq{<optgroup label="Favourite species">\n};
    foreach (@$favourites) {
      my $info = $species_info->{$_};
      my $name = $info->{'common'};
      my $url  = $info->{'key'}.'/Info/Index';
      if ($info->{'key'} eq 'Homo_sapiens' && $species_defs->SWITCH_ASSEMBLY) {
        ## Current assembly
        $name .= ' '.$species_defs->ASSEMBLY_VERSION;
        $html .= sprintf qq{<option value="%s">%s</option>\n}, encode_entities($url), encode_entities($name);
        ## Alternative assembly
        $url   = 'http://'.$species_defs->SWITCH_ARCHIVE_URL.'/'.$url;
        $name = $info->{'common'}.' '.$species_defs->SWITCH_ASSEMBLY;
      }
      $html .= sprintf qq{<option value="%s">%s</option>\n}, encode_entities($url), encode_entities($name);
    }
    $html .= "</optgroup>\n";
  }
  
  foreach my $taxon (@{$species_defs->TAXON_ORDER || []}) {
    my $label = $labels->{$taxon} || $taxon;
    push @group_order, $label unless $label_check{$label}++;
  }

  ## Sort species into desired groups
  my %phylo_tree;
  my %has_strains;
  
  foreach (values %$species_info) {
    ## Omit individual non-reference strains, but record number of strains
    if ($_->{'strain_collection'} && $_->{'strain'} !~ /reference/) {
      $has_strains{$_->{'strain_collection'}}++;
      next;
    }
    my $group = $_->{'group'} ? $labels->{$_->{'group'}} || $_->{'group'} : 'no_group';
    push @{$phylo_tree{$group}}, $_;
  }  

  ## Output in taxonomic groups, ordered by common name  
  foreach my $group_name (@group_order) {
    my $optgroup     = 0;
    my $species_list = $phylo_tree{$group_name};
    my @sorted_by_common;
    
    if ($species_list && ref $species_list eq 'ARRAY' && scalar @$species_list) {
      if ($group_name eq 'no_group') {
        if (scalar @group_order) {
          $html    .= qq{<optgroup label="Other species">\n};
          $optgroup = 1;
        }
      } else {
        $html    .= sprintf qq{<optgroup label="%s">\n}, encode_entities($group_name);
        $optgroup = 1;
      }
      
      @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} } @$species_list;
    }
   
    for (@sorted_by_common) {
      $html .= sprintf qq{<option value="%s/Info/Index">%s</option>\n}, encode_entities($_->{'key'}), encode_entities($_->{'common'});
      my $strain_count = $has_strains{$_->{'strain_collection'}};
      if ($strain_count) {
        my $strain_text = 'strain';
        $strain_text .= 's' if $strain_count > 1;
        $html .= sprintf qq{<option value="%s/Info/Strains">%s %s (%s)</option>\n}, 
                      encode_entities($_->{'key'}), encode_entities($_->{'common'}), 
                      $strain_text, $strain_count;
      }
    }

 
    
    if ($optgroup) {
      $html    .= "</optgroup>\n";
      $optgroup = 0;
    }
  }
  $html .= "</select>";

  my $html_after .= qq{
      </p>
    </form>
    <p><a href="/info/about/species.html">View full list of all $sitename species</a></p>
    </div>
  };
  
  $html = $html_before.$html.$html_after unless $fragment;
  
  return $html;
}

1;
