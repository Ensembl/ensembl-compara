#!/usr/bin/env perl
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
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
my $print_strand = 0;
my $from;
my $host;
my $user;
my $dbname;
my $port;
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
  'print_strand!' => \$print_strand,
  'from=s' => \$from,
  'host=s' => \$host,
  'user=s' => \$user,
  'dbname=s' => \$dbname,
  'port=s'   => \$port,
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

#Load core
if ($reg_conf) {
  $reg->load_all($reg_conf,1);
} elsif ($host && $user && $dbname) {
   #load single, non-standard named core database
   new Bio::EnsEMBL::DBSQL::DBAdaptor(
    -host => $host,
    -user => $user,
    -port => $port,
    -species => $species, 
    -group => 'core',
    -dbname => $dbname);
} else {
  $reg->load_registry_from_url($url);
}

#Load compara from url or Multi.
my $compara_dba;
if ($compara_url) {
    $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
} else {
    #May not need compara if dumping say, core toplevel.
    eval {
       $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
      };
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
} elsif ($feature =~ /^utr/) {
  $track_name = "utr.e$version";
  $description = "$species_name utr in Ensembl $version";
} elsif ($feature =~ /^intron/) {
  $track_name = "intron.e$version";
  $description = "$species_name intron in Ensembl $version";
} elsif ($feature =~ /^splice_site/) {
  $track_name = "splice_site.e$version";
  $description = "$species_name splice site in Ensembl $version";
} elsif ($feature =~ /^transcript/) {
  $track_name = "transcript.e$version";
  $description = "$species_name transcript in Ensembl $version";
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
  } elsif ($feature =~ /^utr/) {
     my $genes = $slice->get_all_Genes_by_type('protein_coding');
     foreach my $this_gene (@$genes) {
       my $transcripts = $this_gene->get_all_Transcripts;
       foreach my $this_transcript (@$transcripts) {
         next if ($this_transcript->biotype ne "protein_coding");
         foreach my $exon (@{$this_transcript->get_all_Exons}) {
           my ($start, $end);
           #5' utr
           next if (!$this_transcript->coding_region_start);
           if ($exon->start < $this_transcript->coding_region_start) {
               $start = $exon->start;
               if ($exon->end < $this_transcript->coding_region_start) {
                  $end = $exon->end;
               } else {
                  $end = $this_transcript->coding_region_start-1;
               }
               my $utr = new Bio::EnsEMBL::Feature(-start => $start,
                                                   -end => $end,
                                                   -slice => $slice,
                                                   -strand => $this_transcript->strand);
               if ($utr->end - $utr->start >= 0) {
                  push @$all_features, $utr;
               }
           }
           #3' utr
           next if (!$this_transcript->coding_region_end);
           if ($exon->end > $this_transcript->coding_region_end) {
              $end = $exon->end;
              if ($exon->start > $this_transcript->coding_region_end) {
                 $start = $exon->start;
              } else {
                 $start = $this_transcript->coding_region_end+1;
              }
               my $utr = new Bio::EnsEMBL::Feature(-start => $start,
                                                   -end => $end,
                                                   -slice => $slice,
                                                   -strand => $this_transcript->strand);
               if ($utr->end - $utr->start >= 0) {
                  push @$all_features, $utr;
               }
           }
         }
       }
     }
  } elsif ($feature =~ /^intron/) {
    my $genes = $slice->get_all_Genes;
    foreach my $this_gene (@$genes) {
      #get transcripts
      foreach my $this_transcript (@{$this_gene->get_all_Transcripts}) {
        foreach my $intron (@{$this_transcript->get_all_Introns}) {
          push @$all_features, $intron;
        }
      }
    }
  } elsif ($feature =~ /^splice_site/) {
    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
      #get transcripts
      foreach my $this_transcript (@{$this_gene->get_all_Transcripts}) {
        foreach my $intron (@{$this_transcript->get_all_Introns}) {
          #start of intron
          my $start = $intron->start - 3;
          my $end = $intron->start + 3;
          my $splice_site = new Bio::EnsEMBL::Feature(-start => $start,
                                                      -end => $end,
                                                      -slice => $intron->slice,
                                                      -strand => $intron->strand);
          push @$all_features, $splice_site;

          #end of intron
          $start = $intron->end - 3;
          $end = $intron->end + 3;
          $splice_site = new Bio::EnsEMBL::Feature(-start => $start,
                                                    -end => $end,
                                                    -slice => $intron->slice,
                                                    -strand => $intron->strand);
          push @$all_features, $splice_site;
        }
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
  } elsif ($feature =~ /^transcript/) {
     my $all_genes = $slice->get_all_Genes();
     foreach my $this_gene (@$all_genes) {
        my $transcripts = $this_gene->get_all_Transcripts;
        foreach my $this_transcript (@$transcripts) {
           push(@$all_features, $this_transcript);
        }
     }

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

    if (!defined $dnafrag_adaptor->fetch_by_Slice($slice)) {
         print STDERR "Unable to fetch " . $slice->name . "\n";
         next;
     }

    my $dnafrag_id = $dnafrag_adaptor->fetch_by_Slice($slice)->dbID;
    my $sql = "SELECT dnafrag_start, dnafrag_end FROM genomic_align WHERE".
        " dnafrag_id = $dnafrag_id and method_link_species_set_id = ".$mlss->dbID;
    if ($extra) {
      $sql = "SELECT dnafrag_start, dnafrag_end FROM genomic_align ga JOIN genomic_align_block USING (genomic_align_block_id) WHERE".
        " dnafrag_id = $dnafrag_id and ga.method_link_species_set_id = ".$mlss->dbID . " AND level_id = $extra";
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
   my $biotype = "";
   #print out biotype for genes
   if ($feature =~ /^gene/) {
       $biotype = $this_feature->biotype if (defined $this_feature->biotype);
   }
   if ($print_strand) {
       print join("\t", $name, $this_feature->seq_region_start - 1,
           $this_feature->seq_region_end, $this_feature->seq_region_strand, $this_feature->display_id, $biotype), "\n";
   } else {
       print join("\t", $name, $this_feature->seq_region_start - 1,
           $this_feature->seq_region_end, $this_feature->display_id, $biotype), "\n";
   }
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
