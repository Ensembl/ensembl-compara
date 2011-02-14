#!/usr/bin/env perl
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";
$reg->no_version_check(1);

use Getopt::Long;

my $reg_conf;
my $url = 'mysql://anonymous@ensembldb.ensembl.org/';
my $compara_url;
my $species = "Homo sapiens";
my $regions;
my $feature = "";
my $extra;
my $from;
my $help;

my $desc = "
USAGE dump_features.pl [options] --feature FEATURE

FEATURES
* toplevel (all top-level seq_regions)
* gene [extra] (extra to get a given type of genes, get
   all protein-coding genes by default)
* exons (all exons of protein-coding genes)
* coding-exons
* constitutive-exons (coding-exons that are in all transcripts)
* cassette-exons (coding-exons that are not present in all transcripts)
* pseudogene
* repeats (see extra for specifying the repeat type)
* regulatory_features
* mlss_ID (genomic align features for this MLSS_id)
* nets_ID (blastz-nets, that is *chained* nets for this MLSS id) 
* ce_ID (constrained elements for this MLSS_id)
(* mlss shows all the method_link_types)
(* mlss_METHOD_LINK_TYPE shows all the MLSS of this type)

Options:
* --url URL [default = $url]
      The URL for the ensembl database
* --compara_url
      The URL for the ensembl compara database if it is not
      a release one (or it lives in a diff. server)
* --species [default = $species]
      The name of the species
* --extra
      Allows to restrict the type of repeats
* --from
      Allows to start with a given chromosome to continue a
      partial run

";

GetOptions(
  'reg_conf=s' => \$reg_conf,
  'url=s' => \$url,
  'compara_url=s' => \$compara_url,
  'species=s' => \$species,
  'regions=s' => \$regions,
  'feature=s' => \$feature,
  'extra=s' => \$extra,
  'from=s' => \$from,
  'help' => \$help
  );

if (!$feature and @ARGV) {
  $feature = shift @ARGV;
}
if (!$extra and @ARGV) {
  $extra = shift @ARGV;
}

if ($help || !$feature) {
  print $desc;
  exit(0);
}

if ($reg_conf) {
  $reg->load_all($reg_conf);
} else {
  $reg->load_registry_from_url($url);
}

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

my $species_name = $reg->get_adaptor($species, "core", "MetaContainer")->get_production_name;

my $slice_adaptor = $reg->get_adaptor($species_name, "core", "Slice");

$feature = shift(@ARGV) if (@ARGV and !$feature);
$extra = shift(@ARGV) if (@ARGV and !$extra);

my $mlss;
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor if ($compara_dba);
my $track_name;
my $description;
my $version = $reg->get_adaptor($species_name, "core", "MetaContainer")->
    list_value_by_key("schema_version")->[0];
if ($feature =~ /^top/) {
  $track_name = "top-level.e$version";
  $description = "All $species_name top-level seq-regions in Ensembl $version";
} elsif ($feature =~ /^gene/ and $extra) {
  $track_name = "$extra.genes.e$version";
  $description = "$species_name $extra genes in Ensembl $version";
} elsif ($feature =~ /^gene/) {
  $track_name = "genes.e$version";
  $description = "$species_name genes in Ensembl $version";
} elsif ($feature =~ /^exon/) {
  $track_name = "exons.e$version";
  $description = "$species_name exons (for protein-coding genes only) in Ensembl $version";
} elsif ($feature =~ /^coding/) {
  $track_name = "coding-exons.e$version";
  $description = "$species_name coding-exons (for protein-coding genes only) in Ensembl $version";
} elsif ($feature =~ /^constitutive/) {
  $track_name = "constitutive.coding-exons.e$version";
  $description = "$species_name constitutive coding-exons (for protein-coding genes only) in Ensembl $version";
} elsif ($feature =~ /^cassette/) {
  $track_name = "cassette coding-exons.e$version";
  $description = "$species_name cassette coding-exons (for protein-coding genes only) in Ensembl $version";
} elsif ($feature =~ /^pseudogene/) {
  $track_name = "pseudogenes.e$version";
  $description = "$species_name pseudogenes in Ensembl $version";
} elsif ($feature =~ /^repeat/) {
  $track_name = "repeats.e$version";
  $description = "Repeats on $species_name in Ensembl $version";
} elsif ($feature =~ /^reg/) {
  $track_name = "reg_feat.e$version";
  $description = "$species_name regulatory features in Ensembl $version";
} elsif ($feature =~ /^ce_?(\d+)/) {
  $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($1);
  $track_name = $mlss->name.".e$version";
  $description = $mlss->name." on $species_name in Ensembl $version";
} elsif ($feature =~ /^nets_?(\d+)/) {
  $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($1);
  $track_name = $mlss->name.".e$version";
  $description = $mlss->name." (grouped) on $species_name in Ensembl $version";
} elsif ($feature =~ /^mlss_?(\d+)/) {
  $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($1);
  $track_name = $mlss->name.".e$version";
  $description = $mlss->name." on $species_name in Ensembl $version";
} elsif ($feature =~ /mlss_?(\w+)/) {
  print join("\n", map {$_->dbID.": ".$_->name} @{$compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($1)}), "\n";
  exit(0);
} elsif ($feature =~ /mlss/) {
  my %types = map {$_->method_link_type => 1} @{$compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all()};
  print join("\n", keys %types), "\n";
  exit(0);
} else {
  die $desc. "ERROR: Unknow feature!\n";
}

if (!defined($from)) {
  print "track name=$track_name description=\"$description\" useScore=0\n";
}

my $all_slices;
if ($regions) {
  $all_slices = get_Slices_from_BED_file($regions, $slice_adaptor);
} else {
  $all_slices = $slice_adaptor->fetch_all("toplevel");
}

foreach my $slice (sort {
    if ($a->seq_region_name=~/^\d+$/ and $b->seq_region_name =~/^\d+$/) {
        $a->seq_region_name <=> $b->seq_region_name
    } else {
        $a->seq_region_name cmp $b->seq_region_name}}
            @$all_slices) {
  # print STDERR $slice->name, "\n";
  my $name = "chr".$slice->seq_region_name;

  if (defined($from)) {
    if ($slice->seq_region_name eq $from) {
      undef($from);
    } else {
      next;
    }
  }

  my $all_features = [];
  if ($feature =~ /^top/) {
    print join("\t", $name, $slice->start - 1, $slice->end, $slice->name), "\n";
    next;
  } elsif ($feature =~ /^gene/ and $extra) {
    $all_features = $slice->get_all_Genes_by_type($extra);
  } elsif ($feature =~ /^gene/) {
    $all_features = $slice->get_all_Genes();
  } elsif ($feature =~ /^exon/) {
    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
      my $transcripts = $this_gene->get_all_Transcripts;
      foreach my $this_transcript (@$transcripts) {
        my $exons = $this_transcript->get_all_Exons();
        push(@$all_features, @$exons);
      }
    }
  } elsif ($feature =~ /^coding/) {
    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
      my $transcripts = $this_gene->get_all_Transcripts;
      foreach my $this_transcript (@$transcripts) {
        my $exons = $this_transcript->get_all_translateable_Exons();
        push(@$all_features, @$exons);
      }
    }
  } elsif ($feature =~ /^constitutive/) {
    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
      my $transcripts = $this_gene->get_all_Transcripts;
      my $num_transcripts = 0;
      my $exon_hash;
      foreach my $this_transcript (@$transcripts) {
        next if(!$this_transcript->translation);
        $num_transcripts++;
        my $exons = $this_transcript->get_all_translateable_Exons();
        foreach my $this_exon (@$exons) {
          $exon_hash->{$this_exon->stable_id}->{obj} = $this_exon;
          $exon_hash->{$this_exon->stable_id}->{num}++;
        }
      }
      foreach my $exon_stable_id (keys %$exon_hash) {
        if ($exon_hash->{$exon_stable_id}->{num} == $num_transcripts) {
          push(@$all_features, $exon_hash->{$exon_stable_id}->{obj});
        }
      }
    }
  } elsif ($feature =~ /^cassette/) {
    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
      my $transcripts = $this_gene->get_all_Transcripts;
      my $num_transcripts = 0;
      my $exon_hash;
      foreach my $this_transcript (@$transcripts) {
        next if(!$this_transcript->translation);
        $num_transcripts++;
        my $exons = $this_transcript->get_all_translateable_Exons();
        foreach my $this_exon (@$exons) {
          $exon_hash->{$this_exon->stable_id}->{obj} = $this_exon;
          $exon_hash->{$this_exon->stable_id}->{num}++;
        }
      }
      foreach my $exon_stable_id (keys %$exon_hash) {
        if ($exon_hash->{$exon_stable_id}->{num} < $num_transcripts) {
          push(@$all_features, $exon_hash->{$exon_stable_id}->{obj});
        }
      }
    }
  } elsif ($feature =~ /^pseudogene/) {
    $all_features = $slice->get_all_Genes_by_type("pseudogene");
  } elsif ($feature =~ /^repeat/) {
    my $all_repeats = $slice->get_all_RepeatFeatures(undef, $extra);
    foreach my $this_feature (sort {$a->start <=> $b->start} @$all_repeats) {
      print join("\t", $name, $this_feature->seq_region_start - 1,
          $this_feature->seq_region_end, $this_feature->display_id,
          $this_feature->repeat_consensus->repeat_class,
          $this_feature->repeat_consensus->repeat_type), "\n";
    }
    next;
  } elsif ($feature =~ /^reg/) {
    my $regulatory_feature_adaptor = $reg->get_adaptor(
        "Homo sapiens", "funcgen", "RegulatoryFeature");
    $all_features = $regulatory_feature_adaptor->fetch_all_by_Slice($slice);
    foreach my $this_feature (@$all_features) {
      print join("\t", $name, ($this_feature->seq_region_start - 1),
          $this_feature->seq_region_end, $this_feature->display_label), "\n";
    }
    next;
  } elsif ($feature =~ /^ce_?(\d+)/) {
    my $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);
    my $dnafrag_id = $dnafrag->dbID;
    my $sql = "SELECT dnafrag_start, dnafrag_end FROM constrained_element WHERE".
        " dnafrag_id = $dnafrag_id and method_link_species_set_id = ".$mlss->dbID.
        " ORDER BY dnafrag_start";
    my $sth = $dnafrag_adaptor->db->dbc->prepare($sql);
    $sth->execute();
    my ($start, $end);
    $sth->bind_columns(\$start, \$end);
    while ($sth->fetch) {
      print join("\t", $name, ($start - 1), $end), "\n";
    }
    $sth->finish();
    next;
  } elsif ($feature =~ /^mlss_?(\d+)/) {
    my $dnafrag_id = $dnafrag_adaptor->fetch_by_Slice($slice)->dbID;
    my $sql = "SELECT dnafrag_start, dnafrag_end FROM genomic_align WHERE".
        " dnafrag_id = $dnafrag_id and method_link_species_set_id = ".$mlss->dbID;
    if ($extra) {
      $sql .= " AND level_id = $extra";
    }
    $sql .= " ORDER BY dnafrag_start";
    my $sth = $dnafrag_adaptor->db->dbc->prepare($sql);
    $sth->execute();
    my ($start, $end);
    $sth->bind_columns(\$start, \$end);
    while ($sth->fetch) {
      print join("\t", $name, ($start - 1), $end), "\n";
    }
    $sth->finish();
    next;
  } elsif ($feature =~ /^nets_?(\d+)/) {
    my $dnafrag_id = $dnafrag_adaptor->fetch_by_Slice($slice)->dbID;
    my $sql = "SELECT dnafrag_start, dnafrag_end, group_id FROM genomic_align LEFT JOIN".
    	" genomic_align_block USING (genomic_align_block_id) WHERE".
        " dnafrag_id = $dnafrag_id and genomic_align.method_link_species_set_id = ".$mlss->dbID.
        " AND level_id = 1 ORDER BY dnafrag_start";
    my $sth = $dnafrag_adaptor->db->dbc->prepare($sql);
    $sth->execute();
    my ($start, $end, $group_id);
    $sth->bind_columns(\$start, \$end, \$group_id);
    while ($sth->fetch) {
      print join("\t", $name, ($start - 1), $end, $group_id), "\n";
    }
    $sth->finish();
    next;
  }
  foreach my $this_feature (sort {$a->start <=> $b->start} @$all_features) {
    print join("\t", $name, $this_feature->seq_region_start - 1,
        $this_feature->seq_region_end, $this_feature->display_id), "\n";
  }
}


sub get_Slices_from_BED_file {
  my ($regions_file, $slice_adaptor) = @_;
  my $slices = [];

  open(REGIONS, $regions_file) or die "Cannot open regions file <$regions_file>\n";
  while (<REGIONS>) {
    next if (/^#/ or /^track/);
    my ($chr, $start0, $end) = split("\t", $_);
    $chr =~ s/^chr//;
    my $slice = $slice_adaptor->fetch_by_region(undef, $chr, $start0+1, $end);
    die "Cannot get Slice for $chr - $start0 - $end\n" if (!$slice);
    push(@$slices, $slice);
  }
  close(REGIONS);

  return $slices;
}
