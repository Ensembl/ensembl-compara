package EnsEMBL::Web::Document::HTML::Compara;

## Provides content for compara documeentation - see /info/docs/compara/analyses.html
## Base class - does not itself output content

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub sci_name {
  my ($self, $name) = @_;
  $name = ucfirst($name);
  $name =~ s/_/ /;
  return $name;
}

sub common_name {
  my ($self, $name) = @_;
  $name = ucfirst($name);
  return $self->hub->species_defs->get_config($name, 'SPECIES_COMMON_NAME');
}

sub get_genome_db {
  my ($self, $adaptor, $short_name) = @_;

  my $all_genome_dbs = $adaptor->fetch_all;
  $short_name =~ tr/\.//d;
  foreach my $genome_db (@$all_genome_dbs) {
    if ($genome_db->short_name eq $short_name) {
      return $genome_db;
    }
  }
}

## Output a list of aligned species
sub format_list {
  my ($self, $method, $list) = @_;
  my $html;

  if ($list && scalar(@{$list||[]})) {
    foreach (@$list) {
     my ($species_order, $info) = $self->mlss_species_info($method, $_->{'name'});

      if ($species_order && scalar(@{$species_order||[]})) {
        my $count = scalar(@$species_order);
        $html .= sprintf '<h3>%s %s %s</h3>
              <p><b>(method_link_type="%s" : species_set_name="%s")</b></p>',
              $count, $_->{'label'}, $method, $method, $_->{'name'};

        $html .= '<ul>';
        foreach my $sp (@$species_order) {
          $html .= sprintf '<li>%s (%s)</li>', $info->{$sp}{'common_name'}, $info->{$sp}{'long_name'};
        }
        $html .= '</ul>';
      }
    }
  }

  return $html;
}

## Fetch name information about a set of aligned species
sub mlss_species_info {
  my ($self, $method, $set_name) = @_;

  my $compara_db = $self->hub->database('compara');
  return [] unless $compara_db;

  my $mlss_adaptor  = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $mlss          = $mlss_adaptor->fetch_by_method_link_type_species_set_name($method, $set_name);

  my $species = [];
  foreach my $db (@{$mlss->species_set_obj->genome_dbs||[]}) {
    push @$species, ucfirst($db->name);
  }
  return $self->get_species_info($species, 1);
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
        $species->{ucfirst($ref_genome_db->name)}++;

        ## Build data matrix
        foreach my $nonref_db (@{$mlss->species_set_obj->genome_dbs}) {
          $species->{ucfirst($nonref_db->name)}++;
          if ($mlss->source eq "ucsc" || ($nonref_db->dbID != $ref_genome_db->dbID)) {
            $data->{ucfirst($ref_genome_db->name)}{ucfirst($nonref_db->name)} = [$method, $mlss->dbID];
          }
        }
      }
    }
  }
  my @species_list = keys %$species;
  return (\@species_list, $data);
}

sub get_species_info {
## Returns an array of species information, optionally sorted according to a taxonomic tree
  my ($self, $species_order, $by_tree) = @_;
  my $hub = $self->hub;
  my $info = {};

  if ($by_tree) {
    ## Get all species from compara database
    my $compara_db = $self->hub->database('compara');
    return [] unless $compara_db;
    my $lookup = {};

    my $tree = $compara_db->get_adaptor('SpeciesTree')->create_species_tree();
    ## Compara now uses full trinomials for all species
    foreach (@$species_order) {
      my $full_name = $hub->species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME');
      $full_name =~ s/ /_/g;
      $lookup->{$full_name} = $_;
    }
    $species_order = []; ## now we override the original order

    my $all_leaves = $tree->get_all_leaves;
    my @top_leaves = ();
    foreach my $top_name (@{$hub->species_defs->DEFAULT_FAVOURITES}) {
      $top_name =~ s/_/ /g;
      foreach my $this_leaf (@$all_leaves) {
        if ($this_leaf->name eq $top_name) {
          push @top_leaves, $this_leaf;
        }
      }
    }
    $all_leaves = $tree->get_all_sorted_leaves(@top_leaves);

    foreach my $this_leaf (@$all_leaves) {
      (my $name = $this_leaf->name) =~ s/ /_/g;
      ## Filthy branch-only hack for error in compara database!
      $name = 'Ictidomys_tridecemlineatus' if $name eq 'Spermophilus_tridecemlineatus';
      push @$species_order, $lookup->{$name} if $lookup->{$name};
    }
  }

  ## Now munge information for selected species
  foreach my $sp (@$species_order) {
    (my $display_name = $sp) =~ s/_/ /g;
    (my $short_name = $sp) =~ s/([A-Z])[a-z]+_([a-z]{3})[a-z]+/$1.$2/; ## e.g. H.sap
    (my $formatted_name = $display_name) =~ s/ /<br>/; ## Only replace first space

    $info->{$sp}{'long_name'}      = $display_name;
    $info->{$sp}{'short_name'}     = $short_name;
    $info->{$sp}{'formatted_name'} = $formatted_name; 
    $info->{$sp}{'common_name'}    = $hub->species_defs->get_config($sp, 'SPECIES_COMMON_NAME');
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
        if ($method eq 'SYNTENY') {
          $content = '<b>YES</b>';
        }
        else {
          my $url = '/info/docs/compara/mlss.html?method='.$method.';mlss='.$mlss_id;
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
