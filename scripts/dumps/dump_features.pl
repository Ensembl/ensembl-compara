#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::SimpleFeature;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
my $reg = "Bio::EnsEMBL::Registry";
$reg->no_version_check(1);

use Getopt::Long;

my $reg_conf;
my $url = 'mysql://anonymous@ensembldb.ensembl.org/';
my ($compara_url, $compara_db);
my $species = "Homo sapiens";
my $component;
my $regions;
my $feature = "";
my $default_promoter_length = 10000;
my $extra;
my $print_strand = 0;
my $from;
my $host;
my $user;
my $dbname;
my $port;
my $help;
my $urls;
my $lex_sort;

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
* utr
* promoter-regions (see extra for specifying the length; $default_promoter_length by default)
* pseudogene
* repeats (see extra for specifying the repeat type)
* regulatory_features
* mlss_ID (genomic align features for this MLSS_id)
* nets_ID (blastz-nets, that is *chained* nets for this MLSS id) 
* ce_ID (constrained elements for this MLSS_id)
* cs_ID (conservation scores for this MLSS_id)
(* mlss shows all the method_link_types)
(* mlss_METHOD_LINK_TYPE shows all the MLSS of this type)

Options:
* --url URL [default = $url]
      The URL for the ensembl database
* --compara_db
      Specify the ensembl compara database if it is not a
      release one (or it lives in a diff. server). Can be a
      URL or registry alias (--compara_url being retired)
* --species [default = $species]
      The name of the species
* --component [optional]
      For polyploid genomes only, the name of the component
* --extra
      Allows to restrict the type of repeats
* --from
      Allows to start with a given chromosome to continue a
      partial run

";

GetOptions(
  'reg_conf=s' => \$reg_conf,
  'url=s' => \$url,
  'urls=s' => \@$urls,
  'compara_url=s' => \$compara_url,
  'compara_db=s' => \$compara_db,
  'species=s' => \$species,
  'component=s' => \$component,
  'regions=s' => \$regions,
  'feature=s' => \$feature,
  'extra=s' => \$extra,
  'print_strand!' => \$print_strand,
  'lex_sort!' => \$lex_sort,
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

# keep until $compara_url is retired from use
$compara_db = $compara_url if defined $compara_url;

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
} elsif ($urls && @$urls > 0) {
    foreach my $this_url (@$urls) {
        $reg->load_registry_from_url($this_url);
    }
} else {
  $reg->load_registry_from_url($url);
}

#Load compara from url or Multi.
my $compara_dba;
if ($compara_db) {
    # $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db );
} else {
    #May not need compara if dumping say, core toplevel.
    eval {
       $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
      };
}

if ($compara_dba) {
    # will have disconnect_when_inactive set to 1.
    map {$_->db_adaptor->dbc->disconnect_when_inactive(0)} grep {$_->db_adaptor} @{$compara_dba->get_GenomeDBAdaptor->fetch_all};
}

my $species_name = $reg->get_adaptor($species, "core", "MetaContainer")->get_production_name;
$species_name .= ".$component" if $component;

my $slice_adaptor = $reg->get_adaptor($species, "core", "Slice");

$feature = shift(@ARGV) if (@ARGV and !$feature);
$extra = shift(@ARGV) if (@ARGV and !$extra);

my $mlss;
my $dnafrag_adaptor = $compara_dba ? $compara_dba->get_DnaFragAdaptor : undef;
my $track_name;
my $description;
my $extra_desc = 'useScore=0';
my $version = $reg->get_adaptor($species, "core", "MetaContainer")->get_schema_version();

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
} elsif ($feature =~ /^promo/) {
  $track_name = "promoters.e$version";
  if (!defined $extra) {
    $extra = $default_promoter_length;
  }
  $description = "$species_name promoters (l=${extra}bp) in Ensembl $version";
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
  if ($mlss->method->class =~ /^GenomicAlign.*_alignment$/) {
      # Check if there is a corresponding CE MLSS
      my $ce_mlsss = $mlss->get_all_linked_mlss_by_class_and_reverse_tag('ConstrainedElement.constrained_element', 'msa_mlss_id');
      if (scalar(@$ce_mlsss) == 1) {
          warn sprintf("Automatically switching from mlss_id=%d (%s) to mlss_id=%d (%s)\n", $mlss->dbID, $mlss->method->type, $ce_mlsss->[0]->dbID, $ce_mlsss->[0]->method->type);
          $mlss = $ce_mlsss->[0];
      }
  }
  die "This mlss is not of Constrained elements: ".$mlss->toString if ($mlss->method->class ne 'ConstrainedElement.constrained_element');
  $track_name = "gerp_elements.".($mlss->species_set->name || $1).".$species_name.e$version";
  $description = $mlss->name." on $species_name in Ensembl $version";
} elsif ($feature =~ /^cs_?(\d+)/) {
  $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($1);
  if ($mlss->method->class =~ /^GenomicAlign.*_alignment$/) {
      # Check if there is a corresponding CS MLSS
      my $cs_mlsss = $mlss->get_all_linked_mlss_by_class_and_reverse_tag('ConservationScore.conservation_score', 'msa_mlss_id');
      if (scalar(@$cs_mlsss) == 1) {
          warn sprintf("Automatically switching from mlss_id=%d (%s) to mlss_id=%d (%s)\n", $mlss->dbID, $mlss->method->type, $cs_mlsss->[0]->dbID, $cs_mlsss->[0]->method->type);
          $mlss = $cs_mlsss->[0];
      }
  }
  die "This mlss is not of Conservation scores: ".$mlss->toString if ($mlss->method->class ne 'ConservationScore.conservation_score');
  $track_name = "gerp_score.".($mlss->species_set->name || $1).".$species_name.e$version";
  $description = $mlss->name." on $species_name in Ensembl $version";
  $extra_desc = 'type=bedGraph';
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
  my %types = map {$_->method->type => 1} @{$compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all()};
  print join("\n", keys %types), "\n";
  exit(0);
} else {
  die $desc. "ERROR: Unknow feature!\n";
}

if (!defined($from)) {
  print "track name=$track_name description=\"$description\" $extra_desc\n";
}

my $all_slices;
if ($regions) {
  $all_slices = get_Slices_from_BED_file($regions, $slice_adaptor);
} elsif ($component) {
  $all_slices = $slice_adaptor->fetch_all_by_genome_component($component);
} else {
  $all_slices = $slice_adaptor->fetch_all("toplevel");
}

# If the slices come from a BED file, preserve their order. Otherwise, sort !
unless ($regions) {
  $all_slices = [sort {
    if (!$lex_sort and $a->seq_region_name=~/^\d+$/ and $b->seq_region_name =~/^\d+$/) {
        $a->seq_region_name <=> $b->seq_region_name
    } else {
        $a->seq_region_name cmp $b->seq_region_name}}
            @$all_slices];
}

foreach my $slice (@$all_slices) {
  # print STDERR $slice->name, "\n";
  my $name = $slice->seq_region_name;

  # Check if the connection is still on
  $slice_adaptor->dbc->reconnect()  unless $slice_adaptor->dbc->db_handle->ping;

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
  } elsif ($feature =~ /^promo/) {
    my $genes = $slice->get_all_Genes_by_type('protein_coding');
    foreach my $this_gene (@$genes) {
      my $transcripts = $this_gene->get_all_Transcripts;
      foreach my $this_transcript (@$transcripts) {
        next if ($this_transcript->biotype ne "protein_coding");
        next if (!$this_transcript->coding_region_start);
        my $start;
        my $end;

        if ($this_transcript->strand == 1) {
          $start = $this_transcript->coding_region_start - $extra;
          $start = 1 if ($start < 1);

          $end = $this_transcript->coding_region_start - 1;
          $end = 1 if ($end < 1);

        } else {
          $start = $this_transcript->coding_region_start + 1;
          $start = $slice->length if ($start > $slice->length);

          $end = $this_transcript->coding_region_start + $extra;
          $end = $slice->length if ($end > $slice->length);
        }
          
        my $promoter = new Bio::EnsEMBL::SimpleFeature(
              -start => $start,
              -end => $end,
              -slice => $slice,
              -strand => $this_transcript->strand,
              -display_label => $this_transcript->display_id."\t".$this_gene->display_id);

        push @$all_features, $promoter;
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
    my $seq_region_start = $slice->seq_region_start;
    my $seq_region_end = $slice->seq_region_end;
    my $sql = "SELECT constrained_element_id, dnafrag_start, dnafrag_end, score, p_value FROM constrained_element WHERE".
        " dnafrag_id = $dnafrag_id and method_link_species_set_id = ".$mlss->dbID.
        " AND dnafrag_start >= $seq_region_start AND dnafrag_end <= $seq_region_end".
        " GROUP BY dnafrag_start, dnafrag_end".
        " ORDER BY dnafrag_start";
    my $sth = $dnafrag_adaptor->db->dbc->prepare($sql);
    $sth->execute();
    my ($constrained_element_id, $start, $end, $score, $pvalue);
    $sth->bind_columns(\$constrained_element_id, \$start, \$end, \$score, \$pvalue);
    while ($sth->fetch) {
      print join("\t", $name, ($start - 1), $end, $constrained_element_id, $score, $pvalue), "\n";
    }
    $sth->finish();
    next;
  } elsif ($feature =~ /^cs_?(\d+)/) {
    # Iterate the slice by chunks of 1Mb
    my $it = $slice->sub_Slice_Iterator(1_000_000);
    while ($it->has_next()) {
        my $sub_slice = $it->next();
        #print STDERR $sub_slice->name() . "\n";
        my $scores = $compara_dba->get_ConservationScoreArrayAdaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $sub_slice);
        # To save space we can merge consecutive positions that have the same score
        my $last_score;
        my $last_start;
        my $current_pos = $sub_slice->seq_region_start - 1;  # Coordinates in BED are 0-based
        foreach my $current_score (@$scores) {
            if (defined $last_score) {
                if (defined $current_score) {
                    if (abs($current_score - $last_score) < 1e-6) {
                        # Same score
                    } else {
                        # Different score
                        print join("\t", $name, $last_start, $current_pos, sprintf('%.6f', $last_score)), "\n";     # The right coordinate is open
                        $last_score = $current_score;
                        $last_start = $current_pos;
                    }
                } else {
                    # No more scores -> end of block
                    print join("\t", $name, $last_start, $current_pos, sprintf('%.6f', $last_score)), "\n";         # The right coordinate is open
                    undef $last_start;
                    undef $last_score;
                }
            } else {
                if (defined $current_score) {
                    $last_start = $current_pos;
                    $last_score = $current_score;
                } else {
                    # Still no score, let's move on
                }
            }
            $current_pos ++;
        }
        # Don't forget the last block !
        if (defined $last_score) {
            print join("\t", $name, $last_start, $current_pos-1, sprintf('%.6f', $last_score)), "\n";
        }
    }
    next;
  } elsif ($feature =~ /^mlss_?(\d+)/) {

    my $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);
    if (!defined $dnafrag) {
         print STDERR "Unable to fetch " . $slice->name . "\n";
         next;
     }

    # Heuristics: There could be quite some alignments on a >1Mbp region,
    # so disconnect from the database
    if ($dnafrag->length > 1_000_000) {
        $slice->adaptor->dbc->disconnect_if_idle;
    }

    my $dnafrag_id = $dnafrag->dbID;
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

  open(my $regions_fh, '<', $regions_file) or die "Cannot open regions file <$regions_file>\n";
  while (<$regions_fh>) {
    next if (/^#/ or /^track/);
    chomp;
    my ($chr, $start0, $end) = split("\t", $_);
    $start0 += 1 if defined $start0;
    my $slice = $slice_adaptor->fetch_by_region(undef, $chr, $start0, $end);
    if (!$slice and ($chr =~ m/^chr(.*)/)) {
        $slice = $slice_adaptor->fetch_by_region(undef, $1, $start0, $end);
    }
    die "Cannot get Slice for $chr - ".($start0//'NA')." - ".($end//'NA')."\n" if (!$slice);
    push(@$slices, $slice);
  }
  close($regions_fh);

  return $slices;
}
