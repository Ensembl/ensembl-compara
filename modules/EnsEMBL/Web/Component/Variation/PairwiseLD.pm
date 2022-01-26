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

package EnsEMBL::Web::Component::Variation::PairwiseLD;

use strict;
use HTML::Entities qw(encode_entities);
use POSIX qw(floor);
use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $variant = $object->Obj;
  my $variant_name = $variant->name;
  my $example_variant = ($variant_name eq 'rs678') ? 'rs549570' : 'rs678';
  my $hub    = $self->hub;
  
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;  

  my $url = $self->ajax_url('results', { second_variant_name => undef });  
  my $id  = $self->id;  
  my $second_variant_name = '';
  return sprintf('
    <h2>Pairwise linkage disequilibrium data by population</h2>
    <div class="navbar print_hide" style="padding-left:5px">
      <input type="hidden" class="panel_type" value="Content" />
      <form class="update_panel" action="#">
        <label for="variant">Focus variant: %s</label><br>
        <label for="variant">Enter the name for the second variant:</label>
        <input type="text" name="second_variant_name" id="variant" value="%s" size="30"/>
        <input type="hidden" name="panel_id" value="%s" />
        <input type="hidden" name="url" value="%s" />
        <input type="hidden" name="element" value=".results" />
        <input class="fbutton" type="submit" value="Compute" />
        <small>(e.g. %s)</small>
      </form>
    </div>
    <div class="results">%s</div>
  ', $variant_name, $second_variant_name, $id, $url, $example_variant, $self->content_results);

}

sub content_results {
  my $self         = shift;
  my $object       = $self->object;
  my $variant      = $object->Obj;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $glossary = $hub->glossary_lookup;
  my $tables_with_no_rows = 0;
  my $table               = $self->new_table([
    { key => 'Population', title => 'Population', sort => 'html', align => 'left' },    
    { key => 'Description', title => 'Description', sort => 'string', align => 'left' },
    { key => 'Variant1', title => 'Focus Variant', sort => 'string' },
    { key => 'Variant2', title => 'Variant 2', sort => 'string' },
    { key => 'LocationVariant2', title => 'Variant 2 Location', sort => 'string' },
    { key => 'r2', title => 'r<sup>2</sup>', sort => 'numeric', align => 'center', help => $glossary->{'r2'} },
    { key => 'd_prime', title => q{D'}, sort => 'numeric', align => 'center',  help => $glossary->{"D'"} },
  ], [], { data_table => 1, download_table => 1, sorting => [ 'd_prime desc' ] } );

  my @colour_gradient = ('ffffff', $hub->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red'));

  my $focus_variant_name  = $variant->name;
  my $second_variant_name = $hub->param('second_variant_name');

  return unless $second_variant_name;
  $second_variant_name =~ s/^\W+//;
  $second_variant_name =~ s/\s+$//;

  # set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE     = $species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $species_defs->ENSEMBL_LD_VCF_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $species_defs->ENSEMBL_TMP_TMP;

  my $ldfca = $variant->adaptor->db->get_LDFeatureContainerAdaptor;
  my $va = $variant->adaptor->db->get_VariationAdaptor;
  my $pa = $variant->adaptor->db->get_PopulationAdaptor;

  my $second_variant = $va->fetch_by_name($second_variant_name);

  if (!$second_variant) {
    my $html = $self->_warning('No variant object', qq{Could not fetch variant object for <b>$second_variant_name</b>});
    return qq{<div class="js_panel">$html</div>};
  }

  my ($vf, $loc) = (
    $object->get_selected_variation_feature,
    $object->selected_variation_feature_mapping
  );

  my $seq_region_name = $vf->seq_region_name;
  my @vfs2 = grep { $_->slice->is_reference } @{$second_variant->get_all_VariationFeatures};
  my @vfs = ($vf);
  foreach my $vf2 (@vfs2) {
    my $seq_region_name2 = $vf2->seq_region_name;
    if ($seq_region_name ne $seq_region_name2) {
      my $html = $self->_warning('No Pairwise Linkage Disequilibrium Data', qq{Could not compute LD data because variants <b>$focus_variant_name</b> and <b>$second_variant_name</b> are on different chromosomes.});
      return qq{<div class="js_panel">$html</div>};
    }   
    push @vfs, $vf2;
  }  

  my @ld_populations = @{$pa->fetch_all_LD_Populations};
  my $rows = [];

  foreach my $ld_population (@ld_populations) {
    my $description = $ld_population->description;
    $description ||= '-';

    if (length $description > 30) {
      my $full_desc = $self->strip_HTML($description);
      while ($description =~ m/^.{30}.*?(\s|\,|\.)/g) {
        $description = sprintf '%s... <span class="_ht ht small" title="%s">(more)</span>', substr($description, 0, (pos $description) - 1), $full_desc;
        last;
      }
    }
    my $pop_name  = $ld_population->name;
    my $pop_dbSNP = $ld_population->get_all_synonyms('dbSNP');

    my $pop_label = $pop_name;
    if ($pop_label =~ /^.+\:.+$/ and $pop_label !~ /(http|https):/) {
      my @composed_name = split(':', $pop_label);
      $composed_name[$#composed_name] = '<b>'.$composed_name[$#composed_name].'</b>';
      $pop_label = join(':',@composed_name);
    }

    # Population external links
    my $pop_url = $self->pop_link($pop_name, $pop_dbSNP, $pop_label);

    my @ld_values = @{$ldfca->fetch_by_VariationFeatures(\@vfs, $ld_population)->get_all_ld_values()};  
    foreach my $hash (@ld_values) {
      my $vf1 = $hash->{'variation1'};
      my $vf2 = $hash->{'variation2'};
      my $variation1 = $hash->{variation_name1};
      my $variation2 = $hash->{variation_name2};
      next unless ($variation1 eq $focus_variant_name || $variation2 eq $focus_variant_name);
      next unless ($variation1 eq $second_variant_name || $variation2 eq $second_variant_name);
      if ($variation1 ne $focus_variant_name) {
        ($variation1, $variation2) = ($variation2, $variation1);
        ($vf1, $vf2) = ($vf2, $vf1);
      }
      my $var_url = $hub->url({
        type   => 'Variation',
        action => 'Explore',
        vdb    => 'variation',
        v      => $second_variant_name,
        vf     => $vf2->dbID,
      });
      # switch start and end to avoid faff
      my ($start, $end) = ($vf2->seq_region_start, $vf2->seq_region_end);
         ($start, $end) = ($end, $start) if $start > $end;
      my $loc_url = $hub->url({
        type   => 'Location',
        action => 'View',
        db     => 'core',
        v      => $second_variant_name,
        vf     => $vf2->dbID,
      });
      my $r2 = $hash->{r2};
      my $d_prime = $hash->{d_prime};
      my $population_id = $hash->{population_id};
      $table->add_row({
        Variant1 => $variation1, 
        Variant2 => qq{<a href="$var_url">$variation2</a>},,
        LocationVariant2 => sprintf('<a href="%s">%s:%s</a>', $loc_url, $vf2->seq_region_name, $start == $end ? $start : "$start-$end"),
        Population => $pop_url,
        Description => $description, 
        r2 => {
          value => $r2,
          style => "background-color:#".($r2 eq '-' ? 'ffffff' : $colour_gradient[floor($r2*40)]),
        },
        d_prime => {
          value => $d_prime,
          style => "background-color:#".($d_prime eq '-' ? 'ffffff' : $colour_gradient[floor($d_prime*40)]),
        },
      });
    } 
  }
     
  my $html = '<div style="margin:0px 0px 25px;padding:0px">'.$table->render.'</div>';
  my $no_results_html = $self->_warning('No Pairwise Linkage Disequilibrium Data', qq{
      <p>A variant may have no LD data in a given population for the following reasons:</p>
      <ul>
        <li>Variant $second_variant_name has a minor allele frequency close or equal to 0</li>
        <li>Variant $second_variant_name does not have enough genotypes to calculate LD values</li>
        <li>Estimated r<sup>2</sup> values are below 0.05 and have been filtered out</li>
      </ul>
    });
  return $table->has_rows ? qq{<div class="js_panel">$html</div>} : qq{<div class="js_panel">$no_results_html</div>};
}

1;
