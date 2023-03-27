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
  $name = $self->hub->species_defs->prodname_to_url($name);
  return $self->hub->species_defs->get_config($name, 'SPECIES_SCIENTIFIC_NAME');
}

sub common_name {
  my ($self, $name) = @_;
  $name = $self->hub->species_defs->prodname_to_url($name);
  return $self->hub->species_defs->get_config($name, 'SPECIES_DISPLAY_NAME');
}

sub combine_names {
  my ($self, $common_name, $sci_name) = @_;
  if ($sci_name eq $common_name) {
      return "<em>$sci_name</em>";
  } else {
      return "$common_name (<em>$sci_name</em>)";
  }
}

sub error_message {
  my ($self, $title, $message, $type) = @_;
  $type ||= 'error';
  $message .= '<p>Please email a report giving the URL and details on how to replicate the error (for example, how you got here), to helpdesk@ensembl.org</p>' if $type ne 'info';
  return qq{
      <div class="$type left-margin right-margin">
        <h3>$title</h3>
        <div class="message-pad">
          $message
        </div>
      </div>
  };
}

## Output a list of whole-genome alignments for a given method, and their species
## NOTE: not used any more since e92
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

## Output a list of whole-genome alignments for a given method, and their species
sub format_wga_table {
  my ($self) = @_;

  my $compara_db = $self->hub->database('compara');
  unless ($compara_db) {
    return $self->error_message('No Compara databse', '<p>No Compara database is configured on this site.</p>' );
  }

  my @all_mlss;
  foreach my $method_link_type (qw(PECAN EPO EPO_LOW_COVERAGE CACTUS_HAL)) {
    push @all_mlss, sort {$a->dbID <=> $b->dbID} @{ $compara_db->get_adaptor('MethodLinkSpeciesSet')->fetch_all_by_method_link_type($method_link_type) };
  }

  unless (@all_mlss) {
    return $self->error_message('No alignments found', qq{<p>This Compara database doesn't contain any multiple-genome alignments.</p>}, 'info');
  }

  my $table = EnsEMBL::Web::Document::Table->new([
    { key => 'name'   , title => 'Name', },
    { key => 'genomes', title => 'Genomes', },
    { key => 'method' , title => 'Method used', },
  ], [], {data_table => 1, exportable => 1, id => 'all_multiple_alignments'});

  foreach my $mlss (@all_mlss) {
    my $name = $mlss->name;
    my $genomes = join(", ", sort map {$_->display_name} @{$mlss->species_set->genome_dbs});
    my $method_link_type = $mlss->method->type;
    # Remove the method name, trying first the type
    $name =~ s/\s+$method_link_type$//i;
    # And then the display name if there is one
    if ($Bio::EnsEMBL::Compara::Method::PLAIN_TEXT_DESCRIPTIONS{$method_link_type}) {
        $method_link_type = $Bio::EnsEMBL::Compara::Method::PLAIN_TEXT_DESCRIPTIONS{$method_link_type};
        $name =~ s/\s+$method_link_type$//i;
    }
    my $url = sprintf(q{<a href="/info/genome/compara/mlss.html?mlss=%d">%s</a>}, $mlss->dbID, $name);
    $table->add_row({
      'name'    => $url,
      'genomes' => $genomes,
      'method'  => $method_link_type,
    });
  }
  return $table->render;
}


sub print_wga_stats {
  my ($self, $mlss) = @_;
  my $hub     = $self->hub;
  my $site    = $hub->species_defs->ENSEMBL_SITETYPE;
  my $division = $hub->species_defs->DIVISION;
  my $html;
  my ($species_order, $info) = $self->mlss_species_info($mlss);

  if ($species_order && scalar(@{$species_order||[]})) {
    my $rel = $mlss->first_release;
    $rel   -= 53 if $division; ## Filthy hack bc compara doesn't understand EG releases
    my $nblocks = $self->thousandify($mlss->get_value_for_tag('num_blocks'));
    my $max_align = $self->thousandify($mlss->max_alignment_length - 1);
    my $count = scalar(@$species_order);
    $html .= sprintf('<h1>%s</h1>', $mlss->name);
    $html .= qq{<p>This alignment has been generated in $site release $rel and is composed of $nblocks blocks (up to $max_align&nbsp;bp long).</p>};
    $html .= $self->error_message('API access', sprintf(
              '<p>This alignment set can be accessed using the Compara API via the Bio::EnsEMBL::DBSQL::MethodLinkSpeciesSetAdaptor using the <em>method_link_type</em> "<b>%s</b>" and the <em>species_set_name</em> "<b>%s</b>".</p>', $mlss->method->type, $mlss->species_set->name), 'info');

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
            'species' => $self->combine_names($info->{$sp}{'common_name'}, $info->{$sp}{'long_name'}),
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
  my $lookup =  $self->hub->species_defs->prodnames_to_urls_lookup;
  foreach my $db (@{$mlss->species_set->genome_dbs||[]}) {
    push @$species, $lookup->{$db->name};
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


sub pairwise_mlss_data {
  my ($self, $methods) = @_;

  my $compara_db = $self->hub->database('compara');
  return unless $compara_db;

  my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');

  my %data;
  my %synt_methods;

  ## Munge all the necessary information
  my $lookup = $self->hub->species_defs->prodnames_to_urls_lookup;
  foreach my $method (@{$methods||[]}) {
    my $mlss_sets  = $mlss_adaptor->fetch_all_by_method_link_type($method);
    if (@$mlss_sets and ($mlss_sets->[0]->method->class =~ /SyntenyRegion.synteny/)) {
      $synt_methods{$method} = 1;
    }

    foreach my $mlss (@$mlss_sets) {
      my ($gdb1, $gdb2) = @{$mlss->species_set->genome_dbs};
      my $name1 = $lookup->{$gdb1->name};
      if ($gdb2) {
        my $name2 = $lookup->{$gdb2->name};
        push @{$data{$name1}->{$name2}}, [$method, $mlss->dbID];
        push @{$data{$name2}->{$name1}}, [$method, $mlss->dbID];
      } else {
        # Self alignment
        push @{$data{$name1}->{$name1}}, [$method, $mlss->dbID];
      }
    }
  }
  return (\%data, \%synt_methods);
}


sub mlss_data {
  my ($self, $methods) = @_;

  my $compara_db = $self->hub->database('compara');
  return unless $compara_db;

  my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $genome_adaptor  = $compara_db->get_adaptor('GenomeDB');
 
  my $data = {};
  my $species = {};
  my $lookup = $self->hub->species_defs->prodnames_to_urls_lookup;

  ## Munge all the necessary information
  foreach my $method (@{$methods||[]}) {
    my $mls_sets  = $mlss_adaptor->fetch_all_by_method_link_type($method);


    foreach my $mlss (@$mls_sets) {
      ## MLSS have a special tag to indicate the reference species
      if ($mlss->has_tag('reference_species')) {
        my $ref_gdb_name = $mlss->get_value_for_tag('reference_species');
      
        ## Add to full list of species
        my $ref_name = $lookup->{$ref_gdb_name};
        $species->{$ref_name}++;

        ## Build data matrix
        my @non_ref_genome_dbs = grep {$_->name ne $ref_gdb_name} @{$mlss->species_set->genome_dbs};
        if (scalar(@non_ref_genome_dbs)) {
          # Alignment between 2+ species
          foreach my $nonref_db (@non_ref_genome_dbs) {
            my $nonref_name = $lookup->{$nonref_db->name};
            $species->{$nonref_name}++;
            $data->{$ref_name}{$nonref_name} = [$method, $mlss->dbID];
          }
        } else {
            # Self-alignment. No need to increment $species->{$ref_name} as it has been done earlier
            $data->{$ref_name}{$ref_name} = [$method, $mlss->dbID];
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

    my $tree = $mlss ? $mlss->species_tree->root : Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree( -compara_dba => $compara_db, -ALLOW_SUBTAXA => 1);
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
  my $genome_db_id_2_node_hash = $mlss && $mlss->species_tree && $mlss->species_tree->get_genome_db_id_2_node_hash;

  ## Now munge information for selected species
  foreach my $sp (@$species_order) {
    my $sci_name = $hub->species_defs->get_config($sp, 'SPECIES_SCIENTIFIC_NAME');
    (my $short_name = $sp) =~ s/([A-Z])[a-z]+_([a-z0-9]{2,3})[a-z]+/$1.$2/; ## e.g. H.sap
    (my $formatted_name = $sci_name) =~ s/ /<br>/; ## Only replace first space

    $info->{$sp}{'long_name'}      = $sci_name;
    $info->{$sp}{'short_name'}     = $short_name;
    $info->{$sp}{'formatted_name'} = $formatted_name; 
    $info->{$sp}{'common_name'}    = $hub->species_defs->get_config($sp, 'SPECIES_DISPLAY_NAME');
    $info->{$sp}{'sample_loc'}     = ($hub->species_defs->get_config($sp, 'SAMPLE_DATA') || {})->{'LOCATION_PARAM'};

    if ($mlss) {
      my $prod_name = $hub->species_defs->get_config($sp, 'SPECIES_PRODUCTION_NAME');
      my $gdb = $genome_db_name_hash->{$prod_name};
      $info->{$sp}{'assembly'} = $gdb->assembly;
      ## Add coverage stats
      my $id = $gdb->dbID;
      my @stats = qw(genome_coverage genome_length coding_exon_coverage coding_exon_length);
      foreach (@stats) {
        $info->{$sp}{$_} = $genome_db_id_2_node_hash && exists $genome_db_id_2_node_hash->{$id} ? $genome_db_id_2_node_hash->{$id}->get_value_for_tag($_) : $mlss->get_value_for_tag($_.'_'.$id);
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
      my ($method, $mlss_id) = @{$data->{$other_species}{$species}||[]};
      my $content = '-';

      if ($mlss_id) {
          my $url = '/info/genome/compara/mlss.html?mlss='.$mlss_id;
          $content = sprintf('<a href="%s">YES</a>', $url);
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


sub draw_pairwise_alignment_list {
    my ($self, $species) = @_;

    my $hub  = $self->hub;
    my ($data, $synt_methods) = $self->pairwise_mlss_data( ['TRANSLATED_BLAT_NET','BLASTZ_NET', 'LASTZ_NET', 'ATAC', 'SYNTENY'] );

    ## Do some munging
    my ($species_order, $info) = $self->get_species_info([keys %$data], 1);

    ## Output HTML
    # Outer table has 1 row per query species
    my $thtml = qq{<table id="genomic_align_table" class="no_col_toggle ss autocenter" style="width: 100%" cellpadding="0" cellspacing="0">};

    my ($i, $j) = (0, 0);
    foreach my $sp (@$species_order) {
        next unless $data->{$sp};

	my $ybg = $i++ % 2 ? 'bg1' : 'bg2';

        # Intermediate table has 1 row per target species
        my $ghtml = sprintf q{
        <table id="%s_aligns" class="no_col_toggle ss toggle_table hide toggleable autocenter all_species_tables" style="width: 100%;" cellpadding="0" cellspacing="0">
        }, $sp;

	$j = $i;
        my $genomic_count = 0;
        my $synteny_count = 0;
        foreach my $other (@$species_order) {
            my $alignments = $data->{$sp}{$other};
            next unless $alignments;
            my $xbg = $j++ % 2 ? 'bg1' : 'bg2';

            # Inner table has 1 row per alignment method
            my $astr = qq{<table cellpadding="0" cellspacing="2" style="width:100%">};
            foreach my $aln (@$alignments) {
                my $method = $aln->[0];
                my $mlss_id = $aln->[1];

                if ($synt_methods->{$method}) {
                    $synteny_count++;
                } else {
                    $genomic_count++;
                }

		my $sample_location = '&nbsp;';
		if ($info->{$sp}->{'sample_loc'}) {
                    if ($synt_methods->{$method}) {
			$sample_location = sprintf qq{<a href="/%s/Location/Synteny?r=%s;otherspecies=%s">example</a>}, $sp, $info->{$sp}->{'sample_loc'}, $other;
		    } else {
			$sample_location = sprintf qq{<a href="/%s/Location/Compara_Alignments/Image?align=%s;r=%s">example</a>}, $sp, $mlss_id, $info->{$sp}->{'sample_loc'};
		    }
		}
                if ($Bio::EnsEMBL::Compara::Method::PLAIN_TEXT_DESCRIPTIONS{$method}) {
                    $method = $Bio::EnsEMBL::Compara::Method::PLAIN_TEXT_DESCRIPTIONS{$method};
                }
                $astr .= qq{<tr>
<td style="padding:0px 10px 0px 0px;text-align:right;">&nbsp;</td>
<td style="padding:0px 10px 0px 0px;text-align:right;widht:20px">$method |</td>
<td style="padding:0px 10px 0px 0px;text-align:left;width:60px;">$sample_location</td>
<td style="padding:0px 10px 0px 0px;text-align:left;width:40px;"><a href="/info/genome/compara/mlss.html?mlss=$mlss_id">stats</a></td><tr>};
            }
            $astr .= qq{</table>};
            my $self_desc = $sp eq $other ? ' [self-alignment]' : '';
            $ghtml .= sprintf qq{<tr class="%s"><td>%s%s</td><td>%s</td></tr>}, $xbg, $self->combine_names($info->{$other}->{'common_name'}, $info->{$other}->{'long_name'}), $self_desc, $astr;
        }
        $ghtml .= qq{</table>};

	my $synteny_str = $synteny_count > 1 ? 'syntenies' : 'synteny';
	my $chtml = sprintf qq {
<span style="text-align:left">%s</span> &nbsp; <span style="text-align:left">%s</span>}, $genomic_count ? ("$genomic_count alignment".($genomic_count > 1 ? 's':'')): "&nbsp;", $synteny_count ? "$synteny_count $synteny_str" : "&nbsp;";

	my $sphtml = sprintf qq{
<tr class="%s">
  <td>
    <a title="Click to show/hide" rel="%s_aligns" class="toggle no_img closed" href="#">
      <span class="open closed" style="width:50%;float:left;">
        <strong>%s</strong>
      </span>
    </a>
    %s
    %s
  </td>
</tr>}, $ybg, $sp, $self->combine_names($info->{$sp}->{'common_name'}, $info->{$sp}->{'long_name'}), $chtml, $ghtml;
	$thtml .= $sphtml;
    }
    $thtml .= qq{</table>};

    my $html = sprintf qq{
<div id="GenomicAlignmentsTab" class="js_panel">
<input type="hidden" class="panel_type" value="Content"/>
<div class="info-box">
  <p>
    <a rel="all_species_tables" href="#" class="closed toggle" title="Expand all tables">
       <span class="closed">Toggle All</span>
       <span class="open">Toggle All</span>
    </a> or click a species names to expand/collapse its alignment list
  </p>
  %s
</div>
</div>
}, $thtml;

    return $html;
}

1;
