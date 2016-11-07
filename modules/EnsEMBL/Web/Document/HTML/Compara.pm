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

package EnsEMBL::Web::Document::HTML::Compara;

## Provides content for compara documeentation - see /info/genome/compara/analyses.html
## Base class - does not itself output content

use strict;

use Math::Round;
use EnsEMBL::Web::Document::Table;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use base qw(EnsEMBL::Web::Document::HTML);

sub sci_name {
  my ($self, $name) = @_;
  $name = $self->hub->species_defs->production_name_mapping($name);
  return $self->hub->species_defs->get_config($name, 'SPECIES_SCIENTIFIC_NAME');
}

sub common_name {
  my ($self, $name) = @_;
  $name = $self->hub->species_defs->production_name_mapping($name);
  return $self->hub->species_defs->get_config($name, 'SPECIES_COMMON_NAME');
}

sub get_genome_db {
  my ($self, $adaptor, $short_name) = @_;

  my $all_genome_dbs = $adaptor->fetch_all;
  $short_name =~ tr/\.//d;
  foreach my $genome_db (@$all_genome_dbs) {
    if ($genome_db->get_short_name eq $short_name) {
      return $genome_db;
    }
  }
}

## Output a list of whole-genome alignments for a given method, and their species
sub format_wga_list {
  my ($self, $method) = @_;
  my $html = '<ul>';

  my $list = $self->list_mlss_by_method($method);
  unless (@$list) {
      return '<p><em>No alignments of this type in this release of Ensembl.</em></p>';
  }
  foreach my $mlss (@$list) {
      my $n = $mlss->name;
      $n =~ s/cactus_hal/Cactus alignment/;
      my $url = '/info/genome/compara/mlss.html?mlss='.$mlss->dbID;
      $html .= sprintf '<li><a href="%s">%s</a></li>', $url, $n;
  }
  $html .= '</ul>';
  return $html;
}

sub print_wga_stats {
  my ($self, $mlss) = @_;
  my $hub     = $self->hub;
  my $site    = $hub->species_defs->ENSEMBL_SITETYPE;
  my $html;
      my ($species_order, $info) = $self->mlss_species_info($mlss);

      if ($species_order && scalar(@{$species_order||[]})) {
        my $rel = $mlss->first_release;
        my $nblocks = $self->thousandify($mlss->get_value_for_tag('num_blocks'));
        my $max_align = $self->thousandify($mlss->max_alignment_length - 1);
        my $count = scalar(@$species_order);
        $html .= sprintf('<h1>%s</h1>', $mlss->name);
        $html .= qq{<p>This alignment has been generated in $site release $rel and is composed of $nblocks blocks (up to $max_align&nbsp;bp long).</p>};
        $html .= $self->error_message('API access', sprintf(
              '<p>This alignment set can be accessed using the Compara API via the Bio::EnsEMBL::DBSQL::MethodLinkSpeciesSetAdaptor using the <em>method_link_type</em> "<b>%s</b>" and either the <em>species_set_name</em> "<b>%s</b>".</p>', $mlss->method->type, $mlss->species_set->name), 'info');

        my $table = EnsEMBL::Web::Document::Table->new([
          { key => 'species', title => 'Species',         width => '22%', align => 'left', sort => 'string' },
          { key => 'asm',     title => 'Assembly',        width => '10%', align => 'left', sort => 'string' },
          { key => 'gl',      title => 'Genome length (bp)', width => '12%', align => 'center', sort => 'string' },
          { key => 'gc',      title => 'Genome coverage (bp)', width => '12%', align => 'center', sort => 'string' },
          { key => 'gcp',     title => 'Genome coverage (%)', width => '10%', align => 'center', sort => 'numeric' },
          { key => 'el',      title => 'Coding exon length (bp)', width => '12%', align => 'center', sort => 'string' },
          { key => 'ec',      title => 'Coding exon coverage (bp)', width => '12%', align => 'center', sort => 'string' },
          { key => 'ecp',     title => 'Coding exon coverage (%)', width => '10%', align => 'center', sort => 'numeric' },
        ], [], {data_table => 1, exportable => 1, id => sprintf('%s_%s', $mlss->method->type, $mlss->species_set->name), sorting => ['species asc']});
        my @colors = qw(#402 #a22 #fc0 #8a2);
        foreach my $sp (@$species_order) {
          my $gc = sprintf('%.2f', $info->{$sp}{'genome_coverage'} / $info->{$sp}{'genome_length'} * 100);
          my $ec = sprintf('%.2f', $info->{$sp}{'coding_exon_coverage'} / $info->{$sp}{'coding_exon_length'} * 100);
          my $cgc = $colors[int($gc/25)];
          my $cec = $colors[int($ec/25)];
          $table->add_row({
            'species' => sprintf('%s (<em>%s</em>)', $info->{$sp}{'common_name'}, $info->{$sp}{'long_name'}),
            'asm'     => $info->{$sp}{'assembly'},
            'gl'      => $self->thousandify($info->{$sp}{'genome_length'}),
            'gc'      => $self->thousandify($info->{$sp}{'genome_coverage'}),
            'gcp'     => sprintf(q{<span style="color: %s">%s</span}, $cgc, $gc),
            'el'      => $self->thousandify($info->{$sp}{'coding_exon_length'}),
            'ec'      => $self->thousandify($info->{$sp}{'coding_exon_coverage'}),
            'ecp'     => sprintf(q{<span style="color: %s">%s</span}, $cec, $ec),
          });
        }
        $html .= $table->render;
      }

  return $html;
}

## Fetch name information about a set of aligned species
sub mlss_species_info {
  my ($self, $mlss) = @_;

  my $compara_db = $self->hub->database('compara');
  return [] unless $compara_db;

  my $species = [];
  foreach my $db (@{$mlss->species_set->genome_dbs||[]}) {
    push @$species, $self->hub->species_defs->production_name_mapping($db->name);
  }
  return $self->get_species_info($species, 1, $mlss);
}


sub list_mlss_by_method {
  my ($self, $method) = @_;

  my $compara_db = $self->hub->database('compara');
  return unless $compara_db;

  my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  return $mlss_adaptor->fetch_all_by_method_link_type($method);
}


sub mlss_data {
  my ($self, $methods) = @_;

  my $compara_db = $self->hub->database('compara');
  return unless $compara_db;

  my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $genome_adaptor  = $compara_db->get_adaptor('GenomeDB');
 
  my $data = {};
  my $species = {};

  ## Munge all the necessary information
  foreach my $method (@{$methods||[]}) {
    my $mls_sets  = $mlss_adaptor->fetch_all_by_method_link_type($method);


    foreach my $mlss (@$mls_sets) {
      ## Work out the name of the reference species using the MLSS title
      my $short_ref_name;
      if ($method =~ /LASTZ/) {
        ($short_ref_name) = $mlss->name =~ /\(on (.+)\)/;
      }
      else {
        $short_ref_name = substr($mlss->name, 0, 5);
      }
      if ($short_ref_name) {
        my $ref_genome_db = $self->get_genome_db($genome_adaptor, $short_ref_name);
      
        ## Add to full list of species
        my $ref_name = $self->hub->species_defs->production_name_mapping($ref_genome_db->name);
        $species->{$ref_name}++;

        ## Build data matrix
        my @non_ref_genome_dbs = grep {$_->dbID != $ref_genome_db->dbID} @{$mlss->species_set->genome_dbs};
        if (scalar(@non_ref_genome_dbs)) {
          # Alignment between 2+ species
          foreach my $nonref_db (@non_ref_genome_dbs) {
            my $nonref_name = $self->hub->species_defs->production_name_mapping($nonref_db->name);
            $species->{$nonref_name}++;
            $data->{$ref_name}{$nonref_name} = [$method, $mlss->dbID, $mlss->has_tag('ensembl_release')];
          }
        } else {
            # Self-alignment. No need to increment $species->{$ref_name} as it has been done earlier
            $data->{$ref_name}{$ref_name} = [$method, $mlss->dbID, $mlss->has_tag('ensembl_release')];
        }
      }
    }
  }
  my @species_list = keys %$species;
  return (\@species_list, $data);
}

sub get_species_info {
## Returns an array of species information, optionally sorted according to a taxonomic tree
  my ($self, $species_order, $by_tree, $mlss) = @_;
  my $hub = $self->hub;
  my $info = {};

  if ($by_tree) {
    ## Get all species from compara database
    my $compara_db = $self->hub->database('compara');
    return [] unless $compara_db;
    my $lookup = {};

    my $tree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree( -compara_dba => $compara_db, -ALLOW_SUBTAXA => 1);
    ## Compara now uses full trinomials for all species
    foreach (@$species_order) {
      my $prod_name = $hub->species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME');
      $lookup->{$prod_name} = $_;
    }
    $species_order = []; ## now we override the original order

    my $all_leaves = $tree->get_all_leaves;
    my @top_leaves = ();
    foreach my $top_name (@{$hub->species_defs->DEFAULT_FAVOURITES}) {
      $top_name = $hub->species_defs->get_config($top_name, 'SPECIES_PRODUCTION_NAME');
      foreach my $this_leaf (@$all_leaves) {
        if ($this_leaf->genome_db->name eq $top_name) {
          push @top_leaves, $this_leaf;
        }
      }
    }
    $all_leaves = $tree->get_all_sorted_leaves(@top_leaves);

    foreach my $this_leaf (@$all_leaves) {
      my $name = $this_leaf->genome_db->name;
      push @$species_order, $lookup->{$name} if $lookup->{$name};
    }
  }

  ## Lookup table from species name to genome_db
  my $genome_db_name_hash = {};
  if ($mlss) {
    foreach my $genome_db (@{$mlss->species_set->genome_dbs}) {
      my $species_tree_name = $genome_db->name;
      $genome_db_name_hash->{$species_tree_name} = $genome_db;
    }
  }
  ## Now munge information for selected species
  foreach my $sp (@$species_order) {
    my $display_name = $hub->species_defs->get_config($sp, 'SPECIES_SCIENTIFIC_NAME');
    (my $short_name = $sp) =~ s/([A-Z])[a-z]+_([a-z0-9]{2,3})[a-z]+/$1.$2/; ## e.g. H.sap
    (my $formatted_name = $display_name) =~ s/ /<br>/; ## Only replace first space

    $info->{$sp}{'long_name'}      = $display_name;
    $info->{$sp}{'short_name'}     = $short_name;
    $info->{$sp}{'formatted_name'} = $formatted_name; 
    $info->{$sp}{'common_name'}    = $hub->species_defs->get_config($sp, 'SPECIES_COMMON_NAME');

    if ($mlss) {
      my $prod_name = $hub->species_defs->get_config($sp, 'SPECIES_PRODUCTION_NAME');
      my $gdb = $genome_db_name_hash->{$prod_name};
      $info->{$sp}{'assembly'} = $gdb->assembly;
      ## Add coverage stats
      my $id = $gdb->dbID;
      my @stats = qw(genome_coverage genome_length coding_exon_coverage coding_exon_length);
      foreach (@stats) {
        $info->{$sp}{$_} = $mlss->get_value_for_tag($_.'_'.$id);
      }
    }
  }

  return $species_order, $info;
}

sub draw_stepped_table {
  my ($self, $method) = @_;
  my $hub  = $self->hub;

  my $methods = [$method];
  my ($species_list, $data) = $self->mlss_data($methods);
  return unless $data;

  my ($species_order, $info) = $self->get_species_info($species_list, 1);

  my $html .= qq{<table class="spreadsheet" style="width:100%;padding-bottom:2em">\n\n};

  my ($i, $j, @to_do);
  foreach my $species (@$species_order) { 
    my $ybg = $i % 2 ? 'bg1' : 'bg3';
    $html .= qq{<tr>\n<th class="$ybg" style="padding:2px"><b><i>}
                  .$info->{$species}{'formatted_name'}.qq{</i></b></th>\n};

    foreach my $other_species (@to_do) {
      my $cbg;
      if ($i % 2) {
        $cbg = $j % 2 ? 'bg1' : 'bg3';
      }
      else {
        $cbg = $j % 2 ? 'bg3' : 'bg4';
      }
      my ($method, $mlss_id, $with_extra_info) = @{$data->{$other_species}{$species}||[]};
      my $content = '-';

      if ($mlss_id) {
        if (not $with_extra_info) {
          $content = '<b>YES</b>';
        }
        else {
          my $url = '/info/genome/compara/mlss.html?mlss='.$mlss_id;
          $content = sprintf('<a href="%s">YES</a>', $url);
        }
      }
      $html .= sprintf '<td class="center %s" style="padding:2px;vertical-align:middle">%s</td>', $cbg, $content;
      $j++;
    }
    $j = 0;

    my $xbg = $i % 2 ? 'bg1' : 'bg4';
    my $next_header = $species_order->[$i];
    $html .= sprintf '<th class="center %s" style="padding:2px">%s</th>', $xbg, $info->{$next_header}{'short_name'};

    $html .= '</tr>';
    $i++;
    push @to_do, $species;
  }

  $html .= "</table>\n";

  return $html;
}

1;
