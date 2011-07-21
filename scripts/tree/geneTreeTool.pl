#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::SimpleAlign;
#use Bio::LocatableSeq;
#use Bio::AlignIO;
#use Bio::TreeIO;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::NCBITaxon;
use Bio::EnsEMBL::Compara::Graph::Algorithms;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::RunnableDB::OrthoTree;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Mapper::RangeRegistry; # mxe_metatranscript
use Switch;

use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

my %compara_conf = ();
$compara_conf{'-user'} = 'ensro';
$compara_conf{'-port'} = 3306;

$self->{'cdna'} = 0;
$self->{'scale'} = 20;
$self->{'align_format'} = 'phylip';
$self->{'debug'} = 0;
$self->{'run_topo_test'} = 1;
$self->{'analyze'} = 0;
$self->{'drawtree'} = 0;
$self->{'print_leaves'} = 0;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

Bio::EnsEMBL::Registry->no_version_check(1);

GetOptions('help'                                     => \$help,
           'url=s'                                    => \$url,
           'h=s'                                      => \$compara_conf{'-host'},
           'u=s'                                      => \$compara_conf{'-user'},
           'p=s'                                      => \$compara_conf{'-pass'},
           'port=s'                                   => \$compara_conf{'-port'},
           'db=s'                                     => \$compara_conf{'-dbname'},
           'file=s'                                   => \$self->{'newick_file'},
           'tree_id=i'                                => \$self->{'tree_id'},
           'nc_tree_id=i'                             => \$self->{'nc_tree_id'},
           'tree_stable_id=s'                             => \$self->{'tree_stable_id'},
           'clusterset_id=i'                          => \$self->{'clusterset_id'},
           'gene=s'                                   => \$self->{'gene_stable_id'},
           'reroot=i'                                 => \$self->{'new_root_id'},
           'parent'                                   => \$self->{'parent'},
           'align'                                    => \$self->{'print_align'},
           'exclude_taxa=s'                           => \$self->{'exclude_taxa'},
           'cdna'                                     => \$self->{'cdna'},
           'exon_cased'                               => \$self->{'exon_cased'},
           'fasta'                                    => \$self->{'output_fasta'},
           'boj'                                      => \$self->{'output_boj'},
           'dump'                                     => \$self->{'dump'},
           'align_format=s'                           => \$self->{'align_format'},
           'scale=f'                                  => \$self->{'scale'},
           'counts'                                   => \$self->{'counts'},
           'newick'                                   => \$self->{'print_newick'},
           'nhx'                                      => \$self->{'print_nhx'},
           'nhx_gene_id'                              => \$self->{'nhx_gene_id'},
           'nhx_protein_id'                           => \$self->{'nhx_protein_id'},
           'nhx_transcript_id'                        => \$self->{'nhx_transcript_id'},
           'nhx_display_label_composite'              => \$self->{'nhx_display_label_composite'},
           'nhx_treebest_ortho'                       => \$self->{'nhx_treebest_ortho'},
           'print'                                    => \$self->{'print_tree'},
           'list'                                     => \$self->{'print_leaves'},
           'draw'                                     => \$self->{'drawtree'},
           'balance'                                  => \$self->{'balance_tree'},
           'chop'                                     => \$self->{'chop_tree'},
           'keep_leaves=s'                            => \$self->{'keep_leaves'},
           'keep_leaves_species=s'                    => \$self->{'keep_leaves_species'},
           'delete_leaves_species=s'                  => \$self->{'delete_leaves_species'},
           'debug=s'                                  => \$self->{'debug'},
           'onlyrapdups'                              => \$self->{'onlyrapdups'},
           'orthotree'                                => \$self->{'orthotree'},
           'species_list=s'                           => \$self->{'species_list'},
           'species=s'                                => \$self->{'_species'},
           'sp1=s'                                    => \$self->{'_species1'},
           'sp2=s'                                    => \$self->{'_species2'},
           'v|verbose=s'                              => \$self->{'verbose'},
           'cutoff=s'                                 => \$self->{'cutoff'},
           'analyze|analyse'                          => \$self->{'analyze'},
           'analyze_homologies'                       => \$self->{'_analyze_homologies'},
           'url2=s'                                   => \$self->{'_url2'},
           'append_taxon_id'                          => \$self->{'append_taxon_id'},
           'align_member_id'                          => \$self->{'align_member_id'},
           'homology_list=s'                          => \$self->{'_homology_list'},
           'test|_orthotree_treefam'                  => \$self->{'_orthotree_treefam'},
           '_treefam_file=s'                          => \$self->{'_treefam_file'},
           'inputfile=s'                              => \$self->{'_inputfile'},
           'inputfile2=s'                             => \$self->{'_inputfile2'},
           '_readonly|readonly=s'                     => \$self->{'_readonly'},
           '_pattern|pattern'                         => \$self->{'_pattern'},
           '_list_defs|list_defs=s'                   => \$self->{'_list_defs'},
           '_check_mfurc|check_mfurc'                 => \$self->{'_check_mfurc'},
           '_topolmis|topolmis=s'                     => \$self->{'_topolmis'},
           'duploss=s'                                => \$self->{'_duploss'},
           'gap_contribution=s'                       => \$self->{'_gap_contribution'},
           'gene_bootstrap_coef=s'                    => \$self->{'_gene_bootstrap_coef'},
           'tree_bootstrap_dupconf=s'                 => \$self->{'_tree_bootstrap_dupconf'},
           'split_genes_stats=s'                            => \$self->{'_split_genes_stats'},
           'merge_split_genes=s'                      => \$self->{'_merge_split_genes'},
           'phylowidget_tests=s'                      => \$self->{'_phylowidget_tests'},
           'phylogenomics=s'                          => \$self->{'_phylogenomics'},
           'phylogenomics_separate=s'                 => \$self->{'_phylogenomics_separate'},
           'phylogenomics_pc=s'                       => \$self->{'_phylogenomics_pc'},
           'phylogenomics_concat=s'                   => \$self->{'_phylogenomics_concat'},
           'fasta2phylip_disk=s'                      => \$self->{'_fasta2phylip_disk'},
           'treefam_guess_name=s'                     => \$self->{'_treefam_guess_name'},
           'gmin=s'                                   => \$self->{'_gmin'},
           'loose_assoc=s'                            => \$self->{'_loose_assoc'},
           'paf_stats=s'                              => \$self->{'_paf_stats'},
           'gap_proportion=s'                         => \$self->{'_gap_proportion'},
           'per_residue_g_contribution=s'             => \$self->{'_per_residue_g_contribution'},
           'distances_taxon_level=s'                  => \$self->{'_distances_taxon_level'},
           'homologs_and_paf_scores=s'                => \$self->{'_homologs_and_paf_scores'},
           'homologs_and_dnaaln=s'                    => \$self->{'_homologs_and_dnaaln'},
           'consistency_orthotree_mlss=s'             => \$self->{'_consistency_orthotree_mlss'},
           'consistency_orthotree_member_id=s'        => \$self->{'_consistency_orthotree_member_id'},
           'pafs=s'                                   => \$self->{'_pafs'},
           'duprates=s'                               => \$self->{'_duprates'},
           'duphop=s'                                 => \$self->{'_duphop'},
           'duphop_subtrees=s'                        => \$self->{'_duphop_subtrees'},
           'duphop_subtrees_global=s'                 => \$self->{'_duphop_subtrees_global'},
           'merge_small_trees=s'                      => \$self->{'_merge_small_trees'},
           'concatenation=s'                          => \$self->{'_concatenation'},
           'family_expansions=s'                      => \$self->{'_family_expansions'},
           'dnds_pairs=s'                             => \$self->{'_dnds_pairs'},
           'dnds_paralogs=s'                          => \$self->{'_dnds_paralogs'},
           'dnds_doublepairs=s'                       => \$self->{'_dnds_doublepairs'},
           'slr=s'                                    => \$self->{'_slr'},
           'slr_subtrees=s'                           => \$self->{'_slr_subtrees'},
           'codeml_mutsel=s'                          => \$self->{'_codeml_mutsel'},
           'slr_das=s'                                => \$self->{'_slr_das'},
           'genetree_domains=s'                       => \$self->{'_genetree_domains'},
           'sitewise_alnwithgaps=s'                   => \$self->{'_sitewise_alnwithgaps'},
           'query_sitewise_domains=s'                 => \$self->{'_query_sitewise_domains'},
           'simul_genetrees=s'                        => \$self->{'_simul_genetrees'},
           'analysis_job_trace=s'                           => \$self->{'_analysis_job_trace'},
           'nytprof_get_homologous_peptide_ids_from_gene=s' => \$self->{'_nytprof_get_homologous_peptide_ids_from_gene'},
           'gblocks_species=s'                        => \$self->{'_gblocks_species'},
           'cafe_genetree=s'                          => \$self->{'_cafe_genetree'},
           'genetree_to_mcl=s'                        => \$self->{'_genetree_to_mcl'},
           'clm_dist_input=s'                         => \$self->{'_clm_dist_input'},
           'family_pid=s'                             => \$self->{'_family_pid'},
           'genetreeview_mcv=s'                       => \$self->{'_genetreeview_mcv'},
           'ensembl_alias_name=s'                     => \$self->{'_ensembl_alias_name'},
           'pep_splice_site=s'                        => \$self->{'_pep_splice_site'},
           'prank_test=s'                             => \$self->{'_prank_test'},
           'sitewise_stats=s'                         => \$self->{'_sitewise_stats'},
           'slr_query=s'                              => \$self->{'_slr_query'},
           'sampling_orang=s'                         => \$self->{'_sampling_orang'},
           'singl_tb=s'                               => \$self->{'_singl_tb'},
           'cox=s'                                    => \$self->{'_cox'},
           'remove_duplicates_orthotree=s'            => \$self->{'_remove_duplicates_orthotree'},
           'remove_duplicates_genesets=s'             => \$self->{'_remove_duplicates_genesets'},
           'fel=s'                                    => \$self->{'_fel'},
           'slac=s'                                   => \$self->{'_slac'},
           'summary_stats=s'                          => \$self->{'_summary_stats'},
           'dnds_msas=s'                              => \$self->{'_dnds_msas'},
           'dnds_go=s'                                => \$self->{'_dnds_go'},
           'viral_genes=s'                            => \$self->{'_viral_genes'},
           'canonical_translation_gene_transcript_list' => \$self->{'_canonical_translation_gene_transcript_list'},
           'binning=s' =>                               \$self->{'_binning'},
           'member_bin=s' =>                               \$self->{'_member_bin'},
           'indelible=s'                                => \$self->{'_indelible'},
           'species_intersection'                     => \$self->{'_species_intersection'},
           'hmm_build=s'                              => \$self->{'_hmm_build'},
           'hbpd=s'                              => \$self->{'_hbpd'},
           'hmm_search=s'                             => \$self->{'_hmm_search'},
           '2xeval=s'                                 => \$self->{'_2xeval'},
           'uce=s'                                    => \$self->{'_uce'},
           'circos=s'                                 => \$self->{'_circos'},
           'circos_synt=s'                            => \$self->{'_circos_synt'},
           'zmenu_prof=s'                             => \$self->{'_zmenu_prof'},
           'simplealign_prof=s'                       => \$self->{'_simplealign_prof'},
           'mxe_metatranscript=s'                     => \$self->{'_mxe_metatranscript'},
           'check_read_clustering=s'                  => \$self->{'_check_read_clustering'},
           'check_velvet_coverage=s'                  => \$self->{'_check_velvet_coverage'},
           'cov_reads=s'                              => \$self->{'_cov_reads'},
           'take_mix=s'                               => \$self->{'_take_mix'},
           'dump_exon_boundaries=s'                   => \$self->{'_dump_exon_boundaries'},
           'dump_genetree_slices=s'                   => \$self->{'_dump_genetree_slices'},
           'dump_proteome_slices=s'                   => \$self->{'_dump_proteome_slices'},
           'timetree_pairwise=s'                      => \$self->{'_timetree_pairwise'},
           'de_bruijn_naming=s'                       => \$self->{'_de_bruijn_naming'},
           'transcript_pair_exonerate=s'              => \$self->{'_transcript_pair_exonerate'},
           'synteny_metric=s'                         => \$self->{'_synteny_metric'},
           'compare_api_treefam=s'                    => \$self->{'_compare_api_treefam'},
           'compare_phyop=s'                          => \$self->{'_compare_phyop'},
           'interpro_coverage=s'                      => \$self->{'_interpro_coverage'},
           'extra_dn_ds=s'                            => \$self->{'_extra_dn_ds'},
           'genomic_aln=s'                            => \$self->{'_genomic_aln'},
           'species_set_tag=s'                        => \$self->{'_species_set_tag'},
           'compare_homologene_refseq=s'              => \$self->{'_compare_homologene_refseq'},
           'benchmark_tree_node_id=s'                 => \$self->{'_benchmark_tree_node_id'},
           'treefam_aln_plot=s'                       => \$self->{'_treefam_aln_plot'},
           'species_set=s'                            => \$self->{'_species_set'},
           'sisrates=s'                               => \$self->{'_sisrates'},
           'print_as_species_ids=s'                   => \$self->{'_print_as_species_ids'},
           'size_clusters=s'                          => \$self->{'_size_clusters'},
           'taxon_name_genes=s'                       => \$self->{'_taxon_name_genes'},
           'ncbi_tree_list_shortnames=s'              => \$self->{'_ncbi_tree_list_shortnames'},
           '_badgenes|badgenes'                       => \$self->{'_badgenes'},
           '_farm|farm=s'                             => \$self->{'_farm'},
           '_modula|modula=s'                         => \$self->{'_modula'},
          );

# This may break other peoples scripts or assumptions
$self->{'clusterset_id'} ||= 1;

if ($help) {
  usage();
}

if ($url) {
  eval { require Bio::EnsEMBL::Hive::URLFactory;};
  if ($@) {
    # Crude alternative to parsing the url
    # format is mysql://user:pass@host/dbname
    $url =~ /mysql\:\/\/(\S+)\@(\S+)\/(\S+)/g;
    my ($myuserpass,$myhost,$mydbname) = ($1,$2,$3);
    my ($myuser,$mypass);
    if ($myuserpass =~ /(\S+)\:(\S+)/) {
      $myuser = $1;
      $mypass = $1;
    } else {
      $myuser = $myuserpass;
    }
    $compara_conf{-user} = $myuser;
    $compara_conf{-pass} = $mypass if (defined($mypass));
    $compara_conf{-host} = $myhost;
    $compara_conf{-dbname} = $mydbname;
    eval { $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf); }
  } else {
    $self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url . ';type=compara');
  }
} else {
  eval { $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf); }
}
unless (defined $self->{'newick_file'} || defined($self->{'comparaDBA'})) {
  print("couldn't connect to compara database or get a newick file\n\n");
  usage();
}

#
# load tree
#

# internal purposes
if ($self->{'_list_defs'}) {
  my @treeids_list = split (":", $self->{'_list_defs'});
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  foreach my $tree_id (@treeids_list) {
    $self->{'tree'} = $treeDBA->fetch_node_by_node_id($tree_id);
    # leaves are Bio::EnsEMBL::Compara::GeneTreeMember objects
    my $leaves = $self->{'tree'}->get_all_leaves;
    #printf("fetched %d leaves\n", scalar(@$leaves));
    printf("treeid %d, %d proteins ########################################\n", $tree_id, scalar(@$leaves));
    foreach my $leaf (@$leaves) {
      #$leaf->print_node;
      my $gene = $leaf->gene_member;
      my $desc = $gene->description;
      $desc = "" unless($desc);
      $desc = "Description : " . $desc if ($desc);
      printf("%s %s : %s\n", $leaf->name,$gene->stable_id, $desc);
    }
    #printf("\n");
    $self->{'tree'}->release_tree;
  }
}

if ($self->{'tree_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($self->{'tree_id'});
} elsif ($self->{'nc_tree_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_NCTreeAdaptor;
  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($self->{'nc_tree_id'});
} elsif ($self->{'tree_stable_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $tree_stable_idDBA = $self->{'comparaDBA'}->get_ProteinTreeStableIdAdaptor;
  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($tree_stable_idDBA->fetch_node_id_by_stable_id($self->{'tree_stable_id'}));
  $DB::single=1;1;
} elsif ($self->{'gene_stable_id'} and $self->{'clusterset_id'} and $self->{orthotree} and !defined($self->{_homology_list})) {
  fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'});
  $self->{'clusterset_id'} = undef;
  _run_orthotree($self);
} elsif ($self->{'gene_stable_id'} and $self->{'clusterset_id'} and !defined($self->{_homology_list})) {
  fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'});
  $self->{'clusterset_id'} = undef;
} elsif (defined($self->{_homology_list})) {
  homology_list($self, $self->{'_homology_list'});
  $self->{'clusterset_id'} = undef;
} elsif ($self->{'newick_file'}) {
  parse_newick($self);
} elsif ($self->{'_treefam_file'}) {
  # internal purposes
  _compare_treefam($self);
  $self->{'keep_leaves'} = 0;
}

if ($self->{'keep_leaves'}) {
  keep_leaves($self);
}

#
# do tree stuff to it
#
if ($self->{'tree'}) {
  if ($self->{'parent'} and $self->{'tree'}->parent) {
    $self->{'tree'} = $self->{'tree'}->parent;
  }

  $self->{'tree'}->disavow_parent;
  #$self->{'tree'}->get_all_leaves;
  #printf("get_all_leaves gives %d proteins\n", scalar(@{$self->{'tree'}->get_all_leaves}));
  #$self->{'tree'}->flatten_tree;

  if ($self->{'new_root_id'}) {
    reroot($self);
  }

  #test7($self);
  if ($self->{'balance_tree'}) {
    balance_tree($self);
  }

  if ($self->{'chop_tree'}) {
    Bio::EnsEMBL::Compara::Graph::Algorithms::chop_tree($self->{'tree'});
  }

  if ($self->{'exclude_taxa'}) {
    my @to_delete;
    foreach my $taxon_id (split(":",$self->{'exclude_taxa'})) {
      push @to_delete, $taxon_id;
    }

    $self->{tree} = $self->{tree}->remove_nodes_by_taxon_ids(\@to_delete);

  }

  #
  # display and statistics routines
  #
  if ($self->{'print_tree'}) {
    $self->{'tree'}->print_tree($self->{'scale'});
    printf("%d proteins\n", scalar(@{$self->{'tree'}->get_all_leaves}));
  }
  if ($self->{'print_leaves'}) {
    # leaves are Bio::EnsEMBL::Compara::GeneTreeMember objects
    my $leaves = $self->{'tree'}->get_all_leaves;
    printf("fetched %d leaves\n", scalar(@$leaves));
    foreach my $leaf (@$leaves) {
      #$leaf->print_node;
      my $gene = $leaf->gene_member;
      my $desc = $gene->description;
      $desc = "" unless($desc);
      printf("%25s %25s : %s\n", $leaf->name,$gene->stable_id, $desc);
    }
    printf("%d proteins\n", scalar(@$leaves));
  }

  if ($self->{'print_newick'}) {
    dumpTreeAsNewick($self, $self->{'tree'});
  }

  if ($self->{'print_nhx'}) {
    dumpTreeAsNHX($self, $self->{'tree'});
  }

  if ($self->{'counts'}) {
    print_cluster_counts($self);
    print_cluster_counts($self, $self->{'tree'});
  }

  if ($self->{'print_align'}) {
    $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\w+)$/g;
    my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
    my $port = 3306;
    if ($myhost =~ /(\S+)\:(\S+)/) {
      $port = $2;
      $myhost = $1;
    }
    Bio::EnsEMBL::Registry->load_registry_from_db
        ( -host => "$myhost",
          -user => "$myuser",
          -db_version => "$mydbversion",
          -port => "$port",
          -verbose => "0" );
    dumpTreeMultipleAlignment($self);
  }

  if ($self->{'output_fasta'}) {
    dumpTreeFasta($self);
  }

  if ($self->{'drawtree'}) {
    drawPStree($self);
  }

  #cleanup memory
  #print("ABOUT TO MANUALLY release tree\n");
  $self->{'tree'}->release_tree unless ($self->{_treefam});
  $self->{'tree'} = undef;
  #print("DONE\n");
}

#
# clusterset stuff
#

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_pattern'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _analyzePattern($self) if($self->{'_pattern'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_topolmis'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _topology_mismatches($self) if($self->{'_topolmis'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_duploss'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _get_all_duploss_fractions($self) if(defined($self->{'_duploss'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_gap_contribution'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  my $species = $self->{_species} || "Homo sapiens";
  _gap_contribution($self,$species) if(defined($self->{'_gap_contribution'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_gene_bootstrap_coef'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _gene_bootstrap_coef($self) if(defined($self->{'_gene_bootstrap_coef'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_tree_bootstrap_dupconf'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _tree_bootstrap_dupconf($self) if(defined($self->{'_tree_bootstrap_dupconf'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_split_genes_stats'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _split_genes_stats($self) if(defined($self->{'_split_genes_stats'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_merge_split_genes'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _merge_split_genes($self) if(defined($self->{'_merge_split_genes'}));

  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_phylowidget_tests'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _phylowidget_tests($self) if(defined($self->{'_phylowidget_tests'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_phylogenomics'}) {
  _phylogenomics($self) if(defined($self->{'_phylogenomics'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_phylogenomics_separate'}) {
  _phylogenomics_separate($self) if(defined($self->{'_phylogenomics_separate'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_phylogenomics_pc'}) {
  _phylogenomics_pc($self) if(defined($self->{'_phylogenomics_pc'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_phylogenomics_concat'}) {
  _phylogenomics_concat($self) if(defined($self->{'_phylogenomics_concat'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_fasta2phylip_disk'}) {
  _fasta2phylip_disk($self) if(defined($self->{'_fasta2phylip_disk'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_treefam_guess_name'}) {
  _treefam_guess_name($self) if(defined($self->{'_treefam_guess_name'}));
  exit(0);
}

# internal purposes
if ($self->{'_loose_assoc'}) {
  my $species = $self->{_species} || "Homo sapiens";
  _loose_assoc($self,$species) if(defined($self->{'_loose_assoc'}));

  exit(0);
}

# internal purposes
if ($self->{'_paf_stats'}) {
  my $species = $self->{_species} || "Homo sapiens";
  _paf_stats($self,$species) if(defined($self->{'_paf_stats'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_per_residue_g_contribution'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  my $species = $self->{_species} || "Homo sapiens";
  my $gap_proportion = $self->{_gap_proportion} || 0.5;
  my $modula = $self->{_modula} or throw("need a modula number for dividing the jobs");
  my $farm = $self->{_farm} or throw("need a farm number for dividing the jobs");
  _per_residue_g_contribution($self,$species,$gap_proportion,$modula,$farm) if(defined($self->{'_per_residue_g_contribution'}));

  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_distances_taxon_level'}) {
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _distances_taxon_level($self, $species) if(defined($self->{'_distances_taxon_level'}));

  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_duphop'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _duphop($self, $species) if(defined($self->{'_duphop'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_duphop_subtrees'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _duphop_subtrees($self, $species, $self->{'_duphop_subtrees'}) if(defined($self->{'_duphop_subtrees'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_duphop_subtrees_global'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _duphop_subtrees_global($self, $species, $self->{'_duphop_subtrees_global'}) if(defined($self->{'_duphop_subtrees_global'}));

  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_dnds_pairs'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species1 = $self->{_species1} || "Homo sapiens";
  my $species2 = $self->{_species2} || "Mus musculus";
  $species1 =~ s/\_/\ /g;
  $species2 =~ s/\_/\ /g;
  _dnds_pairs($self, $species1, $species2) if(defined($self->{'_dnds_pairs'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_dnds_paralogs'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species = $self->{_species} || "Homo_sapiens";
  $species =~ s/\_/\ /g;
  _dnds_paralogs($self, $species) if(defined($self->{'_dnds_paralogs'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_dnds_doublepairs'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta:Otolemur_garnettii";
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _dnds_doublepairs($self, $species_set) if(defined($self->{'_dnds_doublepairs'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_merge_small_trees'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes";
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _merge_small_trees($self, $species_set) if(defined($self->{'_merge_small_trees'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_concatenation'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta:Mus_musculus:Rattus_norvegicus";
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _concatenation($self, $species_set) if(defined($self->{'_concatenation'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_slr'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta";
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _slr($self, $species_set) if(defined($self->{'_slr'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_slr_subtrees'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _slr_subtrees($self) if(defined($self->{'_slr_subtrees'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_codeml_mutsel'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _codeml_mutsel($self) if(defined($self->{'_codeml_mutsel'}));

  exit(0);
}


if ($self->{'clusterset_id'} && $self->{'_slr_das'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _slr_das($self) if(defined($self->{'_slr_das'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_genetree_domains'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _genetree_domains($self) if(defined($self->{'_genetree_domains'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_query_sitewise_domains'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _query_sitewise_domains($self) if(defined($self->{'_query_sitewise_domains'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_simul_genetrees'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _simul_genetrees($self) if(defined($self->{'_simul_genetrees'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_gblocks_species'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _gblocks_species($self) if(defined($self->{'_gblocks_species'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_genetree_to_mcl'}) {
  _genetree_to_mcl($self) if(defined($self->{'_genetree_to_mcl'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_clm_dist_input'}) {
  _clm_dist_input($self) if(defined($self->{'_clm_dist_input'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_family_pid'}) {
  _family_pid($self) if(defined($self->{'_family_pid'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_genetreeview_mcv'}) {
  _genetreeview_mcv($self) if(defined($self->{'_genetreeview_mcv'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_ensembl_alias_name'}) {
  _ensembl_alias_name($self) if(defined($self->{'_ensembl_alias_name'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_pep_splice_site'}) {
  _pep_splice_site($self) if(defined($self->{'_pep_splice_site'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_prank_test'}) {
  _prank_test($self) if(defined($self->{'_prank_test'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_sitewise_stats'}) {
  _sitewise_stats($self) if(defined($self->{'_sitewise_stats'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_slr_query'}) {
  _slr_query($self) if(defined($self->{'_slr_query'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_sampling_orang'}) {
  _sampling_orang($self) if(defined($self->{'_sampling_orang'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_singl_tb'}) {
  _singl_tb($self) if(defined($self->{'_singl_tb'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_cox'}) {
  _cox($self) if(defined($self->{'_cox'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_remove_duplicates_orthotree'}) {
  _remove_duplicates_orthotree($self) if(defined($self->{'_remove_duplicates_orthotree'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_remove_duplicates_genesets'}) {
  _remove_duplicates_genesets($self) if(defined($self->{'_remove_duplicates_genesets'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_cafe_genetree'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _cafe_genetree($self) if(defined($self->{'_cafe_genetree'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_fel'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta";
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _fel($self, $species_set) if(defined($self->{'_fel'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_slac'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta";
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _slac($self, $species_set) if(defined($self->{'_slac'}));

  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_summary_stats'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _summary_stats($self) if(defined($self->{'_summary_stats'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_dnds_msas'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species_set = $self->{_species_set} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta:Otolemur_garnettii";
  _dnds_msas($self, $species_set) if(defined($self->{'_dnds_msas'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_dnds_go'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my $species_set = $self->{_species_set} || "Homo_sapiens:Mus_musculus";
  _dnds_go($self, $species_set) if(defined($self->{'_dnds_go'}));

  exit(0);
}


# internal purposes
if ($self->{'_ncbi_tree_list_shortnames'}) {
  _ncbi_tree_list_shortnames($self);

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_homologs_and_paf_scores'}) {
  my $species = $self->{_species} || "Homo sapiens";
  $species =~ s/\_/\ /g;
  _homologs_and_paf_scores($self, $species) if(defined($self->{'_homologs_and_paf_scores'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_homologs_and_dnaaln'}) {
  my $species1 = $self->{_species1} || "Homo sapiens";
  my $species2 = $self->{_species2} || "Mus musculus";
  $species1 =~ s/\_/\ /g;
  $species2 =~ s/\_/\ /g;
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _homologs_and_dnaaln($self, $species1, $species2) if(defined($self->{'_homologs_and_dnaaln'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_consistency_orthotree_member_id'} && $self->{'_consistency_orthotree_mlss'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my $aligned_member = $treeDBA->
    fetch_AlignedMember_by_member_id_root_id ( $self->{_consistency_orthotree_member_id}, $self->{'clusterset_id'});
  return 0 unless (defined $aligned_member);
  my $node = $aligned_member->subroot;

  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;
  _consistency_orthotree($self) if($self->{'_consistency_orthotree_member_id'} && $self->{'_consistency_orthotree_mlss'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_pafs'}) {
  my $gdb = $self->{_species} || "22";
  _pafs($self, $gdb) if(defined($self->{'_pafs'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'delete_leaves_species'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  delete_leaves_species($self) if(defined($self->{'delete_leaves_species'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_duprates'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _get_all_duprates_for_species_tree($self) if(defined($self->{'_duprates'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_family_expansions'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _family_expansions($self,$self->{'_species'}) if(defined($self->{'_family_expansions'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_viral_genes'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _viral_genes($self,$self->{'_species'}) if(defined($self->{'_viral_genes'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_canonical_translation_gene_transcript_list'}) {
  _canonical_translation_gene_transcript_list($self,$self->{'_species'}) 
    if (defined($self->{'_canonical_translation_gene_transcript_list'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_binning'}) {
  _binning($self,$self->{'_species'}) 
    if (defined($self->{'_binning'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_member_bin'}) {
  _member_bin($self,$self->{'_species'}) 
    if (defined($self->{'_member_bin'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_indelible'}) {
  _indelible($self);
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_species_intersection'}) {
  _species_intersection($self,$self->{'species_list'}) if(defined($self->{'_species_intersection'}));

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_hmm_build'}) {
  _hmm_build($self) if(defined($self->{'_hmm_build'}));
  exit(0);
}


# internal purposes
if ($self->{'clusterset_id'} && $self->{'_hbpd'}) {
  _hbpd($self) if(defined($self->{'_hbpd'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_hmm_search'}) {
  _hmm_search($self) if(defined($self->{'_hmm_search'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_2xeval'}) {
  _2xeval($self) if(defined($self->{'_2xeval'}));
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_uce'}) {
  _uce($self) if(defined($self->{'_uce'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_circos'}) {
  _circos($self) if(defined($self->{'_circos'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_circos_synt'}) {
  _circos_synt($self) if(defined($self->{'_circos_synt'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_zmenu_prof'}) {
  _zmenu_prof($self) if(defined($self->{'_zmenu_prof'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_simplealign_prof'}) {
  _simplealign_prof($self) if(defined($self->{'_simplealign_prof'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_mxe_metatranscript'}) {
  _mxe_metatranscript($self) if(defined($self->{'_mxe_metatranscript'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_check_read_clustering'}) {
  _check_read_clustering($self) if(defined($self->{'_check_read_clustering'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_check_velvet_coverage'}) {
  _check_velvet_coverage($self) if(defined($self->{'_check_velvet_coverage'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_dump_exon_boundaries'}) {
  _dump_exon_boundaries($self) if(defined($self->{'_dump_exon_boundaries'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_dump_genetree_slices'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  _dump_genetree_slices($self) if(defined($self->{'_dump_genetree_slices'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_dump_proteome_slices'}) {
  _dump_proteome_slices($self) if(defined($self->{'_dump_proteome_slices'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_timetree_pairwise'}) {
  _timetree_pairwise($self) if(defined($self->{'_timetree_pairwise'}));
  exit(0);
}

if ($self->{'clusterset_id'} && $self->{'_de_bruijn_naming'}) {
  _de_bruijn_naming($self) if(defined($self->{'_de_bruijn_naming'}));
  exit(0);
}

# internal purposes
if ($self->{'_transcript_pair_exonerate'}) {
  _transcript_pair_exonerate($self) if(defined($self->{'_transcript_pair_exonerate'}));

  exit(0);
}

# internal purposes
if ($self->{'_synteny_metric'}) {
  _synteny_metric($self) if(defined($self->{'_synteny_metric'}));
}

# internal purposes
if ($self->{'_compare_api_treefam'}) {
  _compare_api_treefam($self) if(defined($self->{'_compare_api_treefam'}));
}

# internal purposes
if ($self->{'_compare_phyop'}) {
  _compare_phyop($self) if(defined($self->{'_compare_phyop'}));
}

# internal purposes
if ($self->{'_compare_homologene_refseq'}) {
  _compare_homologene_refseq($self) if(defined($self->{'_compare_homologene_refseq'}));
}

# internal purposes
if ($self->{'_interpro_coverage'}) {
  _interpro_coverage($self) if(defined($self->{'_interpro_coverage'}));
}

# internal purposes
if ($self->{'_extra_dn_ds'}) {
  _extra_dn_ds($self) if(defined($self->{'_extra_dn_ds'}));
}

# internal purposes
if ($self->{'_genomic_aln'}) {
  _genomic_aln($self) if(defined($self->{'_genomic_aln'}));
}

# internal purposes
if ($self->{'_species_set_tag'}) {
  _species_set_tag($self) if(defined($self->{'_species_set_tag'}));
}

if ($self->{'_analysis_job_trace'}) {
  _analysis_job_trace($self) if(defined($self->{'_analysis_job_trace'}));
}

if ($self->{'_nytprof_get_homologous_peptide_ids_from_gene'}) {
  _nytprof_get_homologous_peptide_ids_from_gene($self) if(defined($self->{'_nytprof_get_homologous_peptide_ids_from_gene'}));
}

# internal purposes
if ($self->{'_benchmark_tree_node_id'}) {
  _benchmark_tree_node_id($self) if(defined($self->{'_benchmark_tree_node_id'}));
}

# internal purposes
if ($self->{'_treefam_aln_plot'}) {
  _treefam_aln_plot($self) if(defined($self->{'_treefam_aln_plot'}));
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_print_as_species_ids'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _print_as_species_ids($self) if(defined($self->{'_print_as_species_ids'}));

  exit(0);
}



# internal purposes
if ($self->{'clusterset_id'} && $self->{'_sisrates'}) {
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  if ($self->{_inputfile}) {
    _get_all_duprates_for_species_tree_sis_genelist($self) if(defined($self->{'_sisrates'}));
  } else {
    _get_all_duprates_for_species_tree_sis($self) if(defined($self->{'_sisrates'}));
  }
  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_taxon_name_genes'}) {
  _get_all_genes_for_taxon_name($self) if(defined($self->{'_taxon_name_genes'}));

  exit(0);
}


# internal purposes
if (defined($self->{'clusterset_id'}) && $self->{'_size_clusters'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _size_clusters($self) if($self->{'_size_clusters'});

  exit(0);
}

# internal purposes
if (defined($self->{'clusterset_id'}) && $self->{'_check_mfurc'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _check_mfurc($self) if($self->{'_check_mfurc'});

  exit(0);
}

# internal purposes
if ($self->{'clusterset_id'} && $self->{'_analyze_homologies'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
  _analyzeHomologies($self) if(defined($self->{'_analyze_homologies'}));

  exit(0);
}


# if (defined($self->{'clusterset_id'}) && !($self->{'_treefam_file'}) && !($self->{'keep_leaves_species'})) {
#   my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#   #  printf("loaded %d clusters\n", $self->{'clusterset'}->get_child_count);
#   #  analyzeClusters2($self) if($self->{'analyze'});
#   #  analyzeClusters($self) if($self->{'analyze'});

#   dumpAllTreesToNewick($self) if($self->{'print_newick'});
#   dumpAllTreesToNHX($self) if($self->{'print_nhx'});

#   #   if($self->{'counts'}) {
#   #     print_cluster_counts($self);
#   #     foreach my $cluster (@{$self->{'clusterset'}->children}) {
#   #       print_cluster_counts($self, $cluster);
#   #     }
#   #   }
#   $self->{'clusterset'} = undef;
# }

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "geneTreeTool.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <url>             : connect to compara at url\n";
  print "\n";
  print "  -tree_id <id>          : fetch tree with node_id\n";
  print "  -gene <stable_id>      : fetch tree which contains gene_stable_id\n";
  print "  -file <path>           : parse tree from Newick format file\n";
  print "\n";
  print "  -treefam_file <path>   : parse tree from treefam and compare to genetree db (clusterset_id req)\n";
  print "\n";
  print "  -align                 : output protein multiple alignment\n";
  print "  -cdna                  : output cdna multiple alignment\n";
  print "  -align_format          : alignment format (see perldoc Bio::AlignIO) (def:phylip)\n";
  print "\n";
  print "  -print_tree            : print ASCII formated tree\n";
  print "  -scale <num>           : scale factor for printing tree (def: 100)\n";
  print "  -newick                : output tree(s) in newick format\n";
  print "  -nhx                   : output tree(s) in newick extended (NHX) format with duplication tags\n";
  print "    -nhx_protein_id      : protein_ids in the leaf names for newick extended (NHX) format\n";
  print "    -nhx_gene_id         : gene_ids in the leaf names for newick extended (NHX) format\n";
  print "    -nhx_transcript_id   : transcript_ids in the leaf names for newick extended (NHX) format\n";
  print "  -reroot <id>           : reroot genetree on node_id\n";
  print "  -parent                : move up to the parent of the loaded node\n";
  print "  -dump                  : outputs to autonamed file, not STDOUT\n";
  print "  -draw                  : use PHYLIP drawtree to create ps output\n";
  print "  -counts                : return counts of proteins within tree nestedset\n";
  print "\n";
  print "  -clusterset_id <id>    : load all clusters\n"; 
  print "  -analyze               : perform rosette analysis on all clusters\n"; 
  print "  -newick                : combination of clusterset_id and newick dumps all\n"; 
  print "  -counts                : return counts of each cluster\n";
  print "  -keep_leaves <string>  : if you want to trim your tree and keep a list of leaves (by \$leaf->name) e.g. \"human,mouse,rat\"\n";
  print "geneTreeTool.pl v1.22\n";
  exit(1);
}



sub fetch_protein_tree_with_gene {
  my $self = shift;
  my $gene_stable_id = shift;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

  my $member = $self->{'comparaDBA'}->
    get_MemberAdaptor->
      fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
  return 0 unless (defined $member);
  my $aligned_member = $treeDBA->
    fetch_AlignedMember_by_member_id_root_id( $member->get_canonical_peptide_Member->member_id, $self->{'clusterset_id'});
  return 0 unless (defined $aligned_member);
  my $node = $aligned_member->subroot;

  $self->{'tree'} = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;
  return 1;
}

sub homology_list {
  my $self = shift;
  my $gene_stable_id = shift;

  my $member = $self->{comparaDBA}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
  next unless (defined $member);

  my $species2 = $self->{_species2} || "none";
  $species2 =~s/\_/\ /g;

  $self->{ha} = $self->{'comparaDBA'}->get_HomologyAdaptor;
  my $homologies;

  if ("none" eq $species2) {
    $homologies = $self->{ha}->fetch_all_by_Member($member);
  } else {
    $homologies = $self->{ha}->fetch_all_by_Member_paired_species($member,$species2);
  }

  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $taxonomy_leaf = $self->{taxonDBA}->fetch_node_by_name($member->genome_db->name);
  my $taxonomy_root = $taxonomy_leaf->subroot;
  my $taxonomy_parent = $taxonomy_leaf;
  my %taxonomy_hierarchy;
  my $hierarchy_count = 0;
  do {
    $hierarchy_count++;
    $hierarchy_count = sprintf("%03d",$hierarchy_count);
    $taxonomy_hierarchy{$taxonomy_parent->name} = $hierarchy_count;
    $taxonomy_parent = $taxonomy_parent->parent;
  } while ($taxonomy_parent->dbID != $taxonomy_root->dbID);

  foreach my $homology (@$homologies) {
    my ($m1,$m2) = @{$homology->gene_list};
    my $m1_stable_id = $m1->stable_id;
    my $m2_stable_id = $m2->stable_id;
    my $description = $homology->description;
    my $subtype = $homology->subtype;
    $self->{_homology_list_taxonomy_hierarchy}{$taxonomy_hierarchy{$subtype}}{$m2_stable_id} = "$m1_stable_id,$m2_stable_id,$description,$subtype\n";
  }
  foreach my $hierarchy (sort keys %{$self->{_homology_list_taxonomy_hierarchy}}) {
    foreach my $member2 (sort keys %{$self->{_homology_list_taxonomy_hierarchy}{$hierarchy}}) {
      my $string = $self->{_homology_list_taxonomy_hierarchy}{$hierarchy}{$member2};
      print $string;
    }
  }
  return 1;
}

sub parse_newick {
  my $self = shift;

  my $newick = '';
  print("load from file ", $self->{'newick_file'}, "\n");
  open (FH, $self->{'newick_file'}) or throw("Could not open newick file [$self->{'newick_file'}]");
  while (<FH>) {
    $newick .= $_;
  }
  printf("newick string: $newick\n");
  $self->{'tree'} = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
}

sub keep_leaves {
  my $self = shift;
  my $provided_tree = shift;

  my %leaves_names;
  foreach my $name (split(",",$self->{'keep_leaves'})) {
    $leaves_names{$name} = 1;
  }

  print join(" ",keys %leaves_names),"\n" if $self->{'$debug'};
  my $tree = $provided_tree || $self->{'tree'};

  foreach my $leaf (@{$tree->get_all_leaves}) {
    unless (defined $leaves_names{$leaf->name}) {
      print $leaf->name," leaf disavowing parent\n" if $self->{'$debug'};
      $leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  unless (defined($provided_tree)) {
    $self->{'tree'} = $tree;
  } else {
    return $tree;
  }
}

sub delete_leaves_species {
  my $self = shift;
  my $provided_tree = shift;

  my $tree = $provided_tree || $self->{'tree'};
  my $string = $self->{delete_leaves_species};
  my @to_delete;
  $DB::single=1;1;
  foreach my $taxon_id (split(":",$self->{'delete_leaves_species'})) {
    push @to_delete, $taxon_id;
  }

  $tree->print_tree(10);
  my $ret = $tree->remove_nodes_by_taxon_ids(\@to_delete);
  $ret->print_tree(10);
}

sub keep_leaves_species_old {
  my $self = shift;
  my $provided_tree = shift;

  my $tree = $provided_tree || $self->{'tree'};
  my $string = $self->{keep_leaves_species};
  $string =~ s/\:/\|/g;
  $string =~ s/\_/\ /g;
  my @to_delete;
#   foreach my $node ($tree->get_all_subnodes) {
#     my $value = $node->get_tagvalue("taxon_name");
#     push @to_delete, $node if ($value =~ /heria/);
#   }
  @to_delete = @{$tree->get_all_leaves};
  my $ret = $tree->remove_nodes(\@to_delete);
  # @to_delete = grep{ $_->genome_db->name !~ /$string/ } @{$tree->get_all_leaves};
#   my $ret = $tree->remove_nodes(\@to_delete);
  unless (defined($provided_tree)) {
    $self->{'tree'} = $tree;
  } else {
    return $tree;
  }
}

sub keep_leaves_species_older {
  my $self = shift;
  my $provided_tree = shift;

  my %species_names;
  foreach my $name (split(":",$self->{'keep_leaves_species'})) {
    $name =~ s/\_/\ /g;
    $species_names{$name} = 1;
  }

  print join(" ",keys %species_names),"\n" if $self->{'$debug'};
  my $tree = $provided_tree || $self->{'tree'};

  foreach my $leaf (@{$tree->get_all_leaves}) {
    my $species = $leaf->genome_db->name;
    unless (defined $species_names{$species}) {
      print $leaf->name," leaf disavowing parent\n" if $self->{'debug'};
      $leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  unless (defined($provided_tree)) {
    $self->{'tree'} = $tree;
  } else {
    return $tree;
  }
}


sub reroot {
  my $self = shift;
  my $node_id = $self->{'new_root_id'};

  #my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  #my $node = $treeDBA->fetch_node_by_node_id($node_id);  
  #printf("tree at %d\n", $node->subroot->node_id);
  #my $tree = $treeDBA->fetch_node_by_node_id($node->subroot->node_id);  
  
  my $tree = $self->{'tree'};
  $tree->get_all_leaves;  #make sure entire tree is loaded into memory
  #$tree->print_tree($self->{'scale'});

  my $reroot_node = $tree->find_node_by_node_id($node_id);
  return unless $reroot_node;

  #print("unlink tree from clusterset\n");
  my $parent = $tree->parent;
  my $dist = $tree->distance_to_parent;
  $tree->disavow_parent;
  
  $reroot_node->re_root;
  
  $parent->add_child($tree, $dist);
  
  #$treeDBA->store($tree);
  #$treeDBA->delete_node($new_root);
}



sub dumpTreeMultipleAlignment
  {
    my $self = shift;
  
    warn("missing tree\n") unless($self->{'tree'});
  
    my $tree = $self->{'tree'};

    my $sa;

    if ($self->{append_taxon_id}) {
      $sa = $tree->get_SimpleAlign(-id_type => 'MEMBER',-cdna=>$self->{'cdna'},-stop2x => 1,-append_taxon_id => 1,-exon_cased=>$self->{'exon_cased'});
    } elsif ($self->{align_member_id}) {
      $sa = $tree->get_SimpleAlign(-id_type => 'MEMBER',-cdna=>$self->{'cdna'},-stop2x => 1,-exon_cased=>$self->{'exon_cased'});
    } else {
      $sa = $tree->get_SimpleAlign(-id_type => 'STABLE', -UNIQ_SEQ=>1, -cdna=>$self->{'cdna'},-exon_cased=>$self->{'exon_cased'});
    }
    $sa->set_displayname_flat(1);
    $sa = $sa->remove_gaps(undef,1);
    $sa->set_displayname_flat(1);

    if ($self->{'dump'}) {
      my $aln_file = "proteintree_". $tree->node_id;
      $aln_file =~ s/\/\//\//g; # converts any // in path to /
      $aln_file .= ".cdna" if($self->{'cdna'});
      $aln_file .= "." . $self->{'align_format'};
    
      print("aln_file = '$aln_file'\n") if($self->{'debug'});

      open(OUTSEQ, ">$aln_file")
        or $self->throw("Error opening $aln_file for write");
    } else {
      open OUTSEQ, ">&STDOUT";
    }
  
    if ($self->{'debug'}) {
      my $leafcount = scalar(@{$tree->get_all_leaves});  
      printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    }

    my $alignIO = Bio::AlignIO->newFh(-fh => \*OUTSEQ,
                                      -interleaved => 0,
                                      -format => $self->{'align_format'}
                                     );
    print $alignIO $sa;
    close OUTSEQ;
  }


sub dumpTreeAsNewick 
  {
    my $self = shift;
    my $tree = shift;

    warn("missing tree\n") unless($tree);

    # newick_simple_format is a synonymous of newick_format method
    my $newick = $tree->newick_simple_format;

    if ($self->{'dump'}) {
      my $newick_file = "proteintree_". $tree->node_id;
      $newick_file = $self->{'dump'} if (1 < length($self->{'dump'})); #wise naming
      $newick_file =~ s/\/\//\//g; # converts any // in path to /
      $newick_file .= ".newick";

      $self->{'newick_file'} = $newick_file;

      open(OUTSEQ, ">$newick_file")
        or $self->throw("Error opening $newick_file for write");
    } else {
      open OUTSEQ, ">&STDOUT";
    }

    print $self->{tree}->newick_format("otu_id") if $self->{debug}; 
    print "\n";

    print OUTSEQ "$newick\n\n";
    close OUTSEQ;
  }

sub dumpTreeAsNHX 
  {
    my $self = shift;
    my $tree = shift;
  
    if (defined($self->{keep_leaves_species})) {
      $self->keep_leaves_species;
      $tree = $self->{tree};
    }
    warn("missing tree\n") unless($tree);

    # newick_simple_format is a synonymous of newick_format method
    my $nhx;
    if ($self->{'nhx_gene_id'}) {
      $nhx = $tree->nhx_format("gene_id");
    } elsif ($self->{'nhx_protein_id'}) {
      $nhx = $tree->nhx_format("protein_id");
    } elsif ($self->{'nhx_transcript_id'}) {
      $nhx = $tree->nhx_format("transcript_id");
    } elsif ($self->{'nhx_display_label_composite'}) {
      $nhx = $tree->nhx_format("display_label_composite");
    } elsif ($self->{'nhx_treebest_ortho'}) {
      $nhx = $tree->nhx_format("treebest_ortho");
    } elsif ($self->{'otu_id'}) {
      $nhx = $tree->nhx_format("protein_id");
    } else {
      $nhx = $tree->nhx_format;
    }

    if ($self->{'dump'}) {
      my $aln_file = "proteintree_". $tree->node_id;
      $aln_file =~ s/\/\//\//g; # converts any // in path to /
      $aln_file .= ".nhx";
    
      # we still call this newick_file as we dont need it for much else
      $self->{'newick_file'} = $aln_file;
    
      open(OUTSEQ, ">$aln_file")
        or $self->throw("Error opening $aln_file for write");
    } else {
      open OUTSEQ, ">&STDOUT";
    }

    print OUTSEQ "$nhx\n\n";
    close OUTSEQ;
  }

sub drawPStree
  {
    my $self = shift;
  
    unless ($self->{'newick_file'}) {
      $self->{'dump'} = 1;
      dumpTreeAsNewick($self, $self->{'tree'});
    }
  
    my $ps_file = "proteintree_". $self->{'tree'}->node_id;
    $ps_file =~ s/\/\//\//g;    # converts any // in path to /
    $ps_file .= ".ps";
    $self->{'plot_file'} = $ps_file;

    my $cmd = sprintf("drawtree -auto -charht 0.1 -intree %s -fontfile /usr/local/ensembl/bin/font5 -plotfile %s", 
                      $self->{'newick_file'}, $ps_file);
    print("$cmd\n");
    system($cmd);
    system("open $ps_file");
  }


sub dumpTreeFasta
  {
    my $self = shift;

    if ($self->{'dump'}) {
      my $fastafile = "proteintree_". $self->{'tree'}->node_id. ".fasta";
      $fastafile =~ s/\/\//\//g; # converts any // in path to /

      open(OUTSEQ, ">$fastafile")
        or $self->throw("Error opening $fastafile for write");
    } else {
      open OUTSEQ, ">&STDOUT";
    }

    # my $seq_id_hash = {};
    my $member_list = $self->{'tree'}->get_all_leaves;
    foreach my $member (@{$member_list}) {
      $DB::single=1;1;
      # next if($seq_id_hash->{$member->sequence_id});
      # $seq_id_hash->{$member->sequence_id} = 1;

      my $seq;
      $seq = $member->sequence unless (defined($self->{output_boj}));
      $seq = $member->sequence_exon_bounded if (defined($self->{output_boj}));
      $seq = $member->sequence_cds if (defined($self->{'cdna'}));
      $seq =~ s/(.{72})/$1\n/g;
      chomp $seq;

      # printf OUTSEQ ">%d %s\n$seq\n", $member->sequence_id, $member->stable_id
      printf OUTSEQ ">%s\n$seq\n", $member->stable_id
    }
    close OUTSEQ;

  }


sub print_cluster_counts
  {
    my $self = shift;
    my $tree = shift;
  
    unless($tree) {
      printf("%10s %10s %20s %20s\n", 'tree_id', 'proteins', 'residues', 'PHYML msecs');
      return;
    }
  
    my $proteins = $tree->get_all_leaves;
    my $count = 0;
    foreach my $member (@$proteins) {
      if (!($member->isa("Bio::EnsEMBL::Compara::Member"))) {
        printf("FOUND NOT MEMBER LEAF\n");
        $member->print_node;
        $member->print_tree;
        $member->parent->print_tree;
        next;
      }
      $count += $member->seq_length;
    }

    my $phyml_msec =  $tree->has_tag('PHYML_runtime_msec');
    $phyml_msec ='' unless(defined($phyml_msec));

    printf("%10d %10d %20d %20d\n",
           $tree->node_id, 
           scalar(@$proteins),
           $count, $phyml_msec
          );
  }


  ##################################################
  #
  # tree analysis
  #
  ##################################################

  sub dumpAllTreesToNewick
  {
    my $self = shift;

    foreach my $cluster (@{$self->{'clusterset'}->children}) {
      dumpTreeAsNewick($self, $cluster);
    }
  }

sub dumpAllTreesToNHX
  {
    my $self = shift;

    foreach my $cluster (@{$self->{'clusterset'}->children}) {
      dumpTreeAsNHX($self, $cluster);
    }
  }

sub _genomic_aln {
  my $self = shift;

  $self->{starttime} = time();
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  $self->{gabDBA} = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  $self->{mlssDBA} = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\w+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  my $tree_id = $self->{_genomic_aln};
  my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);

  print "tree_node_id,gab_non_gt,gt_non_gab,isect,gt_string,gab_string\n";
  my $species_set = $self->{_species_set};
  $species_set =~ s/\_/\ /g;
  my @gdbs;
  foreach my $species_name (split(":",$species_set)) {
    my $gdb = $self->{gdba}->fetch_by_name_assembly($species_name);
    next unless defined $gdb;
    push @gdbs, $gdb;
    $self->{species_set}{$gdb->dbID} = 1;
  }

  my $mlss = $self->{mlssDBA}->fetch_by_method_link_type_GenomeDBs('EPO',\@gdbs);

  my @to_delete;
  my   $tree_node_id = $tree->node_id;
  foreach my $leaf (@{$tree->get_all_leaves}) {
    next if (defined ($self->{species_set}{$leaf->genome_db_id}));
    push @to_delete, $leaf;
  }
  my $clean_tree = $tree->remove_nodes(\@to_delete);
  exit 0 unless (defined($clean_tree));

  print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

  foreach my $clean_leaf (@{$clean_tree->get_all_leaves}) {
    $self->{gt_cluster}{$clean_leaf->gene_member->stable_id} = 1;
    next unless ($clean_leaf->genome_db->name eq 'Homo sapiens');

    $DB::single=1;1;
    # my $ref_sequence_exon_bounded = $clean_leaf->sequence_exon_bounded;

#     my $gene_genomic_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
#     $gene_genomic_range->check_and_register
#       ( $gene_stable_id, ($exon->start + $diff_start), ($exon->end + $diff_end) );

    my $ref_exon_number = 1;
    foreach my $ref_exon (@{$clean_leaf->transcript->get_all_translateable_Exons}) {
      my $ref_exon_stable_id = $ref_exon->stable_id;
      print STDERR "[$ref_exon_stable_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
      my $slice = $ref_exon->feature_Slice;
      my $genomic_align_blocks =
        $self->{gabDBA}->fetch_all_by_MethodLinkSpeciesSet_Slice
          (
           $mlss,
           $slice);
      foreach my $genomic_align_block (@$genomic_align_blocks) {
        #my $extra = int(($clean_leaf->chr_end - $clean_leaf->chr_start)*0.01);
        #my $extra = int(($ref_exon->end - $ref_exon->start)*0.01);
        my $extra = 0;
        my $restricted_gab = $genomic_align_block->restrict_between_reference_positions($ref_exon->start-$extra,$ref_exon->end+$extra);
        next unless (defined($restricted_gab));
        foreach my $genomic_align (@{$restricted_gab->get_all_GenomicAligns}) {
          next if ($genomic_align->genome_db->name eq 'Homo sapiens');
          my $exon_slice = $genomic_align->get_Slice;
          next unless (defined ($exon_slice));
          # my $gene_list = $gene_slice->get_all_Genes_by_type('protein_coding');
          my $exon_list = $exon_slice->get_all_Exons;
          foreach my $exon (@$exon_list) {
            $self->{gab_cluster}{$ref_exon_number}{$ref_exon_stable_id}{$exon->stable_id} = 1;
          }
        }
      }
      $ref_exon_number++;
    }
  }
  my $gab_non_gt = 0; my $gt_non_gab = 0; my $isect = 0;
  foreach my $gab_id (keys %{$self->{gab_cluster}}) { if (!defined($self->{gt_cluster}{$gab_id})) { $gab_non_gt++; } else {$isect++;} }
  foreach my $gt_id  (keys  %{$self->{gt_cluster}}) { if (!defined($self->{gab_cluster}{$gt_id})) { $gt_non_gab++; } }
  my $gab_string = join(':',sort keys %{$self->{gab_cluster}});
  my  $gt_string = join(':',sort keys %{$self->{gt_cluster}});
  print "$tree_node_id,$gab_non_gt,$gt_non_gab,$isect,$gt_string,$gab_string\n";
}

sub _species_set_tag {
  my $self = shift;

  $self->{starttime} = time();

  $self->{ssDBA} = $self->{'comparaDBA'}->get_SpeciesSetAdaptor;
  my $ss1 = $self->{ssDBA}->fetch_by_dbID(32729);
  foreach my $species_set (@{$self->{ssDBA}->fetch_all}) {
    $DB::single=1;1;
  }
}

sub _analysis_job_trace {
  my $self = shift;

  $self->{starttime} = time();
  print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  my $root = new Bio::EnsEMBL::Compara::NestedSet;
  $root->node_id(1);

  my $input = $self->{_analysis_job_trace};
  my @logic_names = split(":",$input);
  my $root_logic_name = shift @logic_names;
  my $sql0 = "select (select a.logic_name from analysis a where a.analysis_id=aj.analysis_id) as analysis_name, aj.analysis_job_id, aj.prev_analysis_job_id, aj.completed, aj.runtime_msec, aj.retry_count from analysis_job aj where aj.analysis_id in (select analysis_id from analysis where logic_name=\"$root_logic_name\")";
  my $sth0 = $self->{comparaDBA}->dbc->prepare($sql0);
  $sth0->execute();
  my ($root_analysis_id, $root_analysis_job_id, $root_prev_analysis_job_id, $root_completed, $root_runtime_msec, $root_retry_count) = $sth0->fetchrow_array();
  $sth0->finish;
  exit unless (defined($root_analysis_id));
#   $root->add_tag("completed",$root_completed);
#   $root->add_tag("runtime_msec",$root_runtime_msec);
#   $root->add_tag("analysis_id",$root_analysis_id);
  $root->name($root_analysis_id);

  my $string = join('","',@logic_names);
  my $sql1 = "select (select a.logic_name from analysis a where a.analysis_id=aj.analysis_id) as analysis_name, aj.analysis_job_id, aj.prev_analysis_job_id, aj.completed, aj.runtime_msec, aj.retry_count from analysis_job aj where aj.analysis_id in (select analysis_id from analysis where logic_name  in (\"$string\"))";
  my $sth = $self->{comparaDBA}->dbc->prepare($sql1);
  $sth->execute();
  my ($analysis_id, $analysis_job_id, $prev_analysis_job_id, $completed, $runtime_msec, $retry_count);
  my $max_analysis_job_id = -1;
  print STDERR "[querying] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  while (($analysis_id, $analysis_job_id, $prev_analysis_job_id, $completed, $runtime_msec, $retry_count) = $sth->fetchrow_array) {
    my $node;
    unless (defined($self->{defined_nodes}{$analysis_job_id})) {
    $node = Bio::EnsEMBL::Compara::NestedSet->new; $node->node_id($analysis_job_id);
    $self->{defined_nodes}{$analysis_job_id} = $node;
    } else {
      $node = $self->{defined_nodes}{$analysis_job_id};
    }
    my $parent_node;
    unless (defined($self->{defined_nodes}{$prev_analysis_job_id})) {
      $parent_node = Bio::EnsEMBL::Compara::NestedSet->new;
      $parent_node->node_id($prev_analysis_job_id);
      $self->{defined_nodes}{$prev_analysis_job_id} = $parent_node;
    } else {
      $parent_node = $self->{defined_nodes}{$prev_analysis_job_id};
    }
    $parent_node->add_child($node);
    if ($prev_analysis_job_id == $root_analysis_job_id) {
      $root->add_child($parent_node);
    }
    $node->distance_to_parent(($runtime_msec*(1+$retry_count))/1000);
#     $node->add_tag("completed",$completed);
#     $node->add_tag("runtime_msec",$runtime_msec);
#     $node->add_tag("analysis_id",$analysis_id);
    $node->name($analysis_id);
  }
  $sth->finish;
  print STDERR "[queried] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

  print STDERR "[printing graph] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  my $scale = $self->{'scale'} || 0.005;
  $root->print_tree($scale);
  print STDERR "[printed graph] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
}

sub _nytprof_get_homologous_peptide_ids_from_gene {
  ## Get homologous protein ids for given gene....
  my $self = shift;
  my $genelist = $self->{_nytprof_get_homologous_peptide_ids_from_gene};
  my @genes = split(':',`cat $genelist`);
  my $species_list = $self->{species_list} || "Pan_troglodytes:Macaca_mulatta:Mus_musculus:Rattus_norvegicus";
  my @species = split(':',$species_list);
  foreach my $gene_id (@genes) {
    foreach my $species (@species) {
      $species =~ s/\_/\ /g;
      # my $compara_db = $self->{'container'}->adaptor->db->get_db_adaptor('compara');
      my $compara_db = $self->{comparaDBA};
      return unless $compara_db;
      my $ma = $compara_db->get_MemberAdaptor;
      return () unless $ma;
      my $qy_member = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_id);
      return () unless (defined $qy_member);
      my @homologues;
      my $STABLE_ID = undef;
      my $peptide_id = undef;
      my $ta = $compara_db->get_ProteinTreeAdaptor;
      my $root_id = $ta->gene_member_id_is_in_tree($qy_member->member_id);
      return () unless (defined($root_id));
      my $peptide_members_in_tree = $ta->fetch_all_AlignedMembers_by_root_id($root_id);
      foreach my $member (@$peptide_members_in_tree) {
        if( $member->gene_member_id eq $qy_member->member_id ) {
          $STABLE_ID  = $member->stable_id;
          $peptide_id = $member->member_id;
        } else {
          next unless ($member->genome_db->name eq $species);
          push @homologues, $member->dbID;
        }
      }
#      return ( $STABLE_ID, $peptide_id, \@homologues );
      print STDERR "$STABLE_ID, $peptide_id, ", join(":",@homologues), "\n" if (0 < scalar(@homologues));
      undef @homologues;
    }
  }
}


# sub _topology_mismatches
#   {
#     my $self = shift;
#     my $species_list_as_in_tree = $self->{species_list} 
#       || "22,10,21,23,3,14,15,19,11,16,9,13,4,18,5,24,12,7,17";
#     my $species_list = [22,10,21,25,3,14,15,28,11,16,26,13,4,27,18,5,24,7,17];
#     my @species_list_as_in_tree = split("\:",$species_list_as_in_tree);
#     my @query_species = split("\,",$self->{'_topolmis'});
  
#     printf("topolmis root_id: %d\n", $self->{'clusterset_id'});
  
#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#     #  my $outfile = "topolmis.". $self->{'clusterset_id'} . ".txt";
#     my $outfile = "topolmis.". $self->{'clusterset_id'}. "." . "sp." 
#       . join (".",@query_species) . ".txt";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE "topo_match,tree_id,node_id,duptag,ottag\n";
#     my $cluster_count;
#     foreach my $cluster (@{$clusterset->children}) {
#       my %member_totals;
#       $cluster_count++;
#       my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
#       print STDERR $verbose_string 
#         if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
#       $treeDBA->fetch_subtree_under_node($cluster);

#       my $member_list = $cluster->get_all_leaves;
#       my %member_gdbs;

#       foreach my $member (@{$member_list}) {
#         $member_gdbs{$member->genome_db_id} = 1;
#         $member_totals{$member->genome_db_id}++;
#       }
#       my @genetree_species = keys %member_gdbs;
#       #print the patterns
#       my @isect = my @diff = my @union = ();
#       my %count;
#       foreach my $e (@genetree_species, @query_species) {
#         $count{$e}++;
#       }
#       foreach my $e (keys %count) {
#         push(@union, $e);
#         push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
#       }

#       next if (scalar(@isect) < 3);
#       #trim tree and look at topology
#       my $keep_leaves_string;
#       my %query_species;
#       foreach my $mis (@query_species) {
#         $query_species{$mis}=1;
#       }
#       foreach my $member (@{$member_list}) {
#         next unless ($query_species{$member->genome_db_id});
#         #mark to keep
#         $keep_leaves_string .= $member->name;
#         $keep_leaves_string .= ",";
#       }
#       $keep_leaves_string =~ s/\,$//;
#       $self->{'tree'} = $cluster;
#       $self->{'keep_leaves'} = $keep_leaves_string;
#       keep_leaves($self);
#       $cluster = $self->{'tree'};
#       # For each internal node in the tree
#       ## no intersection of sps btw both child
#       my $nodes_to_inspect = _mark_for_topology_inspection($cluster);
#       foreach my $subnode ($cluster->get_all_subnodes) {
#         next if ($subnode->is_leaf);
#         if ('1' eq $subnode->get_tagvalue('_inspect_topology')) {
#           my $copy = $subnode->copy;
#           my $leaves = $copy->get_all_leaves;
#           foreach my $member (@$leaves) {
#             my $gene_taxon = new Bio::EnsEMBL::Compara::NCBITaxon;
#             $gene_taxon->ncbi_taxid($member->taxon_id);
#             $gene_taxon->distance_to_parent($member->distance_to_parent);
#             $member->parent->add_child($gene_taxon);
#             $member->disavow_parent;
#           }
#           #$copy->print_tree;  
#           #build real taxon tree from NCBI taxon database
#           my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#           my $species_tree = undef;
#           foreach my $member (@$leaves) {
#             my $ncbi_taxon = 
#               $taxonDBA->fetch_node_by_taxon_id($member->taxon_id);
#             $ncbi_taxon->no_autoload_children;
#             $species_tree = $ncbi_taxon->root unless($species_tree);
#             $species_tree->merge_node_via_shared_ancestor($ncbi_taxon);
#           }
#           $species_tree = $species_tree->minimize_tree;
#           my $topology_matches = _compare_topology($copy, $species_tree);
#           my $refetched_cluster = 
#             $treeDBA->fetch_node_by_node_id($subnode->node_id);
#           my $duptag = 
#             $refetched_cluster->find_node_by_node_id($subnode->node_id)->get_tagvalue('Duplication');
#           my $ottag = 
#             $refetched_cluster->find_node_by_node_id
#               ($subnode->node_id)->get_tagvalue('Duplication_alg');
#           $ottag = 1 if ($ottag =~ /species_count/);
#           $ottag = 0 if ($ottag eq '');
#           print OUTFILE $topology_matches, ",", 
#             $subnode->subroot->node_id,",", 
#               $subnode->node_id,",", 
#                 $duptag, "," ,
#                   $ottag, "\n";
#         }
#       }
#     }
#   }
# #topolmis end


# sub _get_all_duprates_for_species_tree_sis_genelist {
#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   my $port = 3306;
#   if ($myhost =~ /(\S+)\:(\S+)/) {
#     $port = $2;
#     $myhost = $1;
#   }
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -port => "$port",
#         -verbose => "0" );

#   $self->{ga} = Bio::EnsEMBL::Registry->get_adaptor("human","core","gene");
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{taxonDBA} =    $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   # first filter list
#   my $inputfile = $self->{_inputfile};
#   $inputfile =~ /\/(\w+)\.csv$/;
#   my $tag = $1;
#   open INFILE, "$inputfile" or die;
#   my $go_count = 0;
#   while (<INFILE>) {
#     chomp $_;
#    next unless (/GO:\d+/);
#     $_ =~ /(GO:\d+)/;
#     next unless (defined($1));
#     next unless (20 > $go_count);
#     $self->{_go_ids}{$1} = 1;
#     $go_count++;
#   }

#   # second filter list
#   my $inputfile2 = $self->{_inputfile2};
#   open INFILE2, "$inputfile2" or die;
#   while (<INFILE2>) {
#     chomp $_;
#     next if (/gene_ids/);
#     $_ =~ /(\w+)\,(\d+)\,\d+\,(\d+)/;
#     next unless (defined($1));
#     # Get rid of non-duplicated
#     next if (0 == $2);
#     next if (0.25 < $3);
#     $self->{_subtrees_genelist}{$1} = 1;
#   }

#   # Get the list of genes associated with GO ids
#   foreach my $go (keys %{$self->{_go_ids}}) {
#     my $genes = $self->{ga}->fetch_all_by_external_name($go,"GO");
#     while (my $gene = shift @$genes) {
#       my $gene_stable_id = $gene->stable_id;
#       # We only want those in second filter list
#       next unless (defined($self->{_subtrees_genelist}{$gene_stable_id}));
#       $self->{_genelist}{$go}{$gene_stable_id} = 1;
#     }
#   }

#   # Get the trees for each gene and cache all the subnode ids in a hash
#   my $numgo_ids = scalar(keys %{$self->{_genelist}});
#   print STDERR "[GO ids: $numgo_ids] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   my $outfile = "sisrates_genelist.$tag". $self->{_mydbname} . "." . 
#     $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE "node_subtype,is_leaf,dupcount,passedcount,coef,dupcount04,passedcount04,coef04,dupcount06,passedcount06,coef06,dupcount08,passedcount08,coef08,go\n";
#   my $outfile2 = "sisrates_genelist_go.$tag". $self->{_mydbname} . "." . 
#     $self->{'clusterset_id'};
#   $outfile2 .= ".csv";
#   open OUTFILE2, ">$outfile2" or die "error opening outfile2: $!\n";
#   print OUTFILE2 "go,gene_count,gene_list\n";

#   foreach my $go (keys %{$self->{_genelist}}) {
#     my $numgenes = scalar(keys %{$self->{_genelist}{$go}});
#     print STDERR "[genelist: $numgenes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     my $genelist = join ":", keys %{$self->{_genelist}{$go}};
#     print OUTFILE2 "$go,$numgenes,$genelist\n";
#     foreach my $gene_stable_id (keys %{$self->{_genelist}{$go}}) {
#       my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
#       next unless ($member);
#       $self->{tree} = $self->{treeDBA}->fetch_by_Member_root_id($member);
#       next unless ($self->{tree});
#       # next if we already went here, same tree as another gene
#       next if (defined($self->{_intnodes}{$self->{tree}->node_id}));
#       my @intnodes = $self->{tree}->get_all_subnodes;
#       foreach my $node (@intnodes) {
#         next if ($node->is_leaf);
#         $self->{_intnodes}{$node->node_id} = 1;
#       }
#       # Also the root
#       $self->{_intnodes}{$self->{tree}->node_id} = 1;
#       my $numnodes = scalar(@intnodes);
#       my $cached_nodes = scalar(keys %{$self->{_intnodes}});
#       print STDERR "[caching intnodes: $numnodes > $cached_nodes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     }

#     my $sql = 
#       "SELECT ptt1.node_id, ptt1.value, ptt2.value FROM protein_tree_tag ptt1, protein_tree_tag ptt2 ".
#         "WHERE ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
#           "AND ptt2.tag='Duplication'";
#     my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my ($node_id, $taxon_name, $duplication);
#     my $count;
#     my $totalcount;
#     while (($node_id, $taxon_name, $duplication) = $sth->fetchrow_array()) {
#       $totalcount++;
#       next unless (defined($self->{_intnodes}{$node_id})); # Only do for the nodes we are interested in
#       my $sql = 
#         "SELECT ptt3.value FROM protein_tree_tag ptt1, protein_tree_tag ptt2, protein_tree_tag ptt3 ".
#           "WHERE ptt1.node_id=$node_id ".
#             "AND ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
#               "AND ptt2.tag='Duplication' AND ptt2.node_id=ptt3.node_id ".
#                 "AND ptt3.tag='species_intersection_score'";
#       my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#       $sth->execute();
#       my $sis = $sth->fetchrow_array() || 0;
#       if (0 != $duplication && 0 != $sis) {
#         $self->{sisrates}{$taxon_name}{dupcount}++;
#       } else {
#         $self->{sisrates}{$taxon_name}{spccount}++;
#       }
#       if (0 != $duplication && 40 <= $sis) {
#         $self->{sisrates}{$taxon_name}{dupcount04}++;
#       } else {
#         $self->{sisrates}{$taxon_name}{spccount04}++;
#       }
#       if (0 != $duplication && 60 <= $sis) {
#         $self->{sisrates}{$taxon_name}{dupcount06}++;
#       } else {
#         $self->{sisrates}{$taxon_name}{spccount06}++;
#       }
#       if (0 != $duplication && 80 <= $sis) {
#         $self->{sisrates}{$taxon_name}{dupcount08}++;
#       } else {
#         $self->{sisrates}{$taxon_name}{spccount08}++;
#       }
#       $count++;
#       my $verbose_string = sprintf "[%5d nodes done]\n", 
#         $count;
#       print STDERR $verbose_string 
#         if ($self->{'verbose'} &&  ($count % $self->{'verbose'} == 0));
#     }
#     print STDERR "[counted nodes $count/$totalcount] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#     my $is_leaf;
#     foreach my $taxon_name (keys %{$self->{sisrates}}) {
#       my $taxon = $self->{taxonDBA}->fetch_node_by_name($taxon_name);
#       my $taxon_id = $taxon->taxon_id;
#       my $sp_pep_count = $self->{memberDBA}->get_source_taxon_count
#         (
#          'ENSEMBLGENE',
#          $taxon_id);
#       my $dupcount = $self->{sisrates}{$taxon_name}{dupcount} || 0;
#       my $spccount = $self->{sisrates}{$taxon_name}{spccount} || 0;
#       my $dupcount04 = $self->{sisrates}{$taxon_name}{dupcount04} || 0;
#       my $spccount04 = $self->{sisrates}{$taxon_name}{spccount04} || 0;
#       my $dupcount06 = $self->{sisrates}{$taxon_name}{dupcount06} || 0;
#       my $spccount06 = $self->{sisrates}{$taxon_name}{spccount06} || 0;
#       my $dupcount08 = $self->{sisrates}{$taxon_name}{dupcount08} || 0;
#       my $spccount08 = $self->{sisrates}{$taxon_name}{spccount08} || 0;
#       my $coef = 1; my $coef04 = 1; my $coef06 = 1;my $coef08 = 1;
#       if (0 != $sp_pep_count) {
#         $coef = $coef04 = $coef06 = $coef08 = $dupcount/$sp_pep_count;
#         $is_leaf = 1;
#       } else {
#         $coef = $dupcount/($dupcount+$spccount) if ($spccount!=0);
#         $coef04 = $dupcount04/($dupcount+$spccount04) if ($spccount04!=0);
#         $coef06 = $dupcount06/($dupcount+$spccount06) if ($spccount06!=0);
#         $coef08 = $dupcount08/($dupcount+$spccount08) if ($spccount08!=0);
#         $is_leaf = 0;
#       }
#       $taxon_name =~ s/\//\_/g; $taxon_name =~ s/\ /\_/g;
#       print OUTFILE "$taxon_name,$is_leaf,$dupcount,$spccount,$coef,$dupcount04,$spccount04,$coef04,$dupcount06,$spccount06,$coef06,$dupcount08,$spccount08,$coef08,$go\n" unless ($is_leaf);
#       print OUTFILE "$taxon_name,$is_leaf,$dupcount,$sp_pep_count,$coef,$dupcount,$sp_pep_count,$coef04,$dupcount,$sp_pep_count,$coef06,$dupcount,$sp_pep_count,$coef08,$go\n" if ($is_leaf);
#     }
#   }
# }


# sub _get_all_duprates_for_species_tree_sis {
#   my $self = shift;
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $sql = 
#     "SELECT ptt1.node_id, ptt1.value, ptt2.value FROM protein_tree_tag ptt1, protein_tree_tag ptt2 ".
#       "WHERE ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
#         "AND ptt2.tag='Duplication'";
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   my ($node_id, $taxon_name, $duplication);
#   my $count;
#   while (($node_id, $taxon_name, $duplication) = $sth->fetchrow_array()) {
#     my $sql = 
#       "SELECT ptt3.value FROM protein_tree_tag ptt1, protein_tree_tag ptt2, protein_tree_tag ptt3 ".
#         "WHERE ptt1.node_id=$node_id ".
#           "AND ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
#             "AND ptt2.tag='Duplication' AND ptt2.node_id=ptt3.node_id ".
#               "AND ptt3.tag='species_intersection_score'";
#     my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my $sis = $sth->fetchrow_array() || 0;
#     if (0 != $duplication && 0 != $sis) {
#       $self->{sisrates}{$taxon_name}{dupcount}++;
#     } else {
#       $self->{sisrates}{$taxon_name}{spccount}++;
#     }
#     if (0 != $duplication && 40 <= $sis) {
#       $self->{sisrates}{$taxon_name}{dupcount04}++;
#     } else {
#       $self->{sisrates}{$taxon_name}{spccount04}++;
#     }
#     if (0 != $duplication && 60 <= $sis) {
#       $self->{sisrates}{$taxon_name}{dupcount06}++;
#     } else {
#       $self->{sisrates}{$taxon_name}{spccount06}++;
#     }
#     if (0 != $duplication && 80 <= $sis) {
#       $self->{sisrates}{$taxon_name}{dupcount08}++;
#     } else {
#       $self->{sisrates}{$taxon_name}{spccount08}++;
#     }
#     $count++;
#   }

#   my $outfile = "sisrates.". $self->{_mydbname} . "." . 
#     $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE "node_subtype,is_leaf,dupcount,passedcount,coef,dupcount04,passedcount04,coef04,dupcount06,passedcount06,coef06,dupcount08,passedcount08,coef08\n";
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{taxonDBA} =    $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   my $is_leaf;
#   foreach my $taxon_name (keys %{$self->{sisrates}}) {
#     my $taxon = $self->{taxonDBA}->fetch_node_by_name($taxon_name);
#     my $taxon_id = $taxon->taxon_id;
#     my $sp_pep_count = $self->{memberDBA}->get_source_taxon_count
#       (
#        'ENSEMBLGENE',
#        $taxon_id);
#     my $dupcount = $self->{sisrates}{$taxon_name}{dupcount} || 0;
#     my $spccount = $self->{sisrates}{$taxon_name}{spccount} || 0;
#     my $dupcount04 = $self->{sisrates}{$taxon_name}{dupcount04} || 0;
#     my $spccount04 = $self->{sisrates}{$taxon_name}{spccount04} || 0;
#     my $dupcount06 = $self->{sisrates}{$taxon_name}{dupcount06} || 0;
#     my $spccount06 = $self->{sisrates}{$taxon_name}{spccount06} || 0;
#     my $dupcount08 = $self->{sisrates}{$taxon_name}{dupcount08} || 0;
#     my $spccount08 = $self->{sisrates}{$taxon_name}{spccount08} || 0;
#     my $coef = 1; my $coef04 = 1; my $coef06 = 1;my $coef08 = 1;
#     if (0 != $sp_pep_count) {
#       $coef = $coef04 = $coef06 = $coef08 = $dupcount/$sp_pep_count;
#       $is_leaf = 1;
#     } else {
#       $coef = $dupcount/($dupcount+$spccount) if ($spccount!=0);
#       $coef04 = $dupcount04/($dupcount+$spccount04) if ($spccount04!=0);
#       $coef06 = $dupcount06/($dupcount+$spccount06) if ($spccount06!=0);
#       $coef08 = $dupcount08/($dupcount+$spccount08) if ($spccount08!=0);
#       $is_leaf = 0;
#     }
#     $taxon_name =~ s/\//\_/g; $taxon_name =~ s/\ /\_/g;
#     print OUTFILE "$taxon_name,$is_leaf,$dupcount,$spccount,$coef,$dupcount04,$spccount04,$coef04,$dupcount06,$spccount06,$coef06,$dupcount08,$spccount08,$coef08\n" unless ($is_leaf);
#     if ($self->{verbose}) {
#       print "$taxon_name,$is_leaf,$dupcount,$spccount,$coef,$dupcount04,$spccount04,$coef04,$dupcount06,$spccount06,$coef06,$dupcount08,$spccount08,$coef08\n" unless ($is_leaf);
#     }
#     if ($self->{verbose}) {
#       print "$taxon_name,$is_leaf,$dupcount,$sp_pep_count,$coef,$dupcount,$sp_pep_count,$coef04,$dupcount,$sp_pep_count,$coef06,$dupcount,$sp_pep_count,$coef08\n" if ($is_leaf);
#     }
#   }
# }

# sub _family_expansions {
#   my $self = shift;
#   my $species = shift || "Homo sapiens";
#   $species =~ s/\_/\ /g;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $genome_db = $self->{gdba}->fetch_by_name_assembly($species);
#   my $gene_adaptor = $genome_db->db_adaptor->get_GeneAdaptor;
#   print STDERR "fetching all genes...\n" if ($self->{verbose});
#   my $genes = $gene_adaptor->fetch_all;
#   foreach my $gene (@$genes) {
#     my $external_name = $gene->external_name;
#     next unless (defined($external_name));
#     my $chopped_name = $external_name;
#     if ($chopped_name =~ /\d+_HUMAN$/) {
#       $chopped_name =~ s/\d+_HUMAN$//;
#     } else {
#       $chopped_name =~ s/.$//;
#     }
#     $self->{_family_names}{$chopped_name}{$external_name}{_gene} = $gene->stable_id;
#   }
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my @prefixes = keys %{$self->{_family_names}};
#   my $prefix_count = 0;
#   my $totalnum_prefixes = scalar(@prefixes);
#   foreach my $prefix (@prefixes) {
#     my @names = keys %{$self->{_family_names}{$prefix}};
#     $prefix_count++;
#     my $verbose_string = sprintf "[%5d / %5d prefixes done]\n", 
#       $prefix_count, $totalnum_prefixes;
#     print STDERR $verbose_string 
#       if ($self->{'verbose'} &&  ($prefix_count % $self->{'verbose'} == 0));
#     next unless ($self->{_family_expansions} == scalar (@names));
#     #    next unless (3 < scalar (@names));
#     foreach my $name (@names) {
#       my $stable_id = $self->{_family_names}{$prefix}{$name}{_gene};
#       my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE', $stable_id);
#       next unless (defined $member);
#       # $self->{tree} = $self->{treeDBA}->fetch_by_Member_root_id($member);
#       my $aligned_member = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id
#         (
#          $member->get_canonical_peptide_Member->member_id,
#          1);
#       next unless (defined $aligned_member);
#       my $node = $aligned_member->subroot;
#       next unless (defined $node);
#       $self->{_family_trees}{$node->node_id}{$stable_id}{$prefix}{$name} = 1;
#       $node->release_tree;
#       # my $newick = $self->{tree}->newick_format("display_label_composite");
#       # $self->{tree}->release_tree;
#     }
#   }
#   foreach my $node_id (keys %{$self->{_family_trees}}) {
#     my @stable_ids = keys %{$self->{_family_trees}{$node_id}};
#     next unless ($self->{_family_expansions} == scalar(@stable_ids));
#     # next unless (3 < scalar(@stable_ids));
#     my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE', $stable_ids[0]);
#     $self->{tree} = $self->{treeDBA}->fetch_by_Member_root_id($member);
#     $self->{keep_leaves_species} = "Homo_sapiens:Pan_troglodytes:Mus_musculus:Canis_familiaris:Gallus_gallus:Drosophila_melanogaster:Caenorhabditis_elegans:Saccharomyces_cerevisiae";
#     $self->keep_leaves_species;
#     my $newick_display_label = $self->{tree}->newick_format("display_label_composite");
#     my $nhx = $self->{tree}->nhx_format("display_label_composite");
#     $self->{tree}->release_tree;
#     my @prefixes = keys %{$self->{_family_trees}{$node_id}{$stable_ids[0]}};
#     my $outfile = $prefixes[0] . ".nh";
#     print STDERR "$outfile\n" if ($self->{verbose});
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE $newick_display_label;
#     close OUTFILE;
#     $outfile = $prefixes[0] . ".nhx";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE $nhx;
#     close OUTFILE;
#   }

#   #   my $sql = 
#   #   'select ptt1.node_id, ptt1.value, ptt2.value from protein_tree_tag ptt1, protein_tree_tag ptt2 where ptt1.tag="OrthoTree_types_hashstr" and ptt1.value like "%many2many%" and ptt2.tag="gene_count" and ptt2.value>20 and ptt1.node_id=ptt2.node_id and ptt2.value<60';

#   #   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   #   $sth->execute();
#   #   my ($node_id, $orthotree_types_hashstr, $gene_count);
#   #   my $count;
#   #   my %node_ids;
#   #   while (($node_id, $orthotree_types_hashstr, $gene_count) = $sth->fetchrow_array()) {
#   #     $orthotree_types_hashstr =~ s|\'||g;
#   #     my $types = eval $orthotree_types_hashstr;
#   #     my $num = $types->{ortholog_many2many} || 0;
#   #     my $denom;
#   #     foreach my $value (values %$types) {
#   #       $denom += $value;
#   #     }
#   #     next unless ($num != 0 && $denom != 0);
#   #     my $coef = sprintf("%.3f",$num/$denom);
#   #     $node_ids{$coef} = $node_id;
#   #   }
#   #   foreach my $perc (sort {$b <=> $a} keys %node_ids) {
#   #     $self->{tree} = $self->{treeDBA}->fetch_node_by_node_id($node_ids{$perc});
#   #   }
# }

# sub _canonical_translation_gene_transcript_list {
#   my $self = shift;
#   my $species = shift || "Homo sapiens";
#   $species =~ s/\_/\ /g;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $genome_db = $self->{gdba}->fetch_by_name_assembly($species);

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+/g;
#   my ($myuser,$myhost) = ($1,$2);
#   Bio::EnsEMBL::Registry->load_registry_from_db(-host=>$myhost, -user=>$myuser, -verbose=>'0');
#   my $gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");
#   print STDERR "fetching all genes...\n" if ($self->{verbose});
#   my $genes = $gene_adaptor->fetch_all;
#   print "gene_stable_id,transcript_id,canonical_peptide_id,chr,start,end\n";
#   while (my $gene = shift @$genes) {
#     my $gene_stable_id = $gene->stable_id;
#     my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
#     unless ($member) {
#       print "$gene_stable_id,na,na,na,na,na\n";
#       next;
#     }
#     my $canonical_peptide_member = $member->get_canonical_peptide_Member;
#     my $canonical_peptide_member_stable_id = $canonical_peptide_member->stable_id;
#     my $description = $canonical_peptide_member->description;
#     $description =~ /Transcript:(\S+)\s+/;
#     my $transcript_id = $1;
#     $description =~ /Chr:(\S+)\s+/;
#     my $chr = $1;
#     $description =~ /Start:(\S+)\s+/;
#     my $start = $1;
#     $description =~ /End:(\S+)/;
#     my $end = $1;
#     print "$gene_stable_id,$transcript_id,$canonical_peptide_member_stable_id,$chr,$start,$end\n";
#   }
# }

# sub _species_intersection_api {
#   my $self = shift;
#   my $species_list = $self->{species_list} || "Homo_sapiens:Pan_troglodytes:Macaca_mulatta";
#   $self->{starttime} = time();

#   $species_list =~ s/\_/\ /g;
#   my @species_set = split("\:",$species_list);

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;

#   my @homologies;
#   my @this_set = @species_set;
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   while (my $species1 = shift (@this_set)) {
#     foreach my $species2 (@this_set) {
#       my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#       my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#       my $sp1_gdb_short_name = $sp1_gdb->short_name;
#       my $sp2_gdb_short_name = $sp2_gdb->short_name;
#       $self->{gdb_short_names}{$sp1_gdb_short_name} = 1;
#       $self->{gdb_short_names}{$sp2_gdb_short_name} = 1;
#       my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#       print STDERR "Fetching homologies btw $species1 and $species2...\n" if ($self->{verbose});
#       my @homologies = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,"ortholog_one2one")};
#       foreach my $homology (@homologies) {
#         my ($ma1,$ma2) = @{$homology->get_all_Member_Attribute};
#         my ($member1, $attribute1) = @{$ma1};
#         my ($member2, $attribute2) = @{$ma2};
#         my $short_name1 = $member1->genome_db->short_name;
#         my $short_name2 = $member2->genome_db->short_name;
#         $self->{homology_sets}{$member1->stable_id}{$short_name1}{$short_name2} = 1;
#         $self->{homology_sets}{$member2->stable_id}{$short_name2}{$short_name1} = 1;
#       }
#       print STDERR "[$sp1_gdb_short_name $sp2_gdb_short_name] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     }
#   }
# }

sub _binning {
  my $self = shift;
  my $species = $self->{_binning} || "Homo_sapiens";  $species =~ s/\_/\ /g;
  # Bin sizes in bps
  my $bin_sizes = [1000000,500000,250000];
  # list of seq_regions
  my $sql1 = 
    "SELECT distinct chr_name, genome_db_id FROM member m ".
      "WHERE m.genome_db_id=(select genome_db_id from genome_db where name=\"$species\")";
  my $sth1 = $self->{comparaDBA}->dbc->prepare($sql1);
  $sth1->execute();
  
  # Temp file for LOAD DATA insert
  my $io = new Bio::Root::IO();
  my $tempdir = $io->tempdir;
  my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => $tempdir); #internal purposes
  open FILE, ">$tempfile" or die "$!";
  ###
  
  # 1) Foreach my seq_region
  while (my ($name,$genome_db_id) = $sth1->fetchrow_array()) {
    my $bin_num = 1;
    ## Until max chr_end coordinate
    my $sql4 = "select max(m.chr_end) from member m where m.genome_db_id=$genome_db_id and m.chr_name=\"$name\"";
    my $sth4 = $self->{comparaDBA}->dbc->prepare($sql4);
    $sth4->execute();
    my ($max_end) = $sth4->fetchrow_array;
    $sth4->finish();
    ###
    
    # 2) Foreach bin_size
    foreach my $size (@$bin_sizes) {
      print STDERR "species $species name $name size $size\n";
      my $offset;
      if (0 == ($bin_num % 2)) { $offset = -1 * int($size/2);} else {$offset = 0;}
      while ($offset < $max_end) {
        ## In this window
        my $end = $size+$offset;
        ## Select start end boundaries for features (genes) in this window
        my $sql2 = "select min(m.chr_start), max(m.chr_end) from member m where m.genome_db_id=$genome_db_id and m.chr_name=\"$name\" and m.chr_start>=$offset and m.chr_end<$end";
        my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
        $sth2->execute();
        my ($chr_start, $chr_end) = $sth2->fetchrow_array;
        $sth2->finish();
        $offset += $size;
        next unless (defined($chr_start) && defined($chr_end));
        ## Define bin, first tab is for AUTO_INCREMENT of seq_region_bin_id
        print FILE "\t$size\t$genome_db_id\t$name\t$chr_start\t$chr_end\n";
      }
      $bin_num++;
    }
  }
  $sth1->finish();
  close FILE;
  ## Load bins into table
  my $sql3 = "LOAD DATA LOCAL INFILE '$tempfile' IGNORE INTO TABLE seq_region_bin";
  my $sth3 = $self->{comparaDBA}->dbc->prepare($sql3);
  $sth3->execute();
  return 1;
}

sub _member_bin {
  my $self = shift;
  my $species = $self->{_member_bin} || "Homo_sapiens";
  $species =~ s/\_/\ /g;
  
  my $sth3 = $self->{comparaDBA}->dbc->prepare
    ("INSERT IGNORE INTO member_bin
           (seq_region_bin_id,
            member_id) VALUES (?,?)");
  
  my $sql1 = 
    "SELECT srb.seq_region_bin_id, srb.genome_db_id, srb.bin_size, srb.chr_name, srb.chr_start, srb.chr_end ".
      "FROM seq_region_bin srb ".
        "WHERE srb.genome_db_id=(select genome_db_id from genome_db where name=\"$species\") order by srb.seq_region_bin_id";
  my $sth1 = $self->{comparaDBA}->dbc->prepare($sql1);
  $sth1->execute();
  while (my ($seq_region_bin_id, $genome_db_id, $bin_size, $chr_name, $chr_start, $chr_end) = $sth1->fetchrow_array()) {
    #     print STDERR "name $chr_name bin_size $bin_size chr_start $chr_start chr_end $chr_end\n";
    my $sql4 = "select member_id from member m where m.source_name='ENSEMBLGENE' and m.genome_db_id=$genome_db_id and m.chr_name=\"$chr_name\" and m.chr_start>=$chr_start and m.chr_end<=$chr_end";
    my $sth4 = $self->{comparaDBA}->dbc->prepare($sql4);
    $sth4->execute();
    while (my ($member_id) = $sth4->fetchrow_array()) {
      $sth3->execute($seq_region_bin_id,
                     $member_id);
    }
    $sth4->finish();
  }
  $sth1->finish();
  $sth3->finish();
}

sub _indelible {
  my $self = shift;
  my $tree_id = $self->{_indelible};
  $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
  my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
  next unless (defined($tree));
  my $total_branch_length;
  foreach my $subnode ($tree->get_all_subnodes) {
    $total_branch_length += $subnode->distance_to_parent;
  }
  my $newick = $tree->newick_format;
  # Add some padding to zero-length branches.
  $newick =~ s/(:0\.?0+)([;,()])/:0.0005$2/g;
  # Get rid of branch length on root.
  $newick =~ s/:\d\.?\d+;/;/g;
  my $aln_num_residues = $tree->get_tagvalue('aln_num_residues');
  my $gene_count = $tree->get_tagvalue('gene_count');
  my $residues_length = int($aln_num_residues/$gene_count);
  my $aln_length = $tree->get_tagvalue('aln_length');
  my $length = $residues_length;

  my $substitution_rate = $total_branch_length/2;
  my $indel_rate = ($aln_length/$residues_length)/$substitution_rate;
  $indel_rate = $indel_rate/10;
  $indel_rate += ($indel_rate/100 * $self->{debug}) if ($self->{debug}); # overrides...

  print STDERR "indel_rate $indel_rate\n";
  my $ins_rate = $indel_rate;
  my $del_rate = $indel_rate;

  my $io = new Bio::Root::IO();
  my $tempdir = $io->tempdir;
  my $output_f = $tempdir."/$tree_id.sim";
  my $ctrl_f   = $tempdir."/control.txt";

  my $ctrl_str = qq^
[TYPE] CODON 1
[SETTINGS]
  [output] FASTA
  [printrates] TRUE
  [randomseed] $tree_id

[MODEL] model1
  [submodel]     2.5  0.5     //  Substitution model is M0 with kappa=2.5, omega=0.5
  [insertmodel] POW 2 50
  [deletemodel] POW 2 50
  [insertrate] $ins_rate
  [deleterate] $del_rate

[TREE] tree1 $newick


[PARTITIONS] partition1
  [tree1 model1 $length]
  [EVOLVE] partition1 1 $output_f
  ^;

  open(OUT,">$ctrl_f");
  print OUT $ctrl_str;
  close(OUT);

  use Cwd;
  my $cwd = getcwd;
  chdir($tempdir);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  my $cmd = "/nfs/acari/avilella/src/indelible/latest/INDELibleV1.02/src/indelible $ctrl_f";
  unless(system("cd $tempdir; $cmd") == 0) {
    print("## $cmd\n"); $self->throw("error running indelible, $!\n");
  }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  my $aln_f = $output_f."_TRUE.fas";
  my $cds_f = $output_f.".fas";
  $indel_rate = sprintf("%.03f",$indel_rate);
  my $farm = $self->{_farm} || undef;
  if ($farm) {
    print `cp $aln_f $farm/$tree_id.$indel_rate.indl.mfa`;
    print `cp $cds_f $farm/$tree_id.$indel_rate.indl.cds`;
  }
  unlink <$tempdir/*>;
  rmdir $tempdir;
}

# sub _binning {
#   my $self = shift;
#   my $species = $self->{_binning} || "Homo_sapiens";  $species =~ s/\_/\ /g;
#   # Bin sizes in bps
#   my $bin_sizes = [1000000,500000,250000];
#   # list of seq_regions
#   my $sql1 = 
#     "SELECT distinct chr_name, genome_db_id FROM member m ".
#       "WHERE m.genome_db_id=(select genome_db_id from genome_db where name=\"$species\")";
#   my $sth1 = $self->{comparaDBA}->dbc->prepare($sql1);
#   $sth1->execute();
  
#   # Temp file for LOAD DATA insert
#   my $io = new Bio::Root::IO();
#   my $tempdir = $io->tempdir;
#   my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => $tempdir); #internal purposes
#   open FILE, ">$tempfile" or die "$!";
#   ###
  
#   # 1) Foreach my seq_region
#   while (my ($name,$genome_db_id) = $sth1->fetchrow_array()) {
#     my $bin_num = 1;
#     ## Until max chr_end coordinate
#     my $sql4 = "select max(m.chr_end) from member m where m.genome_db_id=$genome_db_id and m.chr_name=\"$name\"";
#     my $sth4 = $self->{comparaDBA}->dbc->prepare($sql4);
#     $sth4->execute();
#     my ($max_end) = $sth4->fetchrow_array;
#     $sth4->finish();
#     ###
    
#     # 2) Foreach bin_size
#     foreach my $size (@$bin_sizes) {
#       print STDERR "species $species name $name size $size\n";
#       my $offset;
#       if (0 == ($bin_num % 2)) { $offset = -1 * int($size/2);} else {$offset = 0;}
#       while ($offset < $max_end) {
#         ## In this window
#         my $end = $size+$offset;
#         ## Select start end boundaries for features (genes) in this window
#         my $sql2 = "select min(m.chr_start), max(m.chr_end) from member m where m.genome_db_id=$genome_db_id and m.chr_name=\"$name\" and m.chr_start>=$offset and m.chr_end<$end";
#         my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#         $sth2->execute();
#         my ($chr_start, $chr_end) = $sth2->fetchrow_array;
#         $sth2->finish();
#         $offset += $size;
#         next unless (defined($chr_start) && defined($chr_end));
#         ## Define bin, first tab is for AUTO_INCREMENT of seq_region_bin_id
#         print FILE "\t$size\t$genome_db_id\t$name\t$chr_start\t$chr_end\n";
#       }
#       $bin_num++;
#     }
#   }
#   $sth1->finish();
#   close FILE;
#   ## Load bins into table
#   my $sql3 = "LOAD DATA LOCAL INFILE '$tempfile' IGNORE INTO TABLE seq_region_bin";
#   my $sth3 = $self->{comparaDBA}->dbc->prepare($sql3);
#   $sth3->execute();
#   return 1;
# }

# sub _member_bin {
#   my $self = shift;
#   my $species = $self->{_member_bin} || "Homo_sapiens";
#   $species =~ s/\_/\ /g;
  
#   my $sth3 = $self->{comparaDBA}->dbc->prepare
#     ("INSERT IGNORE INTO member_bin
#            (seq_region_bin_id,
#             member_id) VALUES (?,?)");
  
#   my $sql1 = 
#     "SELECT srb.seq_region_bin_id, srb.genome_db_id, srb.bin_size, srb.chr_name, srb.chr_start, srb.chr_end ".
#       "FROM seq_region_bin srb ".
#         "WHERE srb.genome_db_id=(select genome_db_id from genome_db where name=\"$species\") order by srb.seq_region_bin_id";
#   my $sth1 = $self->{comparaDBA}->dbc->prepare($sql1);
#   $sth1->execute();
#   while (my ($seq_region_bin_id, $genome_db_id, $bin_size, $chr_name, $chr_start, $chr_end) = $sth1->fetchrow_array()) {
#     #     print STDERR "name $chr_name bin_size $bin_size chr_start $chr_start chr_end $chr_end\n";
#     my $sql4 = "select member_id from member m where m.source_name='ENSEMBLGENE' and m.genome_db_id=$genome_db_id and m.chr_name=\"$chr_name\" and m.chr_start>=$chr_start and m.chr_end<=$chr_end";
#     my $sth4 = $self->{comparaDBA}->dbc->prepare($sql4);
#     $sth4->execute();
#     while (my ($member_id) = $sth4->fetchrow_array()) {
#       $sth3->execute($seq_region_bin_id,
#                      $member_id);
#     }
#     $sth4->finish();
#   }
#   $sth1->finish();
#   $sth3->finish();
# }

# sub _viral_genes {
#   my $self = shift;
#   my $species = shift;

#   my $starttime = time();
#   my $inputfile = $self->{_viral_genes};
#   open INFILE, "$inputfile" or die;
#   while (<INFILE>) {
#     chomp $_;
#     $_ =~ /Gene\:\s+(\S+)\s+/;
#     next unless (defined($1));
#     $self->{_viral_gene_ids}{$1} = 1;
#   }

#   foreach my $stable_id (keys %{$self->{_viral_gene_ids}}) {
#     $self->fetch_protein_tree_with_gene($stable_id);
#     $self->{_viral_gene_trees}{$self->{tree}->node_id}{_gene_count}{$self->{tree}->get_tagvalue("gene_count")}{_stable_ids}{$stable_id} = 1;
#     foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
#       next unless (defined($leaf));
#       my $leaf_stable_id = $leaf->stable_id;
#       next if ($leaf_stable_id eq $stable_id);
#       $self->{_viral_gene_trees}{$self->{tree}->node_id}{_gene_list}{$leaf_stable_id} = 1;
#     }
#   }

#   $self->{'comparaDBA2'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{_url2} . ';type=compara');
#   $self->{'temp'}  = $self->{'comparaDBA'};
#   $self->{'comparaDBA'} = $self->{'comparaDBA2'};
#   $self->{'comparaDBA2'} = $self->{'temp'};
#   # look now where are the other
#   print STDERR (time()-$starttime), " secs... \n" if ($self->{verbose});
#   foreach my $node_id (keys %{$self->{_viral_gene_trees}}) {
#     foreach my $stable_id (keys %{$self->{_viral_gene_trees}{$node_id}{_gene_list}}) {
#       $self->fetch_protein_tree_with_gene($stable_id);
#       my $this_node_id = $self->{tree}->node_id;
#       next unless (defined($this_node_id));
#       $self->{_viral_gene_trees}{_A}{$node_id}{_intersects_B}{$this_node_id} = 1;
#       $self->{_viral_gene_trees}{_B}{$this_node_id}{_intersects_A}{$node_id} = 1;
#     }
#   }
#   print STDERR (time()-$starttime), " secs... \n" if ($self->{verbose});
#   foreach my $node_id (keys %{$self->{_viral_gene_trees}{_A}}) {
#     print "$node_id -- ";
#     if (1 < scalar (keys %{$self->{_viral_gene_trees}{_B}{$node_id}})) {
#       foreach my $this_node_id (keys %{$self->{_viral_gene_trees}{_B}{$node_id}{_intersects_A}}) {
#         print join (",",(keys %{$self->{_viral_gene_trees}{_A}{$this_node_id}{_intersects_B}}));
#       }
#     } else {
#       print join (",",(keys %{$self->{_viral_gene_trees}{_A}{$node_id}{_intersects_B}}));
#     }
#     print "\n";
#   }
# }

# sub _hmm_build {
#   my $self = shift;

#   my $tree_id = $self->{_hmm_build};
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
#   my $broken = $tree->get_tagvalue('cluster_had_to_be_broken_down');
#   exit if ($broken eq '1');
#   my $inputfile = $self->{_inputfile};

#   my $starttime = time();
#   my $aln;
#   eval {
#     $aln = $tree->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 0,
#        -stop2x => 1
#       );
#   };
#   $tree->release_tree;
#   unless ($@) {
#     my $alignIO = Bio::AlignIO->new
#       (-file => ">/tmp/$tree_id.fasta",
#        -format => 'fasta',
#       );
#     $aln->set_displayname_flat(1);
#     $alignIO->write_aln($aln);
#     # scalable informatics binary # "/software/worm/bin/hmmer/"
#     my $hmmbuild = "/software/worm/bin/hmmer/" . "hmmbuild";
#     eval { !system("$hmmbuild --amino -g -A /tmp/$tree_id.hmm /tmp/$tree_id.fasta >/dev/null") || die $!; };
#     if ($@) {
#     }
#     #     eval {require Bio::Tools::Run::Hmmer;};
#     #     if ($@) { print STDERR "hmmer not found"; die "$!\n"; }
#     #     my $factory =  Bio::Tools::Run::Hmmer->new('program'=>'hmmbuild','hmm'=>"$tree_id.hmm",'g'=>1);
#     #     $factory->program_dir("/usr/local/ensembl/bin/");
#     #     $factory->run($aln);
#     system("rm -f /tmp/$tree_id.fasta");
#     system("cp /tmp/$tree_id.hmm $inputfile/");
#     system("rm -f /tmp/$tree_id.hmm");
#   }
# }

sub _hbpd {
  my $self = shift;
  $self->{starttime} = time();
  my $filename = $self->{_hbpd};
  my ($infilebase,$path,$type) = fileparse($filename);
  my $root_id = `cat $filename`;
  chomp $root_id;
  next if (1 == $root_id);
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{tree} = $self->{treeDBA}->fetch_node_by_node_id($root_id);

  my $tree = $self->{tree};

  my $aln;
  eval {
    $aln = $tree->get_SimpleAlign
      (
       -id_type => 'STABLE',
       -cdna => 0,
       -stop2x => 1
      );
  };
  $tree->release_tree;
  my $aln_file = "/tmp/$root_id.aln";
  unless ($@) {
    my $alignIO = Bio::AlignIO->new
      (-file => ">$aln_file",
       -format => 'fasta',
      );
    $aln->set_displayname_flat(1);
    $alignIO->write_aln($aln);
  }

  my $stk_file = "/tmp/$root_id.stk";
  my $cmd = "/usr/local/ensembl/bin/sreformat stockholm $aln_file > $stk_file";
  unless( system("$cmd") == 0) {
    print("$cmd\n");
    $self->check_job_fail_options;
    throw("error running sreformat, $!\n");
  }

  $self->{'input_aln'} = $stk_file;

  my $buildhmm_executable = "/nfs/users/nfs_a/avilella/src/hmmer3/latest/hmmer-3.0b3/src/hmmbuild";

  $self->{'hmm_file'} = $self->{'input_aln'} . "_hmmbuild.hmm ";
  $cmd = $buildhmm_executable;
  my $mydbname = $self->{comparaDBA}->dbc->dbname;
  $cmd .= " -n $mydbname.$root_id ";
  $cmd .= " --amino ";
  $cmd .= $self->{'hmm_file'};
  $cmd .= " ". $self->{'input_aln'};
  $cmd .= " 2>&1 > /dev/null" unless($self->{debug});

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->{debug});
  unless(system("cd /tmp; $cmd") == 0) {
    print("$cmd\n");
    throw("error running hmmbuild, $!\n");
  }
  my $file = $self->{'hmm_file'};
  my $ret1 = `rm -f $filename.hmm`;
  my $ret2 = `cp $file $filename.hmm`;
  $DB::single=1;1;#??
}

sub _hmm_search {
  my $self = shift;

  my $starttime = time();
  my $tree_id = $self->{_hmm_search};
  my $inputfile = $self->{_inputfile2};
  $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
  my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
  my $broken = $tree->get_tagvalue('cluster_had_to_be_broken_down');
  exit if ($broken eq '1');

  my $tbl_name = "protein_tree_hmmprofile";
  $tbl_name .= "_dna" if (defined ($self->{cdna}));
  my $type = "dna" if (defined ($self->{cdna}));
  $type = 'aa' unless (defined ($self->{cdna}));

  my $sql = 
    "SELECT hmmprofile FROM $tbl_name p ".
      "WHERE p.node_id=$tree_id";
  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute();
  my $hmmprofile  = $sth->fetchrow;
  my $io = new Bio::Root::IO();
  my $tempdir = $io->tempdir;
  my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => $tempdir); #internal purposes
  open FILE, ">$tempfile" or die "$!";
  print FILE $hmmprofile;
  close FILE;

#   my $num = `grep '>' $inputfile | wc -l`;
#   chomp $num;

  my $fh;
  my $hmmsearch = "/software/pfam/src/hmmer-3.0.a1/bin/" . "hmmsearch";
  eval { !system("") || die $!; };
  #  eval { open($fh, "$hmmsearch -Z $num -E 0.1 --cpu 1 $tempfile $inputfile |") || die $!; };
  eval { open($fh, "$hmmsearch $tempfile $inputfile |") || die $!; };
  if ($@) {
    warn("[treefam::build::run_hmmsearch] problem with hmmsearch $@ $!");
    return;
  }
  my $hash;

  while (<$fh>) {
    if (/^Scores for complete sequences/) {
      $_ = <$fh>;
#       my $pos = index($_, 'Score') - 2;
#       my $e_pos = index($_, 'E-value') - 1;
      <$fh>;
      <$fh>; # /------- ------ -----    ------- ------ -----   ---- --  --------       -----------/
      while (<$fh>) {
        last if (/no hits above thresholds/);
        last if (/^\s*$/);
        $_ =~ /\s+(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/;
        my $evalue = $1;
        my $score = $2;
        my $id = $3;
        #         my $score = substr($_, $pos);
        #         my $evalue = substr($_, $e_pos);
        #         my @t = split;
        #         my $id = $t[0];
        # $sth->execute($id);
        # my ($gid, $swcode) = $sth->fetchrow_array;
        # $hash->{$id}{Gene} = $gid;
        # $hash->{$id}{Swcode} = $swcode;
        $score =~ /^\s*(\S+)/;
        $hash->{$id}{Score} = $1;
        $evalue =~ /^\s*(\S+)/;
        $hash->{$id}{Evalue} = $1;
      }
      last;
    }
  }
  close($fh);
  print STDERR scalar (keys %$hash), " hits - ",(time()-$starttime),"\n";
  my $sth2 = $self->{comparaDBA}->dbc->prepare
    ("INSERT INTO hmmsearch
       (stable_id,
        node_id,
        evalue,
        score,
        type,
        qtaxon_id) VALUES (?,?,?,?,?,?)");

  foreach my $stable_id (keys %$hash) {
    my $evalue = $hash->{$stable_id}{Evalue};
    my $score = $hash->{$stable_id}{Score};
    $sth2->execute($stable_id,
                  $tree_id,
                  $evalue,
                  $score,
                  $type,
                  0);
  }
  $sth2->finish();
  unlink <$tempdir/*>;
  rmdir $tempdir;
}

sub _2xeval {
  my $self = shift;

  $self->{starttime} = time();
  $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
#   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   my $taxon = $self->{taxonDBA}->fetch_node_by_name("Cavia porcellus");
#   my $taxon_id = $taxon->taxon_id;

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -verbose => "0" );

  $self->{'comparaDBA2'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{_url2} . ';type=compara');
  $self->{memberDBA2} = $self->{'comparaDBA2'}->get_MemberAdaptor;

  my $tree_id = $self->{_2xeval};
  my $sql = "select * from hmmsearch_50 where tree_node_id=$tree_id order by evalue";
  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute();
  my $hmmsearch_id; my $stable_id; my $tree_node_id; my $score; my $evalue;
  my @members;

  # Have the tree_id with the highest score
  my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
  my $num = map {$_->stable_id =~ /ENSCPO/} @{$tree->get_all_leaves};

  while (($hmmsearch_id,$stable_id,$tree_node_id,$score,$evalue) = $sth->fetchrow_array()) {
    last if (0 == $num);
    # using only best right now
    $num = 1;
    my $member = $self->{memberDBA2}->fetch_by_source_stable_id('ENSEMBLPEP',$stable_id);
    push @members, $member;
    $num--;

  }

  # Run MUSCLE profile
  my $aln = $tree->get_SimpleAlign
    (-id_type => 'MEMBER',
     -append_taxon_id => 1
    );
  $aln->set_displayname_flat(1);
  my $io = new Bio::Root::IO();

  my $tempdir = $io->tempdir;
  my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => $tempdir); #internal purposes
  my $aln_out = Bio::AlignIO->new
    (-file => ">$tempfile",
     -format => 'fasta');
  $aln_out->write_aln($aln);
  $aln_out->close;
  my ($seqfilefh,$seqfile) = $io->tempfile(-dir => $tempdir); #internal purposes
  my $seq_out = Bio::SeqIO->new
    (-file => ">$seqfile",
     -format => 'fasta');
  foreach my $member (@members) {
    my $display_id = $member->stable_id . "_" . $member->taxon_id;
    my $seq = Bio::LocatableSeq->new
      (-seq => $member->sequence,
       -display_id => $display_id);
    $seq_out->write_seq($seq);
  }
  $seq_out->close;
  my ($outfh, $outfile) = $io->tempfile(-dir => $tempdir);
  my $cmd = "/nfs/acari/avilella/src/muscle3.52_src/muscle -profile -in1 $tempfile -in2 $seqfile 1> $outfile 2>/dev/null";
  print STDERR "Muscle...\n";
  my $ret = system($cmd);
  my $aln_aa_io = Bio::AlignIO->new
    (-file => "$outfile",
     -format => 'fasta');
  my $aa_aln = $aln_aa_io->next_aln;
  $aln_aa_io->close;

  # Run TreeBeST
  # aa_to_dna_aln
  my %seqs;
  foreach my $aln_member (@{$tree->get_all_leaves}) {
    my $id = $aln_member->member_id . "_" . $aln_member->taxon_id;
    my $sequence = $aln_member->transcript->translateable_seq;
    my $seq = Bio::LocatableSeq->new
      (-seq => $sequence,
       -display_id => $id);
    $seqs{$id} = $seq;
  }
  # adding query seqs
  foreach my $member (@members) {
    my $display_id = $member->stable_id . "_" . $member->taxon_id;
    my $query_seq = Bio::LocatableSeq->new
      (-seq => $member->transcript->translateable_seq,
       -display_id => $display_id);
    $seqs{$display_id} = $query_seq;
  }

  use Bio::Align::Utilities qw(aa_to_dna_aln);
  my $dna_aln = aa_to_dna_aln($aa_aln,\%seqs);
  $dna_aln->set_displayname_flat(1);

  my ($tffh, $tffile) = $io->tempfile(-dir => $tempdir);
  my $alnout = Bio::AlignIO->new
        (-file => ">$tffile",
         -format => 'fasta');
  $alnout->write_aln($dna_aln);
  $self->{'input_aln'} = $tffile;
  $self->{'newick_file'} = $self->{'input_aln'} . "_njtree_phyml_tree.txt ";
  my $njtree_phyml_executable = "/nfs/acari/avilella/src/_treesoft/treebest/treebest";
  my $tfcmd = $njtree_phyml_executable;
  $self->{'species_tree_file'} = "/lustre/work1/ensembl/avilella/hive/avilella_compara_homology_$mydbversion/spec_tax.nh";
  $self->{'bootstrap'} = 1;
  if (1 == $self->{'bootstrap'}) {
    $tfcmd .= " best ";
    if (defined($self->{'species_tree_file'})) {
      $tfcmd .= " -f ". $self->{'species_tree_file'};
    }
    $tfcmd .= " ". $self->{'input_aln'};
    $tfcmd .= " -p tree ";
    $tfcmd .= " -o " . $self->{'newick_file'};
    $tfcmd .= " 2>/dev/null 1>/dev/null";

    my $worker_temp_directory = $tempdir;
    print STDERR "Treebest...\n";
    unless(system("cd $worker_temp_directory; $tfcmd") == 0) {
      print("$tfcmd\n");
      die "error running njtree phyml, $!\n";
    }
  }
  my $newick_file =  $self->{'newick_file'};
  #parse newick into a new tree object structure
  my $newick = '';
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while (<FH>) {
    $newick .= $_;
  }
  close(FH);
  my $newtree = 
    Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  my $is_outgroup = 0; my $bsr = 'undef'; my $type = 'other';
#   if ($node->parent->node_id eq $newtree->node_id) {
#     $is_outgroup = 1;
#   } else {
#     my @leaves = @{$node->parent->children};
#     my $sister;
#     if ($leaves[0]->is_leaf && $leaves[1]->is_leaf) {
#       $sister = $leaves[1]->name if ($leaves[0]->name eq $display_id);
#       $sister = $leaves[0]->name unless ($leaves[0]->name eq $display_id);
#       $sister =~ /(\d+)\_(\d+)/;
#       my $sister_member_id = $1;
#       if ($2 eq $member->taxon_id) {$type = 'within';}
#       my $sister_pafs = $self->{ppafa}->fetch_all_by_qmember_id_hmember_id($member->dbID,$sister_member_id);
#       my $sister_paf = shift(@$sister_pafs);
#       my $self_hit = $self->{ppafa}->fetch_selfhit_by_qmember_id($member->dbID);
#       my $self_sister = $self->{ppafa}->fetch_selfhit_by_qmember_id($sister_member_id);
#       my $ref_score = $self_hit->score;
#       my $ref2_score = $self_sister->score;
#       if (!defined($ref_score) or 
#           (defined($ref2_score) and ($ref2_score > $ref_score))) {
#         $ref_score = $ref2_score;
#       }
#       $bsr = sprintf("%.3f",$sister_paf->score / $ref_score);
#     }
#   }
  unlink <$tempdir/*>;
  rmdir $tempdir;
}

sub _uce {
  my $self = shift;

  $self->{starttime} = time();
  $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
#   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -verbose => "0" );
  my $tree_id = $self->{_uce};
  $self->{tree} = $self->{treeDBA}->fetch_node_by_node_id($tree_id);

  my $hash_ref;
  my $score_table = 'protein_tree_member_mcoffee_score';
  foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
    # Grab the score line for each leaf node.
    my $id = $leaf->stable_id; # Must be stable_id to match the aln object.
    my $member_id = $leaf->member_id;
    my $cmd = "SELECT cigar_line FROM $score_table where member_id=$member_id;";
    my $sth = $self->{treeDBA}->prepare($cmd);
    $sth->execute();
    my $data = $sth->fetchrow_hashref();
    $sth->finish();
    my $scores = $data->{'cigar_line'};

    #print $id."\t".$scores ."\n";

    # Convert the protein mask into a DNA-level mask by repeating each char 3 times.
    my @arr = split(//,$scores);
    @arr = map { ($_ . '') x 3 } @arr;
    $scores = join("",@arr);
    $hash_ref->{$id} = $scores;
  }

  my $sa = $self->{tree}->get_SimpleAlign(-exon_cased=>1);
}

# sub _circos_synt {
#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "Circos_synt...\n";
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
#   # $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
# #   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
# #   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
# #  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

# #   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
# #   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
# #   Bio::EnsEMBL::Registry->load_registry_from_db
# #       ( -host => "$myhost",
# #         -user => "$myuser",
# #         -db_version => "$mydbversion",
# #         -verbose => "0" );
#   my $gene_id = $self->{_circos_synt};
#   my $gene_member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$gene_id);

#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly("Homo sapiens");

#   my $sc = {};
# #   $sc->{"Ptro"}="optblue";
# #   $sc->{"Hsap"}= "optgreen";
# #   $sc->{"Ggal"}="optyellow";
# #   $sc->{"Mmul"}="optorange";
# #   $sc->{"Ppyg"}="optred";
# #   $sc->{"Mmus"}="optviolet";
# #   $sc->{"Mdom"}="optpurple";
# #   my @species_set = ("Pan troglodytes","Pongo pygmaeus","Macaca mulatta","Mus musculus","Gallus gallus","Monodelphis domestica");

#   $sc->{"Hsap"}= "optgreen";
#   $sc->{"Ptro"}="optblue";
#   $sc->{"Ppyg"}="optred";
#   $sc->{"Mmur"}="optyellow";
#   $sc->{"Ogar"}="optorange";
#   $sc->{"Mmus"}="optviolet";
#   $sc->{"Cpor"}="optpurple";
#   $sc->{"Mmul"}="green";
#   $sc->{"Tsyr"}="blue";
#   my @species_set = ("Pan troglodytes","Pongo pygmaeus","Macaca mulatta","Microcebus murinus","Otolemur garnettii","Tarsius syrichta","Mus musculus", "Cavia porcellus");
#   my $band_colors = {};
#   $band_colors->{1} = "gneg";
#   $band_colors->{2} = "gneg";
#   $band_colors->{3} = "gneg";
#   $band_colors->{4} = "gneg";
#   $band_colors->{5} = "gneg";

#   #snuggle on
#   #max_snuggle_distance 3r

#   my $karyotypes;
#   my $links;
#   my $bands;
#   my $link_count = 1;
#   my @vicinity_members;
#   my $sql = "select m2.stable_id, ABS(m1.chr_start-m2.chr_start) absdist, (m1.chr_start-m2.chr_start) dist from member m1, member m2 where m1.stable_id=\"$gene_id\" and m1.source_name=\"ENSEMBLGENE\" and m1.source_name=m2.source_name and m1.genome_db_id=m2.genome_db_id and m1.chr_name=m2.chr_name and ABS(m1.chr_start-m2.chr_start)>0 order by absdist limit 4";

#   print STDERR "Vicinity...\n";
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   while (my ($stable_id,$absdist,$dist) = $sth->fetchrow_array()) {
#     push @vicinity_members, $stable_id;
#   }
#   push @vicinity_members, $gene_id;

#   print STDERR "Links...\n";
#   foreach my $vicinity_member_id (@vicinity_members) {
#     print STDERR "Vicinity $vicinity_member_id\n";
#     my $vicinity_member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$vicinity_member_id);
#     foreach my $species (sort @species_set) {
#       my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#       foreach my $homology (@{$self->{ha}->fetch_all_by_Member_paired_species($vicinity_member, $species)}) {
#         next unless $homology->description =~ /one2/;
#         my ($member1, $member2) = @{$homology->gene_list};
#         my $temp; unless ($member1->stable_id =~ /ENSG0/) { $temp = $member1; $member1 = $member2; $member2 = $temp; }
#         my $sp1_kname = $sp1_gdb->short_name . "_" . $member1->chr_name;
#         my $sp2_kname = $sp2_gdb->short_name . "_" . $member2->chr_name;
#         my $sp1_start = $member1->chr_start; my $sp1_end = $member1->chr_end;
#         my $sp2_start = $member2->chr_start; my $sp2_end = $member2->chr_end;
#         $karyotypes->{$sp1_kname}{start} = $sp1_start unless (defined ($karyotypes->{$sp1_kname}{start}) && $karyotypes->{$sp1_kname}{start} < $sp1_start);
#         $karyotypes->{$sp1_kname}{end}   =   $sp1_end unless (defined ($karyotypes->{$sp1_kname}{end})   && $karyotypes->{$sp1_kname}{end} > $sp1_end);
#         $karyotypes->{$sp2_kname}{start} = $sp2_start unless (defined ($karyotypes->{$sp2_kname}{start}) && $karyotypes->{$sp2_kname}{start} < $sp2_start);
#         $karyotypes->{$sp2_kname}{end}   =   $sp2_end unless (defined ($karyotypes->{$sp2_kname}{end})   && $karyotypes->{$sp2_kname}{end} > $sp2_end);
#         $links->{$link_count}{$sp1_kname} = "$sp1_start $sp1_end";
#         $links->{$link_count}{$sp2_kname} = "$sp2_start $sp2_end";
#         $bands->{$sp1_kname}{$member1->stable_id}{start} = $sp1_start; 
#         $bands->{$sp1_kname}{$member1->stable_id}{end} = $sp1_end; 
#         $bands->{$sp1_kname}{$member1->stable_id}{name} = $member1->display_label || $member1->stable_id;
#         $bands->{$sp2_kname}{$member2->stable_id}{start} = $sp2_start; 
#         $bands->{$sp2_kname}{$member2->stable_id}{end} = $sp2_end; 
#         $bands->{$sp2_kname}{$member2->stable_id}{name} = $member2->display_label || $member2->stable_id;
#         $link_count++;
#       }
#     }
#   }
#   # Add 10% padding
#   foreach my $kname (keys %$karyotypes) {
#     my $start = $karyotypes->{$kname}{start};
#     my $end   = $karyotypes->{$kname}{end};
#     my $tag_10 = int(($end-$start)/10);
#     $start = $start - $tag_10 unless ($tag_10 > $start);
#     $end = $end + $tag_10;
#     $karyotypes->{$kname}{start} = $start;
#     $karyotypes->{$kname}{end}   = $end;
#   }
#   open KARYO,">$gene_id.karyotype.txt" or die $!;
#   # chr - hs11 11 0 134452384 green
#   foreach my $kname (sort keys %$karyotypes) {
#     my $start = $karyotypes->{$kname}{start};
#     my $end   = $karyotypes->{$kname}{end};
#     my ($sp,$chr_name) = split("_",$kname);
#     my $color = $sc->{$sp};
#     print KARYO "chr - $kname $kname $start $end $color\n";
#   }
#   foreach my $kname (sort keys %$bands) {
#     my $count = 1;
#     foreach my $stable_id (sort keys %{$bands->{$kname}}) {
#       my $start = $bands->{$kname}{$stable_id}{start};
#       my $end   = $bands->{$kname}{$stable_id}{end};
#       my $name  = $bands->{$kname}{$stable_id}{name};
#       my $bcolor = $band_colors->{$count};
#       print KARYO "band $kname $name $name $start $end $bcolor\n";
#       $count++;
#     }
#   }
#   close KARYO;
#   open LINKS,">$gene_id.links.txt" or die $!;
#   foreach my $link_id (sort {$a<=>$b} keys %$links) {
#     foreach my $kname (sort keys %{$links->{$link_id}}) {
#       my $start_end = $links->{$link_id}{$kname};
#       my ($sp,$chr_name) = split("_",$kname);
#       my $color = $sc->{$sp};
#       $DB::single=1;1;
#       print LINKS "segdup"."$link_id $kname $start_end color=$color\n";
#     }
#   }
#   close LINKS;

#   my $conf = 
#     "<colors>\n" . 
# "<<include etc/colors.conf>>\n" . 
# "</colors>\n" . 
# "<fonts>\n" . 
# "<<include etc/fonts.conf>>\n" . 
# "</fonts>\n" . 
# "<<include ideogram.conf>>\n" . 
# "<<include ticks.conf>>\n" . 
# "karyotype   = /lustre/work1/ensembl/avilella/circos/$gene_id.karyotype.txt\n" . 
# "<image>\n" . 
# "dir = /lustre/work1/ensembl/avilella/circos\n" . 
# "file  = $gene_id.png\n" . 
# "# radius of inscribed circle in image\n" . 
# "radius         = 1500p\n" . 
# "background     = white\n" . 
# "# by default angle=0 is at 3 o'clock position\n" . 
# "angle_offset   = -90\n" . 
# "</image>\n" . 
# "<links>\n" . 
# "z      = 0\n" . 
# "radius = 0.9r\n" . 
# "crest  = 1\n" . 
# "color  = grey\n" . 
# "bezier_radius        = 0.2r\n" . 
# "bezier_radius_purity = 0.5\n" . 
# "<link segdup>\n" . 
# "thickness    = 5\n" . 
# "ribbon    = no\n" . 
# "stroke_thickness    = 4\n" . 
# "file         = /lustre/work1/ensembl/avilella/circos/$gene_id.links.txt\n" . 
# "<rules>\n" . 
# "<rule>\n" . 
# "importance = 110\n" . 
# "condition  = _THICKNESS1_ == 4 && rand() < 0.25\n" . 
# "thickness  = 10\n" . 
# "color      = green\n" . 
# "z          = 15\n" . 
# "</rule>\n" . 
# "<rule>\n" . 
# "importance = 100\n" . 
# "condition  = _COLOR1_ eq \"red\"\n" . 
# "thickness  = 4\n" . 
# "z          = 10\n" . 
# "flow = restart\n" . 
# "</rule>\n" . 
# "<rule>\n" . 
# "importance = 90\n" . 
# "condition  = _COLOR1_ ne \"grey\" && _THICKNESS1_ == 2\n" . 
# "z          = 5\n" . 
# "</rule>\n" . 
# "</rules>\n" . 
# "</link>\n" . 
# "</links>\n" . 
# "chromosomes_units           = 500\n" . 
# "chromosomes_display_default = yes\n" . 
# "anglestep       = 0.5\n" . 
# "minslicestep    = 10\n" . 
# "beziersamples   = 8\n" . 
# "debug           = no\n" . 
# "warnings        = no\n" . 
# "imagemap        = no\n" . 
# "units_ok = bupr\n" . 
# "units_nounit = n";

#   open CONF,">$gene_id.conf" or die $!;
#   print CONF $conf;
#   close CONF;
# }

sub _zmenu_prof {
  my $self = shift;

  $self->{starttime} = time();
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
# #   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
# #   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
# #  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  my $members = $self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$self->{gdba}->fetch_by_name_assembly("Homo sapiens")->taxon_id);
  foreach my $member (@$members) {
    next unless ($member->stable_id eq 'ENSG00000199172');
    my $prot_member = $member->get_canonical_peptide_Member;
    my $node = $self->{treeDBA}->fetch_by_Member_root_id($member);
    $DB::single=1;1;
    next unless defined($node);
    my $tagvalues;
    my $is_leaf = $node->is_leaf;
    my $leaf_count;
    if ($self->{debug}) {
      $leaf_count = $node->num_leaves;
      $tagvalues = $node->{_tags};
    } else {
      $leaf_count = scalar @{$node->get_all_leaves};
      $tagvalues = $node->get_tagvalue_hash;
    }
    my $parent_distance = $node->distance_to_parent || 0;
    $node->release_tree;
  }
}

# sub _simplealign_prof {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
# #   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
#    $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
# # #   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
# # #   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
# #   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
# # #  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
# #   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#   my $count = 0;
#   my $members = $self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$self->{gdba}->fetch_by_name_assembly("Homo sapiens")->taxon_id);
#   foreach my $member (@$members) {
#     my $tree = $self->{treeDBA}->fetch_by_Member_root_id($member);
#     next unless defined($tree);
#     my $align = $tree->get_SimpleAlign('','','','','',1);
#     my $nh = $tree->newick_format("full_web");
#     $tree->release_tree;
#     last if ($count++ > $self->{debug});
#   }
# }

sub _other_feature_reads {
  my $self = shift;
  $self->{starttime} = time();
  $DB::single=1;1;
}

sub _mxe_metatranscript_reads {
  my $self = shift;
  $self->{starttime} = time();
  my $species_name = $self->{_species};
  $species_name =~ s/\_/\ /g;

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  my $count = 0;
  print STDERR "[fetching human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  my $members = $self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$self->{gdba}->fetch_by_name_assembly($species_name)->taxon_id);
  print STDERR "[fetched  human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  print "species,gene_stable_id,is_translateable,is_mod3,transcript_num,increase\n";
#   my @members;
#   push @members, $self->{comparaDBA}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', 'ENSG00000139618'); #brca2


  my $url2 = $self->{_url2};
  $url2 =~ /mysql\:\/\/(\S+)\@(\S+)\/(\S+\_(\w+))$/g;
  ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor
    (-host   => $myhost,
     -user   => $myuser,
     -dbname => $mydbversion,
     -port => $port);
  my $slice_adaptor = $db->get_SliceAdaptor;
  while (my $member = shift @$members) {
    # last if ($count++ > $self->{debug});
    my $gene = $member->get_Gene;
    my $gene_stable_id = $gene->stable_id;
    my $transcripts = $gene->get_all_Transcripts;
    my $transcript_num = scalar @$transcripts;
    if (1 == $transcript_num) {
      print $self->{_species},",$gene_stable_id,1,1,1,0\n";
      next;
    }
    my $gene_slice = $gene->slice;
    my $gene_genomic_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
    my $this_transcript_num = 1;
    # my $ranges;
    foreach my $transcript (@$transcripts) {
      my $transcript_stable_id = $transcript->stable_id;
      my $exons = $transcript->get_all_translateable_Exons;
      # my $exons = $transcript->get_all_Exons;
      my $miniexon = 0;
      my $exon_num = scalar @$exons;
      my $this_exon = 1;
      foreach my $exon (@$exons) {
        if ($exon->end - $exon->start + 1 < 3) {
          next if (1 == $this_exon);
          next if ($exon_num == $this_exon);
          $miniexon = 1;
          # print STDERR "# $transcript_stable_id miniexon ". $exon->stable_id . " [" . (($exon->end)-($exon->start)+1) . "] " . $member->chr_name . " " .  $exon->end ."-" . $exon->start . "\n";
        }
        $this_exon++;
      }
      next if ($miniexon);
      foreach my $exon (@$exons) {
        my $rel_coding_start = $exon->cdna_coding_start($transcript);
        my $rel_coding_end = $exon->cdna_coding_end($transcript);
        my $rel_start = $exon->cdna_start($transcript);
        my $rel_end = $exon->cdna_end($transcript);
        my $diff_start = $rel_coding_start - $rel_start;
        my $diff_end = $rel_end - $rel_coding_end;
        my $slice; eval { $slice = $slice_adaptor->fetch_by_exon_stable_id($exon->stable_id);};
        my $feats = $slice->get_all_DnaAlignFeatures('solexa_ga') if (defined($slice));
        if (defined $feats) {
          # $DB::single=$self->{debug};1;
        }
        $gene_genomic_range->check_and_register
          ( $gene_stable_id, ($exon->start + $diff_start), ($exon->end + $diff_end) );

      }
      $this_transcript_num++;
    }
    # Create exons from ranges
    #   Deal with exon cdna start for partially coding exons
    #        end_phase will be -1 if the exon is half-coding and its 3 prime end is UTR.
    #   Deal with MXEs
    # Create a transcript using the exons translation using the first and last coding exon
    # Associate a tranlation with a transcript
    my $translation;

    my $meta_transcript;
    my $meta_seq;
    my @ranges; eval {@ranges = @{$gene_genomic_range->get_ranges($gene_stable_id)};};
    next if ($@);
    foreach my $range (@ranges) {
      my ($start_range, $end_range) = @$range;
      my $sub_slice = $gene_slice->sub_Slice($start_range,$end_range);
      $meta_seq .= $sub_slice->seq . "#";
      my $meta_exon_id = $start_range . "_" . $end_range;
      $meta_transcript->{$meta_exon_id} = $sub_slice;
    }

    # Stats
    # my $meta_seq = join("#",map {$_->seq} values %$meta_transcript);
    my $is_translateable = '1';
    my $copy = $meta_seq;
    $meta_seq =~ s/\#//g;
    my $is_mod3 = '1';
    if (0 != (length($meta_seq) % 3)) {
      $is_mod3 = -1*(length($meta_seq) % 3);
      # print ">meta_$gene_stable_id\n$meta_seq\n";
    }
    my $seq = Bio::Seq->new(); $seq->seq($meta_seq);
    my $translated_seq = $seq->translate->seq;
    if ($translated_seq =~ /\*./ && $member->chr_name ne 'MT') {
      $is_translateable = -1;
    }
    my $increase = 0;
    my $canonical_translation = $member->get_canonical_peptide_Member->sequence;
    $translated_seq =~ s/\*$//;
    $increase = ((length($translated_seq) - length($canonical_translation))*100 / length($canonical_translation));
    if (1 == $is_translateable) {
      if ($increase>10) {
        my $rincrease = sprintf("%.1f",$increase);
        print STDERR "\>$gene_stable_id/$rincrease\%\n$translated_seq\n";
      }
    }
    print $self->{_species},",$gene_stable_id,$is_translateable,$is_mod3,$transcript_num,$increase\n";
  }
}

sub _mxe_metatranscript {
  my $self = shift;
  $self->{starttime} = time();
  my $species_name = $self->{_species};
  $species_name =~ s/\_/\ /g;
  my $farm = $self->{_farm} || undef;

  my ($myuser,$myhost,$mydbversion,$port);
  eval {
  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );
  ;};

  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  my $count = 0;
  print STDERR "[fetching human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  my $members = $self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$self->{gdba}->fetch_by_name_assembly($species_name)->taxon_id);
  print STDERR "[fetched  human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  print "species,gene_stable_id,is_translateable,is_mod3,transcript_num,increase\n";
#   my @members;
#   push @members, $self->{comparaDBA}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', 'ENSG00000139618'); #brca2

  my $url2 = $self->{_url2} || $url;
  $url2 =~ /mysql\:\/\/(\S+)\@(\S+)\/(\S+\_(\w+))$/g;
  ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor
    (-host   => $myhost,
     -user   => $myuser,
     -dbname => $mydbversion,
     -port => $port);
  my $slice_adaptor = $db->get_SliceAdaptor;
  while (my $member = shift @$members) {
    # last if ($count++ > $self->{debug});
    my $gene = $member->get_Gene;
    my $gene_stable_id = $gene->stable_id;
    my $transcripts = $gene->get_all_Transcripts;
    my $transcript_num = scalar @$transcripts;
    if (1 == $transcript_num) {
      print $self->{_species},",$gene_stable_id,1,1,1,0\n";
      next;
    }
    my $gene_slice = $gene->slice;
    my $gene_genomic_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
    my $this_transcript_num = 1;
    # my $ranges;
    foreach my $transcript (@$transcripts) {
      my $transcript_stable_id = $transcript->stable_id;
      my $exons = $transcript->get_all_translateable_Exons;
      # my $exons = $transcript->get_all_Exons;
      my $miniexon = 0;
      my $exon_num = scalar @$exons;
      my $this_exon = 1;
      foreach my $exon (@$exons) {
        if ($exon->end - $exon->start + 1 < 3) {
          next if (1 == $this_exon);
          next if ($exon_num == $this_exon);
          $miniexon = 1;
          # print STDERR "# $transcript_stable_id miniexon ". $exon->stable_id . " [" . (($exon->end)-($exon->start)+1) . "] " . $member->chr_name . " " .  $exon->end ."-" . $exon->start . "\n";
        }
        $this_exon++;
      }
      next if ($miniexon);
      foreach my $exon (@$exons) {
        my $rel_coding_start = $exon->cdna_coding_start($transcript);
        my $rel_coding_end = $exon->cdna_coding_end($transcript);
        my $rel_start = $exon->cdna_start($transcript);
        my $rel_end = $exon->cdna_end($transcript);
        my $diff_start = $rel_coding_start - $rel_start;
        my $diff_end = $rel_end - $rel_coding_end;
        my $slice; eval { $slice = $slice_adaptor->fetch_by_exon_stable_id($exon->stable_id);};
        my $feats = $slice->get_all_DnaAlignFeatures('solexa_ga') if (defined($slice));
        if (0 < scalar @$feats) {
          # $DB::single=$self->{debug};1;
        }
        $gene_genomic_range->check_and_register
          ( $gene_stable_id, ($exon->start + $diff_start), ($exon->end + $diff_end) );

      }
      $this_transcript_num++;
    }
    # Create exons from ranges
    #   Deal with exon cdna start for partially coding exons
    #        end_phase will be -1 if the exon is half-coding and its 3 prime end is UTR.
    #   Deal with MXEs
    # Create a transcript using the exons translation using the first and last coding exon
    # Associate a tranlation with a transcript
    my $translation;

    my $meta_transcript;
    my $meta_seq;
    my @ranges; eval {@ranges = @{$gene_genomic_range->get_ranges($gene_stable_id)};};
    next if ($@);
    foreach my $range (@ranges) {
      my ($start_range, $end_range) = @$range;
      my $sub_slice = $gene_slice->sub_Slice($start_range,$end_range);
      $meta_seq .= $sub_slice->seq . "#";
      my $meta_exon_id = $start_range . "_" . $end_range;
      $meta_transcript->{$meta_exon_id} = $sub_slice;
    }

    # Stats
    # my $meta_seq = join("#",map {$_->seq} values %$meta_transcript);
    my $is_translateable = '1';
    my $copy = $meta_seq;
    $meta_seq =~ s/\#//g;
    my $is_mod3 = '1';
    if (0 != (length($meta_seq) % 3)) {
      $is_mod3 = -1*(length($meta_seq) % 3);
      # print ">meta_$gene_stable_id\n$meta_seq\n";
    }
    my $seq = Bio::Seq->new(); $seq->seq($meta_seq);
    my $translated_seq = $seq->translate->seq;
    if ($translated_seq =~ /\*./ && $member->chr_name ne 'MT') {
      $is_translateable = -1;
    }
    my $increase = 0;
    my $canonical_translation = $member->get_canonical_peptide_Member->sequence;
    $translated_seq =~ s/\*$//;
    $increase = ((length($translated_seq) - length($canonical_translation))*100 / length($canonical_translation));
    if (1 == $is_translateable) {
      if ($increase>10) {
        my $rincrease = sprintf("%.1f",$increase);
        print STDERR "\>$gene_stable_id/$rincrease\%\n$translated_seq\n";
      }
    }
    if ($increase > 0) {
      print $self->{_species},",$gene_stable_id,$is_translateable,$is_mod3,$transcript_num,$increase\n";
      if ($farm && $increase > $self->{debug}) {
        my $tree_id = $self->{treeDBA}->gene_member_id_is_in_tree($member->member_id);
        open OUTFILE, ">$farm/$tree_id.$gene_stable_id.fasta" or die "$!\n";
        foreach my $peptide_member (@{$member->get_all_peptide_Members}) {
          my $stable_id = $peptide_member->stable_id;
          my $seq = $peptide_member->sequence_cds;
          print OUTFILE "\>$stable_id\n$seq\n";
        }
        close OUTFILE;
      }
    }
  }
}

sub _check_human_reads {
  my $self = shift;
  $self->{starttime} = time();
  my $species_name = $self->{_species};
  $species_name =~ s/\_/\ /g;

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  my $count = 0;
  print STDERR "[fetching human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  my $members = $self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$self->{gdba}->fetch_by_name_assembly($species_name)->taxon_id);
  print STDERR "[fetched  human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  print "species,gene_stable_id,is_translateable,is_mod3,transcript_num,increase\n";
#   my @members;
#   push @members, $self->{comparaDBA}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', 'ENSG00000139618'); #brca2


  my $url2 = $self->{_url2};
  $url2 =~ /mysql\:\/\/(\S+)\@(\S+)\/(\S+\_(\w+))$/g;
  ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor
    (-host   => $myhost,
     -user   => $myuser,
     -dbname => $mydbversion,
     -port => $port);
  my $slice_adaptor = $db->get_SliceAdaptor;
  while (my $member = shift @$members) {
    # last if ($count++ > $self->{debug});
    my $gene = $member->get_Gene;
    my $gene_stable_id = $gene->stable_id;
    my $transcripts = $gene->get_all_Transcripts;
    my $transcript_num = scalar @$transcripts;
    if (1 == $transcript_num) {
      print $self->{_species},",$gene_stable_id,1,1,1,0\n";
      next;
    }
    my $gene_slice = $gene->slice;
    my $gene_genomic_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
    my $this_transcript_num = 1;
    # my $ranges;
    foreach my $transcript (@$transcripts) {
      my $transcript_stable_id = $transcript->stable_id;
      my $exons = $transcript->get_all_translateable_Exons;
      # my $exons = $transcript->get_all_Exons;
      my $miniexon = 0;
      my $exon_num = scalar @$exons;
      my $this_exon = 1;
      foreach my $exon (@$exons) {
        if ($exon->end - $exon->start + 1 < 3) {
          next if (1 == $this_exon);
          next if ($exon_num == $this_exon);
          $miniexon = 1;
          # print STDERR "# $transcript_stable_id miniexon ". $exon->stable_id . " [" . (($exon->end)-($exon->start)+1) . "] " . $member->chr_name . " " .  $exon->end ."-" . $exon->start . "\n";
        }
        $this_exon++;
      }
      next if ($miniexon);
      foreach my $exon (@$exons) {
        my $rel_coding_start = $exon->cdna_coding_start($transcript);
        my $rel_coding_end = $exon->cdna_coding_end($transcript);
        my $rel_start = $exon->cdna_start($transcript);
        my $rel_end = $exon->cdna_end($transcript);
        my $diff_start = $rel_coding_start - $rel_start;
        my $diff_end = $rel_end - $rel_coding_end;
        my $slice; eval { $slice = $slice_adaptor->fetch_by_exon_stable_id($exon->stable_id);};
        my $feats = $slice->get_all_DnaAlignFeatures('solexa_ga') if (defined($slice));
        if (defined $feats) {
          $DB::single=$self->{debug};1;
        }
        $gene_genomic_range->check_and_register
          ( $gene_stable_id, ($exon->start + $diff_start), ($exon->end + $diff_end) );

      }
      $this_transcript_num++;
    }
    # Create exons from ranges
    #   Deal with exon cdna start for partially coding exons
    #        end_phase will be -1 if the exon is half-coding and its 3 prime end is UTR.
    #   Deal with MXEs
    # Create a transcript using the exons translation using the first and last coding exon
    # Associate a tranlation with a transcript
    my $translation;

    my $meta_transcript;
    my $meta_seq;
    #FIXME change overlap method to do direct-MSA;
    my @ranges; eval {@ranges = @{$gene_genomic_range->get_ranges($gene_stable_id)};};
    next if ($@);
    foreach my $range (@ranges) {
      my ($start_range, $end_range) = @$range;
      my $sub_slice = $gene_slice->sub_Slice($start_range,$end_range);
      $meta_seq .= $sub_slice->seq . "#";
      my $meta_exon_id = $start_range . "_" . $end_range;
      $meta_transcript->{$meta_exon_id} = $sub_slice;
    }

    # Stats
    # my $meta_seq = join("#",map {$_->seq} values %$meta_transcript);
    my $is_translateable = '1';
    my $copy = $meta_seq;
    $meta_seq =~ s/\#//g;
    my $is_mod3 = '1';
    if (0 != (length($meta_seq) % 3)) {
      $is_mod3 = -1*(length($meta_seq) % 3);
      # print ">meta_$gene_stable_id\n$meta_seq\n";
    }
    my $seq = Bio::Seq->new(); $seq->seq($meta_seq);
    my $translated_seq = $seq->translate->seq;
    if ($translated_seq =~ /\*./ && $member->chr_name ne 'MT') {
      $is_translateable = -1;
    }
    my $increase = 0;
    my $canonical_translation = $member->get_canonical_peptide_Member->sequence;
    $translated_seq =~ s/\*$//;
    $increase = ((length($translated_seq) - length($canonical_translation))*100 / length($canonical_translation));
    if (1 == $is_translateable) {
      if ($increase>10) {
        my $rincrease = sprintf("%.1f",$increase);
        print STDERR "\>$gene_stable_id/$rincrease\%\n$translated_seq\n";
      }
    }
    print $self->{_species},",$gene_stable_id,$is_translateable,$is_mod3,$transcript_num,$increase\n";
  }
}

sub _check_read_clustering {
  my $self = shift;
  $self->{starttime} = time();
  my $species_name = $self->{_species};
  $species_name =~ s/\_/\ /g;
  my $filename = $self->{_check_read_clustering};
  my ($infilebase,$path,$type) = fileparse($filename);
  my $tree_id = `cat $filename`;
  chomp $tree_id;

  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{tree} = $self->{treeDBA}->fetch_node_by_node_id($tree_id);

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  my $cdna_alignment_string;
  my $length;
  foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
    next unless ($leaf->taxon->name eq $species_name);
    $cdna_alignment_string = $leaf->cdna_alignment_string;
    $cdna_alignment_string =~ s/-//g;
    $cdna_alignment_string =~ s/\ //g;
    $length = length($cdna_alignment_string);
  }

  return unless (defined($cdna_alignment_string) && length($cdna_alignment_string)>0);

  my $fh;
  my $hmmsearch = "/nfs/acari/avilella/src/hmmer3/latest/hmmer-3.0b3/src/" . "hmmsearch";

  my $inputfile = $path . "realseq.fa";
  my $realseq = $cdna_alignment_string;
  $realseq =~ s/(.{60})/$1\n/g;
  open LONG, ">$inputfile" or die "$!";
  print LONG "\>$tree_id\n$realseq\n";
  close LONG;
  $inputfile = $path . "reads.fasta";
  open FILE2, ">$inputfile" or die "$!";
  my $count = 0;
  my $cov_reads = $self->{_cov_reads} || 100;
  my $num_reads = ($length*$cov_reads)/75;
  while ($count < $num_reads) {
    my $simread = substr($cdna_alignment_string, int(rand($length)-74),75);
    next unless(length($simread)>=75);
    my $id = $tree_id . "_" . int(rand(999999)) . int(rand(999999));
    print FILE2 "\>$id\n$simread\n";
    $count++;
  }
  close FILE2;
}

sub _check_velvet_coverage {
  my $self = shift;
  $self->{starttime} = time();
  my $species_name = $self->{_species};
  $species_name =~ s/\_/\ /g;
  my $filename = $self->{_check_velvet_coverage};
  my ($infilebase,$path,$type) = fileparse($filename);
  # my $tree_id = `cat $filename`;
  # chomp $tree_id;
  my $tree_id = $filename;

  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{tree} = $self->{treeDBA}->fetch_node_by_node_id($tree_id);

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }

  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "ensro",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  my $cdna_alignment_string;
  my $real_length;
  my $realseqs_cross_species;
  my $stable_id;
  my $mix;
  my $mix_count = 0;
  my $same;
  my $same_count = 0;
  foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
    $cdna_alignment_string = $leaf->cdna_alignment_string;
    $cdna_alignment_string =~ s/-//g;
    $cdna_alignment_string =~ s/\ //g;
    if ($leaf->taxon->name eq $species_name) {
      # $cdna_alignment_string =~ s/(.{60})/$1\n/g;
      $same_count++;
      $realseqs_cross_species .= ">" . $leaf->stable_id . "\n" . "$cdna_alignment_string\n";
      $same->{$same_count} = $cdna_alignment_string;
      $real_length = length($cdna_alignment_string);
    } else {
      $mix_count++;
      $stable_id = $leaf->stable_id;
      $mix->{$mix_count} = $cdna_alignment_string;
    }
  }

  return unless (0 < scalar keys %$same || 0< scalar keys %$mix);

  my $io = new Bio::Root::IO();
  my $tempdir = $io->tempdir;
  my ($tmpfilefh1,$tempfile1) = $io->tempfile(-dir => $tempdir); #internal purposes
  #   my $realseq = $cdna_alignment_string;
  #   $realseq =~ s/(.{60})/$1\n/g;
  open LONG, ">$tempfile1" or die "$!";
  # print LONG "\>$tree_id\n$realseq\n";
  $realseqs_cross_species =~ s/\n\n/\n/g;
  print LONG "$realseqs_cross_species";
  close LONG;

  my $take_mix = $self->{_take_mix} || 0;
  print STDERR "Using mix...\n" if ($take_mix && $self->{debug});
  my $use_long = $take_mix;
  my $cmd;
  my $seqcount = 0;
  my $cov_reads = $self->{_cov_reads} || 0.25;
  my $iter;
  my $snp_rate = 0;
  my $indel_rate = 0;
  my $indel_size = 0;
  my $saturation_count = 10;
  my $read_length = 75;
  my $desired_rel_contig_length = 0.900;

  print STDERR "real length $real_length\n" if ($self->{debug});
  $iter->{$cov_reads} = 1;
  my $iter_count = 0;
  my $this;
  $this = $mix if ($take_mix);
  $this = $same unless ($take_mix);
  my $this_count;
  $this_count = $mix_count if ($take_mix);
  $this_count = $same_count unless ($take_mix);
  while (1) {
    my $count = 0;
    my $num_reads = ($real_length*$cov_reads)/$read_length;
    $num_reads = 2 if ($num_reads < 2);
    my ($tmpfilefh2,$tempfile2) = $io->tempfile(-dir => $tempdir); #internal purposes
    open FILE2, ">$tempfile2" or die "$!";
    while ($count < $num_reads) {
      my $simread;
      my $seq_id = int(rand($this_count)+0.5);
      $cdna_alignment_string = $this->{$this_count};
      my $length = length($cdna_alignment_string);
      $simread = substr($cdna_alignment_string, int(rand($length)-($read_length-1)),$read_length);
      next unless(length($simread)>=$read_length);
      my $id = $tree_id . "_" . int(rand(999999)) . int(rand(999999));
      print FILE2 "\>$id\n$simread\n";
      $count++;
    }
    close FILE2;
    $cmd = "/nfs/acari/avilella/src/velvet/velvet_0.7.29/velveth $tempdir 21 -short $tempfile2";
    $cmd = "/nfs/acari/avilella/src/velvet/velvet_0.7.28/velveth $tempdir 21 -short $tempfile2 -long $tempfile1" if ($use_long);
    eval { !system("$cmd 1>/dev/null 2>/dev/null") || die $!; };
    if ($@) {
      exit "$@\n";
    }
    $cmd = "/nfs/acari/avilella/src/velvet/velvet_0.7.29/velvetg $tempdir -exp_cov $cov_reads";
    eval { !system("$cmd 1>/dev/null 2>/dev/null") || die $!; };
    if ($@) {
      exit "$@\n";
    }
    my $contigs_file = $tempdir . "/contigs.fa";
    my $seqio = Bio::SeqIO->new
      (-file => $contigs_file,
       -format => 'fasta');
    $seqcount = 0;
    my $max_contig_length = 0;
    foreach my $seq ($seqio->next_seq) {
      my $contig_length = $seq->length;
      $max_contig_length = $contig_length if ($contig_length > $max_contig_length);
      $seqcount++;
    }
    my $perc = sprintf("%.03f",$max_contig_length / $real_length);
    if ($perc >= $desired_rel_contig_length) {
      $iter->{$cov_reads}++;
      if ($iter->{$cov_reads} > $saturation_count) {
        print "Saturation coverage at $desired_rel_contig_length contig length is $cov_reads with use_long=$use_long (iter $iter_count)\n";
        my $sth = $self->{comparaDBA}->dbc->prepare
          ("INSERT INTO read_statistics 
                                 (stable_id,
                                  tree_id,
                                  read_length,
                                  cov_reads,
                                  num_reads,
                                  use_long,
                                  desired_rel_contig_length,
                                  real_length,
                                  saturation_count,
                                  snp_rate,
                                  indel_rate,
                                  indel_size,
                                  species_name) VALUES
                                  (?,?,?,?,?,?,?,?,?,?,?,?,?)");
        $sth->execute
          ($stable_id,
           $tree_id,
           $read_length,
           $cov_reads,
           $num_reads,
           $use_long,
           $desired_rel_contig_length,
           $real_length,
           $saturation_count,
           $snp_rate,
           $indel_rate,
           $indel_size,
           $species_name);
        exit 0;
      }
    }
    print STDERR "cov_reads $cov_reads (" . $iter->{$cov_reads} .") / r_contig_len $perc / num_reads $count / seqcount $seqcount / max_contig_length $max_contig_length\n" if ($self->{debug});
    if ($perc < $desired_rel_contig_length) {
      $cov_reads = sprintf("%.02f",$cov_reads + 0.5);
    } else {
      $cov_reads =  sprintf("%.02f",$cov_reads - 1);
    }
    $cov_reads = 0.25 if ($cov_reads < 0.25);
    $iter->{$cov_reads} = 1 if (!defined($iter->{$cov_reads}));
    $iter_count++;
    unlink $tempfile2;
  }
}


sub _dump_exon_boundaries {
  my $self = shift;
  $self->{starttime} = time();

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -verbose => "0" );

  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  my @clusters;

  my $id = $self->{_dump_exon_boundaries};
  if ($id =~ /ENS/) {
    $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
    my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLPEP',$id);
    my $tree = $self->{treeDBA}->fetch_by_Member_root_id($member);
    push @clusters, $tree;
  } else {
    $self->{'clusterset'} = $self->{treeDBA}->fetch_node_by_node_id($self->{'clusterset_id'});
    @clusters = @{$self->{'clusterset'}->children};
    my $totalnum_clusters = scalar(@clusters);
    printf("totalnum_trees: %d\n", $totalnum_clusters);
  }

  my $count = 0;
  foreach my $cluster (@clusters) {
    my $gene_count = $cluster->get_tagvalue("gene_count");
    my $fastafile = "proteintree_". $cluster->node_id. ".fasta";
    print STDERR "## $fastafile\n";
    open(OUTSEQ, ">$fastafile")
      or $self->throw("Error opening $fastafile for write");

    my $seq_id_hash = {};
    my $member_list = $cluster->get_all_leaves;
    my $aln = $cluster->get_SimpleAlign;
    my $alnfile = "proteintree_". $cluster->node_id. ".fasta.aln";
    my $alnout = Bio::AlignIO->new
      (-file => ">$alnfile",
       -format => 'fasta');
    $alnout->write_aln($aln);
    $alnout->close;
    foreach my $member (@{$member_list}) {
      next if($seq_id_hash->{$member->sequence_id});
      $seq_id_hash->{$member->sequence_id} = 1;
      my $seq = $member->get_exon_bounded_sequence;
      $seq =~ s/(.{72})/$1\n/g;
      chomp $seq;

      printf OUTSEQ ">%d %s\n$seq\n", $member->sequence_id, $member->stable_id
    }
    close OUTSEQ;
  }
}

sub _timetree_pairwise {
  my $self           = shift;
  $self->{starttime} = time();
  $self->{gdba}      = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{taxonDBA}  = $self->{comparaDBA}->get_NCBITaxonAdaptor;

  require Cwd;
  my $dir = $self->{_timetree_pairwise};
  chdir("$dir");
  my $species_list = $self->{species_list};
  $species_list =~ s/\_/\ /g;
  my @species_set = split("\:",$species_list);
  my $baseurl = 'time_e_query.php';
  unlink <$baseurl*>;
  my $species_tree;
  foreach my $sp (@species_set) {
    my $taxon = $self->{taxonDBA}->fetch_node_by_name($sp);
    $taxon->release_children;
    $species_tree = $taxon->root unless ($species_tree);
    $species_tree->merge_node_via_shared_ancestor($taxon);
  }
  $species_tree = $species_tree->minimize_tree;

  print "species1,species2,ancestor_name,mya\n";
  while (my $species1 = shift (@species_set)) {
    foreach my $species2 (@species_set) {
      my $ancestor;
      eval {$ancestor = $species_tree->find_node_by_name($species1)->find_first_shared_ancestor($species_tree->find_node_by_name($species2));};
      next if ($@);
      my $ancestor_name = $ancestor->name;
      my $ancestor_taxon_id = $ancestor->taxon_id;
      my $fileurl = $baseurl . '?taxon_a=' . $species1 . '&taxon_b=' . $species2;
      my $url = "http://www.timetree.org/" . $fileurl;
      my $ret = `export HTTP_PROXY="http://cache.internal.sanger.ac.uk:3128"; wget "$url" 1>/dev/null 2>/dev/null`;

      next unless (-e $fileurl);
      open FILE, "$fileurl" or die "$!";
      my $weighted = 0; my $all = 0; my $mya = undef; my $simple_average = 0;
      while (<FILE>) {
        if (1 == $weighted && 1 == $all && 1 == $simple_average && $_ =~ /Mya/) {
          $_ =~ /\>(.+)\&nbsp\;Mya/;
          $mya = $1;
          last;
        }
        if (1 == $weighted && 1 == $all && $_ =~ /Mya/) {
          $simple_average = 1;
          next;
        }
        if (1 == $weighted && $_ =~ /All/) {
          $all = 1;
          next;
        }
        if ($_ =~ /Weighted/) {
          $weighted = 1;
          next;
        }
      }

      close FILE;
      unlink "$fileurl";
      my $taxon_id = $species_tree->taxon_id;
      # print "insert into ncbi_taxa_name (taxon_id, name, name_class) values (9528,   \"13.64\",\"ensembl timetree mya\");"
      if (defined($mya)) {
        print "$species1,$species2,$ancestor_name,$mya\n";
        $self->{timetree_ancestor_values}{$ancestor_taxon_id}{$mya} = $ancestor_name;
        $self->{timetree_ancestor_names}{$ancestor_taxon_id} = $ancestor_name;
      }
    }
  }
  print STDERR "# ancestor_name,ancestor_node_id,timetree_values\n";
  foreach my $ancestor_node_id (keys %{$self->{timetree_ancestor_values}}) {
    my $ancestor_name = $self->{timetree_ancestor_names}{$ancestor_node_id};

    next unless defined ($self->{timetree_ancestor_values}{$ancestor_node_id});
    $DB::single=1;1;
    my @myas = keys %{$self->{timetree_ancestor_values}{$ancestor_node_id}};
    print STDERR "# $ancestor_name,$ancestor_node_id, " . join(",",sort {$b<=>$a} keys %{$self->{timetree_ancestor_values}{$ancestor_node_id}}), "\n";
    my $best_mya = $myas[0];
    print STDERR "insert ignore into ncbi_taxa_name (taxon_id, name_class, name) values ($ancestor_node_id,\"ensembl timetree mya\", \"$best_mya\");\n";
  }
}

sub _dump_proteome_slices {
  my $self = shift;
  $self->{starttime} = time();
  my $species = $self->{_dump_proteome_slices};
  $species =~ s/\_/\ /g;

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -verbose => "0" );

  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;

  my $gdb = $self->{gdba}->fetch_by_name_assembly($species);

my $slice_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("$species", "core", "Slice");

  foreach my $member (@{$self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$gdb->taxon_id)}) {
    my $gene = $member->get_Gene;
    my $gene_stable_id = $member->stable_id;
    my $slice = $slice_adaptor->fetch_by_gene_stable_id($gene_stable_id,'200%');
    # my $slice = $gene->feature_Slice;
    my $seq = $slice->seq;
    $seq =~ s/(.{72})/$1\n/g;
    print ">$gene_stable_id\n$seq\n";
  }
}

sub _dump_genetree_slices {
  my $self = shift;
  $self->{starttime} = time();

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -verbose => "0" );

  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  my @clusters = @{$self->{'clusterset'}->children};
  my $totalnum_clusters = scalar(@clusters);
  printf("totalnum_trees: %d\n", $totalnum_clusters);

  my $count = 0;
  foreach my $cluster (@clusters) {
    my $gene_count = $cluster->get_tagvalue("gene_count");
    next if $gene_count > 42;
    next if $gene_count < 40;

    my $fastafile = "proteintree_". $cluster->node_id. ".fasta";
    print STDERR "## $fastafile\n";
    open(OUTSEQ, ">$fastafile")
      or $self->throw("Error opening $fastafile for write");

    my $hash_seq;
    foreach my $member (@{$cluster->get_all_leaves}) {
      my $gene = $member->gene_member->get_Gene;
      my $slice = $gene->feature_Slice;
      my $seq = $slice->seq;
      my $real_length = length($seq);
      $hash_seq->{len}{$member->stable_id} = $real_length;
      $hash_seq->{seq}{$member->stable_id} = $seq;
    }

    my $to_delete;
    foreach my $seqid (keys %$hash_seq) {
      #       $seq =~ s/(.{72})/$1\n/g;
      #       chomp $seq;

      # printf OUTSEQ ">%s\n$seq\n", $seqid;
    }
    close OUTSEQ;

    my $newickfile = "proteintree_". $cluster->node_id. ".nh";
    open(NEWICK, ">$newickfile")
      or $self->throw("Error opening $newickfile for write");
    print NEWICK $cluster->newick_format;
    close NEWICK;
  }
}

# sub _de_bruijn_naming {
#   my $self = shift;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;

#   my $member_id = $self->{_de_bruijn_naming};
#   my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$member_id);
#   my $tree = $self->{treeDBA}->fetch_by_Member_root_id($member);
#   exit unless (defined ($tree));

#   my ($desc, $sym, $count, $cat_sym, $count_all, %hash, @array);
#   $count_all = $count = 0; $cat_sym = '';
#   foreach my $leaf (@{$tree->get_all_leaves}) {
#     next unless ($leaf->taxon->name eq 'Homo sapiens');
#     ++$count_all;
#     my $desc = $leaf->description;
#     my $sym  = $leaf->gene_member->display_label;
#     next unless ($desc);
#     $desc =~ s/\[[^\[\]]+\]\s*$//; # chop source tag
#     $desc =~ s/'//g;
#     $desc =~ s/\B\([^\(\)]*\)\B//g;
#     $desc =~ s/\.\B//g;
#     $_ = $desc;
#     foreach my $p (split) {
#       if (defined($hash{$p})) {
#         ++$hash{$p};
#       } else {
#         $hash{$p} = 1;
#         push(@array, $p);
#       }
#     }
#     $cat_sym .= "$sym/" if ($sym && $sym !~ /^ENS/);
#     ++$count;
#   }
#   $desc = '';
#   chop($cat_sym);

#   foreach my $p (@array) {
#     $desc .= "$p " if ($hash{$p} / $count >= 0.50);
#   }
#   if (1 == scalar(keys %hash)) {
#     $desc = '';
#   }
#   unless ($desc) {
#     $desc = $cat_sym;
#   } else {
#     chop($desc);
#   }
#   if ($count >= 4) {          # otherwise the symbol will be too long.
#     print STDERR "($cat_sym) ";
#     $cat_sym = 'MIXED';
#   } 
#   $cat_sym = 'N/A' unless ($cat_sym);
#   $desc = 'N/A' unless ($desc);
#   print $tree->node_id, " $cat_sym %% $desc\n";
# }

# sub _circos {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
#   # $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
# #   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
# #   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
# #  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

# #   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
# #   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
# #   Bio::EnsEMBL::Registry->load_registry_from_db
# #       ( -host => "$myhost",
# #         -user => "$myuser",
# #         -db_version => "$mydbversion",
# #         -verbose => "0" );
#   my $gene_id = $self->{_circos};
#   my $gene_member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$gene_id);

#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly("Homo sapiens");

#   my $sc = {}; $sc->{"Hsap"}= "green"; $sc->{"Ptro"}="blue"; $sc->{"Ppyg"}="red"; $sc->{"Mmul"}="orange";
#   my @species_set = ("Pan troglodytes","Pongo pygmaeus","Macaca mulatta");
#   my $karyotypes;
#   my $links;

#   my $link_count = 1;
#   my @within_species_paralogies = @{$self->{ha}->fetch_all_by_Member_paired_species($gene_member,$sp1_gdb->name,['ENSEMBL_PARALOGUES'])};
#   my @within_members;
#   # FIXME -- fetch only the within_species_paralogues
#   foreach my $within_species_paralogy (@within_species_paralogies) {
#     my ($member1, $member2) = @{$within_species_paralogy->gene_list};
#     push @within_members, $member1 unless ($member1->stable_id eq $gene_member->stable_id);
#     push @within_members, $member2 unless ($member2->stable_id eq $gene_member->stable_id);
#     my $sp1_kname = $sp1_gdb->short_name . "_" . $member1->chr_name;
#     my $sp1_start = $member1->chr_start; my $sp1_end = $member1->chr_end;
#     my $sp2_start = $member2->chr_start; my $sp2_end = $member2->chr_end;
#     $karyotypes->{$sp1_kname}{start} = $sp1_start unless (defined ($karyotypes->{$sp1_kname}{start}) && $karyotypes->{$sp1_kname}{start} < $sp1_start);
#     $karyotypes->{$sp1_kname}{end}   =   $sp1_end unless (defined ($karyotypes->{$sp1_kname}{end})   && $karyotypes->{$sp1_kname}{end} > $sp1_end);
#     $links->{$link_count}{$sp1_kname} = "$sp1_start $sp1_end";
#     $links->{$link_count}{$sp1_kname} = "$sp2_start $sp2_end";
#     $link_count++;
#   }
# #   @within_members = undef;
# #   push @within_members, $gene_member;
#   foreach my $within_member (@within_members) {
#     foreach my $species (sort @species_set) {
#       my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#       foreach my $homology (@{$self->{ha}->fetch_all_by_Member_paired_species($within_member, $species)}) {
#         my ($member1, $member2) = @{$homology->gene_list};
#         my $temp; unless ($member1->stable_id =~ /ENSG0/) { $temp = $member1; $member1 = $member2; $member2 = $temp; }
#         my $sp1_kname = $sp1_gdb->short_name . "_" . $member1->chr_name;
#         my $sp2_kname = $sp2_gdb->short_name . "_" . $member2->chr_name;
#         my $sp1_start = $member1->chr_start; my $sp1_end = $member1->chr_end;
#         my $sp2_start = $member2->chr_start; my $sp2_end = $member2->chr_end;
#         $karyotypes->{$sp1_kname}{start} = $sp1_start unless (defined ($karyotypes->{$sp1_kname}{start}) && $karyotypes->{$sp1_kname}{start} < $sp1_start);
#         $karyotypes->{$sp1_kname}{end}   =   $sp1_end unless (defined ($karyotypes->{$sp1_kname}{end})   && $karyotypes->{$sp1_kname}{end} > $sp1_end);
#         $karyotypes->{$sp2_kname}{start} = $sp2_start unless (defined ($karyotypes->{$sp2_kname}{start}) && $karyotypes->{$sp2_kname}{start} < $sp2_start);
#         $karyotypes->{$sp2_kname}{end}   =   $sp2_end unless (defined ($karyotypes->{$sp2_kname}{end})   && $karyotypes->{$sp2_kname}{end} > $sp2_end);
#         $links->{$link_count}{$sp1_kname} = "$sp1_start $sp1_end";
#         $links->{$link_count}{$sp2_kname} = "$sp2_start $sp2_end";
#         $link_count++;
#       }
#     }
#   }
#   # Add 10% padding
#   foreach my $kname (keys %$karyotypes) {
#     my $start = $karyotypes->{$kname}{start};
#     my $end   = $karyotypes->{$kname}{end};
#     my $tag_10 = int(($end-$start)/10);
#     $start = $start - $tag_10 unless ($tag_10 > $start);
#     $end = $end + $tag_10;
#     $karyotypes->{$kname}{start} = $start;
#     $karyotypes->{$kname}{end}   = $end;
#   }
#   open KARYO,">$gene_id.karyotype.txt" or die $!;
#   # chr - hs11 11 0 134452384 green
#   foreach my $kname (sort keys %$karyotypes) {
#     my $start = $karyotypes->{$kname}{start};
#     my $end   = $karyotypes->{$kname}{end};
#     my ($sp,$chr_name) = split("_",$kname);
#     my $color = $sc->{$sp};
#     print KARYO "chr - $kname $kname $start $end $color\n";
#   }
#   close KARYO;
#   open LINKS,">$gene_id.links.txt" or die $!;
#   foreach my $link_id (sort keys %$links) {
#     foreach my $kname (sort keys %{$links->{$link_id}}) {
#       my $start_end = $links->{$link_id}{$kname};
#       my ($sp,$chr_name) = split("_",$kname);
#       my $color = $sc->{$sp};
#       print LINKS "segdup"."$link_id $kname $start_end color=$color\n";
#     }
#   }
#   close LINKS;

#   my $conf = 
#     "<colors>\n" . 
# "<<include etc/colors.conf>>\n" . 
# "</colors>\n" . 
# "<fonts>\n" . 
# "<<include etc/fonts.conf>>\n" . 
# "</fonts>\n" . 
# "<<include ideogram.conf>>\n" . 
# "<<include ticks.conf>>\n" . 
# "karyotype   = /lustre/work1/ensembl/avilella/circos/$gene_id.karyotype.txt\n" . 
# "<image>\n" . 
# "dir = /lustre/work1/ensembl/avilella/circos\n" . 
# "file  = $gene_id.png\n" . 
# "# radius of inscribed circle in image\n" . 
# "radius         = 1500p\n" . 
# "background     = white\n" . 
# "# by default angle=0 is at 3 o'clock position\n" . 
# "angle_offset   = -90\n" . 
# "</image>\n" . 
# "<links>\n" . 
# "z      = 0\n" . 
# "radius = 0.9r\n" . 
# "crest  = 1\n" . 
# "color  = grey\n" . 
# "bezier_radius        = 0.2r\n" . 
# "bezier_radius_purity = 0.5\n" . 
# "<link segdup>\n" . 
# "thickness    = 2\n" . 
# "file         = /lustre/work1/ensembl/avilella/circos/$gene_id.links.txt\n" . 
# "<rules>\n" . 
# "<rule>\n" . 
# "importance = 110\n" . 
# "condition  = _THICKNESS1_ == 4 && rand() < 0.25\n" . 
# "thickness  = 10\n" . 
# "color      = green\n" . 
# "z          = 15\n" . 
# "</rule>\n" . 
# "<rule>\n" . 
# "importance = 100\n" . 
# "condition  = _COLOR1_ eq \"red\"\n" . 
# "thickness  = 4\n" . 
# "z          = 10\n" . 
# "flow = restart\n" . 
# "</rule>\n" . 
# "<rule>\n" . 
# "importance = 90\n" . 
# "condition  = _COLOR1_ ne \"grey\" && _THICKNESS1_ == 2\n" . 
# "z          = 5\n" . 
# "</rule>\n" . 
# "</rules>\n" . 
# "</link>\n" . 
# "</links>\n" . 
# "chromosomes_units           = 1000\n" . 
# "chromosomes_display_default = yes\n" . 
# "anglestep       = 0.5\n" . 
# "minslicestep    = 10\n" . 
# "beziersamples   = 40\n" . 
# "debug           = no\n" . 
# "warnings        = no\n" . 
# "imagemap        = no\n" . 
# "units_ok = bupr\n" . 
# "units_nounit = n";

#   open CONF,">$gene_id.conf" or die $!;
#   print CONF $conf;
#   close CONF;
# }


# sub _transcript_pair_exonerate {
#   my $self = shift;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly("Homo sapiens");
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly("Pan troglodytes");

#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   my @homologies = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,'ortholog_one2one')};

#   eval {require Bio::Tools::Run::Alignment::Exonerate;};
#   if ($@) {
#     print STDERR "Bio::Tools::Run::Alignment::Exonerate not found"; die "$!\n";
#   }
#   eval {require Bio::SeqIO;};
#   if ($@) {
#     print STDERR "Bio::SeqIO not found"; die "$!\n";
#   }

#   foreach my $this_homology (@homologies) {
#     my ($member1,$member2) = map { $_->get_canonical_peptide_Member } @{$this_homology->gene_list};
#     my $transcript1 = $member1->get_Transcript;
#     my $transcript2 = $member2->get_Transcript;
#     my $seq1 = Bio::Seq->new
#       (
#        -display_id => $transcript1->stable_id,
#        -seq => $transcript1->slice->subseq($transcript1->start(),$transcript1->end(),$transcript1->strand())
#       );
#     my $seq2 = Bio::Seq->new
#       (
#        -display_id => $transcript2->stable_id,
#        -seq => $transcript2->slice->subseq($transcript2->start(),$transcript2->end(),$transcript2->strand())
#       );
#     my $run = Bio::Tools::Run::Alignment::Exonerate->new(model=> 'coding2coding');
#     # my $run = Bio::Tools::Run::Alignment::Exonerate->new(arguments=>'--model coding2coding');
#     my $c2c_obj = $run->run($seq1,$seq2);
#   }

#   #exonerate --model coding2coding query.fasta target.fasta
#   #   #exonerate parameters can all be passed via arguments parameter.
#   #   #parameters passed are not checked for validity


#   #   while(my $result = $searchio->next_result){
#   #     while( my $hit = $result->next_hit ) {
#   #       while( my $hsp = $hit->next_hsp ) {
#   #         print $hsp->start."\t".$hsp->end."\n";
#   #       }
#   #     }
#   #   }

# }

# sub _synteny_metric {
#   my $self = shift;

#   my @dummy;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $species1 = $self->{_species1} || "Homo sapiens";
#   my $species2 = $self->{_species2} || "Pan troglodytes";
#   $species1 =~ s/\_/\ /g;
#   $species2 =~ s/\_/\ /g;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#   my $sp1_gdb_id = $sp1_gdb->dbID;
#   my $sp2_gdb_id = $sp2_gdb->dbID;

#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#   my $starttime;
#   $starttime = time();

#   print STDERR "fetching all homologies\n";
#   my $homologies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss);
#   #   if ($self->{debug} == 1) {
#   #     my $mlss_2 = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
#   #     my $paralogies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss_2);
#   #     push @{$homologies}, @{$paralogies} if (defined $paralogies);
#   #   }
#   #   print STDERR (time()-$starttime), " secs... \n" if ($self->{verbose});

#   my $homology_count;
#   my $totalnum_homologies = scalar(@$homologies);
#   print STDERR "$totalnum_homologies homologies\n";

#   print "gene_stable_id,hit_stable_id,synt_type,left_distance,right_distance,chr_name,chr_start,chr_strand,left_hit_stable_id,right_hit_stable_id\n";

#   #  my @susp = ("ENSG00000000971","ENSG00000002587","ENSG00000003096","ENSG00000004864","ENSG00000005020","ENSG00000005108","ENSG00000005302","ENSG00000006116","ENSG00000006468","ENSG00000007001","ENSG00000007174","ENSG00000007372","ENSG00000008083");
#   foreach my $homology (@$homologies) {
#     #     next if ((1 == $self->{debug}) && ($homology->description !~ /one2one/));
#     #     next if ((2 == $self->{debug}) && ($homology->description =~ /RHS/));
#     my ($member1, $member2) = @{$homology->gene_list};
#     $homology_count++;
#     #     if ($self->{'verbose'} &&  ($homology_count % $self->{'verbose'} == 0)) {
#     #       my $verbose_string = sprintf "[%5d / %5d homologies done]\n", 
#     #         $homology_count, $totalnum_homologies;
#     #       print STDERR $verbose_string;
#     #     }
#     my $member1_stable_id = $member1->stable_id;
#     my $member1_genome_db = $member1->genome_db;
#     my $member1_genome_db_id = $member1_genome_db->dbID;
#     my $member2_stable_id = $member2->stable_id;
#     my $member2_genome_db = $member2->genome_db;
#     my $member2_genome_db_id = $member2_genome_db->dbID;
#     # A list of homology correspondencies
#     $self->{_synt_orthologs}{$member1_genome_db_id}{$member1_stable_id}{$member2_stable_id} = 1;
#     $self->{_synt_orthologs}{$member2_genome_db_id}{$member2_stable_id}{$member1_stable_id} = 1;
#     # Info about the chr location of $member1
#     $self->{_m_chr_info}{$member1_genome_db_id}{$member1_stable_id}{chr_name} = $member1->chr_name;
#     my $member1_start = sprintf("%10d",$member1->chr_start);
#     $self->{_m_chr_info}{$member1_genome_db_id}{$member1_stable_id}{chr_start} = $member1_start;
#     $self->{_m_chr_info}{$member1_genome_db_id}{$member1_stable_id}{chr_strand} = $member1->chr_strand;
#     $self->{_chr_map}{$member1_genome_db_id}{$member1->chr_name}{$member1_start} = $member1_stable_id;
#     # Info about the chr location of $member2
#     $self->{_m_chr_info}{$member2_genome_db_id}{$member2_stable_id}{chr_name} = $member2->chr_name;
#     my $member2_start = sprintf("%10d",$member2->chr_start);
#     $self->{_m_chr_info}{$member2_genome_db_id}{$member2_stable_id}{chr_start} = $member2_start;
#     $self->{_m_chr_info}{$member2_genome_db_id}{$member2_stable_id}{chr_strand} = $member2->chr_strand;
#     $self->{_chr_map}{$member2_genome_db_id}{$member2->chr_name}{$member2_start} = $member2_stable_id;
#   }
#   foreach my $member1 (keys %{$self->{_m_chr_info}{$sp1_gdb_id}}) {
#     # From genome A to genome B
#     my $chr_start = $self->{_m_chr_info}{$sp1_gdb_id}{$member1}{chr_start};
#     my $chr_name = $self->{_m_chr_info}{$sp1_gdb_id}{$member1}{chr_name};
#     my $chr_strand = $self->{_m_chr_info}{$sp1_gdb_id}{$member1}{chr_strand};
#     my $lower_limit1 = (($chr_start)-($self->{_synteny_metric}));
#     $lower_limit1 = 1 if ($lower_limit1 <= 0);
#     my $upper_limit1 = (($chr_start)+($self->{_synteny_metric}));
#     foreach my $map_point (sort keys %{$self->{_chr_map}{$sp1_gdb_id}{$chr_name}}) {
#       next unless ($map_point > $lower_limit1 && $map_point < $upper_limit1);
#       my $distance1 =  $chr_start - $map_point;
#       my $abs_distance1 = abs($distance1); $abs_distance1 = sprintf("%10d",$abs_distance1);
#       my $nb_member1 = $self->{_chr_map}{$sp1_gdb_id}{$chr_name}{$map_point};
#       $self->{_each_synteny}{$sp1_gdb_id}{$member1}{left}{$abs_distance1}{$nb_member1}{$chr_strand} = 1 if ($distance1 > 0);
#       $self->{_each_synteny}{$sp1_gdb_id}{$member1}{right}{$abs_distance1}{$nb_member1}{$chr_strand} = 1 if ($distance1 < 0);
#     }
#     if (!defined($self->{_each_synteny}{$sp1_gdb_id}{$member1})) {
#       $self->{_synt_types}{$member1} = "too_dist";
#       my $chr_name = $self->{_m_chr_info}{$sp1_gdb_id}{$member1}{chr_name};
#       my $chr_start = $self->{_m_chr_info}{$sp1_gdb_id}{$member1}{chr_start};
#       my $chr_strand = $self->{_m_chr_info}{$sp1_gdb_id}{$member1}{chr_strand};
#       my $result = "$member1,na,too_dist,na,na,$chr_name,$chr_start,$chr_strand,na,na\n";
#       $result =~ s/\ //g;
#       print $result;
#     }
#   }

#   foreach my $reference_stable_id (keys %{$self->{_each_synteny}{$sp1_gdb_id}}) {
#     # We are trying to find the neighbor genes left and right of $reference_stable_id
    
#     # For that we look at the closest on one side, and check if its
#     # orthologies are hitting the ortholog of $reference_stable_id. If so, we
#     # go to the next gene, until we find an unrelated one or run out
#     # of genes in the slice. We do the same for the other side, and
#     # then we check for the specific type of synteny
    
#     @dummy = keys %{$self->{_synt_orthologs}{$sp1_gdb_id}{$reference_stable_id}};
#     my $hit_stable_id = $dummy[0];
#     next unless (defined($hit_stable_id));

#     my $resolved_unrelated_left = 0;
#     my $resolved_unrelated_right = 0;
#     my @left_distances = sort keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{left}};
#     my @right_distances = sort keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{right}};
    
#     if (0 == scalar(@left_distances) || 0 == scalar(@right_distances)) {
#       my $left = $left_distances[0] || "na";
#       my $right = $right_distances[0] || "na";
#       $left = sprintf("%d",$left) unless ($left eq 'na'); $right = sprintf("%d",$right) unless ($right eq 'na');
#       $self->{_synt_types}{$reference_stable_id} = "onehanded_too_dist";
#       my $chr_name = $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_name};
#       my $chr_start = $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_start};
#       my $chr_strand = $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_strand};
#       my $result = "$reference_stable_id,$hit_stable_id,too_dist,$left,$right,$chr_name,$chr_start,$chr_strand,na,na\n";
#       $result =~ s/\ //g;
#       print $result;
#       next;
#     }

#     my $left_nb = 0;
#     my $right_nb = 0;
#     my $final_left_nb = 0;
#     my $final_right_nb = 0;
#     my $final_left_hit_ortholog_stable_id;
#     my $final_right_hit_ortholog_stable_id;

#     #print "\n",time()-$starttime,"\n" if ($self->{verbose} == 2);
#     while (0 == $resolved_unrelated_left || 0 == $resolved_unrelated_right) {
#       if ($left_nb >= scalar(@left_distances) || $right_nb >= scalar(@right_distances)) {
#         last;
#       }
#       my @left_to_reference_stable_ids1 = keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{left}{$left_distances[$left_nb]}};
#       my @right_to_reference_stable_ids1 = keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{right}{$right_distances[$right_nb]}};
#       my $left_to_reference_stable_id = $left_to_reference_stable_ids1[0];
#       my $right_to_reference_stable_id = $right_to_reference_stable_ids1[0];
#       # Check if the closest left and right are syntenic orthologs on both sides or only one, or in a triangle
#       @dummy = keys %{$self->{_synt_orthologs}{$sp1_gdb_id}{$left_to_reference_stable_id}};
#       my $left_hit_ortholog_stable_id = $dummy[0];
#       @dummy = keys %{$self->{_synt_orthologs}{$sp1_gdb_id}{$right_to_reference_stable_id}};;
#       my $right_hit_ortholog_stable_id = $dummy[0];
#       my $chr_hit = ''; $chr_hit = $self->{_m_chr_info}{$sp2_gdb_id}{$hit_stable_id}{chr_name};
#       my $chr_left_hit_ortholog = ''; $chr_left_hit_ortholog = $self->{_m_chr_info}{$sp2_gdb_id}{$left_hit_ortholog_stable_id}{chr_name} if defined($left_hit_ortholog_stable_id);
#       my $chr_right_hit_ortholog = ''; $chr_right_hit_ortholog = $self->{_m_chr_info}{$sp2_gdb_id}{$right_hit_ortholog_stable_id}{chr_name} if defined($right_hit_ortholog_stable_id);
      
#       if (defined($left_hit_ortholog_stable_id) && defined($right_hit_ortholog_stable_id)) {
#         my $unrelated_left = 0; $unrelated_left = 1 if (!defined($self->{_synt_orthologs}{$sp1_gdb_id}{$left_to_reference_stable_id}{$hit_stable_id}));
#         my $unrelated_right = 0; $unrelated_right = 1 if (!defined($self->{_synt_orthologs}{$sp1_gdb_id}{$right_to_reference_stable_id}{$hit_stable_id}));
#         my $chr_left_to_hit_distance = 
#           abs(
#               $self->{_m_chr_info}{$sp2_gdb_id}{$hit_stable_id}{chr_start} - 
#               $self->{_m_chr_info}{$sp2_gdb_id}{$left_hit_ortholog_stable_id}{chr_start});
#         my $chr_right_to_hit_distance = 
#           abs(
#               $self->{_m_chr_info}{$sp2_gdb_id}{$hit_stable_id}{chr_start} - 
#               $self->{_m_chr_info}{$sp2_gdb_id}{$right_hit_ortholog_stable_id}{chr_start});
#         if ((1 == $unrelated_left) && 
#             ($chr_left_hit_ortholog eq $chr_hit) && 
#             ($chr_left_to_hit_distance <= ($self->{_synteny_metric})) &&
#             $left_hit_ortholog_stable_id ne $right_hit_ortholog_stable_id) {
#           $resolved_unrelated_left = 1;
#           $final_left_nb = $left_nb;
#           $final_left_hit_ortholog_stable_id = $left_hit_ortholog_stable_id;
#         } else {
#           $left_nb++;
#         }
#         if ((1 == $unrelated_right) && 
#             ($chr_right_hit_ortholog eq $chr_hit) && 
#             ($chr_right_to_hit_distance <= ($self->{_synteny_metric})) &&
#             $left_hit_ortholog_stable_id ne $right_hit_ortholog_stable_id) {
#           $resolved_unrelated_right = 1;
#           $final_right_nb = $right_nb;
#           $final_right_hit_ortholog_stable_id = $right_hit_ortholog_stable_id;
#         } else {
#           $right_nb++;
#         }
#       } elsif (defined($left_hit_ortholog_stable_id) && 
#                !defined($right_hit_ortholog_stable_id)) {
#         # we have a left but not a right
#         my $unrelated_left = 0; $unrelated_left = 1 if (!defined($self->{_synt_orthologs}{$sp1_gdb_id}{$left_to_reference_stable_id}{$hit_stable_id}));
#         my $chr_left_to_hit_distance = 
#           abs(
#               $self->{_m_chr_info}{$sp2_gdb_id}{$hit_stable_id}{chr_start} - 
#               $self->{_m_chr_info}{$sp2_gdb_id}{$left_hit_ortholog_stable_id}{chr_start});
#         if ((1 == $unrelated_left) && 
#             ($chr_left_hit_ortholog eq $chr_hit) && 
#             ($chr_left_to_hit_distance <= ($self->{_synteny_metric})) &&
#             $left_hit_ortholog_stable_id ne $right_hit_ortholog_stable_id) {
#           $resolved_unrelated_left = 1;
#           $final_left_nb = $left_nb;
#           $final_left_hit_ortholog_stable_id = $left_hit_ortholog_stable_id;
#           $right_nb++;
#         }
#       } elsif (!defined($left_hit_ortholog_stable_id) && 
#                defined($right_hit_ortholog_stable_id)) {
#         # we have a right but not a left
#         my $unrelated_right = 0; $unrelated_right = 1 if (!defined($self->{_synt_orthologs}{$sp1_gdb_id}{$right_to_reference_stable_id}{$hit_stable_id}));
#         my $chr_right_to_hit_distance = 
#           abs(
#               $self->{_m_chr_info}{$sp2_gdb_id}{$hit_stable_id}{chr_start} - 
#               $self->{_m_chr_info}{$sp2_gdb_id}{$right_hit_ortholog_stable_id}{chr_start});
#         if ((1 == $unrelated_right) && 
#             ($chr_right_hit_ortholog eq $chr_hit) && 
#             ($chr_right_to_hit_distance <= ($self->{_synteny_metric})) &&
#             $left_hit_ortholog_stable_id ne $right_hit_ortholog_stable_id) {
#           $resolved_unrelated_right = 1;
#           $final_right_nb = $right_nb;
#           $final_right_hit_ortholog_stable_id = $right_hit_ortholog_stable_id;
#           $left_nb++;
#         }
#       } else {
#         # Keep looking as we may have a synteny in the next neighbours
#         $resolved_unrelated_left = 0;
#         $resolved_unrelated_right = 0;
#         $left_nb++;
#         $right_nb++;
#       }
#     }

#     if (defined($final_left_hit_ortholog_stable_id) && defined($final_right_hit_ortholog_stable_id)) {
#       $self->{_synt_types}{$reference_stable_id} = "perfect_synt";
#       print "$reference_stable_id,$hit_stable_id,perfect_synt,", $left_distances[$final_left_nb],",", $right_distances[$final_right_nb], ",",
#         $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_name},",",
#           int($self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_start}),",",
#             $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_strand},",",
#               $final_left_hit_ortholog_stable_id,",",
#                 $final_right_hit_ortholog_stable_id,
#                   "\n";
#       print STDERR "\nhttp://www.ensembl.org/Homo_sapiens/multicontigview?gene=$reference_stable_id;context=100000;s1=",$self->{_species2},";g1=$hit_stable_id\n" if ($self->{verbose});
#     } elsif (!defined($final_left_hit_ortholog_stable_id) && defined($final_right_hit_ortholog_stable_id)) {
#       $self->{_synt_types}{$reference_stable_id} = "good_synt";
#       print "$reference_stable_id,$hit_stable_id,good_synt,", "na",",", $right_distances[$final_right_nb], ",",
#         $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_name},",",
#           int($self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_start}),",",
#             $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_strand},",",
#               "na",",",
#                 $final_right_hit_ortholog_stable_id,
#                   "\n";
#     } elsif (defined($final_left_hit_ortholog_stable_id) && !defined($final_right_hit_ortholog_stable_id)) {
#       $self->{_synt_types}{$reference_stable_id} = "good_synt";
#       print "$reference_stable_id,$hit_stable_id,good_synt,", $left_distances[$final_left_nb],",", "na", ",",
#         $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_name},",",
#           int($self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_start}),",",
#             $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_strand},",",
#               $final_left_hit_ortholog_stable_id,",",
#                 "na",
#                   "\n";
#       print STDERR "\nhttp://www.ensembl.org/Homo_sapiens/multicontigview?gene=$reference_stable_id;context=100000;s1=",$self->{_species2},";g1=$hit_stable_id\n" if ($self->{verbose});
#     } else {
#       $self->{_synt_types}{$reference_stable_id} = "too_dist";
#       my $chr_name = $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_name};
#       my $chr_start = $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_start};
#       my $chr_strand = $self->{_m_chr_info}{$sp1_gdb_id}{$reference_stable_id}{chr_strand};
#       my $result = "$reference_stable_id,$hit_stable_id,too_dist,na,na,$chr_name,$chr_start,$chr_strand,na,na\n";
#       $result =~ s/\ //g;
#       print $result;
#     }
#   }
#   # this is the very last step for species2-singleton printouts
#   my $sp1_genes = $self->{comparaDBA}->get_MemberAdaptor->fetch_all_by_source_taxon('ENSEMBLGENE', $sp1_gdb->taxon_id);
#   foreach my $gene (@$sp1_genes) {
#     next if (defined($self->{_synt_types}{$gene->stable_id}));
#     my $gene_stable_id = $gene->stable_id;
#     my $chr_name = $gene->chr_name;
#     my $chr_start = $gene->chr_start;
#     my $chr_strand = $gene->chr_strand;
#     $self->{_synt_types}{$gene_stable_id} = "nohit_orth";
#     print $gene_stable_id, ",na,nohit_orth,na,na,", $chr_name,",", $chr_start,",", $chr_strand,"\n";
#   }
# }

# sub _old_synteny_metric {
#   my $self = shift;

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+/g;
#   my ($myuser,$myhost) = ($1,$2);
#   Bio::EnsEMBL::Registry->load_registry_from_db(-host=>$myhost, -user=>$myuser, -verbose=>'0');
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $species1 = $self->{_species1} || "Homo sapiens";
#   my $species2 = $self->{_species2} || "Pan troglodytes";
#   $species1 =~ s/\_/\ /g;
#   $species2 =~ s/\_/\ /g;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#   my $sp1_gdb_id = $sp1_gdb->dbID;
#   my $sp2_gdb_id = $sp2_gdb->dbID;

#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#   my $starttime;
#   $starttime = time();

#   print STDERR "fetching all homologies\n";
#   my $homologies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss);
# #   if ($self->{debug} == 1) {
# #     my $mlss_2 = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
# #     my $paralogies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss_2);
# #     push @{$homologies}, @{$paralogies} if (defined $paralogies);
# #   }
#   print STDERR (time()-$starttime), " secs... \n" if ($self->{verbose});

#   my $homology_count;
#   my $totalnum_homologies = scalar(@$homologies);
#   print STDERR "$totalnum_homologies homologies\n";

#   print "gene_stable_id,synt_type,left_distance,right_distance,chr_name,chr_start,chr_strand,left_hit_stable_id,right_hit_stable_id\n";
#   foreach my $homology (@$homologies) {
#     next if (($self->{debug} == 2) && ($homology->description =~ /RHS/));
#     my ($member1, $member2) = @{$homology->gene_list};
#     $homology_count++;
#     if ($self->{'verbose'} &&  ($homology_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d homologies done]\n", 
#         $homology_count, $totalnum_homologies;
#       print STDERR $verbose_string;
#     }
# #     if (1 == $self->{debug}) {
# #       next if ($member1->chr_name ne '22'); # to speed up loading when debugging
# #     }
#     my $member1_stable_id = $member1->stable_id;
#     my $member1_genome_db = $member1->genome_db;
#     my $member1_genome_db_id = $member1_genome_db->dbID;
#     my $member2_stable_id = $member2->stable_id;
#     my $member2_genome_db = $member2->genome_db;
#     my $member2_genome_db_id = $member2_genome_db->dbID;
#     # A list of homology correspondencies
#     $self->{_synt_orthologs}{$member1_genome_db_id}{$member1_stable_id} = $member2_stable_id;
#     $self->{_synt_orthologs}{$member2_genome_db_id}{$member2_stable_id} = $member1_stable_id;
#     # Info about the chr location of $member1
#     $self->{_m_chr_info}{$member1_stable_id}{chr_name} = $member1->chr_name;
#     $self->{_m_chr_info}{$member1_stable_id}{chr_start} = $member1->chr_start;
#     $self->{_m_chr_info}{$member1_stable_id}{chr_strand} = $member1->chr_strand;
#     # Info about the chr location of $member2
#     $self->{_m_chr_info}{$member2_stable_id}{chr_name} = $member2->chr_name;
#     $self->{_m_chr_info}{$member2_stable_id}{chr_start} = $member2->chr_start;
#     $self->{_m_chr_info}{$member2_stable_id}{chr_strand} = $member2->chr_strand;
    
#     # From genome A to genome B
#     my $lower_limit1 = (($member1->chr_start)-($self->{_synteny_metric}));
#     $lower_limit1 = 1 if ($lower_limit1 <= 0);
#     my $upper_limit1 = (($member1->chr_start)+($self->{_synteny_metric}));
    
#     my $slice_adaptor1;
#     $slice_adaptor1 = $member1_genome_db->db_adaptor->get_SliceAdaptor if (defined($member1_genome_db->db_adaptor));
#     $slice_adaptor1 = Bio::EnsEMBL::Registry->get_adaptor($member1_genome_db->name, 'core', 'Slice') unless (defined($slice_adaptor1));
#     # Fetch a slice with the start of the gene as a center, and a certain distance left and right to that
#     my $slice1 = $slice_adaptor1->fetch_by_region(undef, $member1->chr_name, $lower_limit1, $upper_limit1);
#     next unless (defined($slice1));
    
#     foreach my $gene (@{$slice1->get_all_Genes}) {
#       next if ($gene->stable_id eq $member1->stable_id);
#       my $distance1 =  $member1->chr_start - $gene->seq_region_start;
#       my $abs_distance1 = abs($distance1); $abs_distance1 = sprintf("%09d",$abs_distance1);
#       my $gene_stable_id = $gene->stable_id;
#       my $gene_strand = $gene->seq_region_strand;
#       $self->{_each_synteny}{$member1_genome_db_id}{$member1_stable_id}{left}{$abs_distance1}{$gene_stable_id}{$gene_strand} = 1 if ($distance1 > 0);
#       $self->{_each_synteny}{$member1_genome_db_id}{$member1_stable_id}{right}{$abs_distance1}{$gene_stable_id}{$gene_strand} = 1 if ($distance1 < 0);
#     }
    
#     # From genome B to genome A
#     my $lower_limit2 = (($member2->chr_start)-($self->{_synteny_metric}));
#     $lower_limit2 = 1 if ($lower_limit2 <= 0);
#     my $upper_limit2 = (($member2->chr_start)+($self->{_synteny_metric}));
    
#     my $slice_adaptor2 = $member2_genome_db->db_adaptor->get_SliceAdaptor;
#     # Fetch a slice with the start of the gene as a center, and a certain distance left and right to that
#     my $slice2 = $slice_adaptor2->fetch_by_region(undef, $member2->chr_name, $lower_limit2, $upper_limit2);
#     next unless (defined($slice2));
    
#     foreach my $gene (@{$slice2->get_all_Genes}) {
#       next if ($gene->stable_id eq $member2->stable_id);
#       my $distance2 =  $member2->chr_start - $gene->seq_region_start;
#       my $abs_distance2 = abs($distance2); $abs_distance2 = sprintf("%09d",$abs_distance2);
#       my $gene_stable_id = $gene->stable_id;
#       my $gene_strand = $gene->seq_region_strand;
#       $self->{_each_synteny}{$member2_genome_db_id}{$member2_stable_id}{left}{$abs_distance2}{$gene_stable_id}{$gene_strand} = 1 if ($distance2 > 0);
#       $self->{_each_synteny}{$member2_genome_db_id}{$member2_stable_id}{right}{$abs_distance2}{$gene_stable_id}{$gene_strand} = 1 if ($distance2 < 0);
#     }
#   }

#   foreach my $reference_stable_id (keys %{$self->{_each_synteny}{$sp1_gdb_id}}) {
#     # We are trying to find the neighbor genes left and right of $reference_stable_id
    
#     # For that we look at the closest on one side, and check if its
#     # orthologies are hitting the ortholog of $reference_stable_id. If so, we
#     # go to the next gene, until we find an unrelated one or run out
#     # of genes in the slice. We do the same for the other side, and
#     # then we check for the specific type of synteny
    
#     my $hit_stable_id = $self->{_synt_orthologs}{$sp1_gdb_id}{$reference_stable_id};
#     next unless (defined($hit_stable_id));

#     my $resolved_unrelated_left = 0;
#     my $resolved_unrelated_right = 0;
#     my @left_distances = sort keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{left}};
#     my @right_distances = sort keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{right}};
    
#     if (0 == scalar(@left_distances) || 0 == scalar(@right_distances)) {
#       my $left = $left_distances[0] || "na";
#       my $right = $right_distances[0] || "na";
#       $left = sprintf("%d",$left) unless ($left eq 'na'); $right = sprintf("%d",$right) unless ($right eq 'na');
#       $self->{_synt_types}{$reference_stable_id} = "too_dist";
#       print "$reference_stable_id,too_dist,", $left, ",", $right, ",",
#         $self->{_m_chr_info}{$reference_stable_id}{chr_name},",",
#           $self->{_m_chr_info}{$reference_stable_id}{chr_start},",",
#             $self->{_m_chr_info}{$reference_stable_id}{chr_strand},",",
#               "na",",",
#                 "na",",",
#                   "\n";
#       $resolved_unrelated_left = 1; $resolved_unrelated_right = 1;
#     }

#     my $left_nb = 0;
#     my $right_nb = 0;
#     my $final_left_nb = 0;
#     my $final_right_nb = 0;
#     my $final_left_hit_ortholog_stable_id;
#     my $final_right_hit_ortholog_stable_id;

#     while (0 == $resolved_unrelated_left || 0 == $resolved_unrelated_right) {
#       my @left_to_reference_stable_ids1 = keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{left}{$left_distances[$left_nb]}};
#       my @right_to_reference_stable_ids1 = keys %{$self->{_each_synteny}{$sp1_gdb_id}{$reference_stable_id}{right}{$right_distances[$right_nb]}};
#       my $left_to_reference_stable_id = $left_to_reference_stable_ids1[0];
#       my $right_to_reference_stable_id = $right_to_reference_stable_ids1[0];
#       # Check if the closest left and right are syntenic orthologs on both sides or only one, or in a triangle
#       my $left_hit_ortholog_stable_id = $self->{_synt_orthologs}{$sp1_gdb_id}{$left_to_reference_stable_id};
#       my $right_hit_ortholog_stable_id = $self->{_synt_orthologs}{$sp1_gdb_id}{$right_to_reference_stable_id};
#       my $chr_hit = ''; $chr_hit = $self->{_m_chr_info}{$hit_stable_id}{chr_name};
#       my $chr_left_hit_ortholog = ''; $chr_left_hit_ortholog = $self->{_m_chr_info}{$left_hit_ortholog_stable_id}{chr_name} if defined($left_hit_ortholog_stable_id);
#       my $chr_right_hit_ortholog = ''; $chr_right_hit_ortholog = $self->{_m_chr_info}{$right_hit_ortholog_stable_id}{chr_name} if defined($right_hit_ortholog_stable_id);
      
#       if (defined($left_hit_ortholog_stable_id) && defined($right_hit_ortholog_stable_id)) {
#         my $unrelated_left = 1 if (!defined($self->{_synt_orthologs}{$left_to_reference_stable_id}{$hit_stable_id}));
#         my $unrelated_right = 1 if (!defined($self->{_synt_orthologs}{$right_to_reference_stable_id}{$hit_stable_id}));
#         if ((1 == $unrelated_left) && ($chr_left_hit_ortholog eq $chr_hit)) {
#           $resolved_unrelated_left = 1;
#           $final_left_nb = $left_nb;
#           $final_left_hit_ortholog_stable_id = $left_hit_ortholog_stable_id;
#         }
#         if ((1 == $unrelated_right) && ($chr_right_hit_ortholog eq $chr_hit)) {
#           $resolved_unrelated_right = 1;
#           $final_right_nb = $right_nb;
#           $final_right_hit_ortholog_stable_id = $right_hit_ortholog_stable_id;
#         }
#       } elsif (defined($left_hit_ortholog_stable_id) && !defined($right_hit_ortholog_stable_id)) {
#         # we have a left but not a right
#         my $unrelated_left = 1 if (!defined($self->{_synt_orthologs}{$left_to_reference_stable_id}{$hit_stable_id}));
#         if ((1 == $unrelated_left) && ($chr_left_hit_ortholog eq $chr_hit)) {
#           $resolved_unrelated_left = 1;
#           $final_left_nb = $left_nb;
#           $final_left_hit_ortholog_stable_id = $left_hit_ortholog_stable_id;
#           $right_nb++;
#         }
#       } elsif (!defined($left_hit_ortholog_stable_id) && defined($right_hit_ortholog_stable_id)) {
#         # we have a right but not a left
#         my $unrelated_right = 1 if (!defined($self->{_synt_orthologs}{$right_to_reference_stable_id}{$hit_stable_id}));
#         if (1 == $unrelated_right) {
#           $resolved_unrelated_right = 1;
#           $final_right_nb = $right_nb;
#           $final_right_hit_ortholog_stable_id = $right_hit_ortholog_stable_id;
#           $left_nb++;
#         }
#       } else {
#         # Keep looking as we may have a synteny in the next neighbours
#         $resolved_unrelated_left = 0;
#         $resolved_unrelated_right = 0;
#         $left_nb++;
#         $right_nb++;
#       }
#     }

#     $self->{_synt_types}{$reference_stable_id} = "perfect_synt";
#     print "$reference_stable_id,perfect_synt,", $left_distances[$final_left_nb],",", $right_distances[$final_right_nb], ",",
#       $self->{_m_chr_info}{$reference_stable_id}{chr_name},",",
#         $self->{_m_chr_info}{$reference_stable_id}{chr_start},",",
#           $self->{_m_chr_info}{$reference_stable_id}{chr_strand},",",
#             $final_left_hit_ortholog_stable_id,",",
#             $final_right_hit_ortholog_stable_id,",",
#             "\n";

#   }
#   # this is the very last step for species2-singleton printouts
#   my $sp1_genes = $self->{comparaDBA}->get_MemberAdaptor->fetch_all_by_source_taxon('ENSEMBLGENE', $sp1_gdb->taxon_id);
#   foreach my $gene (@$sp1_genes) {
#     next if (defined($self->{_synt_orthologs}{$sp1_gdb->dbID}{$gene->stable_id}));
#     my $gene_stable_id = $gene->stable_id;
#     my $chr_name = $gene->chr_name;
#     my $chr_start = $gene->chr_start;
#     my $chr_strand = $gene->chr_strand;
#     $self->{_synt_types}{$gene_stable_id} = "nohit_orth";
#     print $gene_stable_id, ",nohit_orth,na,na,", $chr_name,",", $chr_start,",", $chr_strand,"\n";
#   }
#   # And finally check that there are no genes not in member in between the triads...
#   # TODO: Label perfection like the number of perfect matches found at left and right.
# }


# sub _compare_phyop {
#   my $self = shift;

#   my $starttime = time();
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{gdbDBA} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

#   open (FH, $self->{_compare_phyop}) 
#     or die("Could not open phyop_nhx file") unless $self->{'_farm'};
#   my ($phyop_entry,$phyop_nhx) = '';
#   while (<FH>) {
#     $phyop_entry .= $_;
#     $phyop_entry =~ s/\[.+skipped\.//;
#     next unless $phyop_entry =~ /;/;
#     my @tokens = split ("\t",$phyop_entry);
#     my $phyopid = $tokens[0];
#     my $phyop_nhx = $tokens[-1];
#     $phyop_entry = '';
#     next if (0 == length($phyopid));
#     next unless (defined($phyop_nhx));
#     $self->{tree} = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($phyop_nhx);
#     next unless (defined $self->{tree});
    
#     my %phyop_map;
#     my %phyop_count;
#     my @leaves = @{$self->{tree}->get_all_leaves};
#     foreach my $leaf (@leaves) {
#       my $leaf_name = $leaf->name;
#       $leaf_name =~ /(\w+)\_[A-Z]{5}/;
#       my $genename = $1;
#       $leaf->add_tag("G",$genename);
#       next if (0==length($genename)); # for weird pseudoleaf tags with no gene name
#       # Asking for a genetree given the genename of a phyop tree
#       my $gene = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$genename);
#       if (defined($gene)) {
#         $leaf->add_tag("S",$gene->taxon->name);
#         $phyop_map{$genename} = 1;
#         $phyop_count{$genename}++;
#         bless $leaf, "Bio::EnsEMBL::Compara::GeneTreeMember";
#         $leaf->name($genename);
#         $leaf->genome_db_id($gene->genome_db_id);
#       }
#     }
    
#     my $more_than_one_transcript = 0;
#     foreach my $genename (%phyop_count) {
#       my $count = $phyop_count{$genename};
#       next unless (defined($count));
#       if ($count > 1) {
#         $more_than_one_transcript = 1;
#       }
#     }
#     # next unless (defined($self->{foundcase})); #debug
#     next if (1 == $more_than_one_transcript);
    
#     $self->{'keep_leaves'} = join(",",keys %phyop_map);
#     keep_leaves($self);
    
#     my @intnodes = $self->{tree}->get_all_subnodes;
#     foreach my $node (@intnodes) {
#       next if ($node->is_leaf);
#       my $s = $node->get_tagvalue("S");
#       next unless (defined($s) && $s ne '');
#       my $taxon = $self->{taxonDBA}->fetch_node_by_name($s);
#       $node->add_tag("taxon_level", $taxon);
#       $node->add_tag("duplication_confidence_score", 1);
#       $node->add_tag("species_intersection_score", 1);
#     }
#     $phyop_nhx =~ /.+S\=(\w+).+\;/;
#     my $sroot = $1;
#     my $roottaxon = $self->{taxonDBA}->fetch_node_by_name($sroot);
#     $self->{tree}->root->add_tag("taxon_level", $roottaxon);
#     $phyop_nhx =~ /.+D\=(\w+).+\;/;
#     my $duproot = $1;
#     $duproot =~ s/Y/1/;
#     $duproot =~ s/N/0/;
#     $duproot = 0 unless (1 == $duproot);
#     $self->{tree}->root->add_tag("Duplication", $duproot);
#     $self->{tree}->root->add_tag("duplication_confidence_score", 1);
#     $self->{tree}->root->add_tag("species_intersection_score", 1);
    
#     print STDERR (time()-$starttime), " secs... \n" if ($self->{verbose});
#     print STDERR $phyopid,"\n" if ($self->{verbose});
#     next if (1==scalar(@{$self->{tree}->get_all_leaves}));
#     print STDERR join (",",map {$_->stable_id} @{$self->{tree}->get_all_leaves}),"\n" if ($self->{verbose});
#     print STDERR $self->{tree}->newick_format if ($self->{verbose});
    
#     # Make sure we have Duplication tag everywhere
#     map { if ('' eq $_->get_tagvalue("Duplication")) {$_->add_tag("Duplication",0)} } $self->{tree}->get_all_subnodes;
#     map { if ('' eq $_->get_tagvalue("species_intersection_score")) {$_->add_tag("species_intersection_score",1)} } $self->{tree}->get_all_subnodes;
    
#     _run_orthotree($self);
#     print $self->{_homologytable};
#     $self->{_homologytable} = '';
#     $self->{tree} = undef;
#   }
# }

sub _interpro_coverage {
  my $self = shift;
  $self->{starttime} = time();

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
  my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  my $species = $self->{_species} || "Homo sapiens";
  my $uspecies = $species;
  $species =~ s/\_/\ /g;

  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  my $gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Gene");

  my $gdb = $self->{gdba}->fetch_by_name_assembly($species);
  my $gdb_id = $gdb->dbID;
  my $genes = $self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$gdb->taxon_id);
  print STDERR "[fetching $species genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
  foreach my $gene (@$genes) {
    my $stable_id = $gene->stable_id;
    my $canonical_peptide;
    eval { $canonical_peptide = $gene->get_canonical_peptide_Member;};
    eval { $canonical_peptide = $gene->get_longest_peptide_Member;} if ($@);
    my $protein_stable_id = $canonical_peptide->stable_id;
    my $mcl_id = $canonical_peptide->member_id . "_" . $gdb_id;
    my @interpro_entries = @{$gene_adaptor->get_Interpro_by_geneid($stable_id)};
    my @interpro_ids;
    foreach my $interpro_entry (@interpro_entries) {
      $interpro_entry =~ /(IPR\d+)\:/;
      my $interpro_id = $1;
      push @interpro_ids, $interpro_id;
    }

    my $result = join(",",$uspecies,$stable_id,$protein_stable_id,$mcl_id,(join(":",@interpro_ids)));
    print "$result\n";
    $self->{interpro_coverage}{$stable_id} = 1;
  }
  print STDERR "Interpro covered genes: ", scalar keys %{$self->{interpro_coverage}}, "\n";
}

sub _extra_dn_ds {
  my $self = shift;

  $self->{gdba}  = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
  $self->{ha} =  $self->{comparaDBA}->get_HomologyAdaptor;

  my $species_set = $self->{_species_set};
  $species_set =~ s/\_/\ /g;
  my @species_set = split(":",$species_set);
  my @saved_species_set = @species_set;

  my %gdb_short_names;
  my @homologies;
  print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

  eval {require Bio::Align::DNAStatistics;};

  print "seq1id,seq2id,aln_length,transitions,transversions,dn,ds,omega,lnl\n";

  while (my $species1 = shift (@species_set)) {
    foreach my $species2 (@species_set) {
      my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
      my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
      $gdb_short_names{$sp1_gdb->name} = $sp1_gdb->short_name;
      $gdb_short_names{$sp2_gdb->name} = $sp2_gdb->short_name;
      my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
      foreach my $homology (@{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss)}) {
        eval {
          my $aln = $homology->get_SimpleAlign('cdna'=>1);
          my $stats = new Bio::Align::DNAStatistics;
          if($stats->can('calc_KaKs_pair')) {
            my ($seq1id,$seq2id) = map { $_->display_id } $aln->each_seq;
            #           my $results = $stats->calc_KaKs_pair($aln, $seq1id, $seq2id);
            #           my $counting_method_dn = $results->[0]{D_n};
            #           my $counting_method_ds = $results->[0]{D_s};
            my $omega = $homology->dnds_ratio(0) || 'na';
            my $dn = $homology->dn(undef,0) || 'na';
            my $ds = $homology->ds(undef,0) || 'na';
            my $lnl = $homology->lnl || 'na';
            my $transitions = $stats->transitions($aln);
            my $transversions = $stats->transversions($aln);
            my $aln_length = $aln->length;
            print "$seq1id,$seq2id,$aln_length,$transitions,$transversions,$dn,$ds,$omega,$lnl\n";
          }
        }
      }
    }
  }
  print STDERR "[fetching orthologues] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

  1;
}

# sub _sitewise_alnwithgaps {
#   my $self = shift;
#   $self->{starttime} = time();

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   my $port = 3306;
#   if ($myhost =~ /(\S+)\:(\S+)/) {
#     $port = $2;
#     $myhost = $1;
#   }
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -port => "$port",
#         -verbose => "0" );

#   my $sql = 
#     "SELECT ptt1.node_id FROM protein_tree_tag ptt1 ".
#       "WHERE ptt1.tag='taxon_name' AND ptt1.node_id=ptt2.node_id ".
#         "AND ptt2.tag='Duplication'";
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();


#   print "Interpro covered genes: ", scalar keys %{$self->{interpro_coverage}}, "\n";
# }

# sub _compare_homologene_refseq {
#   my $self = shift;

#   $self->{starttime} = time();
#   my $starttime = time();
#   # $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   # $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;

#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly("Homo sapiens");
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly("Mus musculus");

#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   open (FH, $self->{_compare_homologene_refseq}) 
#     or die("Could not open homologene refseq file") unless $self->{'_farm'};
#   my ($hlg_entry,$hlg_refseq) = '';
#   while (<FH>) {
#     my @values = split("\t",$_);
#     my $refseq_id = $values[-1];
#     unless ($refseq_id =~ /[NX]P/) {
#       1;
#     }
#     $self->{hlg}{hlg_refseqs}{$refseq_id} = 1;
#   }
#   close(FH);

#   print STDERR "[reading homologene refseqs] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+/g;
#   my ($myuser,$myhost) = ($1,$2);
#   Bio::EnsEMBL::Registry->load_registry_from_db(-host=>$myhost, -user=>$myuser, -verbose=>'0');

#   my @homologies;
#   my $gene_count = 0;
#   my $mlss;
#   $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#   push @homologies, @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss)};
#   $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
#   push @homologies, @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss)};
#   print STDERR "[fetching human-mouse homologies] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   foreach my $homology (@homologies) {
#     my ($stable_id1,$stable_id2) = map { $_->stable_id } @{$homology->gene_list};
#     my $temp;
#     unless ($stable_id1 =~ /ENSG0/) {
#       $temp = $stable_id1;
#       $stable_id1 = $stable_id2;
#       $stable_id2 = $temp;
#     }
#     $self->{hlg}{genetrees_stableids}{$stable_id1} = 1;
#   }
#   print STDERR "[hashing genetrees] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   my $gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");
#   my $genes = $gene_adaptor->fetch_all;
#   print STDERR "[fetching human genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   foreach my $gene (@$genes) {
#     my $stable_id = $gene->stable_id;
#     $self->{hlg}{ensembl_allgenes}{$stable_id} = 1;
#     my @refseq_ids;
#     foreach my $refseq_dblink (@{$gene->get_all_DBLinks("RefSeq_peptide")}) {
#       my $refseq_id = $refseq_dblink->primary_id;
#       $self->{hlg}{ensembl_refseqs}{$refseq_dblink->primary_id}{$stable_id} = 1;
#       push @refseq_ids, $refseq_id;
#     }
#     my $verbose_string = sprintf "[%5d genes done]\n", $gene_count;
#     print STDERR $verbose_string 
#       if ($self->{'verbose'} && ($gene_count % $self->{'verbose'} == 0));
#     $gene_count++;
#   }
#   print STDERR "[hashing genes] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
# }

# sub _compare_api_treefam {
#   my $self = shift;

#   my $starttime = time();
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{gdbDBA} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
#   my $species1 = $self->{_species1} || "Homo sapiens";
#   my $species2 = $self->{_species2} || "Mus musculus";

#   eval {require Treefam::DBConnection;};
#   if ($@) {
#     print STDERR "treefam api not found"; die "$!\n";
#   }

#   my $dbc =  Treefam::DBConnection->new
#     (-database => 'treefam_4',
#      -host     => 'vegasrv.sanger.ac.uk',
#      -user     => 'anonymous',
#      -port     => 3308);

#   my $famh = $dbc->get_FamilyHandle();
#   my $trh = $dbc->get_TreeHandle();
#   my $gh = $dbc->get_GeneHandle;
#   # gets families with human genes
#   my @families = $famh->get_all_by_type('A');
#   foreach my $family (@families) {
#     # next unless ($family->ID eq 'TF105641');
#     # We dont want familyB types, as these are old PHIGS clusters
#     next unless ($family->type eq 'familyA');
#     #     my @genes = $gh->get_all_by_species($species2,$family);
#     #     if (0 != scalar(@genes)) {
#     # my $famh = $dbc->get_FamilyHandle();
#     # my @famA = $famh->get_all_by_type('A');
#     my $tree = $trh->get_by_family($family,'SEED');
#     my $treefamid = $tree->ID;
#     my $treefam_nhx = $tree->nhx;
#     next unless ($treefam_nhx =~ /\;/);
#     $self->{tree} = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($treefam_nhx);
#     next unless (defined $self->{tree});

#     my %tf_map;
#     my %tf_count;
#     my @leaves = @{$self->{tree}->get_all_leaves};
#     foreach my $leaf (@leaves) {
#       my $leaf_name = $leaf->name;
#       # treefam uses G NHX tag for genename
#       my $genename = $leaf->get_tagvalue('G');
#       next if (0==length($genename)); # for weird pseudoleaf tags with no gene name
#       # Asking for a genetree given the genename of a treefam tree
#       my $gene = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$genename);
#       if (defined($gene)) {
#         $tf_map{$genename} = 1;
#         $tf_count{$genename}++;
#         bless $leaf, "Bio::EnsEMBL::Compara::GeneTreeMember";
#         $leaf->name($genename);
#         $leaf->genome_db_id($gene->genome_db_id);
#       }
#     }

#     my $more_than_one_transcript = 0;
#     foreach my $genename (%tf_count) {
#       my $count = $tf_count{$genename};
#       next unless (defined($count));
#       if ($count > 1) {
#         $more_than_one_transcript = 1;
#       }
#     }
#     #    next unless (defined($self->{foundcase})); #debug
#     next if (1 == $more_than_one_transcript);

#     $self->{'keep_leaves'} = join(",",keys %tf_map);
#     keep_leaves($self);

#     my @intnodes = $self->{tree}->get_all_subnodes;
#     foreach my $node (@intnodes) {
#       next if ($node->is_leaf);
#       my $s = $node->get_tagvalue("S");
#       next unless (defined($s) && $s ne '');
#       my $taxon = $self->{taxonDBA}->fetch_node_by_name($s);
#       $node->add_tag("taxon_level", $taxon);
#       $node->add_tag("duplication_confidence_score", 1);
#       $node->add_tag("species_intersection_score", 1);
#     }
#     $treefam_nhx =~ /.+S\=(\w+).+\;/;
#     my $sroot = $1;
#     my $roottaxon = $self->{taxonDBA}->fetch_node_by_name($sroot);
#     $self->{tree}->root->add_tag("taxon_level", $roottaxon);
#     $treefam_nhx =~ /.+D\=(\w+).+\;/;
#     my $duproot = $1;
#     $duproot =~ s/Y/1/;
#     $duproot =~ s/N/0/;
#     $duproot = 0 unless (1 == $duproot);
#     $self->{tree}->root->add_tag("Duplication", $duproot);
#     $self->{tree}->root->add_tag("duplication_confidence_score", 1);
#     $self->{tree}->root->add_tag("species_intersection_score", 1);

#     print STDERR (time()-$starttime), " secs... \n" if ($self->{verbose});
#     print STDERR $family->ID,"\n" if ($self->{verbose});
#     print STDERR join (",",map {$_->stable_id} @{$self->{tree}->get_all_leaves}),"\n" if ($self->{verbose});
#     print STDERR $self->{tree}->newick_format if ($self->{verbose});

#     # Make sure we have Duplication tag everywhere
#     map { if ('' eq $_->get_tagvalue("Duplication")) {$_->add_tag("Duplication",0)} } $self->{tree}->get_all_subnodes;
#     map { if ('' eq $_->get_tagvalue("species_intersection_score")) {$_->add_tag("species_intersection_score",1)} } $self->{tree}->get_all_subnodes;

#     _run_orthotree($self);
#     print $self->{_homologytable};
#     $self->{_homologytable} = '';
#     $self->{tree} = undef;
#     #    }
#   }
# }

# sub _treefam_aln_plot {
#   my $self = shift;
#   my $gene_stable_id = $self->{_treefam_aln_plot};

#   my $member = $self->{'comparaDBA'}->
#     get_MemberAdaptor->
#       fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);

#   my $tree = $self->{comparaDBA}->get_ProteinTreeAdaptor->fetch_by_Member_root_id($member);

#   my @aln;
#   foreach my $leaf (@{$tree->get_all_leaves}) {
#     my $DISP_ID = $leaf->gene_member->stable_id . "_" . $leaf->genome_db->short_name;
#     # next if (($DISP_ID =~ /Olat/) || ($DISP_ID =~ /Cpor/) || ($DISP_ID =~ /Aaeg/) || ($DISP_ID =~ /Ogar/) || ($DISP_ID =~ /Mlug/));
#     my $CIGAR = $leaf->cigar_line;
#     my $hash;
#     $hash->{CIGAR} = $CIGAR;
#     $hash->{DISP_ID} = $DISP_ID;
#     $hash->{GID} = $leaf->gene_member->stable_id;
#     $hash->{ID} = $leaf->gene_member->stable_id;
#     my $transcript = $leaf->transcript;
#     # $DISP_ID = $transcript->stable_id . "." . $transcript->version;
#     my $transcript_strand = (1 == $transcript->strand) ? ("+") : ("-");
#     my $transcript_start = $transcript->start - 1;
#     my $transcript_end = $transcript->end; #    my $transcript_end = $transcript->end - 1;
#     my @transl_exons = @{$transcript->get_all_translateable_Exons};
#     my $c_start = $transl_exons[0]->start - 1;
#     my $c_end = $transl_exons[-1]->end;
#     my @exons = @{$transcript->get_all_Exons};
#     my $exon_num = scalar(@exons);
#     my $exon_start_string = join(",", map {$_->start - 1} @exons) . ",";
#     my $exon_end_string = join(",", map {$_->end} @exons) . ",";

#     $hash->{MAP} = join("\t",($DISP_ID,"chromosome1",$transcript_strand,$transcript_start,$transcript_end,$c_start,$c_end,$exon_num,$exon_start_string,$exon_end_string));
#     #    print $hash->{MAP}, "\n";
#     $hash->{SWCODE} = 'HUMAN';
#     my @a; @{$hash->{PFAM}} = @a;
#     push @aln, $hash;
#   }

#   eval {require treefam::db;};
#   if ($@) {
#     print STDERR "treefam api not found"; die "$!\n";
#   }
#   eval {require treefam::align_plot;};
#   if ($@) {
#     print STDERR "treefam api not found"; die "$!\n";
#   }

#   my $db = treefam::db->new(-host=>'vegasrv.sanger.ac.uk', -port=>3308, -name=>'treefam_4', user=>'anonymous');
#   my $aln_plot = treefam::align_plot->new;
#   $aln_plot->init(\@aln);
#   my $im = $aln_plot->plot_im(); # print into a PNG file.
#   open(ALNPLOT, ">$gene_stable_id.ENSEMBL.png")
#     or $self->throw("Error opening $gene_stable_id.png for write");
#   print ALNPLOT $im->png;
#   close(ALNPLOT);
# }

# sub _benchmark_tree_node_id {
#   my $self = shift;

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+/g;
#   my ($myuser,$myhost) = ($1,$2);
#   Bio::EnsEMBL::Registry->load_registry_from_db(-host=>$myhost, -user=>$myuser, -verbose=>'0');
#   my $species = $self->{_species} || "Homo sapiens";
#   $species =~ s/\_/\ /g;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   $self->{starttime} = time();
#   my $sp_members = $self->{comparaDBA}->get_MemberAdaptor->fetch_all_by_source_taxon('ENSEMBLGENE', $sp_gdb->taxon_id);
#   print STDERR "[fetch members] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   print "align_type,tree_id,gene_count,cluster_residue_count,secs\n";
#   foreach my $member (@$sp_members) {
#     $self->{tree} = $self->{treeDBA}->fetch_by_Member_root_id($member);
#     next if (defined($self->{tree}->get_tagvalue('cluster_had_to_be_broken_down')) && '1' eq $self->{tree}->get_tagvalue('cluster_had_to_be_broken_down'));
#     # print "fetch_by_Member_root_id,",time()-$self->{starttime},"\n" if ($self->{verbose}); $self->{starttime} = time();
#     my $cased_aln = $self->{tree}->get_SimpleAlign(-exon_cased=>1);
#     #Bio::AlignIO->new(-fh => \*STDERR, -format => 'phylip', -idlength => 30, -tag_length => 1)->write_aln($cased_aln);
#     print "exon_cased,",$self->{tree}->node_id,",",$self->{tree}->get_tagvalue("gene_count"),",",$self->{tree}->get_tagvalue("cluster_residue_count"),",",time()-$self->{starttime},"\n"; $self->{starttime} = time();
#     my $aln = $self->{tree}->get_SimpleAlign();
#     #Bio::AlignIO->new(-fh => \*STDERR, -format => 'phylip', -idlength => 30, -tag_length => 1)->write_aln($aln);
#     print "protein,",$self->{tree}->node_id,",",$self->{tree}->get_tagvalue("gene_count"),",",$self->{tree}->get_tagvalue("cluster_residue_count"),",",time()-$self->{starttime},"\n"; $self->{starttime} = time();
#     $self->{tree}->get_SimpleAlign(-cdna=>1);
#     print "cds,",$self->{tree}->node_id,",",$self->{tree}->get_tagvalue("gene_count"),",",time()-$self->{starttime},"\n"; $self->{starttime} = time();
#     #    print "protein,",$self->{tree}->get_tagvalue("gene_count"),",",time()-$self->{starttime},"\n"; $self->{starttime} = time();
#     $self->{tree}->release_tree;
#     #print "  [release_tree] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   }
# }

# sub _get_all_duprates_for_species_tree
#   {
#     my $self = shift;
#     $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#     printf("dbname: %s\n", $self->{'_mydbname'});
#     printf("duprates_for_species_tree_root_id: %d\n", $self->{'clusterset_id'});

#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#     my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#     my $outfile = "duprates.". $self->{_mydbname} . "." . 
#       $self->{'clusterset_id'};
#     $outfile .= ".csv";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE "node_subtype,dupcount,";
#     print OUTFILE "dupcount0.0,dupcount0.1,dupcount0.2,dupcount0.3,";
#     print OUTFILE "dupcount0.4,dupcount0.5,dupcount0.6,dupcount0.7,";
#     print OUTFILE "dupcount0.8,dupcount0.9,dupcount1.0,";
#     print OUTFILE "passedcount,coef,numgenes\n";
#     my $cluster_count;

#     # Load species tree
#     $self->{_myspecies_tree} = $self->{'root'};
#     $self->{gdb_list} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
#     foreach my $gdb (@{$self->{gdb_list}}) {
#       my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($gdb->taxon_id);
#       $taxon->release_children;
#       $self->{_myspecies_tree} = $taxon->root unless($self->{_myspecies_tree});
#       $self->{_myspecies_tree}->merge_node_via_shared_ancestor($taxon);
#     }
#     $self->{_myspecies_tree} = $self->{_myspecies_tree}->minimize_tree;

#     my @clusters = @{$clusterset->children};
#     my $totalnum_clusters = scalar(@clusters);
#     printf("totalnum_trees: %d\n", $totalnum_clusters);
#     foreach my $cluster (@clusters) {
#       my %member_totals;
#       $cluster_count++;
#       my $verbose_string = sprintf "[%5d / %5d trees done]\n", 
#         $cluster_count, $totalnum_clusters;
#       print STDERR $verbose_string 
#         if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
#       next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#       $treeDBA->fetch_subtree_under_node($cluster);

#       my $member_list = $cluster->get_all_leaves;
#       # Store the duprates for every cluster
#       # next if (3000 < scalar(@$member_list));
#       $self->_count_dups($cluster);
#     }

#     $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#     foreach my $sp_node ($self->{_myspecies_tree}->get_all_subnodes) {
#       next if ($sp_node->is_leaf);
#       my $sp_node_name = $sp_node->get_tagvalue('name');
#       # For internal nodes
#       my @taxon_ids = map {$_->taxon_id } @{$sp_node->get_all_leaves};
#       # and for leaves
#       if (0 == scalar(@taxon_ids)) {
#         1;
#         $taxon_ids[0] = $sp_node->taxon_id;
#       }

#       my $pep_totals;
#       foreach my $taxon_id (@taxon_ids) {
#         my $sp_pep_count = $self->{memberDBA}->get_source_taxon_count
#           (
#            'ENSEMBLGENE',
#            $taxon_id);
#         $pep_totals += $sp_pep_count;
#         $sp_node->{_peps}{$taxon_id} = $sp_pep_count;
#       }
#       if (0 == $pep_totals) {
#         1;
#       }
#       $sp_node->add_tag('pep_totals', $pep_totals);
#     }
#     # Get the list of ENSEMBLPEP for each of the species in a given
#     # internal node
#     # TODO: do the same but only with homology_members

#     foreach my $sp_node ($self->{_myspecies_tree}->get_all_subnodes) {
#       my $sp_node_name = $sp_node->get_tagvalue('name');
#       my $sp_node_dupcount = $sp_node->get_tagvalue('dupcount') || 0;
#       my $sp_node_dupcount00 = $sp_node->get_tagvalue('dupcount0.0') || 0;
#       my $sp_node_dupcount01 = $sp_node->get_tagvalue('dupcount0.1') || 0;
#       my $sp_node_dupcount02 = $sp_node->get_tagvalue('dupcount0.2') || 0;
#       my $sp_node_dupcount03 = $sp_node->get_tagvalue('dupcount0.3') || 0;
#       my $sp_node_dupcount04 = $sp_node->get_tagvalue('dupcount0.4') || 0;
#       my $sp_node_dupcount05 = $sp_node->get_tagvalue('dupcount0.5') || 0;
#       my $sp_node_dupcount06 = $sp_node->get_tagvalue('dupcount0.6') || 0;
#       my $sp_node_dupcount07 = $sp_node->get_tagvalue('dupcount0.7') || 0;
#       my $sp_node_dupcount08 = $sp_node->get_tagvalue('dupcount0.8') || 0;
#       my $sp_node_dupcount09 = $sp_node->get_tagvalue('dupcount0.9') || 0;
#       my $sp_node_dupcount10 = $sp_node->get_tagvalue('dupcount1.0') || 0;
#       my $sp_node_passedcount = $sp_node->get_tagvalue('passedcount') || 0;
#       my $sp_node_pep_totals = $sp_node->get_tagvalue('pep_totals') || 0;
#       my $results = 
#         $sp_node_name. ",". 
#           $sp_node_dupcount. ",". 
#             $sp_node_dupcount00. ",". 
#               $sp_node_dupcount01. ",". 
#                 $sp_node_dupcount02. ",". 
#                   $sp_node_dupcount03. ",". 
#                     $sp_node_dupcount04. ",". 
#                       $sp_node_dupcount05. ",". 
#                         $sp_node_dupcount06. ",". 
#                           $sp_node_dupcount07. ",". 
#                             $sp_node_dupcount08. ",". 
#                               $sp_node_dupcount09. ",". 
#                                 $sp_node_dupcount10. ",". 
#                                   $sp_node_passedcount. ",",
#                                     $sp_node_dupcount/$sp_node_passedcount. ",". 
#                                       $sp_node_pep_totals. 
#                                         "\n";
#       print $results;
#       print OUTFILE $results;
#     }
#   }
# #

# sub _get_all_genes_for_taxon_name {
#   my $self = shift;

#   my $species = $self->{_species};
#   my $taxon_name = $self->{_taxon_name_genes};
#   print "dups\n" if($self->{verbose});
#   my $dup_gene_stable_ids;
#   $dup_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag_hm(1) if (2==$self->{verbose});
#   $dup_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag(1) if (2!=$self->{verbose});
#   open DUPS, ">dups_genes_".$species."_for_taxon_name_".$taxon_name.".txt" or die "$!";
#   foreach my $gene_stable_id (keys %$dup_gene_stable_ids) {
#     if ($gene_stable_id =~ /$species/) {
#       print DUPS "$gene_stable_id\n";
#     }
#   }
#   close DUPS;
#   print "specs\n" if($self->{verbose});
#   my $spc_gene_stable_ids;
#   $spc_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag_hm(0) if (2==$self->{verbose});
#   $spc_gene_stable_ids = $self->_get_all_genes_for_taxon_name_dup_tag(0) if (2!=$self->{verbose});
#   open SPECS, ">specs_genes_".$species."_for_taxon_name_".$taxon_name.".txt" or die "$!";
#   foreach my $gene_stable_id (keys %$spc_gene_stable_ids) {
#     if ($gene_stable_id =~ /$species/) {
#       print SPECS "$gene_stable_id\n";
#     }
#   }
#   close SPECS;
# }

# sub _get_all_genes_for_taxon_name_dup_tag {
#   my $self = shift;
#   my $dup_tag = shift;

#   # get all nodes that have the taxon_name tag and have duplications
#   # 1 - nodes that have the adequate taxon_name and adequate Duplication tag
#   my $sql = 
#     "select ptt1.node_id from protein_tree_tag ptt1, protein_tree_tag ptt2 where ptt1.tag='taxon_name' and ptt1.value='" .
#       $self->{_taxon_name_genes} 
#         . "' and ptt1.node_id=ptt2.node_id and ptt2.tag='Duplication' and ptt2.value";
#   $sql .= "=0" if (0 == $dup_tag);
#   $sql .= "!=0" if (0 != $dup_tag);
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   my $node_id;
#   my @nodes;
#   my %gene_stable_ids;
#   while ($node_id = $sth->fetchrow_array()) {
#     # 2 - left and right index of the previous nodes
#     my $sql = 
#       "select node_id, left_index, right_index from protein_tree_node where node_id=$node_id";
#     my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my ($node_id,$left_index,$right_index);
#     while (($node_id,$left_index,$right_index) = $sth->fetchrow_array()) {
#       # 3 - all the leaves for those nodes
#       my $sql = 
#         "select node_id from protein_tree_node where left_index > $left_index and right_index < $right_index and (right_index-left_index)=1";
#       my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#       $sth->execute();
#       my $leaf_node_ids;
#       my $leaf_node_id;
#       while ($leaf_node_id = $sth->fetchrow_array()) {
#         $leaf_node_ids .= $leaf_node_id . ",";
#       }
#       $leaf_node_ids =~ s/\,$//;
#       # 4 - Get only those leaves that actually have the ancestral node_id in homology
#       my $sql2 = "SELECT distinct(m1.stable_id) FROM member m1, member m2, protein_tree_member ptm, homology_member hm, homology h WHERE ptm.node_id in ($leaf_node_ids) AND ptm.member_id=m2.member_id AND hm.member_id=m2.gene_member_id AND h.node_id=$node_id AND h.homology_id=hm.homology_id AND m2.gene_member_id=m1.member_id";
#       # my $sql = "select m.stable_id from member m, protein_tree_member ptm where ptm.node_id=$leaf_node_id and ptm.member_id=m.member_id";
#       my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#       $sth2->execute();
#       my $gene_stable_id;
#       while ($gene_stable_id = $sth2->fetchrow_array()) {
#         $gene_stable_ids{$gene_stable_id} = 1;
#       }
#       print scalar(keys %gene_stable_ids), " ids\n" if(((scalar( keys %gene_stable_ids)) % 1000 < 25) && $self->{verbose});
#     }
#   }
#   $sth->finish();
#   return \%gene_stable_ids;
# }

# sub _get_all_genes_for_taxon_name_dup_tag_hm {
#   my $self = shift;
#   my $dup_tag = shift;

#   # get all nodes that have the taxon_name tag and have duplications
#   # 1 - nodes that have the adequate taxon_name and adequate Duplication tag
#   print "query 1/4\n" if $self->{verbose};
#   my $sql = 
#     "select ptt1.node_id from protein_tree_tag ptt1, protein_tree_tag ptt2 where ptt1.tag='taxon_name' and ptt1.value='" .
#       $self->{_taxon_name_genes} 
#         . "' and ptt1.node_id=ptt2.node_id and ptt2.tag='Duplication' and ptt2.value";
#   $sql .= "=0" if (0 == $dup_tag);
#   $sql .= "!=0" if (0 != $dup_tag);
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   my $node_id;
#   my @nodes;
#   my %gene_stable_ids;
#   my $in_node_ids;
#   while ($node_id = $sth->fetchrow_array()) {
#     $in_node_ids .= $node_id . ",";
#   }
#   $in_node_ids =~ s/\,$//;
#   print "query 2/4\n" if $self->{verbose};
#   my $sql2 = "SELECT homology_id FROM homology WHERE node_id in ($in_node_ids)";
#   my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#   $sth2->execute();
#   my $homology_id;
#   my $in_homology_ids;
#   while ($homology_id = $sth2->fetchrow_array()) {
#     $in_homology_ids .= $homology_id . ",";
#   }
#   $in_homology_ids =~ s/\,$//;
#   print "query 3/4\n" if $self->{verbose};
#   my $sql3 = "SELECT member_id FROM homology_member WHERE homology_id in ($in_homology_ids)";
#   my $sth3 = $self->{comparaDBA}->dbc->prepare($sql3);
#   $sth3->execute();
#   my $member_id;
#   print "query 4/4\n" if $self->{verbose};
#   while ($member_id = $sth3->fetchrow_array()) {
#     my $sql4 = "SELECT stable_id FROM member WHERE member_id=$member_id";
#     my $sth4 = $self->{comparaDBA}->dbc->prepare($sql4);
#     $sth4->execute();
#     my $gene_stable_id;
#     while ($gene_stable_id = $sth4->fetchrow_array()) {
#       $gene_stable_ids{$gene_stable_id} = 1;
#     }
#   }
#   $sth->finish();
#   return \%gene_stable_ids;
# }

# #

# sub _count_dups {
#   my $self = shift;
#   my $cluster = shift;
#   #Assumes $self->{_myspecies_tree} exists
#   foreach my $node ($cluster->get_all_subnodes) {
#     next if ($node->is_leaf);
#     my $taxon_name = '';
#     my $taxon;
#     $taxon_name = $node->get_tagvalue('taxon_name'); # this was name instead of taxon_name in v41
#     unless (defined($taxon_name)) {
#       $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($node->taxon_id);
#       $taxon_name = $taxon->name;
#     }
#     my $taxon_node = $self->{_myspecies_tree}->find_node_by_name($taxon_name);
#     my $dups = $node->get_tagvalue('Duplication') || 0;
#     my $dupcount = $taxon_node->get_tagvalue('dupcount') || 0;
#     if ($dups) {
#       my $dup_confidence_score = 
#         $node->get_tagvalue('duplication_confidence_score');
#       unless ('' eq $dup_confidence_score) {
#         $dup_confidence_score = sprintf ("%.1f", $dup_confidence_score);
#         my $decr_score = $dup_confidence_score;
#         while (0.0 <= $decr_score) {
#           $decr_score = sprintf ("%.1f", $decr_score);
#           print "  $decr_score\n" if ($self->{debug});
#           my $decr_tag = 'dupcount' . $decr_score;
#           my $tagcount = $taxon_node->get_tagvalue($decr_tag) || 0;
#           $taxon_node->add_tag($decr_tag,($tagcount+1));
#           $decr_score = $decr_score - 0.1;
#         }
#       }
#       $taxon_node->add_tag('dupcount',($dupcount+1));
#     }
#     my $passedcount = $taxon_node->get_tagvalue('passedcount') || 0;
#     $taxon_node->add_tag('passedcount',($passedcount+1));
#   }
# }

# sub _get_all_duploss_fractions
#   {
#     my $self = shift;
#     $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#     printf("dbname: %s\n", $self->{'_mydbname'});
#     printf("duploss_fractions_root_id: %d\n", $self->{'clusterset_id'});

#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#     my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#     my $outfile = "duploss_fraction.". 
#       $self->{_mydbname} . "." . $self->{'clusterset_id'};
#     $outfile .= ".csv";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE 
#       "tree_id,node_id,parent_id,node_subtype,duploss_fraction,num,denom," . 
#         "child_a_avg_dist,child_a_leaves,child_b_avg_dist,child_b_leaves," . 
#           "aln_overlap_coef,aln_overlap_prod_coef,repr_stable_id,stable_ids_md5sum\n";

#     my $outfile_human = "duploss_fraction_human_heterotachy."
#       . $self->{_mydbname} . "." . $self->{'clusterset_id'};
#     $outfile_human .= ".csv";
#     open OUTFILE_HUMAN, ">$outfile_human" or die "error opening outfile: $!\n";
#     print OUTFILE_HUMAN 
#       "tree_id,node_id,parent_id,node_subtype,duploss_fraction,num,denom," . 
#         "child_a_human_dist,child_a_leaves,child_b_human_dist,child_b_leaves," . 
#           "child_a_human_stable_id,child_b_human_stable_id,stable_ids_md5sum\n";

#     my $cluster_count;
#     my @clusters = @{$clusterset->children};
#     my $totalnum_clusters = scalar(@clusters);
#     printf("totalnum_trees: %d\n", $totalnum_clusters);
#     foreach my $cluster (@clusters) {
#       next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#       my %member_totals;
#       $cluster_count++;
#       my $verbose_string = sprintf "[%5d / %5d trees done]\n", 
#         $cluster_count, $totalnum_clusters;
#       print STDERR $verbose_string 
#         if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
#       #$treeDBA->fetch_subtree_under_node($cluster);

#       my $member_list = $cluster->get_all_leaves;
#       my %member_gdbs;

#       foreach my $member (@{$member_list}) {
#         $member_gdbs{$member->genome_db_id} = 1;
#         $member_totals{$member->genome_db_id}++;
#       }
#       my @genetree_species = keys %member_gdbs;
#       # Do we want 1-species trees?
#       $cluster->{duploss_number_of_species} = scalar(@genetree_species);
#       # For each internal node in the tree
#       # no intersection of sps btw both child
#       _duploss_fraction($cluster);
#     }
#   }


# # internal purposes
# sub _duploss_fraction {
#   my $cluster = shift;
#   eval {require Digest::MD5;};  die "$@ \n" if ($@);
#   my $taxon_id = $cluster->get_tagvalue('taxon_id') || 0;
#   my ($child_a, $child_b, $dummy) = @{$cluster->children};
#   warn "multifurcated tree! check code!\n" if (defined($dummy));
#   print STDERR "multifurcated tree - ", $cluster->node_id, "\n" 
#     if (defined($dummy));
#   # Look at the childs
#   my $child_a_dups = _count_dups_in_subtree($child_a);
#   my $child_b_dups = _count_dups_in_subtree($child_b);
#   # Look at the node
#   my $dups = $cluster->get_tagvalue('Duplication') || 0;

#   # Only look at duplications
#   return 0 if (0 == $dups && 0 == $child_a_dups && 0 == $child_b_dups);

#   # Representative gene name
#   my @child_a_leaves = @{$child_a->get_all_leaves};
#   my @child_b_leaves = @{$child_b->get_all_leaves};

#   my @taxon_a_tmp = map {$_->taxon_id} @child_a_leaves;
#   my %taxon_a_tmp;
#   foreach my $taxon_tmp (@taxon_a_tmp) {
#     $taxon_a_tmp{$taxon_tmp}=1;
#   }
#   $child_a->{duploss_number_of_species} = scalar(keys %taxon_a_tmp);
#   my @taxon_b_tmp = map {$_->taxon_id} @child_b_leaves;
#   my %taxon_b_tmp;
#   foreach my $taxon_tmp (@taxon_b_tmp) {
#     $taxon_b_tmp{$taxon_tmp}=1;
#   }
#   $child_b->{duploss_number_of_species} = scalar(keys %taxon_b_tmp);

#   my $using_genes = 0;
#   my @child_a_stable_ids; my @child_b_stable_ids;
#   @child_a_stable_ids = map {$_->stable_id} @child_a_leaves;
#   @child_b_stable_ids = map {$_->stable_id} @child_b_leaves;
#   my $stable_ids_pattern = '';
#   my $r_chosen = 0;
#   my %child_a_stable_ids; my %child_b_stable_ids;
#   foreach my $stable_id (@child_a_stable_ids) {
#     $child_a_stable_ids{$stable_id} = 1;
#   }
#   foreach my $stable_id (@child_b_stable_ids) {
#     $child_b_stable_ids{$stable_id} = 1;
#   }
#   foreach my $stable_id (sort(@child_a_stable_ids,@child_b_stable_ids)) {
#     $stable_ids_pattern .= "$stable_id"."#";
#     # FIXME - put in a generic function
#     if (0 == $r_chosen) {
#       if ($stable_id =~ /^ENSP0/) {
#         $r_chosen = 1;
#       } elsif ($stable_id =~ /^ENSMUSP0/) {
#         $r_chosen = 1;
#       } elsif ($stable_id =~ /^ENSDARP0/) {
#         $r_chosen = 1;
#       } elsif ($stable_id =~ /^ENSCINP0/) {
#         $r_chosen = 1;
#       } else {
#         $r_chosen = 0;
#       }
#       $cluster->{_repr_stable_id} = $stable_id if (1 == $r_chosen);
#     }
#   }
#   unless (defined($cluster->{_repr_stable_id})) {
#     $cluster->{_repr_stable_id} = $child_a_stable_ids[0];
#   }
#   # Generate a md5sum string to compare among databases
#   $cluster->{_stable_ids_md5sum} = md5_hex($stable_ids_pattern);

#   ##########
#   my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @taxon_a_tmp;
#   %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @taxon_b_tmp;
#   my @isect = my @diff = my @union = (); my %count;
#   foreach my $e (@gdb_a, @gdb_b) {
#     $count{$e}++;
#   }
#   foreach my $e (keys %count) {
#     push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
#   }
#   my %isect;
#   foreach my $elem (@isect) {
#     $isect{$elem} = 1;
#   }
#   ##########

#   if (0 == $taxon_id) {
#     my $root_id = $cluster->node_id;
#     warn "no taxon_id found for this cluster's root: $root_id\n";
#   }
#   my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($taxon_id);
#   my $taxon_name = $taxon->name;
#   my $scalar_isect = scalar(@isect); my $scalar_union = scalar(@union);
#   my $duploss_frac = $scalar_isect/$scalar_union;
#   # we want to check for dupl nodes only
#   unless (0 == $dups) {
#     $taxon_name =~ s/\//\_/g; $taxon_name =~ s/\ /\_/g;
#     # Heterotachy
#     my $child_a_avg_dist; my $child_b_avg_dist;
#     foreach my $leaf (@child_a_leaves) {
#       $child_a_avg_dist += $leaf->distance_to_ancestor($child_a);
#     }
#     foreach my $leaf (@child_b_leaves) {
#       $child_b_avg_dist += $leaf->distance_to_ancestor($child_b);
#     }
#     $cluster->add_tag
#       ('child_a_avg_dist', ($child_a_avg_dist/scalar(@child_a_leaves)));
#     $cluster->add_tag
#       ('child_a_leaves', (scalar(@child_a_leaves)));
#     $cluster->add_tag
#       ('child_b_avg_dist', ($child_b_avg_dist/scalar(@child_b_leaves)));
#     $cluster->add_tag
#       ('child_b_leaves', (scalar(@child_b_leaves)));

#     # We get the msa from the cluster, but then remove_seq to convert
#     # to child_a and child_b respectively
#     my $parent_aln = $cluster->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 0,
#        -stop2x => 1
#       );
#     my $ungapped; my $ungapped_len;
#     # FIXME: this depends on the latest SimpleAlign.pm
#     eval { $ungapped = $parent_aln->remove_gaps; };
#     if ($@) {
#       $ungapped_len = 0;
#     } else {
#       $ungapped_len = $ungapped->length;
#     }
#     my $total_len = $parent_aln->length;
#     my $parent_aln_gap_coef = $ungapped_len/$total_len;
#     $cluster->add_tag('parent_aln_gap_coef',$parent_aln_gap_coef);

#     # Purge seqs not in child_a (i.e. in child_b)
#     my $child_a_aln = $cluster->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 0,
#        -stop2x => 1
#       );
#     my $child_a_aln_gap_coef;
#     if (2 <= scalar(keys %child_a_stable_ids)) {
#       foreach my $seq ($child_a_aln->each_seq) {
#         my $display_id = $seq->display_id;
#         $child_a_aln->remove_seq($seq) 
#           unless (defined($child_a_stable_ids{$display_id}));
#       }
#       # FIXME: this depends on the latest SimpleAlign.pm
#       eval { $ungapped = $child_a_aln->remove_gaps; };
#       if ($@) {
#         $ungapped_len = 0;
#       } else {
#         $ungapped_len = $ungapped->length;
#       }
#       $total_len = $child_a_aln->length;
#       $child_a_aln_gap_coef = $ungapped_len/$total_len;
#     } else {
#       my @key = keys %child_a_stable_ids;
#       my @seq = $child_a_aln->each_seq_with_id($key[0]);
#       $child_a_aln_gap_coef = 
#         ((($seq[0]->length)-($seq[0]->no_gaps))/$seq[0]->length);
#     }
#     $cluster->add_tag('child_a_aln_gap_coef',$child_a_aln_gap_coef);

#     # Purge seqs not in child_b (i.e. in child_a)
#     my $child_b_aln = $cluster->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 0,
#        -stop2x => 1
#       );
#     my $child_b_aln_gap_coef;
#     if (2 <= scalar(keys %child_b_stable_ids)) {
#       foreach my $seq ($child_b_aln->each_seq) {
#         my $display_id = $seq->display_id;
#         $child_b_aln->remove_seq($seq) 
#           unless (defined($child_b_stable_ids{$display_id}));
#       }
#       # FIXME: this depends on the latest SimpleAlign.pm
#       eval { $ungapped = $child_b_aln->remove_gaps; };
#       if ($@) {
#         $ungapped_len = 0;
#       } else {
#         $ungapped_len = $ungapped->length;
#       }
#       $total_len = $child_b_aln->length;
#       $child_b_aln_gap_coef = $ungapped_len/$total_len;
#     } else {
#       my @key = keys %child_b_stable_ids;
#       my @seq = $child_b_aln->each_seq_with_id($key[0]);
#       $child_b_aln_gap_coef = 
#         ((($seq[0]->length)-($seq[0]->no_gaps))/$seq[0]->length);
#     }
#     $cluster->add_tag('child_b_aln_gap_coef',$child_b_aln_gap_coef);

#     # human - human heterotachy --- taxon_id = 9606
#     my $human_taxon_id = "9606";
#     if (defined($isect{$human_taxon_id})) {
#       foreach my $leaf (@child_a_leaves) {
#         if ($leaf->taxon_id eq $human_taxon_id) {
#           my $human_dist = $leaf->distance_to_ancestor($child_a);
#           $cluster->add_tag('child_a_human_stable_id', $leaf->stable_id);
#           $cluster->add_tag('child_a_human_dist', $human_dist);
#         }
#       }
#       foreach my $leaf (@child_b_leaves) {
#         if ($leaf->taxon_id eq $human_taxon_id) {
#           my $human_dist = $leaf->distance_to_ancestor($child_b);
#           $cluster->add_tag('child_b_human_stable_id', $leaf->stable_id);
#           $cluster->add_tag('child_b_human_dist', $human_dist);
#         }
#       }
      
#       my $results_human = 
#         $cluster->subroot->node_id . 
#           "," . 
#             $cluster->node_id . 
#               "," . 
#                 $cluster->parent->node_id . 
#                   "," . 
#                     $taxon_name . 
#                       "," . 
#                         $duploss_frac . 
#                           "," . 
#                             $scalar_isect . 
#                               "," . 
#                                 $scalar_union . 
#                                   "," . 
#                                     $cluster->get_tagvalue('child_a_human_dist') . 
#                                       "," . 
#                                         $cluster->get_tagvalue('child_a_leaves') . 
#                                           "," . 
#                                             $cluster->get_tagvalue('child_b_human_dist') . 
#                                               "," . 
#                                                 $cluster->get_tagvalue('child_b_leaves') . 
#                                                   "," . 
#                                                     $cluster->get_tagvalue('child_a_human_stable_id') . 
#                                                       "," . 
#                                                         $cluster->get_tagvalue('child_b_human_stable_id') . 
#                                                           "," . 
#                                                             $cluster->{_stable_ids_md5sum} . 
#                                                               "\n";
#       print OUTFILE_HUMAN $results_human;
#     }
#     # we dont want leaf-level 1/1 within_species_paralogs
#     my $number_of_species = $cluster->{duploss_number_of_species};
#     if (1 < $number_of_species) {
#       unless (1 == $scalar_isect && 1 == $scalar_union) {
#         my $aln_overlap_coef;
#         eval {$aln_overlap_coef = 
#                 ($cluster->get_tagvalue('parent_aln_gap_coef')/
#                  ($cluster->get_tagvalue('child_a_aln_gap_coef')+
#                   $cluster->get_tagvalue('child_b_aln_gap_coef')/2));};
#         $aln_overlap_coef = 0 if ($@);
#         $aln_overlap_coef = -1 
#           if ($@ && 0 < $cluster->get_tagvalue('parent_aln_gap_coef'));
#         my $aln_overlap_prod_coef = 
#           (($cluster->get_tagvalue('parent_aln_gap_coef'))*
#            (
#             ($cluster->get_tagvalue('child_a_aln_gap_coef')+
#              $cluster->get_tagvalue('child_b_aln_gap_coef')/2)
#            ));
#         my $results = 
#           $cluster->subroot->node_id . 
#             "," . 
#               $cluster->node_id . 
#                 "," . 
#                   $cluster->parent->node_id . 
#                     "," . 
#                       $taxon_name . 
#                         "," . 
#                           $duploss_frac . 
#                             "," . 
#                               $scalar_isect . 
#                                 "," . 
#                                   $scalar_union . 
#                                     "," . 
#                                       $cluster->get_tagvalue('child_a_avg_dist') . 
#                                         "," . 
#                                           $cluster->get_tagvalue('child_a_leaves') . 
#                                             "," . 
#                                               $cluster->get_tagvalue('child_b_avg_dist') . 
#                                                 "," . 
#                                                   $cluster->get_tagvalue('child_b_leaves') . 
#                                                     "," . 
#                                                       $aln_overlap_coef . 
#                                                         "," . 
#                                                           $aln_overlap_prod_coef . 
#                                                             "," . 
#                                                               $cluster->{_repr_stable_id} . 
#                                                                 "," . 
#                                                                   $cluster->{_stable_ids_md5sum} . 
#                                                                     "\n";
#         print OUTFILE $results;
#         print $results if ($self->{debug});
#       }
#     }
#   }

#   # Recurse
#   _duploss_fraction($child_a) if (0 < $child_a_dups);
#   _duploss_fraction($child_b) if (0 < $child_b_dups);
# }




# sub _dnds_msas {
#   my $self = shift;
#   my $species_set = shift;

#   # mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_44
#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+/g;
#   my ($myuser,$myhost) = ($1,$2);
#   Bio::EnsEMBL::Registry->load_registry_from_db(-host=>$myhost, -user=>$myuser, -verbose=>'0');

#   $species_set =~ s/\_/\ /g;
#   my @species_set = split(":",$species_set);
#   my $species1 = $species_set[0];
#   my $species2 = $species_set[1];

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my %gdb_ids;
#   foreach my $species (@species_set) {
#     $gdb_ids{$self->{gdba}->fetch_by_name_assembly($species)->dbID} = 1;
#   }

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#   my $sp1_short_name = $sp1_gdb->get_short_name;
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#   my $sp2_short_name = $sp2_gdb->get_short_name;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   my $taxonomy_leaf = $self->{taxonDBA}->fetch_node_by_name($sp1_gdb->name);
#   my $taxonomy_root = $taxonomy_leaf->subroot;
#   my $taxonomy_parent = $taxonomy_leaf;
#   my %taxonomy_hierarchy;
#   my $hierarchy_count = 0;
#   do {
#     $hierarchy_count++;
#     $taxonomy_hierarchy{$taxonomy_parent->name} = $hierarchy_count;
#     $taxonomy_parent = $taxonomy_parent->parent;
#   } while ($taxonomy_parent->dbID != $taxonomy_root->dbID);

#   my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#   my @homologies = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,'ortholog_one2one')};
#   my $homology_count=0;
#   my $totalnum_homologies = scalar(@homologies);
#   my $sth;
#   my $root_id;

#   my $sql = "SELECT node_id,left_index,right_index FROM protein_tree_node WHERE parent_id = root_id";
#   $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   while (my ($root_id,$root_left_index,$root_right_index) = $sth->fetchrow) {
#     foreach my $index ($root_left_index .. $root_right_index) {
#       $self->{_hashed_indexes}{$index} = $root_id;
#     }
#   }
#   $sth->finish();

#   foreach my $homology (@homologies) {
#     my $homology_node_id = $homology->node_id;
#     $sql = "SELECT left_index, right_index FROM protein_tree_node WHERE node_id=$homology_node_id";
#     $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my ($left_index,$right_index) = $sth->fetchrow;

#     if (defined($self->{_hashed_indexes}{$left_index})) {
#       $root_id = $self->{_hashed_indexes}{$left_index};
#     }
#     $self->{_homologies_by_cluster}{$root_id}{$homology->dbID} = $homology;
#     $homology_count++;
#     if ($self->{'verbose'} &&  ($homology_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d homologies done]\n", 
#         $homology_count, $totalnum_homologies;
#       print STDERR $verbose_string;
#     }
#   }
#   $sth->finish;

#   print "root_id,avg_perc_ident\n";
#   foreach my $root_id (keys %{$self->{_homologies_by_cluster}}) {
#     my @this_tree_homology_ids = keys %{$self->{_homologies_by_cluster}{$root_id}};
#     my $num_homologies = scalar(@this_tree_homology_ids);
#     next unless ($num_homologies != 1);
#     $self->{tree} = $self->{treeDBA}->fetch_node_by_node_id($root_id);

#     foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
#       my $leaf_gdb_id = $leaf->genome_db->dbID;
#       next unless (defined($gdb_ids{$leaf_gdb_id}));
#       my $leaf_name = $leaf->name;
#       $self->{'keep_leaves'} .= $leaf_name . ",";
#     }
#     $self->{keep_leaves} =~ s/\,$//;
#     keep_leaves($self);

#     my $simple_align = $self->{tree}->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 1,
#        -stop2x => 1);
#     my $newick_tree = $self->{tree}->newick_simple_format;
#     my $collapsed_simple_align = $simple_align->remove_gaps(undef,1);
#     my $avg_perc_ident = $collapsed_simple_align->average_percentage_identity;
#     $simple_align = undef;
#     $self->{tree}->release_tree;
#     my $cutoff = $self->{cutoff} || 85;
#     print "$root_id,$avg_perc_ident\n";
#     next unless ($avg_perc_ident > $cutoff);
#     my $outfile = $sp1_short_name ."." . $sp2_short_name ."." . $root_id . ".fasta";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     my $alignIO = Bio::AlignIO->newFh(-fh => \*OUTFILE,
#                                       -format => 'fasta',
#                                      );
#     $collapsed_simple_align->set_displayname_flat(1);
#     print $alignIO $collapsed_simple_align;
#     close OUTFILE;
#     $outfile = $sp1_short_name ."." . $sp2_short_name ."." . $root_id . ".nex";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE $newick_tree;
#     close OUTFILE;
#   }
# }

# sub _dnds_go {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{starttime} = time();

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -verbose => "0" );

#   $self->{ga} = Bio::EnsEMBL::Registry->get_adaptor("human","core","gene");

#   $species_set =~ s/\_/\ /g;
#   my @species_set = split(":",$species_set);
#   my @saved_species_set = @species_set;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my %gdb_short_names;
#   my @homologies;
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   while (my $species1 = shift (@species_set)) {
#     foreach my $species2 (@species_set) {
#       my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#       my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#       $gdb_short_names{$sp1_gdb->name} = $sp1_gdb->short_name;
#       $gdb_short_names{$sp2_gdb->name} = $sp2_gdb->short_name;
#       my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#       my @homology_set = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,'ortholog_one2one')};
#       @homologies = (@homologies, @homology_set);
#     }
#   }
#   print STDERR "[fetching orthologues] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;

#   my $short_name_list;
#   foreach my $name (@saved_species_set) {
#     $short_name_list .= "_";
#     $short_name_list .= $gdb_short_names{$name};
#   }
#   my $outfile = "dnds_go". $short_name_list ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE "gene1_stable_id,short_name1,gene2_stable_id,short_name2,dn,ds,lnl,go_id,go_type\n";

#   # Can't do this using GO adaptor from the registry as it needs direct SQL
#   my $dbi = DBI->connect("dbi:mysql:host=ens-livemirror;port=3306;database=ensembl_go_46",
#                          "ensadmin", "ensembl", {'RaiseError' => 1}) || die "Can't connect to ensembl_go_46";

#   my $sth = $dbi->prepare("SELECT acc, term_type FROM term WHERE acc LIKE 'GO:%'");
#   my ($acc, $type);
#   $sth->execute();
#   $sth->bind_columns(\$acc, \$type);

#   my %acc_to_type;
#   while (my @row = $sth->fetchrow_array()) {
#     $acc_to_type{$acc}=$type;
#   }

#   foreach my $homology (@homologies) {
#     next unless ($homology->description =~ /one2one/);
#     my $dn = $homology->dn;
#     my $ds = $homology->ds;
#     my $lnl = $homology->lnl;
#     my $threshold_on_ds = $homology->threshold_on_ds;
#     next unless (defined($dn) && defined($ds) && defined($lnl));
#     next if ($ds > $threshold_on_ds);

#     my ($gene1,$gene2) = @{$homology->gene_list};
#     my $temp;
#     if ($gene1->genome_db->name ne $saved_species_set[0]) {
#       $temp = $gene1;
#       $gene1 = $gene2;
#       $gene2 = $temp;
#     }
#     my $gene1_stable_id = $gene1->stable_id;
#     my $gene2_stable_id = $gene2->stable_id;
#     my $short_name1 = $gdb_short_names{$gene1->genome_db->name};
#     my $short_name2 = $gdb_short_names{$gene2->genome_db->name};

#     my $gene = $self->{ga}->fetch_by_stable_id($gene1_stable_id);
#     foreach my $dblink (@{ $gene->get_all_DBLinks("GO")}) {
#       my $go_id = $dblink->primary_id;
#       my $type = $acc_to_type{$go_id} || "unknown";
#       print OUTFILE "$gene1_stable_id,$short_name1,$gene2_stable_id,$short_name2,$dn,$ds,$lnl,$go_id,$type\n";
#     }
#   }
#   close OUTFILE;
# }

# sub _dnds_doublepairs {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   # Get set of species from cmdline option
#   $species_set =~ s/\_/\ /g;
#   my @species_set = split(":",$species_set);

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my %gdb_short_names;
#   my @homologies;
#   # Obtain all the homology objects
#   while (my $species1 = shift (@species_set)) {
#     foreach my $species2 (@species_set) {
#       my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#       my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#       $gdb_short_names{$sp1_gdb->short_name} = 1;
#       $gdb_short_names{$sp2_gdb->short_name} = 1;
#       my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#       print STDERR "Fetching homologies btw $species1 and $species2...\n" if ($self->{verbose});
#       my @homology_set = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,'ortholog_one2one')};
#       @homologies = (@homologies, @homology_set);
#     }
#   }

#   my $short_name_list = join ("_",keys %gdb_short_names);

#   # Print to this file
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "dnds_doublepairs.". $short_name_list ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   my $header = "tree_id1,ancestor_node_id,ancestor_is_duplication,ancestor_taxon_name,". 
#     "gene1_stable_id1,gene2_stable_id1,dn1,ds1,dups_to_ancestor1," . 
#       "gene1_stable_id2,gene2_stable_id2,dn2,ds2,dups_to_ancestor2\n";
#   print OUTFILE "$header"; 
#   print "$header" if ($self->{verbose});

#   my $homology_count=0;
#   my $totalnum_homologies = scalar(@homologies);
#   my $sth;
#   my $root_id;

#   # Select only ancestral nodes which we are interested in
#   my $sql = "SELECT node_id,left_index,right_index FROM protein_tree_node WHERE parent_id = root_id";
#   $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   while (my ($root_id,$root_left_index,$root_right_index) = $sth->fetchrow) {
#     foreach my $index ($root_left_index .. $root_right_index) {
#       $self->{_hashed_indexes}{$index} = $root_id;
#     }
#   }
#   $sth->finish();

#   foreach my $homology (@homologies) {
#     my $homology_node_id = $homology->node_id;
#     $sql = "SELECT left_index, right_index FROM protein_tree_node WHERE node_id=$homology_node_id";
#     $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my ($left_index,$right_index) = $sth->fetchrow;

#     if (defined($self->{_hashed_indexes}{$left_index})) {
#       $root_id = $self->{_hashed_indexes}{$left_index};
#     }
#     $self->{_homologies_by_cluster}{$root_id}{$homology->dbID} = $homology;
#     $homology_count++;
#     if ($self->{'verbose'} &&  ($homology_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d homologies done]\n", 
#         $homology_count, $totalnum_homologies;
#       print STDERR $verbose_string;
#     }
#   }
#   $sth->finish;

#   foreach my $root_id (keys %{$self->{_homologies_by_cluster}}) {
#     my @this_tree_homology_ids = keys %{$self->{_homologies_by_cluster}{$root_id}};
#     my $num_homologies = scalar(@this_tree_homology_ids);
#     next unless ($num_homologies != 1);
#     while (my $homology_id1 = shift (@this_tree_homology_ids)) {
#       foreach my $homology_id2 (@this_tree_homology_ids) {
#         my $homology1 = $self->{_homologies_by_cluster}{$root_id}{$homology_id1};
#         my $homology2 = $self->{_homologies_by_cluster}{$root_id}{$homology_id2};
#         my @homology1_member_ids;
#         @homology1_member_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology1->gene_list};
#         my @homology2_member_ids;
#         @homology2_member_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology2->gene_list};
#         my %tetrad;
#         $tetrad{$homology1_member_ids[0]} = 1;
#         $tetrad{$homology1_member_ids[1]} = 1;
#         $tetrad{$homology2_member_ids[0]} = 1;
#         $tetrad{$homology2_member_ids[1]} = 1;
#         # We dont want double pairs that share one of the members
#         next if (4 != scalar(keys %tetrad));
#         my $node_a = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology1_member_ids[0],$self->{'clusterset_id'});
#         my $node_b = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology1_member_ids[1],$self->{'clusterset_id'});
#         my $node_c = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology2_member_ids[0],$self->{'clusterset_id'});
#         my $node_d = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology2_member_ids[1],$self->{'clusterset_id'});

#         my $root = $node_a->subroot;
#         $root->merge_node_via_shared_ancestor($node_b);
#         my $ancestor_ab = $node_a->find_first_shared_ancestor($node_b);
#         my $ancestor_ab_node_id = $ancestor_ab->node_id;

#         $root = $node_c->subroot;
#         $root->merge_node_via_shared_ancestor($node_d);
#         my $ancestor_cd = $node_c->find_first_shared_ancestor($node_d);
#         my $ancestor_cd_node_id = $ancestor_cd->node_id;

#         $root = $node_a->subroot;
#         $root->merge_node_via_shared_ancestor($node_c);
#         my $crossed_ancestor = $node_a->find_first_shared_ancestor($node_c);
#         my $crossed_ancestor_node_id = $crossed_ancestor->node_id;

#         # We dont want double pairs that share one of the ancestors
#         if ($ancestor_ab_node_id == $crossed_ancestor_node_id || $ancestor_cd_node_id == $crossed_ancestor_node_id) {
#           $root->release_tree;
#           next;
#         }
#         if ($ancestor_ab->parent->node_id == $ancestor_cd_node_id) {
#           $root->release_tree;
#           next;
#         }
#         if ($ancestor_cd->parent->node_id == $ancestor_ab_node_id) {
#           $root->release_tree;
#           next;
#         }
#         my $ancestor_taxon_name = $crossed_ancestor->get_tagvalue("taxon_name");
#         my $num_duplications_a=0;
#         my $num_duplications_c=0;
#         my $parent_a;
#         my $parent_c;
#         $parent_a = $node_a->parent;
#         do {
#           my $duptag = $parent_a->get_tagvalue("Duplication");
#           my $sistag = $parent_a->get_tagvalue("duplication_confidence_score");
#           if ($duptag ne "") {
#             if ($duptag > 0) {
#               if ($sistag > 0) {
#                 $num_duplications_a++;
#               }
#             }
#           }
#           $parent_a = $parent_a->parent;
#         } while (defined($parent_a) && ($parent_a->node_id != $crossed_ancestor_node_id));

#         $parent_c = $node_c->parent;
#         do {
#           my $duptag = $parent_c->get_tagvalue("Duplication");
#           my $sistag = $parent_c->get_tagvalue("duplication_confidence_score");
#           if ($duptag ne "") {
#             if ($duptag > 0) {
#               if ($sistag > 0) {
#                 $num_duplications_c++;
#               }
#             }
#           }
#           $parent_c = $parent_c->parent;
#         } while (defined($parent_c) && ($parent_c->node_id != $crossed_ancestor_node_id));

#         # Duplication at the crossed_ancestor
#         my $crossed_duptag = $crossed_ancestor->get_tagvalue("Duplication");
#         my $crossed_sistag = $crossed_ancestor->get_tagvalue("duplication_confidence_score");
#         my $crossed_ancestor_is_duplication = 0;
#         if ($crossed_duptag ne "") {
#           if ($crossed_duptag > 0) {
#             if ($crossed_sistag > 0) {
#               $crossed_ancestor_is_duplication = 1;
#             }
#           }
#         }

#         my $dn1 = $homology1->dn;
#         my $ds1 = $homology1->ds;
#         my $lnl1 = $homology1->lnl;
#         next unless (defined($dn1) && defined($ds1) && defined($lnl1));
#         my $gene1_stable_id1 = $node_a->gene_member->stable_id;
#         my $gene2_stable_id1 = $node_b->gene_member->stable_id;
#         my $taxonomy_level1 = $homology1->subtype;
#         my $dn2 = $homology2->dn;
#         my $ds2 = $homology2->ds;
#         my $lnl2 = $homology2->lnl;
#         next unless (defined($dn2) && defined($ds2) && defined($lnl2));
#         my $gene1_stable_id2 = $node_c->gene_member->stable_id;
#         my $gene2_stable_id2 = $node_d->gene_member->stable_id;
#         my $taxonomy_level2 = $homology2->subtype;
#         my $results = "$root_id,$crossed_ancestor_node_id,$crossed_ancestor_is_duplication,$ancestor_taxon_name," .
#           "$gene1_stable_id1," .
#             "$gene2_stable_id1," .
#               "$dn1,$ds1,$num_duplications_a,";
#         $results .= 
#           "$gene1_stable_id2," .
#             "$gene2_stable_id2," .
#               "$dn2,$ds2,$num_duplications_c\n";
#         print "$results" if ($self->{verbose});
#         print OUTFILE "$results";
#         $root->release_tree;
#       }
#     }
#   }
# }

# sub _slr {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{starttime} = time();

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   if (-e $self->{_slr}) {
#     my $file = $self->{_slr};
#     open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#     while (<LIST>) {
#       chomp $_;
#       $self->{_slr_ids}{$_} = 1;
#     }
#   }

#   $species_set =~ s/\_/\ /g;
#   my @species_set = split(":",$species_set);

#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my %gdb_short_names;
#   my @homologies;
#   while (my $species1 = shift (@species_set)) {
#     foreach my $species2 (@species_set) {
#       my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#       my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#       $gdb_short_names{$sp1_gdb->short_name} = 1;
#       $gdb_short_names{$sp2_gdb->short_name} = 1;
#       my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#       print STDERR "Fetching homologies btw $species1 and $species2...\n" if ($self->{verbose});
#       my @homology_set = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,'ortholog_one2one')};
#       @homologies = (@homologies, @homology_set);
#     }
#   }

#   my $short_name_list = join ("_",keys %gdb_short_names);

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "slr.". $short_name_list ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   #   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   #   my $header = "tree_id1,ancestor_node_id,ancestor_is_duplication,ancestor_taxon_name,". 
#   #                "gene1_stable_id1,gene2_stable_id1,dn1,ds1,dups_to_ancestor1," . 
#   #                "gene1_stable_id2,gene2_stable_id2,dn2,ds2,dups_to_ancestor2\n";
#   #   print OUTFILE "$header"; 
#   #   print "$header" if ($self->{verbose});

#   my $homology_count=0;
#   my $totalnum_homologies = scalar(@homologies);
#   my $sth;
#   my $root_id;

#   my $sql = "SELECT node_id,left_index,right_index FROM protein_tree_node WHERE parent_id = root_id";
#   $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   while (my ($root_id,$root_left_index,$root_right_index) = $sth->fetchrow) {
#     foreach my $index ($root_left_index .. $root_right_index) {
#       $self->{_hashed_indexes}{$index} = $root_id;
#     }
#   }
#   $sth->finish();

#   foreach my $homology (@homologies) {
#     my $homology_node_id = $homology->node_id;
#     $sql = "SELECT left_index, right_index FROM protein_tree_node WHERE node_id=$homology_node_id";
#     $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my ($left_index,$right_index) = $sth->fetchrow;

#     if (defined($self->{_hashed_indexes}{$left_index})) {
#       $root_id = $self->{_hashed_indexes}{$left_index};
#     }
#     $self->{_homologies_by_cluster}{$root_id}{$homology->dbID} = $homology;
#     $homology_count++;
#     if ($self->{'verbose'} &&  ($homology_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d homologies done]\n", 
#         $homology_count, $totalnum_homologies;
#       print STDERR $verbose_string;
#     }
#   }
#   $sth->finish;

#   last if (0 == scalar(keys %{$self->{_slr_ids}}));

#   foreach my $root_id (keys %{$self->{_homologies_by_cluster}}) {
#     my @this_tree_homology_ids = keys %{$self->{_homologies_by_cluster}{$root_id}};
#     my $num_homologies = scalar(@this_tree_homology_ids);
#     next unless ($num_homologies != 1);
#     while (my $homology_id1 = shift (@this_tree_homology_ids)) {
#       foreach my $homology_id2 (@this_tree_homology_ids) {
#         my $homology1 = $self->{_homologies_by_cluster}{$root_id}{$homology_id1};
#         my $homology2 = $self->{_homologies_by_cluster}{$root_id}{$homology_id2};
#         my @homology1_member_ids;
#         @homology1_member_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology1->gene_list};
#         my @homology2_member_ids;
#         @homology2_member_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology2->gene_list};
#         my %tetrad;
#         $tetrad{$homology1_member_ids[0]} = 1;
#         $tetrad{$homology1_member_ids[1]} = 1;
#         $tetrad{$homology2_member_ids[0]} = 1;
#         $tetrad{$homology2_member_ids[1]} = 1;
#         # We dont want double pairs that share one of the members
#         next if (4 != scalar(keys %tetrad));
#         my $node_a = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology1_member_ids[0],$self->{'clusterset_id'});
#         my $node_b = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology1_member_ids[1],$self->{'clusterset_id'});
#         my $node_c = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology2_member_ids[0],$self->{'clusterset_id'});
#         my $node_d = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology2_member_ids[1],$self->{'clusterset_id'});

#         my $root = $node_a->subroot;
#         $root->merge_node_via_shared_ancestor($node_b);
#         my $ancestor_ab = $node_a->find_first_shared_ancestor($node_b);
#         my $ancestor_ab_node_id = $ancestor_ab->node_id;

#         $root = $node_c->subroot;
#         $root->merge_node_via_shared_ancestor($node_d);
#         my $ancestor_cd = $node_c->find_first_shared_ancestor($node_d);
#         my $ancestor_cd_node_id = $ancestor_cd->node_id;

#         $root = $node_a->subroot;
#         $root->merge_node_via_shared_ancestor($node_c);
#         my $crossed_ancestor = $node_a->find_first_shared_ancestor($node_c);
#         my $crossed_ancestor_node_id = $crossed_ancestor->node_id;

#         # We dont want double pairs that share one of the ancestors
#         if ($ancestor_ab_node_id == $crossed_ancestor_node_id || $ancestor_cd_node_id == $crossed_ancestor_node_id) {
#           $root->release_tree;
#           next;
#         }
#         if ($ancestor_ab->parent->node_id == $ancestor_cd_node_id) {
#           $root->release_tree;
#           next;
#         }
#         if ($ancestor_cd->parent->node_id == $ancestor_ab_node_id) {
#           $root->release_tree;
#           next;
#         }

#         my $cds_aln = $crossed_ancestor->get_SimpleAlign(-cdna => 1);
#         my $minimized_tree = $crossed_ancestor->minimize_tree;
#         my $newick_tree = $minimized_tree->newick_format;
#         my $node_id = $crossed_ancestor->node_id;
#         if (-e $self->{_slr}) {
#           next unless (defined($self->{_slr_ids}{$node_id}));
#         }
#         next if (defined($self->{_slr_done}{$node_id}));
#         print STDERR "[aln $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#         open TREE, ">$node_id.nh" or die "couldnt open $node_id.nh: $!\n"; print TREE "$newick_tree\n"; close TREE;
# 	my $treeio = Bio::TreeIO->new
#           (-format => 'newick',-file   => "$node_id.nh");
# 	my $tree = $treeio->next_tree;
#         eval { require Bio::Tools::Run::Phylo::SLR; };
#         die "slr wrapper not found: $!\n" if ($@);
#         my $slr = Bio::Tools::Run::Phylo::SLR->new
#           (
#            '-executable' => '/nfs/acari/avilella/src/slr/bin/Slr',
#            '-program_dir' => '/nfs/acari/avilella/src/slr/bin');

# 	$slr->alignment($cds_aln);
# 	$slr->tree($tree);
# 	my ($rc,$results) = $slr->run();
#         print STDERR "[slr $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#         unless (defined($results)) {
#           print "$node_id,na,na,na\n";
#           next;
#         }
#         my $summary; my $total;
#         foreach my $type (keys %{$results}) {
#           my $num = scalar (@{$results->{$type}});
#           $summary->{$type} = $num;
#           $total += $num;
#         }
#         my @display_ids = map {$_->display_id } $cds_aln->each_seq;
#         foreach my $type (keys %{$summary}) {
#           print "$node_id,$type,", $summary->{$type}/$total,",",join("\:",@display_ids), "\n";
#         }
#         unlink "$node_id.nh";
#         $self->{_slr_done}{$node_id} = 1;
#         delete $self->{_slr_ids}{$node_id};
#         last if (0 == scalar(keys %{$self->{_slr_ids}}));

#         #         my $ancestor_taxon_name = $crossed_ancestor->get_tagvalue("taxon_name");
#         #         my $num_duplications_a=0;
#         #         my $num_duplications_c=0;
#         #         my $parent_a;
#         #         my $parent_c;
#         #         $parent_a = $node_a->parent;
#         #         do {
#         #           my $duptag = $parent_a->get_tagvalue("Duplication");
#         #           my $sistag = $parent_a->get_tagvalue("duplication_confidence_score");
#         #           if ($duptag ne "") {
#         #             if ($duptag > 0) {
#         #               if ($sistag > 0) {
#         #                 $num_duplications_a++;
#         #               }
#         #             }
#         #           }
#         #           $parent_a = $parent_a->parent;
#         #         } while (defined($parent_a) && ($parent_a->node_id != $crossed_ancestor_node_id));

#         #         $parent_c = $node_c->parent;
#         #         do {
#         #           my $duptag = $parent_c->get_tagvalue("Duplication");
#         #           my $sistag = $parent_c->get_tagvalue("duplication_confidence_score");
#         #           if ($duptag ne "") {
#         #             if ($duptag > 0) {
#         #               if ($sistag > 0) {
#         #                 $num_duplications_c++;
#         #               }
#         #             }
#         #           }
#         #           $parent_c = $parent_c->parent;
#         #         } while (defined($parent_c) && ($parent_c->node_id != $crossed_ancestor_node_id));

#         #         # Duplication at the crossed_ancestor
#         #         my $crossed_duptag = $crossed_ancestor->get_tagvalue("Duplication");
#         #         my $crossed_sistag = $crossed_ancestor->get_tagvalue("duplication_confidence_score");
#         #         my $crossed_ancestor_is_duplication = 0;
#         #         if ($crossed_duptag ne "") {
#         #           if ($crossed_duptag > 0) {
#         #             if ($crossed_sistag > 0) {
#         #               $crossed_ancestor_is_duplication = 1;
#         #             }
#         #           }
#         #         }

#         #         my $dn1 = $homology1->dn;
#         #         my $ds1 = $homology1->ds;
#         #         my $lnl1 = $homology1->lnl;
#         #         next unless (defined($dn1) && defined($ds1) && defined($lnl1));
#         #         my $gene1_stable_id1 = $node_a->gene_member->stable_id;
#         #         my $gene2_stable_id1 = $node_b->gene_member->stable_id;
#         #         my $taxonomy_level1 = $homology1->subtype;
#         #         my $dn2 = $homology2->dn;
#         #         my $ds2 = $homology2->ds;
#         #         my $lnl2 = $homology2->lnl;
#         #         next unless (defined($dn2) && defined($ds2) && defined($lnl2));
#         #         my $gene1_stable_id2 = $node_c->gene_member->stable_id;
#         #         my $gene2_stable_id2 = $node_d->gene_member->stable_id;
#         #         my $taxonomy_level2 = $homology2->subtype;
#         #         my $results = "$root_id,$crossed_ancestor_node_id,$crossed_ancestor_is_duplication,$ancestor_taxon_name," .
#         #           "$gene1_stable_id1," .
#         #             "$gene2_stable_id1," .
#         #               "$dn1,$ds1,$num_duplications_a,";
#         #         $results .= 
#         #           "$gene1_stable_id2," .
#         #             "$gene2_stable_id2," .
#         #               "$dn2,$ds2,$num_duplications_c\n";
#         #         print "$results" if ($self->{verbose});
#         #         print OUTFILE "$results";
#         $root->release_tree;
#       }
#     }
#   }
# }

# sub _simul_genetrees {
#   my $self = shift;

#   $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   my $type = $self->{debug} || "SIS1";
#   my $gmin = $self->{_gmin} || 0.5;

#   my $species_tree = "(((((((((((((((((((Homo sapiens:0.005873,Pan troglodytes:0.007668)A:0.013037,Pongo pygmaeus:0.019969)B:0.013037,Macaca mulatta:0.031973)C:0.013300,Callithrix jacchus:0.074420)D:0.060000,(Microcebus murinus:0.07,Otolemur garnettii:0.071185)II:0.07)E:0.015682,Tupaia belangeri:0.162844)F:0.006272,((((Rattus norvegicus:0.044383,Mus musculus:0.036274)GG:0.04,Spermophilus tridecemlineatus:0.08)G:0.200607,Cavia porcellus:0.202990)H:0.034350,(Ochotona princeps:0.1,Oryctolagus cuniculus:0.108548)KK:0.1)I:0.014587)J:0.019763,((Sorex araneus:0.248532,Erinaceus europaeus:0.222255)K:0.045693,((((Canis familiaris:0.101137,Felis catus:0.098203)L:0.048213,Equus caballus:0.099323)M:0.007287,Bos taurus:0.163945)N:0.012398),Myotis lucifugus:0.18928)O:0.02)P:0.030081,(Dasypus novemcinctus:0.133274,(Loxodonta africana:0.103030,Echinops telfairi:0.232706)Q:0.049511)R:0.008424)S:0.213469,Monodelphis domestica:0.320721)T:0.088647,Ornithorhynchus anatinus:0.488110)U:0.118797,(Gallus gallus:0.395136,Anolis carolinensis:0.513962)V:0.093688)W:0.151358,Xenopus tropicalis:0.778272)X:0.174596,(((Tetraodon nigroviridis:0.203933,Takifugu rubripes:0.239587)Y:0.203949,(Gasterosteus aculeatus:0.314162,Oryzias latipes:0.501915)Z:0.055354)AA:0.346008,Danio rerio:0.730028)BB:0.174596)CC:0.1),(Ciona intestinalis:0.8,Ciona savignyi:0.8)FF:0.4)LL:0.2,(((Anopheles gambiae:0.65,Aedes aegypti:0.65)DD:0.2,Drosophila melanogaster:0.85)EE:0.5)MM:0.01),Caenorhabditis elegans:1.35)JJ:0.3,Saccharomyces cerevisiae:1.65)ROOT:0.0;\n";

#   open RAPSP, ">/tmp/species_tree.rap.nh" or die "$!";
#   print RAPSP $species_tree;
#   close RAPSP;

#   require Bio::Tools::Run::Phylo::PAML::Evolver;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $file = $self->{_simul_genetrees};
#   open LIST, "$file" or die "couldnt open file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     next if ($_ eq '');
#     $self->{_ids}{$_} = 1;
#   }

#   # print "tree_id,subnode_id,dupconf,bootstrap,dist_parent,dist_leaves,root_gblocks,subtree_gblocks,subtree_local_gblocks,num_leaves,gene_count,genes\n";
#   foreach my $root_id (keys %{$self->{_ids}}) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     next unless (defined($root));
#     next if (3 >= $root->num_leaves);
#     my $root_id = $root->node_id;
#     my $newick = $root->newick_format;
#     my $aln = $root->get_SimpleAlign;
#     my $aln_length = $aln->length;

#     open(my $fake_fh, "+<", \$newick);
#     my $treein = new Bio::TreeIO
#       (-fh => $fake_fh,
#        -format => 'newick');
#     my $tree = $treein->next_tree;
#     $treein->close;

#     #     BEGIN {$ENV{EVOLVER_INDELDIR} = '/nfs/acari/avilella/src/evolver_indel/evolver_indel'; };

#     my $total_branch_length = 0;
#     my $rescale = 0;
#     foreach my $node ($tree->get_nodes) {
#       $total_branch_length += $node->branch_length || 0;
#     }

#     if ($rescale) {
#       $total_branch_length = 0;
#       foreach my $node ($tree->get_nodes) {
#         $total_branch_length += $node->branch_length;
#       }
#       foreach my $node ($tree->get_nodes) {
#         my $branch_length = $node->branch_length;
#         next unless (defined($branch_length));
#         $node->branch_length(sprintf("%.10f",$branch_length/$total_branch_length));
#       }
#       my $new_branch_length;
#       foreach my $node ($tree->get_nodes) {
#         $new_branch_length += $node->branch_length;
#       }
#     }

#     open (REF, ">/tmp/ensrtree.$root_id.nh") or die "$!";
#     print REF $root->newick_format, "\n";
#     close REF;

#     open (OUT, ">/tmp/treebest.$root_id.nh") or die "$!";
#     open (PHYMLOUT, ">/tmp/phyml.$root_id.nh") or die "$!";
#     my $replicates = $self->{verbose} || 2;
#     foreach my $replicate (1 .. $replicates) {
#       my $evolver = new Bio::Tools::Run::Phylo::PAML::Evolver();
#       $evolver->executable('/nfs/acari/avilella/src/paml3.14/src/evolver');
#       $evolver->save_tempfiles(1);
#       my $nuclsites = $aln_length*3;
#       #       my $dummynuclsites = (int(rand(10000)))+1;
#       $evolver->set_parameter("nuclsites","$nuclsites");
#       $evolver->set_parameter("tree_length","$total_branch_length");
#       $evolver->set_parameter("kappa","2");

#       #FIXME - tree to sum 1
#       $evolver->tree($tree);
#       my $tempdir = $evolver->tempdir;
#       my $treeoutfile = Bio::TreeIO->new(-format => 'newick', -file => ">$tempdir/evolver.input_tree.nh"); #print to STDOUT instead
#       $treeoutfile->write_tree($tree);
#       my $dummyomega = (int(rand(10))/10);
#       $evolver->set_parameter("omega","$dummyomega");
#       $evolver->save_tempfiles(1);
#       my $dummy = $evolver->prepare();
#       my $rc = $evolver->run();
#       my $in  = Bio::AlignIO->new
#         ('-file'   => "$tempdir/mc.paml", 
#          '-format' => 'phylip',
#          '-idlength' => 30,
#          '-interleaved' => 0);
#       my $aln = $in->next_aln();

#       # Renaming sequences for njtree
#       my $new_aln = Bio::SimpleAlign->new;
#       my $alnlength = $aln->length;
#       foreach my $seq ($aln->each_seq) {
#         my $display_id = $seq->display_id;
#         my $taxon_id = $root->find_node_by_name($display_id)->taxon_id;
#         my $member_id = $root->find_node_by_name($display_id)->member_id;
#         my $njtree_display_id = $member_id . "_" . $taxon_id;
#         my $newseq = new Bio::LocatableSeq
#           (-seq => $seq->seq,
#            -id  => "$njtree_display_id");
#         $new_aln->add_seq($newseq);
#       }
#       my $outfile = "$tempdir/$root_id.fasta";
#       my $alnout = Bio::AlignIO->new
#         (-file => ">$outfile",
#          -format => 'fasta');
#       $alnout->force_displayname_flat(1);
#       $alnout->write_aln($new_aln);
#       $self->{'input_aln'} = $outfile;
#       $self->{'newick_file'} = $self->{'input_aln'} . "_njtree_phyml_tree.txt ";
#       my $njtree_phyml_executable = "/nfs/acari/avilella/src/_treesoft/treebest/treebest";
#       my $cmd = $njtree_phyml_executable;
#       $self->{'species_tree_file'} = '/nfs/acari/avilella/spec_tax.nh';
#       $self->{'bootstrap'} = 1;
#       if (1 == $self->{'bootstrap'}) {
#         $cmd .= " best ";
#         if (defined($self->{'species_tree_file'})) {
#           $cmd .= " -f ". $self->{'species_tree_file'};
#         }
#         $cmd .= " ". $self->{'input_aln'};
#         $cmd .= " -p tree ";
#         $cmd .= " -o " . $self->{'newick_file'};
#         $cmd .= " 2>/dev/null 1>/dev/null";

#         # print("$cmd\n") if($self->{verbose});
#         my $worker_temp_directory = $tempdir;
#         unless(system("cd $worker_temp_directory; $cmd") == 0) {
#           print("$cmd\n");
#           $self->throw("error running njtree phyml, $!\n");
#         }
#       }

#       # PARSE
#       my $newick_file =  $self->{'newick_file'};
#       my $tree = $self->{treeDBA}->fetch_node_by_node_id($root_id);

#       #cleanup old tree structure- 
#       #  flatten and reduce to only GeneTreeMember leaves
#       $tree->flatten_tree;
#       # $tree->print_tree(20) if($self->{verbose});
#       foreach my $node (@{$tree->get_all_leaves}) {
#         next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
#         $node->disavow_parent;
#       }

#       #parse newick into a new tree object structure
#       my $newick = '';
#       # print("load from file $newick_file\n") if($self->{verbose});
#       open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
#       while (<FH>) {
#         $newick .= $_;
#       }
#       close(FH);
#       my $newtree = 
#         Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);

#       # get rid of the taxon_id needed by njtree -- name tag
#       foreach my $leaf (@{$newtree->get_all_leaves}) {
#         my $njtree_phyml_name = $leaf->get_tagvalue('name');
#         $njtree_phyml_name =~ /(\d+)\_\d+/;
#         my $member_name = $1;
#         $leaf->add_tag('name', $member_name);
#       }

#       # Leaves of newick tree are named with member_id of members from
#       # input tree move members (leaves) of input tree into newick tree to
#       # mirror the 'member_id' nodes
#       foreach my $member (@{$tree->get_all_leaves}) {
#         my $tmpnode = $newtree->find_node_by_name($member->member_id);
#         if ($tmpnode) {
#           $tmpnode->add_child($member, 0.0);
#           $tmpnode->minimize_node; #tmpnode is now redundant so it is removed
#         } else {
#           print("unable to find node in newick for member"); 
#           $member->print_member;
#         }
#       }

#       # Merge the trees so that the children of the newick tree are now
#       # attached to the input tree's root node
#       $tree->merge_children($newtree);
#       $self->add_tags($tree);

#       # Newick tree is now empty so release it
#       $newtree->release_tree;

#       # $tree->print_tree if($self->{verbose});

#       my $newick_tree = $tree->newick_format;
#       print OUT $newick_tree, "\n";
#       print STDERR "[njtree] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#       ########################################
#       my $phymloutfile = "$tempdir/$root_id.phylip";
#       $alnout = Bio::AlignIO->new
#         (-file => ">$phymloutfile",
#          -format => 'phylip',
#          -interleaved => 1);
#       $alnout->force_displayname_flat(1);
#       $alnout->write_aln($new_aln);
#       $self->{'input_aln'} = $phymloutfile;

#       $self->{'newick_file'} = $self->{'input_aln'} . "_phyml_tree.txt ";
#       my $phyml_executable = "/usr/local/ensembl/bin/phyml";

#       throw("can't find a phyml executable to run\n") unless(-e $phyml_executable);

#       #./phyml seqs2 1 i 1 0 JTT 0.0 4 1.0 BIONJ n n 
#       $cmd = $phyml_executable;
#       $cmd .= " ". $self->{'input_aln'};  
#       $cmd .= " 0 i 1 0 HKY e 0.0 4 e BIONJ y y";
#       $cmd .= " 2>/dev/null 1>/dev/null";

#       unless(system($cmd) == 0) {
#         print("$cmd\n");
#         throw("error running phyml, $!\n");
#       }

#       # PARSE
#       $newick_file =  $self->{'newick_file'};
#       my $phymltree = $self->{treeDBA}->fetch_node_by_node_id($root_id);

#       #cleanup old tree structure- 
#       #  flatten and reduce to only GeneTreeMember leaves
#       $phymltree->flatten_tree;
#       # $tree->print_tree(20) if($self->{verbose});
#       foreach my $node (@{$phymltree->get_all_leaves}) {
#         next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
#         $node->disavow_parent;
#       }

#       #parse newick into a new tree object structure
#       $newick = '';
#       # print("load from file $newick_file\n") if($self->{verbose});
#       open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
#       while (<FH>) {
#         $newick .= $_;
#       }
#       close(FH);
#       $newtree = '';
#       $newtree = 
#         Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);

#       # get rid of the taxon_id needed by njtree -- name tag
#       foreach my $leaf (@{$newtree->get_all_leaves}) {
#         my $njtree_phyml_name = $leaf->get_tagvalue('name');
#         $njtree_phyml_name =~ /(\d+)\_\d+/;
#         my $member_name = $1;
#         $leaf->add_tag('name', $member_name);
#       }

#       # Leaves of newick tree are named with member_id of members from
#       # input tree move members (leaves) of input tree into newick tree to
#       # mirror the 'member_id' nodes
#       foreach my $member (@{$phymltree->get_all_leaves}) {
#         my $tmpnode = $newtree->find_node_by_name($member->member_id);
#         if ($tmpnode) {
#           $tmpnode->add_child($member, 0.0);
#           $tmpnode->minimize_node; #tmpnode is now redundant so it is removed
#         } else {
#           print("unable to find node in newick for member"); 
#           $member->print_member;
#         }
#       }

#       # Merge the trees so that the children of the newick tree are now
#       # attached to the input tree's root node
#       $phymltree->merge_children($newtree);
#       $self->add_tags($phymltree);

#       # Newick tree is now empty so release it
#       $newtree->release_tree;

#       # $tree->print_tree if($self->{verbose});

#       # balance tree
#       my $node = new Bio::EnsEMBL::Compara::NestedSet;
#       $node->merge_children($phymltree); #moves childen from $phymltree onto $node
#       #$node->node_id($phymltree->node_id); #give old node_id for debugging
#       #$phymltree now has no children

#       #get a link and search the tree for the balancing link (link length sum)
#       my ($link) = @{$node->links};  

#       #create new root node at the midpoint on this 'balanced' link
#       my $root = Bio::EnsEMBL::Compara::Graph::Algorithms::root_tree_on_link($link);

#       #remove temp root if it has become a redundant internal node (only 1 child)
#       $node->minimize_node;

#       #move newly rooted tree back to original '$phymltree' node  
#       $phymltree->merge_children($root);
#       ########################################

#       $newick_tree = '';
#       $newick_tree = $phymltree->newick_format;
#       print PHYMLOUT $newick_tree, "\n";
#       print STDERR "[phyml] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#       ########################################

#       #       $self->{'protein_tree'} = $phymltree;
#       #       $self->{'rap_infile'} = $self->dumpTreeToWorkdir($self->{'protein_tree'},$tempdir);
#       #       return unless($self->{'rap_infile'});

#       #       $self->{'species_tree_file'} = "/tmp/species_tree.rap.nh";
#       #       $self->{'newick_file'} = $self->{'rap_infile'} . "_rap_tree.txt ";

#       #       $cmd = "/software/farm/java/bin/java -jar /software/ensembl/bin/rap.jar";
#       #       $cmd .= " 80";    #Max bootstrap for reduction
#       #       $cmd .= " 50.0";  #Max relative rate ratio before duplication
#       #       $cmd .= " 30";    #Gene Tree Max depth for best root research 
#       #       $cmd .= " 0.15";  #Maximum length for polymorphism
#       #       $cmd .= " 0.03";  #Maximum length for reduction - Species Tree (was 10.0)
#       #       $cmd .= " 0.15";  #Maximum length for reduction - Gene tree  
#       #       $cmd .= " ". $self->{'species_tree_file'};
#       #       $cmd .= " ". $self->{'rap_infile'};
#       #       $cmd .= " ". $self->{'rap_outfile'};
#       #       $cmd .= " 2>&1 > /dev/null";

#       #       $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
#       #       # print("$cmd\n") if($self->debug);
#       #       unless(system($cmd) == 0) {
#       #         print("$cmd\n");
#       #         throw("error running rap, $!\n");
#       #       }

#       #       $self->parse_RAP_output;
#       #       $self->{tree} = $self->{protein_tree};
#       #       $self->{'_readonly'} = 1;
#       #       _run_orthotree($self);

#       $evolver->cleanup;
#     }
#     close OUT;
#     close PHYMLOUT;

#     my $ret = `perl /nfs/acari/avilella/src/ktreedist/Ktreedist_v1/Ktreedist.pl -rt /tmp/ensrtree.$root_id.nh -ct /tmp/treebest.$root_id.nh -a`;
#     foreach my $line (split("\n",$ret)) {
#       if ($line =~ /Tree (\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
#         $self->{ktreedist}{$root_id}{njtree}{$1}{kscore} = $2;
#         $self->{ktreedist}{$root_id}{njtree}{$1}{scale_factor} = $3;
#         $self->{ktreedist}{$root_id}{njtree}{$1}{symm_diff} = $4;
#         $self->{ktreedist}{$root_id}{njtree}{$1}{n_partitions} = $5;
#       }
#     }
#     $ret='';
#     $ret = `perl /nfs/acari/avilella/src/ktreedist/Ktreedist_v1/Ktreedist.pl -rt /tmp/ensrtree.$root_id.nh -ct /tmp/phyml.$root_id.nh -a`;
#     foreach my $line (split("\n",$ret)) {
#       if ($line =~ /Tree (\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
#         $self->{ktreedist}{$root_id}{phyml}{$1}{kscore} = $2;
#         $self->{ktreedist}{$root_id}{phyml}{$1}{scale_factor} = $3;
#         $self->{ktreedist}{$root_id}{phyml}{$1}{symm_diff} = $4;
#         $self->{ktreedist}{$root_id}{phyml}{$1}{n_partitions} = $5;
#       }
#     }
#   }
#   print "root_id,method,replicate,kscore,scale_factor,symm_diff,n_partitions\n";
#   foreach my $root_id (keys %{$self->{ktreedist}}) {
#     foreach my $method (keys %{$self->{ktreedist}{$root_id}}) {
#       foreach my $replicate (keys %{$self->{ktreedist}{$root_id}{$method}}) {
#         my $kscore = $self->{ktreedist}{$root_id}{$method}{$replicate}{kscore};
#         my $scale_factor = $self->{ktreedist}{$root_id}{$method}{$replicate}{scale_factor};
#         my $symm_diff = $self->{ktreedist}{$root_id}{$method}{$replicate}{symm_diff};
#         my $n_partitions = $self->{ktreedist}{$root_id}{$method}{$replicate}{n_partitions};
#         print "$root_id,$method,$replicate,$kscore,$scale_factor,$symm_diff,$n_partitions\n";
#       }
#     }
#   }
#   unlink </tmp/*>;
# }

# sub _gblocks_species {
#   my $self = shift;
#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   my $gmin = $self->{_gmin} || 0.8;

#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -verbose => "0" );

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $file = $self->{_gblocks_species};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     next if ($_ eq '');
#     $self->{_ids}{$_} = 1;
#   }

#   # print "type_rank,rank,root_id,num_leaves,aln_length,leaf_stable_id,leaf_total_missing,join_leaf_missing_stretches,leaf_total_extra,join_leaf_extra_stretches,join_exon_extra_stretches,url\n";
#   print "type_rank,rank,root_id,num_leaves,aln_length,leaf_stable_id,species,leaf_total_missing,join_leaf_missing_stretches,leaf_total_extra,join_leaf_extra_stretches,better_transcript,url\n";
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "gblocks_species.transcripts.". $self->{_mydbname};
#   my ($infilebase,$path,$type) = fileparse($self->{_gblocks_species});
#   $outfile = "$path/$outfile.csv";
#   open TRANSCRIPTS, ">$outfile" or die "$!";
#   print STDERR "$outfile ...\n";
#   print TRANSCRIPTS "root_id,num_leaves,aln_length,alt_alnl,cov,altcov,diff,leaf_stable_id,transcript_stable_id,sp_short_name,link\n";
#   foreach my $root_id (keys %{$self->{_ids}}) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     next unless (defined($root));
#     next if ('1' eq $root->get_tagvalue('cluster_had_to_be_broken_down'));
#     my $num_leaves = $root->num_leaves;
#     next unless (8 <= $num_leaves);
#     my $aln = $root->get_SimpleAlign;
#     my $aln_length = $aln->length;
#     my $tree_id = $root->node_id;

#     my $flanks_gblocks = _run_gblocks($root,$gmin);

#     my @leaves = @{$root->get_all_leaves};
#     my $numseq = scalar(@leaves);

#     # Gblocks coverage
#     my @gblocks_coverage;
#     foreach my $aln_pos (1 .. $aln_length) {
#       push @gblocks_coverage, "0";
#     }
#     if ($flanks_gblocks =~ /\[\d+  \d+\]/) {
#       foreach my $segment ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#         my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#         foreach my $aln_pos ($start .. $end) {
#           $gblocks_coverage[$aln_pos] = "2";
#         }
#       }
#     }
#     ####

#     my $covp = join("",@gblocks_coverage);
#     my $covp_tmp = $covp;
#     $covp_tmp =~ s/0//g;
#     my $alnl = length($covp);
#     my $alnc = length($covp_tmp);
#     my $perc_cov = sprintf("%.4f",$alnc/$alnl);

#     my $ranking_loosers;
#     my $ranking_gainers;
#     my $results;

#     while (my $leaf = shift @leaves) {
#       my $leaf_total_missing = 0;
#       my $leaf_total_extra = 0;
#       my @leaf_missing_stretches;
#       my @leaf_extra_stretches;
#       my @exon_extra_stretches;
#       my @seqs = $aln->each_seq_with_id($leaf->stable_id);
#       my $leaf_stable_id = $leaf->stable_id;
#       my $leaf_genome_db = $leaf->genome_db;
#       my $sp_short_name = $leaf_genome_db->short_name;
#       my $sp_name = $leaf_genome_db->name; $sp_name =~ s/\ /\_/g;
#       my $link = "http://www.ensembl.org/$sp_name/genetreeview?peptide=$leaf_stable_id";
#       my $positive = 0;
#       if ($flanks_gblocks =~ /\[\d+  \d+\]/g) {
#         # Finding missing peptide stretches not in seq but in gblocks
#         foreach my $segment ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#           my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#           my $subseq = $seqs[0]->subseq($start,$end);
#           $subseq =~ s/\-//g;
#           my $missing_length = ($end-$start+1) - length($subseq);
#           if (0 != $missing_length) {
#             push @leaf_missing_stretches, $missing_length;
#             $leaf_total_missing += $missing_length;
#           }
#         }
#         $ranking_loosers->{$leaf_total_missing}{$leaf_stable_id} = 0;
#         # Finding extra peptide stretches not in gblocks but in seq
#         my $seqp = $seqs[0]->seq;
#         $seqp =~ s/[^-]/1/g;
#         $seqp =~ s/-/0/g;
#         my $isect = sprintf($covp | $seqp);
#         foreach my $intraextra ($isect =~ /(1+)/g) {
#           my $intraextra_length = length($intraextra);
#           # Don't count very small insertions
#           if ($intraextra_length > 4) {
#             push @leaf_extra_stretches, $intraextra_length;
#             $leaf_total_extra += $intraextra_length;
#           }
#         }
#         if (0 < $leaf_total_extra) {
#           my $gene_member = $leaf->gene_member->get_Gene;
#           my @transcripts = @{$gene_member->get_all_Transcripts};
#           next unless (1 < scalar(@transcripts));
#           foreach my $transcript (@transcripts) {
#             my $peptide = $transcript->translation->seq;
#             my $leaf_peptide = $leaf->sequence;
#             my $transcript_stable_id = $transcript->stable_id;
#             next if ($peptide eq $leaf_peptide);
#             eval {require Bio::SeqIO;};
#             if ($@) {
#               print STDERR "Bio::SeqIO not found"; die "$!\n";
#             }
#             my $seqio = Bio::SeqIO->new
#               (-file => ">/tmp/tmp_transcript",
#                -format => 'fasta');
#             my $seq = Bio::Seq->new
#               (-display_id => $transcript_stable_id,
#                -seq => $peptide);
#             $seqio->write_seq($seq);
#             $seqio->close;
#             my $alnio = Bio::AlignIO->new
#               (-file => ">/tmp/tmp_aln",
#                -format => 'fasta');
#             $alnio->write_aln($aln);
#             $alnio->close;
#             my $eval = `/software/ensembl/compara/bin/muscle352 -profile -in1 /tmp/tmp_aln -in2 /tmp/tmp_transcript 1> /tmp/tmp_out 2>/dev/null`;
#             my $alnout = Bio::AlignIO->new
#               (-file => "/tmp/tmp_out",
#                -format => 'fasta');
#             my $oaln = $alnout->next_aln;
#             $alnout->close;
#             $oaln->remove_seq($oaln->each_seq_with_id($leaf->stable_id));
#             $oaln = $oaln->remove_gaps('', 1);
#             my $alt_gblocks = _run_gblocks($oaln,$gmin);
#             my @alt_coverage;
#             foreach my $aln_pos (1 .. $oaln->length) {
#               push @alt_coverage, "0";
#             }
#             if ($alt_gblocks =~ /\[\d+  \d+\]/) {
#               foreach my $segment ($alt_gblocks =~ /(\[\d+  \d+\])/g) {
#                 my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#                 foreach my $aln_pos ($start .. $end) {
#                   $alt_coverage[$aln_pos] = "2";
#                 }
#               }
#             }
#             my $altp = join("",@alt_coverage);
#             my $alt_alnl = length($altp);
#             $altp =~ s/0//g;
#             my $alt_alnc = length($altp);
#             my $perc_altcov = sprintf("%.4f",$alt_alnc/$alt_alnl);
#             my $perc_diff = sprintf("%.4f",($perc_altcov-$perc_cov)/((($perc_cov+$perc_altcov))/2));
#             if (0 < $perc_diff) {
#               $positive = 1;
#             }
#             ;
#             print TRANSCRIPTS "$root_id,$num_leaves,$aln_length,$alt_alnl,$perc_cov,$perc_altcov,$perc_diff,$leaf_stable_id,$transcript_stable_id,$sp_short_name,$link\n";
#           }
#           unlink </tmp/tmp*>;
#         }
#         $ranking_gainers->{$leaf_total_extra}{$leaf_stable_id} = 1;
#       }
#       my $join_leaf_missing_stretches = join(":",@leaf_missing_stretches) || "na";
#       my $join_leaf_extra_stretches = join(":",@leaf_extra_stretches) || "na";
#       # my $join_exon_extra_stretches = join(":",@exon_extra_stretches) || "na";
#       # $results->{$leaf_stable_id} = "$root_id,$num_leaves,$aln_length,$leaf_stable_id,$sp_short_name,$leaf_total_missing,$join_leaf_missing_stretches,$leaf_total_extra,$join_leaf_extra_stretches,$join_exon_extra_stretches,$link\n";
#       $results->{$leaf_stable_id} = "$root_id,$num_leaves,$aln_length,$leaf_stable_id,$sp_short_name,$leaf_total_missing,$join_leaf_missing_stretches,$leaf_total_extra,$join_leaf_extra_stretches,$positive,$link\n";
#     }
#     my $gainer_ranking = 0;
#     foreach my $num (sort {$a <=> $b} keys %{$ranking_gainers}) {
#       foreach my $leaf_stable_id (keys %{$ranking_gainers->{$num}}) {
#         my $string = $results->{$leaf_stable_id} if (defined($results->{$leaf_stable_id}));
#         if ($num > 0) {
#           $gainer_ranking++;
#           delete $results->{$leaf_stable_id};
#           print "g,$gainer_ranking,$string" if (defined($string) && $string ne '');
#         }
#       }
#     }
#     my $looser_ranking = 0;
#     foreach my $num (sort {$b <=> $a} keys %{$ranking_loosers}) {
#       foreach my $leaf_stable_id (keys %{$ranking_loosers->{$num}}) {
#         my $string = $results->{$leaf_stable_id} if (defined($results->{$leaf_stable_id}));
#         delete $results->{$leaf_stable_id};
#         $looser_ranking++ if ($num > 0);
#         print "l,$looser_ranking,$string" if (defined($string) && $string ne '');
#       }
#     }
#     print STDERR "[$root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     $root->release_tree;
#   }
#   close TRANSCRIPTS;
# }

sub _genetree_domains {
  my $self = shift;

  $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
  $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;

  my $file = $self->{_genetree_domains};
  if (-e $file) {
    open LIST, "$file" or die "couldnt open genetree_domains file $file: $!\n";
    while (<LIST>) { chomp $_; next if ($_ eq ''); $self->{_ids}{$_} = 1; }
  } else {$self->{_ids}{$file} = 1; }

  $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\w+)$/g;
  my ($myuserpass,$myhost,$mydbversion) = ($1,$2,$3);
  my $port = 3306;
  my ($myuser,$mypass);
  if ($myuserpass =~ /(\S+)\:(\S+)/) {
    $myuser = $1;
    $mypass = $2;
  }
  if ($myhost =~ /(\S+)\:(\S+)/) {
    $port = $2;
    $myhost = $1;
  }
  Bio::EnsEMBL::Registry->load_registry_from_db
      ( -host => "$myhost",
        -user => "$myuser",
        -pass => "$mypass",
        -db_version => "$mydbversion",
        -port => "$port",
        -verbose => "0" );

  #   open OUT,">$file.out" or die "$!\n";
  #   print OUT "root_id,pfam_num_domains,aln_length,domain_coverage,root_taxon_name,treefam_id,dev_treefam_id,domain_string\n";
  foreach my $root_id (keys %{$self->{_ids}}) {
    my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
    next unless (defined($root));

    my @leaves = @{$root->get_all_leaves};
    my $member_domain;
    my $domain_boundaries;
    my $domain_coverage;
    my $representative_member = '';
    while (my $member = shift @leaves) {
      my $member_id = $member->dbID;
      my $member_stable_id = $member->stable_id;
      unless ($representative_member ne '') {
        if ($member_stable_id =~ /ENSP0/) { 
          my $d = $member->description; $d =~ /Gene\:(\S+)/; my $g = $1; $representative_member = $g; }
        elsif ($member_stable_id =~ /ENSMUSP0/) { 
          my $d = $member->description; $d =~ /Gene\:(\S+)/; my $g = $1; $representative_member = $g; }
        elsif ($member_stable_id =~ /ENSDARP0/) { 
          my $d = $member->description; $d =~ /Gene\:(\S+)/; my $g = $1; $representative_member = $g; }
      }

      my $translation = $member->translation;
      if (!defined($translation)) {
        warn "missing translation for $member_id\n";
        next;
      }
      my @domains = @{$translation->get_all_ProteinFeatures('pfam')};
      my $count = 1;
      my $member_domain_counter;
      while (my $domain = shift @domains) {
        my $type = $domain->analysis->logic_name;
        next unless ($type =~ /Pfam/i);
        my $start = $domain->start;
        my $end = $domain->end;
        my $pfamid = $domain->hseqname;
        # We first add up a $member_domain->{$pfamid}{$member_id}
        $member_domain_counter->{$pfamid}++;
        # Then we get it to start on the right index
        my $copy = $member_domain_counter->{$pfamid};
        $member_domain->{$pfamid}{$member_id}{$copy}{start} = $start;
        $member_domain->{$pfamid}{$member_id}{$copy}{end} = $end;
        $member_domain->{$pfamid}{$member_id}{$copy}{id} = $member->stable_id;
        $count++;

      }
    }
    unless (defined($member_domain)) {
      $root->adaptor->delete_tag($root->node_id,'pfam_representative_member'); $root->store_tag('pfam_representative_member',$representative_member) unless ($self->{debug});
      $root->adaptor->delete_tag($root->node_id,'pfam_num_domains'); $root->store_tag('pfam_num_domains',0) unless ($self->{debug});
      $root->adaptor->delete_tag($root->node_id,'pfam_non_overlapping_domains'); $root->store_tag('pfam_non_overlapping_domains',0) unless ($self->{debug});
      $root->adaptor->delete_tag($root->node_id,'pfam_domain_coverage'); $root->store_tag('pfam_domain_coverage',0) unless ($self->{debug});
      $root->adaptor->delete_tag($root->node_id,'pfam_domain_string'); $root->store_tag('pfam_domain_string','na') unless ($self->{debug});
      $root->adaptor->delete_tag($root->node_id,'pfam_domain_vector_string'); $root->store_tag('pfam_domain_vector_string','na') unless ($self->{debug});
      next;
    }

    my $aln_domains_hash;

    my $aln = $root->get_SimpleAlign(-id_type => 'MEMBER');
    my $prev_aln_length = $root->get_tagvalue("aln_length");
    if ($prev_aln_length eq '') { my $aln_length = $aln->length; $root->store_tag('aln_length',$aln_length); }
    my $ranges;
    foreach my $pfamid (keys %$member_domain) {
      my $aln_domain_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
      $ranges->{$pfamid} = $aln_domain_range;
      foreach my $member_id (keys %{$member_domain->{$pfamid}}) {
        foreach my $copy (keys %{$member_domain->{$pfamid}{$member_id}}) {
          my $start = $member_domain->{$pfamid}{$member_id}{$copy}{start};
          my $end = $member_domain->{$pfamid}{$member_id}{$copy}{end};
          my $start_loc = $aln->column_from_residue_number($member_id, $start);
          my $end_loc   = $aln->column_from_residue_number($member_id, $end);
          $domain_boundaries->{$pfamid}{aln_start}{$start_loc}++;
          $domain_boundaries->{$pfamid}{aln_end}{$end_loc}++;
          $domain_boundaries->{$pfamid}{aln_start_id}{$start_loc}{$member_domain->{$pfamid}{$member_id}{$copy}{id}} = 1;
          $domain_boundaries->{$pfamid}{aln_end_id}{$start_loc}{$member_domain->{$pfamid}{$member_id}{$copy}{id}} = 1;
          $member_domain->{$pfamid}{$member_id}{$copy}{aln_start}{$start_loc}++;
          $member_domain->{$pfamid}{$member_id}{$copy}{aln_end}{$end_loc}++;
          my $coord_pair = $start_loc . "_" . $end_loc;
          $aln_domains_hash->{$coord_pair} = 1;
          $aln_domain_range->check_and_register( $pfamid, $start_loc, $end_loc, undef, undef, 1);
        }
      }
    }
    my $num_elements = scalar keys %$aln_domains_hash;
    print STDERR "num_elements $num_elements\n";

    my $ranged_coverage;
    my $global_domain_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
    foreach my $pfamid (keys %$ranges) {

      my $aln_domain_range = $ranges->{$pfamid};
      foreach my $range (@{$aln_domain_range->get_ranges($pfamid)}) {
        my ($start_range_loc,$end_range_loc) = @$range;
        my $range_id = $start_range_loc . "_" . $end_range_loc;
        my ($range_starts,$range_ends);

        # Calculating start
        foreach my $start (keys %{$domain_boundaries->{$pfamid}{aln_start}}) {
          next unless ($start >= $start_range_loc && $start <= $end_range_loc);
          $range_starts->{$start} = $domain_boundaries->{$pfamid}{aln_start}{$start};
        }
        my $max_num_start = 0; my $consensus_start;
        foreach my $start (sort {$a<=>$b} keys %{$range_starts}) {
          my $num = $range_starts->{$start};
          if ($max_num_start < $num) { $max_num_start = $num; $consensus_start = $start; }
          if (($max_num_start == $num) && ($consensus_start < $start)) { $max_num_start = $num; $consensus_start = $start; }
        }
        # Calculating end
        foreach my $end (keys %{$domain_boundaries->{$pfamid}{aln_end}}) {
          next unless ($end >= $start_range_loc && $end <= $end_range_loc);
          $range_ends->{$end} = $domain_boundaries->{$pfamid}{aln_end}{$end};
        }
        my $max_num_end = 0; my $consensus_end;
        foreach my $end (sort {$a<=>$b} keys %{$range_ends}) {
          my $num = $range_ends->{$end};
          if (($max_num_end < $num)  && ($end > $consensus_start)) { $max_num_end = $num; $consensus_end = $end; }
          if (($max_num_end == $num) && ($consensus_end > $end) && ($end > $consensus_start)) { $max_num_end = $num; $consensus_end = $end; }
        }

        $ranged_coverage->{$pfamid}{$range_id}{consensus_start} = $consensus_start;
        $ranged_coverage->{$pfamid}{$range_id}{consensus_end} = $consensus_end;
        if ($consensus_end < $consensus_start) {
          $DB::single=1;1;
        }
        $global_domain_range->check_and_register( 'global', $consensus_start, $consensus_end, undef, undef, 1);
        $ranged_coverage->{$pfamid}{$range_id}{consensus_length} = $consensus_end - $consensus_start;
      }
    }

    my $pfam_num_domains = 0;
    my $root_id = $root->node_id;
    my $pfam_domain_string = join(":",sort keys %$ranged_coverage);
    my $pfam_domain_coverage;
    my $pfam_non_overlapping_domains = 0; my $in = 0; my $out = 1;
    my @domain_vector;
    foreach my $range (@{$global_domain_range->get_ranges('global')}) {
      my ($start_range_loc,$end_range_loc) = @$range;
      my $length = $end_range_loc - $start_range_loc;
      $pfam_domain_coverage += $length;
    }
    foreach my $pfamid (sort keys %$ranged_coverage) {
      $pfam_num_domains++;
      foreach my $range_id (keys %{$ranged_coverage->{$pfamid}}) {
        push @domain_vector, $pfamid;
        $pfam_non_overlapping_domains++;
      }
    }
    my $pfam_domain_vector_string = join(":",@domain_vector);
    $root->adaptor->delete_tag($root->node_id,'pfam_representative_member'); $root->store_tag('pfam_representative_member',$representative_member);
    print 'pfam_representative_member ',$representative_member, "\n" if ($self->{debug});
    $root->adaptor->delete_tag($root->node_id,'pfam_num_domains'); $root->store_tag('pfam_num_domains',$pfam_num_domains);
    print 'pfam_num_domains ',$pfam_num_domains, "\n" if ($self->{debug});
    $root->adaptor->delete_tag($root->node_id,'pfam_non_overlapping_domains'); $root->store_tag('pfam_non_overlapping_domains',$pfam_non_overlapping_domains);
    print 'pfam_non_overlapping_domains ',$pfam_non_overlapping_domains, "\n" if ($self->{debug});
    $root->adaptor->delete_tag($root->node_id,'pfam_domain_coverage'); $root->store_tag('pfam_domain_coverage',$pfam_domain_coverage);
    print 'pfam_domain_coverage ',$pfam_domain_coverage, "\n" if ($self->{debug});
    $root->adaptor->delete_tag($root->node_id,'pfam_domain_string'); $root->store_tag('pfam_domain_string',$pfam_domain_string);
    print 'pfam_domain_string ',$pfam_domain_string, "\n" if ($self->{debug});
    $root->adaptor->delete_tag($root->node_id,'pfam_domain_vector_string'); $root->store_tag('pfam_domain_vector_string',$pfam_domain_vector_string);
    print 'pfam_domain_vector_string ',$pfam_domain_vector_string, "\n" if ($self->{debug});
    print "\n";
    $root->release_tree;
  }
}

# sub _query_sitewise_domains {
#   my $self = shift;
#   my $species_set = shift;

#   # $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
#   #  $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;

#   my $file = $self->{_query_sitewise_domains};
#   open LIST, "$file" or die "couldnt open query_sitewise_domains file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     next if ($_ eq '');
#     $self->{_ids}{$_} = 1;
#   }

#   foreach my $root_id (keys %{$self->{_ids}}) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     next unless (defined($root));
#     next if ('1' eq $root->get_tagvalue('cluster_had_to_be_broken_down'));
#     # my $aln = $root->get_SimpleAlign;
#     # my @leaves = @{$root->get_all_leaves};
#     my @leaves = @{$root->get_all_leaves_indexed};

#     my $member_domain;
#     while (my $member = shift @leaves) {
#       my $member_string;
#       my $member_id = $member->dbID;
#       my @domains = @{$member->translation->get_all_DomainFeatures};
#       foreach my $pos (1 .. length($member->sequence)) {
#         $member_string->{$pos} = 0;
#       }
#       while (my $domain = shift @domains) {
#         my $type = $domain->analysis->logic_name;
#         my $start = $domain->start;
#         my $end = $domain->end;
#         foreach my $pos ($start .. $end) {
#           $member_domain->{$member_id}{$pos}{$type} = 1;
#           # $member_string->{$pos}++;
#         }
#       }
#       #       foreach my $pos (sort {$b <=> $a} keys %{$member_string}) {
#       #         my $val = $member_string->{$pos};
#       #         $val = "X" if ($val > 9);
#       #         #         foreach my $sitewise_value (@sitewise_dnds_values) {
#       #         #           $sitewise_value->member_position($member,$aln);
#       #         #         }
#       #       }
#     }
#     foreach my $member_id (keys %$member_domain) {
#       foreach my $pos (keys %{$member_domain->{$member_id}}) {
#         my $cat_domain;
#         foreach my $domain (sort keys %{$member_domain->{$member_id}{$pos}}) {
#           my $code;
#           $code = "N" if ($domain =~ /Ncoils/i);
#           $code = "I" if ($domain =~ /PIRSF/i);
#           $code = "P" if ($domain =~ /Pfam/i);
#           $code = "R" if ($domain =~ /Prints/i);
#           $code = "E" if ($domain =~ /Seg/i);
#           $code = "S" if ($domain =~ /Signalp/i);
#           $code = "M" if ($domain =~ /Smart/i);
#           $code = "F" if ($domain =~ /Superfamily/i);
#           $code = "T" if ($domain =~ /Tigrfam/i);
#           $code = "H" if ($domain =~ /Tmhmm/i);
#           $code = "C" if ($domain =~ /pfscan/i);
#           $code = "O" if ($domain =~ /scanprosite/i);
#           $cat_domain .= $code;
#         }
#         my $sth = $self->{comparaDBA}->dbc->prepare
#           ("UPDATE sitewise_member set domain=\"$cat_domain\" 
#             WHERE member_id=$member_id and member_position=$pos");
#         $sth->execute();
#       }
#     }
#     #     my @sitewise_dnds_values = @{$root->get_SitewiseOmega_values};
#     #     my $conservation_string;
#     #     foreach my $site (@sitewise_dnds_values) {
#     #       my $type = $site->type;
#     #       $type =~ s/^(\w).+/$1/; $type = uc($type);
#     #       my $member_position = $site->member_position($leaves[0],$aln) || 'na';
#     #       print "$member_position\t", $site->aln_position, "\n";
#     #     }
#   }
# }


# sub _slr_das {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $sql = "select distinct sm.member_id from sitewise_member sm, sitewise_aln sa where sa.sitewise_id=sm.sitewise_id and sa.type like \"positive%\"";
#   my $sth = $self->{comparaDBA}->dbc->prepare("$sql");
#   $sth->execute();
#   my $member_id;
#   while ($member_id = $sth->fetchrow_array()) {
#     my $sql2 = "select member_position from sitewise_member sm where sm.member_id=\"$member_id\"";
#     my $sth2 = $self->{comparaDBA}->dbc->prepare("$sql2");
#     $sth2->execute();
#     my $member = $self->{ma}->fetch_by_dbID($member_id);
#     my $chr_name = $member->chr_name;
#     my $chr_strand = $member->chr_strand;
#     $chr_strand = "-" if (-1 == $chr_strand);
#     my $stable_id = $member->stable_id;
#     my $member_position;
#     my $tm = $member->transcript->get_TranscriptMapper;
#     while ($member_position = $sth2->fetchrow_array()) {
#       #Gene	ABCD1	exon	curated	X	152511170	152512468	+	.	1.0e-12	1	1299
#       my ($coords,$gaps) = $tm->pep2genomic($member_position,$member_position);
#       my $start = $coords->start;
#       my $end = $coords->end;
#       print "positive\t$stable_id\tblah\t$member_position\t$chr_name\t$start\t$end\t$chr_strand\t.\t.\n";
#     }
#   }
# }

# sub _slr_query {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;

#   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;

#   my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
#   my $taxon_tree=undef;
#   foreach my $gdb (@$gdb_list) {
#     next if ($gdb->name =~ /Ancestral/);
#     next if ($gdb->name =~ /ilurana/);
#     my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($gdb->taxon_id);
#     $taxon->no_autoload_children;
#     $taxon_tree = $taxon->root unless($taxon_tree);
#     $taxon_tree->merge_node_via_shared_ancestor($taxon);
#   }
#   $taxon_tree = $taxon_tree->minimize_tree;

#   my $root_id = $self->{_slr_query};
#   my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#   my $node_count = ($root->right_index - $root->left_index + 1) / 2;
#   exit unless ($node_count >= 4);

#   # print "root_id,subnode_id,subnode_taxon_id,subnode_taxon_name,represented_species,subtaxon_species,species_sampling\n";
#   foreach my $subnode ($root->get_all_subnodes) {
#     next if $subnode->is_leaf;
#     my $subnode_num_leaves = $subnode->num_leaves;
#     next if ($subnode_num_leaves < 4);
#     my $subnode_taxon_id   = $subnode->get_tagvalue("taxon_id");
#     my $subnode_taxon_name = $subnode->get_tagvalue("taxon_name");
#     my $subtaxon_species = scalar @{ $taxon_tree->find_node_by_node_id($subnode_taxon_id)->get_all_leaves};
#     next unless ($subtaxon_species > 1);
#     my %species;
#     my @species_array = map {$_->taxon->name} @{$subnode->get_all_leaves};
#     @species{@species_array} = (1) x @species_array;
#     my $represented_species = scalar keys %species;
#     my $species_sampling = $represented_species / $subtaxon_species;
#     $species_sampling = sprintf("%.4f",$species_sampling);
#     my $subnode_id = $subnode->node_id;
#     $subnode->store_tag('species_sampling',$species_sampling);
#     $subnode->store_tag('species_num',$represented_species);
#     # print "$root_id,$subnode_id,$subnode_taxon_id,$subnode_taxon_name,$represented_species,$subtaxon_species,$species_sampling\n";
#   }

# #   my $sw = $self->{soa}->fetch_all_by_ProteinTreeId($root->node_id);
# #   foreach my $sw_position (@$sw) {
# #     $DB::single=1;1;
# #   }
# }

# sub _sampling_orang {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;

#   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;

#   my $subroot_id = $self->{_sampling_orang};
#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($subroot_id);
#   my $present = 0;
#   while ($tree->parent->node_id != 1) {
#     $tree = $tree->parent;
#     my $taxon_name = $tree->get_tagvalue("taxon_name");
#     if ($taxon_name eq 'Primates') {
#       foreach my $leaf (@{$tree->get_all_leaves}) {
#         if ($leaf->taxon->name =~ /Pongo/) {
#           $present = 1;
#           last;
#         }
#       }
#       if (0==$present) {
#         my $new_tree = $self->{treeDBA}->fetch_node_by_node_id($tree->node_id);
#         my $species_sampling = $new_tree->get_tagvalue("species_sampling");
#         my %species;
#         my @species_array = map {$_->taxon->name} @{$new_tree->get_all_leaves};
#         @species{@species_array} = (1) x @species_array;
#         my $represented_species = scalar keys %species;
#         exit unless (6==$represented_species);
#         print "Present 6 species\n", $new_tree->print_tree(10), "\n";
#         $DB::single=1;1;#
#       }
#     }
#   }
#   $DB::single=1;1;#
# }

# sub _singl_tb {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
# #   $self->{soa} = $self->{'comparaDBA'}->get_SitewiseOmegaAdaptor;
# #   $self->{taxonDBA} = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;


#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -verbose => "0" );

#   my $singleton_member_id = $self->{_singl_tb};
#   open OUT, ">/lustre/scratch1/ensembl/avilella/genetree_biology/singleton_treebest/$singleton_member_id" or die "$!";
#   my $gene_member = $self->{memberDBA}->fetch_by_dbID($singleton_member_id);
#   my $member = $gene_member->get_canonical_peptide_Member;
#   my $pafs = $self->{ppafa}->fetch_all_by_qmember_id($member->dbID);
#   my $connecting_trees;
#   foreach my $paf (@$pafs) {
#     my $tree = $self->{treeDBA}->fetch_by_Member_root_id($paf->hit_member);
#     if (defined $tree) {
#       $connecting_trees->{$tree->node_id}{$paf->score} = 1;
#       $tree->release_tree;
#     }
#   }
#   # More than one tree, get the best hit
#   my $chosen_tree; my $highest_score = -1;
#   if (1 < scalar keys %$connecting_trees) {
#     foreach my $tree_id (keys %$connecting_trees) {
#       my @scores = sort {$b <=> $a} keys %{$connecting_trees->{$tree_id}};
#       if ($scores[0] > $highest_score) {
#         $highest_score = $scores[0];
#         $chosen_tree = $tree_id;
#       }
#     }
#   } else {
#     my @trees = keys %$connecting_trees;
#     $chosen_tree = $trees[0];
#   }

#   my $taxon_name = $member->taxon->name;
#   $taxon_name =~ s/\ /\_/g;
#   $taxon_name =~ s/\//\_/g;

#   unless (defined $chosen_tree) {
#     print OUT "member_stable_id,taxon_name,tree_id,is_outgroup,bsr,type\n";
#     print OUT $member->stable_id,",", $taxon_name, ",", "undef", ",", "undef", ",", "undef", ",", "undef", "\n";
#     close OUT;
#     exit;
#   }
#   # Have the tree_id with the highest score
#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($chosen_tree);

#   # Run MUSCLE profile
#   my $aln = $tree->get_SimpleAlign
#     (-id_type => 'MEMBER',
#      -append_taxon_id => 1
#     );
#   $aln->set_displayname_flat(1);
#   my $io = new Bio::Root::IO();
#   my $tempdir = $io->tempdir;
#   my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => $tempdir); #internal purposes
#   my $aln_out = Bio::AlignIO->new
#     (-file => ">$tempfile",
#      -format => 'fasta');
#   $aln_out->write_aln($aln);
#   $aln_out->close;
#   my ($seqfilefh,$seqfile) = $io->tempfile(-dir => $tempdir); #internal purposes
#   my $seq_out = Bio::SeqIO->new
#     (-file => ">$seqfile",
#      -format => 'fasta');
#   my $display_id = $member->member_id . "_" . $member->taxon_id;
#   my $seq = Bio::LocatableSeq->new
#     (-seq => $member->sequence,
#     -display_id => $display_id);
#   $seq_out->write_seq($seq);
#   $seq_out->close;
#   my ($outfh, $outfile) = $io->tempfile(-dir => $tempdir);
#   my $cmd = "/nfs/acari/avilella/src/muscle3.52_src/muscle -profile -in1 $tempfile -in2 $seqfile 1> $outfile 2>/dev/null";
#   print STDERR "Muscle...\n";
#   my $ret = system($cmd);
#   my $aln_aa_io = Bio::AlignIO->new
#     (-file => "$outfile",
#      -format => 'fasta');
#   my $aa_aln = $aln_aa_io->next_aln;
#   $aln_aa_io->close;
#   # Run TreeBeST
#   # aa_to_dna_aln
#   my %seqs;
#   foreach my $aln_member (@{$tree->get_all_leaves}) {
#     my $id = $aln_member->member_id . "_" . $aln_member->taxon_id;
#     my $sequence = $aln_member->transcript->translateable_seq;
#     my $seq = Bio::LocatableSeq->new
#       (-seq => $sequence,
#        -display_id => $id);
#     $seqs{$id} = $seq;
#   }
#   # adding query seq
#   my $query_seq = Bio::LocatableSeq->new
#     (-seq => $member->transcript->translateable_seq,
#     -display_id => $display_id);
#   $seqs{$display_id} = $query_seq;

#   use Bio::Align::Utilities qw(aa_to_dna_aln);
#   my $dna_aln = aa_to_dna_aln($aa_aln,\%seqs);
#   $dna_aln->set_displayname_flat(1);

#   my ($tffh, $tffile) = $io->tempfile(-dir => $tempdir);
#   my $alnout = Bio::AlignIO->new
#         (-file => ">$tffile",
#          -format => 'fasta');
#   $alnout->write_aln($dna_aln);
#   $self->{'input_aln'} = $tffile;
#   $self->{'newick_file'} = $self->{'input_aln'} . "_njtree_phyml_tree.txt ";
#   my $njtree_phyml_executable = "/nfs/acari/avilella/src/_treesoft/treebest/treebest";
#   my $tfcmd = $njtree_phyml_executable;
#   $self->{'species_tree_file'} = "/lustre/work1/ensembl/avilella/hive/avilella_compara_homology_$mydbversion/spec_tax.nh";
#   $self->{'bootstrap'} = 1;
#   if (1 == $self->{'bootstrap'}) {
#     $tfcmd .= " best ";
#     if (defined($self->{'species_tree_file'})) {
#       $tfcmd .= " -f ". $self->{'species_tree_file'};
#     }
#     $tfcmd .= " ". $self->{'input_aln'};
#     $tfcmd .= " -p tree ";
#     $tfcmd .= " -o " . $self->{'newick_file'};
#     $tfcmd .= " 2>/dev/null 1>/dev/null";

#     my $worker_temp_directory = $tempdir;
#     print STDERR "Treebest...\n";
#     unless(system("cd $worker_temp_directory; $tfcmd") == 0) {
#       print("$tfcmd\n");
#       die "error running njtree phyml, $!\n";
#     }
#   }
#   my $newick_file =  $self->{'newick_file'};
#   #parse newick into a new tree object structure
#   my $newick = '';
#   open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
#   while (<FH>) {
#     $newick .= $_;
#   }
#   close(FH);
#   my $newtree = 
#     Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
#   my $node = $newtree->find_node_by_name($display_id);
#   my $is_outgroup = 0; my $bsr = 'undef'; my $type = 'other';
#   if ($node->parent->node_id eq $newtree->node_id) {
#     $is_outgroup = 1;
#   } else {
#     my @leaves = @{$node->parent->children};
#     my $sister;
#     if ($leaves[0]->is_leaf && $leaves[1]->is_leaf) {
#       $sister = $leaves[1]->name if ($leaves[0]->name eq $display_id);
#       $sister = $leaves[0]->name unless ($leaves[0]->name eq $display_id);
#       $sister =~ /(\d+)\_(\d+)/;
#       my $sister_member_id = $1;
#       if ($2 eq $member->taxon_id) {$type = 'within';}
#       my $sister_pafs = $self->{ppafa}->fetch_all_by_qmember_id_hmember_id($member->dbID,$sister_member_id);
#       my $sister_paf = shift(@$sister_pafs);
#       my $self_hit = $self->{ppafa}->fetch_selfhit_by_qmember_id($member->dbID);
#       my $self_sister = $self->{ppafa}->fetch_selfhit_by_qmember_id($sister_member_id);
#       my $ref_score = $self_hit->score;
#       my $ref2_score = $self_sister->score;
#       if (!defined($ref_score) or 
#           (defined($ref2_score) and ($ref2_score > $ref_score))) {
#         $ref_score = $ref2_score;
#       }
#       $bsr = sprintf("%.3f",$sister_paf->score / $ref_score);
#     }
#   }
#   my $tree_id = $tree->node_id;
#   print OUT "member_stable_id,taxon_name,tree_id,is_outgroup,bsr,type\n";
#   print OUT $member->stable_id, ",", $taxon_name, ",", $tree_id, ",", $is_outgroup, ",", $bsr, ",", $type, "\n";
#   unlink <$tempdir/*>;
#   rmdir $tempdir;
#   close OUT;
# }

# sub _cox {
#   my $self = shift;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $genome_db =  $self->{gdba}->fetch_by_name_assembly("Homo sapiens");
#   $self->{coreDBA} = $genome_db->db_adaptor;

#   my @slices = @{$self->{'coreDBA'}->get_SliceAdaptor->fetch_all('toplevel')};

#   $DB::single=1;1;#
# }

# sub _slr_subtrees {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $root_id = $self->{_slr_subtrees};
#   my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#   my $node_count = ($root->right_index - $root->left_index + 1) / 2;
#   next unless ($node_count > 5);

#   print STDERR "[root $root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   my $aln = $root->get_SimpleAlign();
#   #     print "========================================\n";
#   #     foreach my $seq ($aln->each_seq) {
#   #       printf ("%30s ", $seq->display_id);
#   #       foreach my $pos (1 .. $aln->length) {
#   #         my $loc = $seq->location_from_column($pos);
#   #         my $type;
#   #         my $seq_pos = '-';
#   #         if (!defined($loc)) {
#   #           $type = "UNK";
#   #         } else {
#   #           $type = $loc->location_type;
#   #           $type =~ s/IN-BETWEEN/BTW/;
#   #           $type =~ s/EXACT/XCT/;
#   #           if ($type eq 'XCT') {
#   #             $seq_pos = $loc->start;
#   #           }
#   #         }
#   #         printf ("%3s%3s%3s ", $seq_pos, $type, $pos);
#   #       }
#   #       print "\n";
#   #     }
#   #     print "========================================\n";
#   my $cds_aln = $root->get_SimpleAlign(-cdna => 1);
#   my $newick_tree = $root->newick_format("int_node_id");
#   my $node_id = $root_id;
#   next if (defined($self->{_slr_done}{$node_id}));
#   print STDERR "[aln $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   open TREE, ">$node_id.nh" or die "couldnt open $node_id.nh: $!\n"; print TREE "$newick_tree\n"; close TREE;
#   my $treeio = Bio::TreeIO->new(-format => 'newick',-file => "$node_id.nh");
#   my $tree = $treeio->next_tree;
#   unlink "$node_id.nh";
#   my @display_ids = map {$_->display_id } $cds_aln->each_seq;
#   my $cds_aln_length = (($cds_aln->length)/3);
#   eval { require Bio::Tools::Run::Phylo::SLR; };
#   die "slr wrapper not found: $!\n" if ($@);
#   # '-executable' => '/nfs/acari/avilella/src/slr/bin/Slr_64',
#   my $slr = Bio::Tools::Run::Phylo::SLR->new
#     (
#      '-executable' => '/software/ensembl/compara/bin/Slr_ensembl',
#      '-program_dir' => '/nfs/acari/avilella/src/slr/bin');

#   $slr->alignment($cds_aln);
#   $slr->tree($tree);
#   $slr->no_param_checks(1);
#   $slr->set_parameter("saturated","1.5");
#   my $repr_member_id = $aln->get_seq_by_pos(1);
#   my $repr_member = $self->{ma}->fetch_by_source_stable_id("ENSEMBLPEP",$repr_member_id->display_id);
#   my $chr_name = $repr_member->chr_name;
#   $slr->set_parameter("gencode","mammalian") if ($chr_name =~ /mt/i);
#   $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
#   my ($rc,$results) = $slr->run();
#   $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
#   if (defined($results->{saturated})) {
#     next unless (defined($results->{trees}));
#     foreach my $subtree_num (keys %{$results->{trees}}) {
#       my $subtree = $results->{trees}{$subtree_num};
#       my @nodes;
#       foreach my $node ($subtree->get_nodes) {
#         if ($node->is_Leaf) {
#           push @nodes, $node->id;
#         }
#       }
#       my $members;
#       foreach my $node (@nodes) {
#         $node =~ s/\s+//;
#         # my $member = $self->{ma}->fetch_by_source_stable_id("ENSEMBLPEP",$node);
#         $members->{$node} = 1;
#       }
#       my $partial_tree = $self->{treeDBA}->fetch_node_by_node_id($root->node_id);
#       print STDERR "[subtree $subtree_num] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#       foreach my $leaf (@{$partial_tree->get_all_leaves}) {
#         next if (defined($members->{$leaf->stable_id}));
#         $leaf->disavow_parent;
#         $partial_tree = $partial_tree->minimize_tree;
#       }
#       my $subroot = $partial_tree->node_id;
#       $partial_tree->release_tree;
#       next if ($partial_tree->num_leaves >= $root->num_leaves);
#       print STDERR "[slr subtree $subtree_num] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     }
#     $root->release_tree;
#     next;
#   }
#   print STDERR "[slr $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   unless (defined($results)) {
#     print "$node_id,na,na,na\n";
#     next;
#   }

#   foreach my $type (keys %{$results->{sites}}) {
#     foreach my $position (@{$results->{sites}{$type}}) {
#       # Site  Neutral  Optimal   Omega    lower    upper LRT_Stat    Pval     Adj.Pval    Q-value Result Note
#       # 1     4.77     3.44   0.0000   0.0000   1.4655   2.6626 1.0273e-01 8.6803e-01 1.7835e-02        Constant;
#       # 0     1        2      3        4        5        6      7          8          9
#       my ($site, $neutral, $optimal, $omega, $lower, $upper, $lrt_stat, $pval, $adj_pval, $q_value) = @$position;
#       my $sth = $self->{comparaDBA}->dbc->prepare
#         ("INSERT INTO sitewise_aln_cons 
#                                  (aln_position,
#                                   node_id,
#                                   omega,
#                                   omega_lower,
#                                   omega_upper,
#                                   type) VALUES (?,?,?,?,?,?)");
#       $sth->execute($site,
#                     $root_id,
#                     $omega,
#                     $lower,
#                     $upper,
#                     $type);
#     }
#   }

#   $root->release_tree;
# }


# sub _slr_subtrees_old {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $file = $self->{_slr_subtrees};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     $self->{_slr_ids}{$_} = 1;
#   }

#   my @tree_ids = keys %{$self->{_slr_ids}};

#   print "node_id,num_codons,node_count,omega,kappa,lnL,type,proportion,gene_ids\n";
#   while (my $root_id = shift @tree_ids) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     my $node_count = ($root->right_index - $root->left_index + 1) / 2;
#     next unless ($node_count > 5);

#     print STDERR "[root $root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#     my $aln = $root->get_SimpleAlign();
#     #     print "========================================\n";
#     #     foreach my $seq ($aln->each_seq) {
#     #       printf ("%30s ", $seq->display_id);
#     #       foreach my $pos (1 .. $aln->length) {
#     #         my $loc = $seq->location_from_column($pos);
#     #         my $type;
#     #         my $seq_pos = '-';
#     #         if (!defined($loc)) {
#     #           $type = "UNK";
#     #         } else {
#     #           $type = $loc->location_type;
#     #           $type =~ s/IN-BETWEEN/BTW/;
#     #           $type =~ s/EXACT/XCT/;
#     #           if ($type eq 'XCT') {
#     #             $seq_pos = $loc->start;
#     #           }
#     #         }
#     #         printf ("%3s%3s%3s ", $seq_pos, $type, $pos);
#     #       }
#     #       print "\n";
#     #     }
#     #     print "========================================\n";
#     my $cds_aln = $root->get_SimpleAlign(-cdna => 1);
#     my $newick_tree = $root->newick_format("int_node_id");
#     my $node_id = $root_id;
#     next if (defined($self->{_slr_done}{$node_id}));
#     print STDERR "[aln $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     open TREE, ">$node_id.nh" or die "couldnt open $node_id.nh: $!\n"; print TREE "$newick_tree\n"; close TREE;
#     my $treeio = Bio::TreeIO->new(-format => 'newick',-file => "$node_id.nh");
#     my $tree = $treeio->next_tree;
#     unlink "$node_id.nh";
#     my @display_ids = map {$_->display_id } $cds_aln->each_seq;
#     my $cds_aln_length = (($cds_aln->length)/3);
#     eval { require Bio::Tools::Run::Phylo::SLR; };
#     die "slr wrapper not found: $!\n" if ($@);
#     # '-executable' => '/nfs/acari/avilella/src/slr/bin/Slr_64',
#     my $slr = Bio::Tools::Run::Phylo::SLR->new
#       (
#        '-executable' => '/software/ensembl/compara/bin/Slr_ensembl',
#        '-program_dir' => '/nfs/acari/avilella/src/slr/bin');

#     $slr->alignment($cds_aln);
#     $slr->tree($tree);
#     $slr->set_parameter("saturated",1);
#     my $repr_member_id = $aln->get_seq_by_pos(1);
#     my $repr_member = $self->{ma}->fetch_by_source_stable_id("ENSEMBLPEP",$repr_member_id->display_id);
#     my $chr_name = $repr_member->chr_name;
#     $slr->set_parameter("gencode","mammalian") if ($chr_name =~ /mt/i);
#     my ($rc,$results) = $slr->run();
#     if (defined($results->{saturated})) {
#       next unless (defined($results->{trees}));
#       foreach my $subtree_num (keys %{$results->{trees}}) {
#         my $subtree = $results->{trees}{$subtree_num};
#         my @nodes;
#         foreach my $node ($subtree->get_nodes) {
#           if ($node->is_Leaf) {
#             push @nodes, $node->id;
#           }
#         }
#         my $members;
#         foreach my $node (@nodes) {
#           $node =~ s/\s+//;
#           # my $member = $self->{ma}->fetch_by_source_stable_id("ENSEMBLPEP",$node);
#           $members->{$node} = 1;
#         }
#         my $partial_tree = $self->{treeDBA}->fetch_node_by_node_id($root->node_id);
#         print STDERR "[subtree $subtree_num] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#         foreach my $leaf (@{$partial_tree->get_all_leaves}) {
#           next if (defined($members->{$leaf->stable_id}));
#           $leaf->disavow_parent;
#           $partial_tree = $partial_tree->minimize_tree;
#         }
#         my $subroot = $partial_tree->node_id;
#         $partial_tree->release_tree;
#         next if ($partial_tree->num_leaves >= $root->num_leaves);
#         push @tree_ids, $subroot;
#         my $tnum = scalar @tree_ids;
#         print STDERR "[slr subtree $subtree_num] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#         print STDERR "[num subtree $tnum] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#       }
#       $root->release_tree;
#       next;
#     }
#     print STDERR "[slr $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     unless (defined($results)) {
#       print "$node_id,na,na,na\n";
#       next;
#     }

#     #     foreach my $type (keys %{$results->{sites}}) {
#     #       foreach my $position (@{$results->{sites}{$type}}) {
#     #         # Site  Neutral  Optimal   Omega    lower    upper LRT_Stat    Pval     Adj.Pval    Q-value Result Note
#     #         # 1     4.77     3.44   0.0000   0.0000   1.4655   2.6626 1.0273e-01 8.6803e-01 1.7835e-02        Constant;
#     #         # 0     1        2      3        4        5        6      7          8          9
#     #         my ($site, $neutral, $optimal, $omega, $lower, $upper, $lrt_stat, $pval, $adj_pval, $q_value) = @$position;
#     #         my $sth = $self->{comparaDBA}->dbc->prepare
#     #           ("INSERT INTO sitewise_aln 
#     #                              (aln_position,
#     #                               node_id,
#     #                               omega,
#     #                               omega_lower,
#     #                               omega_upper,
#     #                               type) VALUES (?,?,?,?,?,?)");
#     #         $sth->execute($site,
#     #                       $root_id,
#     #                       $omega,
#     #                       $lower,
#     #                       $upper,
#     #                       $type);
#     #         my $stored_id = $sth->{'mysql_insertid'};
#     #         if ($type =~ /positive/) {
#     #           foreach my $seq ($aln->each_seq) {
#     #             next unless ($seq->display_id =~ /ENSP0/);
#     #             my $seq_location;
#     #             eval { $seq_location = $seq->location_from_column($site);};
#     #             if ($@) {
#     #               # gaps before the first nucleotide, skip
#     #               next;
#     #             }
#     #             my $location_type;
#     #             eval { $location_type = $seq_location->location_type;};
#     #             if ($@) {
#     #               # gaps before the first nucleotide, skip
#     #               next;
#     #             }
#     #             if ($seq_location->location_type eq 'EXACT') {
#     #               my $member = $self->{ma}->fetch_by_source_stable_id("ENSEMBLPEP",$seq->display_id);
#     #               my $member_id = $member->dbID;
#     #               my $member_position = $seq_location->start;
#     #               my $aa = $seq->subseq($seq_location->start,$seq_location->end);
#     #               my $sth = $self->{comparaDBA}->dbc->prepare
#     #                 ("INSERT INTO sitewise_member 
#     #                              (sitewise_id,
#     #                               member_id,
#     #                               member_position) VALUES (?,?,?)");
#     #               $sth->execute($stored_id,
#     #                             $member_id,
#     #                             $member_position);
#     #             }
#     #           }
#     #         }
#     #       }
#     #     }

#     $root->release_tree;
#   }
# }


# sub _codeml_mutsel {
#   my $self = shift;

#   $self->{starttime} = time();
#   $self->{comparaDBA}->dbc->disconnect_when_inactive(1);

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $file = $self->{_codeml_mutsel};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     $self->{_mutsel_ids}{$_} = 1;
#   }

#   my @tree_ids = keys %{$self->{_mutsel_ids}};

#   while (my $root_id = shift @tree_ids) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     my $node_count = ($root->right_index - $root->left_index + 1) / 2;
#     next unless ($node_count > 5);

#     print STDERR "[root $root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#     my $aln = $root->get_SimpleAlign();
#     my $cds_aln = $root->get_SimpleAlign(-cdna => 1);
#     my $newick = $root->newick_format("int_node_id");
#     my $node_id = $root_id;
#     print STDERR "[aln $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     open(my $fake_fh, "+<", \$newick);
#     my $treein = new Bio::TreeIO
#       (-fh => $fake_fh,
#        -format => 'newick');
#     my $tree = $treein->next_tree;
#     $treein->close;
#     my @display_ids = map {$_->display_id } $cds_aln->each_seq;
#     my $cds_aln_length = (($cds_aln->length)/3);
#     if (-e "/lustre/scratch1/ensembl/avilella/hive/avilella_compara_homology_49/hashed/do_paml") {
#       eval { require Bio::Tools::Run::Phylo::PAML::Codeml; };
#       die "codeml wrapper not found: $!\n" if ($@);
#       # '-executable' => '/nfs/acari/avilella/src/slr/bin/Slr_64',
#       my $codeml = Bio::Tools::Run::Phylo::PAML::Codeml->new
#         (
#          '-executable' => '/software/ensembl/compara/bin/paml4b/codeml',
#          '-program_dir' => '/software/ensembl/compara/bin/paml4b');
#       $codeml->alignment($cds_aln);
#       $codeml->tree($tree);
#       $codeml->no_param_checks(1);
#       $codeml->set_parameter("noisy","3");
#       $codeml->set_parameter("verbose","1");
#       $codeml->set_parameter("runmode","0");
#       $codeml->set_parameter("seqtype","1");
#       # codeml.c:194:char *codonfreqs[]={"Fequal", "F1x4", "F3x4", "Fcodon", "F1x4MG", "F3x4MG", "FMutSel0", "FMutSel"};
#       #                                        0       1       2         3         4         5           6          7
#       $codeml->set_parameter("CodonFreq","6");
#       $codeml->set_parameter("model","0");
#       $codeml->set_parameter("NSsites","0");
#       $codeml->set_parameter("ndata","1");
#       $codeml->set_parameter("clock","6");
#       $codeml->set_parameter("icode","1");
#       $codeml->set_parameter("fix_kappa","1");
#       $codeml->set_parameter("kappa","5.43711");
#       $codeml->set_parameter("fix_omega","1");
#       $codeml->set_parameter("omega","0.03162");
#       $codeml->set_parameter("fix_alpha","1");
#       $codeml->set_parameter("alpha","0.");
#       $codeml->set_parameter("ncatG","3");
#       $codeml->set_parameter("getSE","0");
#       $codeml->set_parameter("RateAncestor","0");
#       $codeml->set_parameter("Small_Diff",".5e-6");
#       $codeml->set_parameter("method","1");
#       $codeml->set_parameter("fix_blength","0");
#       my ($rc,$parser) = $codeml->run();
#       if ($rc == 0) {
#         $DB::single=1;1;
#       }
#       my $result;
#       eval{ $result = $parser->next_result };
#       unless( $result ){
#         if ( $@ ) { 
#           warn( "$@\n" );
#         }
#         warn( "Parser failed" );
#       }
#       my $MLmatrix = $result->get_MLmatrix();
#       #       $homology->n($MLmatrix->[0]->[1]->{'N'});
#       #       $homology->s($MLmatrix->[0]->[1]->{'S'});
#       #       $homology->dn($MLmatrix->[0]->[1]->{'dN'});
#       #       $homology->ds($MLmatrix->[0]->[1]->{'dS'});
#       #       $homology->lnl($MLmatrix->[0]->[1]->{'lnL'});
#     }

#     #     my $summary; my $total;
#     #     my $lnl = $results->{lnL};
#     #     my $kappa = $results->{kappa};
#     #     my $omega = $results->{omega};
#     #     foreach my $type (keys %{$results->{sites}}) {
#     #       my $num = scalar (@{$results->{sites}{$type}});
#     #       $summary->{$type} = $num;
#     #       $total += $num;
#     #     }

#     #     foreach my $type (keys %{$results->{sites}}) {
#     #       foreach my $position (@{$results->{sites}{$type}}) {
#     #         # Site  Neutral  Optimal   Omega    lower    upper LRT_Stat    Pval     Adj.Pval    Q-value Result Note
#     #         # 1     4.77     3.44   0.0000   0.0000   1.4655   2.6626 1.0273e-01 8.6803e-01 1.7835e-02        Constant;
#     #         # 0     1        2      3        4        5        6      7          8          9
#     #         my ($site, $neutral, $optimal, $omega, $lower, $upper, $lrt_stat, $pval, $adj_pval, $q_value) = @$position;
#     #         my $sth = $self->{comparaDBA}->dbc->prepare
#     #           ("INSERT INTO sitewise_aln 
#     #                              (aln_position,
#     #                               node_id,
#     #                               omega,
#     #                               omega_lower,
#     #                               omega_upper,
#     #                               type) VALUES (?,?,?,?,?,?)");
#     #         $sth->execute($site,
#     #                       $root_id,
#     #                       $omega,
#     #                       $lower,
#     #                       $upper,
#     #                       $type);
#     #         my $stored_id = $sth->{'mysql_insertid'};
#     #         if ($type =~ /positive/) {
#     #           foreach my $seq ($aln->each_seq) {
#     #             next unless ($seq->display_id =~ /ENSP0/);
#     #             my $seq_location;
#     #             eval { $seq_location = $seq->location_from_column($site);};
#     #             if ($@) {
#     #               # gaps before the first nucleotide, skip
#     #               next;
#     #             }
#     #             my $location_type;
#     #             eval { $location_type = $seq_location->location_type;};
#     #             if ($@) {
#     #               # gaps before the first nucleotide, skip
#     #               next;
#     #             }
#     #             if ($seq_location->location_type eq 'EXACT') {
#     #               my $member = $self->{ma}->fetch_by_source_stable_id("ENSEMBLPEP",$seq->display_id);
#     #               my $member_id = $member->dbID;
#     #               my $member_position = $seq_location->start;
#     #               my $aa = $seq->subseq($seq_location->start,$seq_location->end);
#     #               my $sth = $self->{comparaDBA}->dbc->prepare
#     #                 ("INSERT INTO sitewise_member 
#     #                              (sitewise_id,
#     #                               member_id,
#     #                               member_position) VALUES (?,?,?)");
#     #               $sth->execute($stored_id,
#     #                             $member_id,
#     #                             $member_position);
#     #             }
#     #           }
#     #         }
#     #       }
#     #     }

#     $root->release_tree;
#   }
# }

# sub _clm_dist_input {
#   my $self = shift;

#   my $value = $self->{_clm_dist_input};

#   my $sql = "select node_id from protein_tree_node where parent_id=root_id and root_id!=0";
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   my $count = 0;
#   while (my $node_id = $sth->fetchrow) {
#     my $sql2 = "select m1.stable_id from member m1, homology_member hm, homology h where h.homology_id=hm.homology_id and hm.member_id=m1.member_id and h.tree_node_id=$node_id";
#     my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#     $sth2->execute();
#     my $list;
#     while (my $stable_id = $sth2->fetchrow) {
#       $list->{$stable_id} = 1;
#     }
#     print join("\t", keys %$list, "\n");
#     $sth2->finish;
#     $count++;
#     print STDERR "[$count]\n" if (0 == ($count % $value));
#   }
#   $sth->finish;
# }

# sub _genetree_to_mcl {
#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{'clusterset'} = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#   my $cluster_count = 1;
#   my $member_count = 0;

#   $self->{_mydbname1} = $self->{comparaDBA}->dbc->dbname;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;

#   # Uniprot
# #   print STDERR "[loading uniprot SWISSPROT] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
# #   map {$self->{cluster_to_mcl}{$cluster_count}{$_->member_id} = 1; $member_count++} @{$self->{ma}->fetch_all_by_source('Uniprot/SWISSPROT')};
# #   print STDERR "[loading uniprot SPTREMBL] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
# #   $cluster_count++;
# #   map {$self->{cluster_to_mcl}{$cluster_count}{$_->member_id} = 1; $member_count++} @{$self->{ma}->fetch_all_by_source('Uniprot/SPTREMBL')};
# #   print STDERR "[loaded uniprot SPTREMBL] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
# #   $cluster_count++;

#   #Singletons
#   my $all_dbs = $self->{gdba}->fetch_all;

#   foreach my $gdb (@$all_dbs) {
#     my $gdb_name = $gdb->name;
#     next if $gdb_name =~ /ncestral/;
#     my @gene_members = @{$self->{ha}->fetch_all_orphans_by_GenomeDB($gdb)};
#     foreach my $gene_member (@gene_members) {
#       my $canonical = $gene_member->get_canonical_peptide_Member;
#       my $canonical_member_id = $canonical->member_id;
#       my $canonical_stable_id = $canonical->stable_id;
#       $self->{cluster_to_mcl1}{$cluster_count}{$canonical_stable_id} = $canonical_member_id;
#       $self->{cluster1}{$canonical_stable_id} = 1;
#       $cluster_count++;
#     }
#     print STDERR "[singletons $gdb_name] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     last if ($self->{debug});
#   }
#   my $singletons1_count = $cluster_count;

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $clusterset = $self->{treeDBA}->fetch_node_by_node_id($self->{'clusterset_id'});
#   my @clusters = @{$clusterset->children};

#   my $totalnum_clusters = scalar(@clusters);
#   print STDERR "[loaded clusters $totalnum_clusters] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $DB::single=1;1;
#   while (my $cluster = shift @clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     foreach my $leaf (@{$cluster->get_all_leaves}) {
#       # my $canonical = $leaf->gene_member->get_canonical_peptide_Member;
#       # my @all_transl = @{$leaf->gene_member->get_all_peptide_Members};
#       my $canonical_member_id = $leaf->member_id;
#       my $canonical_stable_id = $leaf->stable_id;
#       $self->{cluster_to_mcl1}{$cluster_count}{$canonical_stable_id} = $canonical_member_id;
#       $self->{cluster1}{$canonical_stable_id} = 1;
#     }
#     $member_count += scalar keys %{$self->{cluster_to_mcl1}{$cluster_count}};
#     if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0)) {
#       my $this_count = $cluster_count-$singletons1_count;
#       my $verbose_string = sprintf "[%5d / %5d clusters done] ", 
#         $this_count, $totalnum_clusters;
#       print STDERR $verbose_string;
#       print STDERR time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     }
#     $cluster_count++;
#     last if ($self->{debug} && $self->{debug} == $cluster_count);
#   }

#   ########################################
#   ########################################
#   ########################################
#   ########################################

#   $cluster_count = 1;
#   $member_count = 0;

#   $self->{'comparaDBA2'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{_url2} . ';type=compara');
#   $self->{'temp'}  = $self->{'comparaDBA'};
#   $self->{'comparaDBA'} = $self->{'comparaDBA2'};
#   $self->{'comparaDBA2'} = $self->{'temp'};

#   $self->{_mydbname2} = $self->{comparaDBA}->dbc->dbname;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;

#   #Singletons
#   my $all_dbs2 = $self->{gdba}->fetch_all;

#   foreach my $gdb (@$all_dbs) {
#     my $gdb_name = $gdb->name;
#     next if $gdb_name =~ /ncestral/;
#     my @gene_members = @{$self->{ha}->fetch_all_orphans_by_GenomeDB($gdb)};
#     foreach my $gene_member (@gene_members) {
#       my $canonical = $gene_member->get_canonical_peptide_Member;
#       # my @all_transl = @{$gene_member->get_all_peptide_Members};
#       my $canonical_stable_id = $canonical->stable_id;
#       my $member_id = $canonical->member_id;
#       $self->{cluster_to_mcl2}{$cluster_count}{$canonical_stable_id} = 1;
#       $self->{cluster2}{$canonical_stable_id} = $member_id;
#       $cluster_count++;
#     }
#     print STDERR "[singletons $gdb_name] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     last if ($self->{debug});
#   }
#   my $singletons2_count = $cluster_count;

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $clusterset2 = $self->{treeDBA}->fetch_node_by_node_id($self->{'clusterset_id'});

#   my @clusters2 = @{$clusterset2->children};

#   my $totalnum_clusters2 = scalar(@clusters2);
#   print STDERR "[loaded clusters $totalnum_clusters] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   while (my $cluster = shift @clusters2) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     foreach my $leaf (@{$cluster->get_all_leaves}) {
#       # my $canonical = $leaf->gene_member->get_canonical_peptide_Member;
#       # my @all_transl = @{$leaf->gene_member->get_all_peptide_Members};
#       my $canonical_stable_id = $leaf->stable_id;
#       my $member_id = $leaf->member_id;
#       # cluster 2 will only have the stable_ids
#       $self->{cluster_to_mcl2}{$cluster_count}{$canonical_stable_id} = 1;
#       $self->{cluster2}{$canonical_stable_id} = $member_id;
#     }
#     $member_count += scalar keys %{$self->{cluster_to_mcl2}{$cluster_count}};
#     if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0)) {
#       my $this_count = $cluster_count-$singletons2_count;
#       my $verbose_string = sprintf "[%5d / %5d clusters done] ", 
#         $this_count, $totalnum_clusters;
#       print STDERR $verbose_string;
#       print STDERR time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     }
#     $cluster_count++;
#     last if ($self->{debug} && $self->{debug} == $cluster_count);
#   }

#   print STDERR "[intersecting clusters] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   # Make the intersection and union
#   foreach my $cluster1 (keys %{$self->{cluster_to_mcl1}}) {
#     foreach my $stable_id1 (keys %{$self->{cluster_to_mcl1}{$cluster1}}) {
#       if (defined($self->{cluster2}{$stable_id1})) {
#         $self->{cluster_isect}{$stable_id1} = $self->{cluster_to_mcl1}{$cluster1}{$stable_id1};
#         # cluster2 will end up being cluster_complement1
#         delete $self->{cluster2}{$stable_id1};
#       } else {
#         $self->{cluster_complement1}{$stable_id1} = $self->{cluster_to_mcl1}{$cluster1}{$stable_id1};
#       }
#     }
#   }
#   print STDERR "[intersected clusters] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   # Now we have the intersection, cluster_complement1 and the equivalent complement2

#   my $outfile = "cluster_to_mcl"."." . 
#     $self->{_mydbname1} . "." . $self->{'clusterset_id'};
#   $outfile .= ".txt";
#   open OUT1, ">$outfile" or die "error opening outfile: $!\n";

# #   # complement1
# #   foreach my $stable_id (keys %{$self->{cluster_complement1}}) {
# #     my $member_id = $self->{cluster_complement1}{$stable_id};
# #     print OUT1 "$member_id ";
# #   }
# #   print OUT1 "\n";

#   # print 1
#   foreach my $cluster (keys %{$self->{cluster_to_mcl1}}) {
#     foreach my $stable_id (keys %{$self->{cluster_to_mcl1}{$cluster}}) {
#       my $member_id = $self->{cluster_to_mcl1}{$cluster}{$stable_id};
#       next unless (defined $self->{cluster_isect}{$stable_id});
#       print OUT1 "$member_id ";
#     }
#     print OUT1 "\n";
#   }
#   close OUT1;
#   print STDERR "[printed $outfile] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   ########################################

#   my $outfile2 = "cluster_to_mcl"."." . 
#     $self->{_mydbname2} . "." . $self->{'clusterset_id'};
#   $outfile2 .= ".txt";
#   open OUT2, ">$outfile2" or die "error opening outfile: $!\n";

# #   # complement2
# #   foreach my $stable_id (keys %{$self->{cluster2}}) {
# #     my $member_id = $self->{cluster2}{$stable_id};
# #     $member_id += 3000000000; # make sure we dont overlap with members in cluster1
# #     print OUT2 "$member_id ";
# #   }
# #   print OUT2 "\n";

#   # print 2
#   foreach my $cluster (keys %{$self->{cluster_to_mcl2}}) {
#     foreach my $stable_id (keys %{$self->{cluster_to_mcl2}{$cluster}}) {
#       my $member_id1 = $self->{cluster_isect}{$stable_id};
#       next unless (defined($member_id1));
#       print OUT2 "$member_id1 ";
#     }
#     print OUT2 "\n";
#   }
#   close OUT2;
#   print STDERR "[printed $outfile2] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   ########################################

#   my $outfile3 = "cluster_to_mcl"."." . 
#     $self->{_mydbname1} . "." . $self->{'clusterset_id'};
#   $outfile3 .= ".csv";
#   open OUT3, ">$outfile3" or die "error opening outfile: $!\n";
#   # print 1
#   foreach my $cluster (keys %{$self->{cluster_to_mcl1}}) {
#     foreach my $stable_id (keys %{$self->{cluster_to_mcl1}{$cluster}}) {
#       my $member_id = $self->{cluster_to_mcl1}{$cluster}{$stable_id};
#       print OUT3 "$member_id $stable_id\n";
#     }
#   }
#   close OUT3;
#   print STDERR "[printed $outfile3] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
# }

# sub _genetree_to_mcl_old {
#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   my $cluster_count = 1;
#   my $member_count = 0;

#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;

#   # Uniprot
#   print STDERR "[loading uniprot SWISSPROT] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   map {$self->{cluster_to_mcl}{$cluster_count}{$_->member_id} = 1; $member_count++} @{$self->{ma}->fetch_all_by_source('Uniprot/SWISSPROT')};
#   print STDERR "[loading uniprot SPTREMBL] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   $cluster_count++;
#   map {$self->{cluster_to_mcl}{$cluster_count}{$_->member_id} = 1; $member_count++} @{$self->{ma}->fetch_all_by_source('Uniprot/SPTREMBL')};
#   print STDERR "[loaded uniprot SPTREMBL] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   $cluster_count++;

#   #Singletons
#   my $all_dbs = $self->{gdba}->fetch_all;

#   foreach my $gdb (@$all_dbs) {
#     my $gdb_name = $gdb->name;
#     next if $gdb_name =~ /ancest/;
#     my @gene_members = @{$self->{ha}->fetch_all_orphans_by_GenomeDB($gdb)};
#     foreach my $gene_member (@gene_members) {
#       my $canonical = $gene_member->get_canonical_peptide_Member;
#       my @all_transl = @{$gene_member->get_all_peptide_Members};
#       my $canonical_member_id = $canonical->member_id;
#       if (1 == scalar @all_transl) {
#         $self->{cluster_to_mcl}{$cluster_count}{$canonical_member_id} = 1;
#         $self->{in_singletons}{$canonical_member_id} = 1;
#         $member_count++;
#       } else {
#         foreach my $translation (@all_transl) {
#           my $translation_id = $translation->member_id;
#           $self->{cluster_to_mcl}{$cluster_count}{$translation_id} = 1;
#           $self->{in_singletons}{$translation_id} = 1;
#           $member_count++;
#         }
#       }
#       $cluster_count++;
#     }
#     print STDERR "[singletons $gdb_name] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     last if ($self->{debug});
#   }

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $clusterset = $self->{treeDBA}->fetch_node_by_node_id($self->{'clusterset_id'});

#   my @clusters = @{$clusterset->children};

#   my $totalnum_clusters = scalar(@clusters);
#   print STDERR "[loaded clusters $totalnum_clusters] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   while (my $cluster = shift @clusters) {
#     foreach my $leaf (@{$cluster->get_all_leaves}) {
#       my $canonical = $leaf->gene_member->get_canonical_peptide_Member;
#       my @all_transl = @{$leaf->gene_member->get_all_peptide_Members};
#       my $canonical_member_id = $canonical->member_id;
#       if (1 == scalar @all_transl) {
#         next if (defined($self->{in_singletons}{$canonical_member_id}));
#         $self->{cluster_to_mcl}{$cluster_count}{$canonical_member_id} = 1;
#       } else {
#         foreach my $translation (@all_transl) {
#           my $translation_id = $translation->member_id;
#           next if (defined($self->{in_singletons}{$translation_id}));
#           $self->{cluster_to_mcl}{$cluster_count}{$translation_id} = 1;
#         }
#       }
#     }
#     $member_count += scalar keys %{$self->{cluster_to_mcl}{$cluster_count}};
#     if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d clusters done] ", 
#         $cluster_count, $totalnum_clusters;
#       print STDERR $verbose_string;
#       print STDERR time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     }
#     $cluster_count++;
#     last if ($self->{debug} && $self->{debug} == $cluster_count);
#   }

#   # Dont need anymore, free up
#   $self->{in_singletons} = undef;

#   # print header
#   my $num_clusters = $cluster_count - 1;
#   print "(mclheader\n";
#   print "mcltype matrix\n";
#   print "dimensions $member_count","x","$num_clusters\n";
#   print ")\n";
#   print "(mclmatrix\n";
#   print "begin\n";

#   #print each cluster
#   foreach my $id (sort {$a<=>$b} keys %{$self->{cluster_to_mcl}}) {
#     my $id_mcl = sprintf('%-8s', ($id - 1));
#     print "$id_mcl";
#     my @member_ids = sort {$a<=>$b} keys %{$self->{cluster_to_mcl}{$id}};
#     my $firstline = 1;
#     while (my $line =  join(" ", splice(@member_ids,0,10))) {
#       if (0 != scalar @member_ids) {
#         if ($firstline) {
#           print "$line\n";
#           $firstline = 0;
#         } else {
#           print "          $line\n";
#         }
#       } else {
#         if ($firstline) {
#           print "$line ",'$',"\n";
#           $firstline = 0;
#         } else {
#           print "          $line ",'$',"\n";
#         }
#       }
#     }
#   }

#   # print end
#   print ")\n";
# }

# sub _family_pid {
#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $self->{fa} = $self->{comparaDBA}->get_FamilyAdaptor;

#   my $file = $self->{_family_pid};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     $self->{_families}{$_} = 1;
#   }

#   foreach my $family_stable_id (keys %{$self->{_families}}) {
#     my $family = $self->{fa}->fetch_by_stable_id($family_stable_id);
#     $DB::single=1;1;
#     my $aln;
#     eval {$aln = $family->get_SimpleAlign};
#     next if ($@);
#     my $family_id = $family->dbID;
#     my $average_pid = $aln->average_percentage_identity;
#     my $overall_pid = $aln->overall_percentage_identity;
#     my $len = $aln->length;
#     my $nrd = $aln->no_residues;
#     my $nsq = $aln->no_sequences;

#     my $sth = $self->{comparaDBA}->dbc->prepare
#       ("INSERT INTO family_pid
#                              (family_id,
#                               average_pid,
#                               overall_pid,
#                               length,
#                               num_residues,
#                               num_sequences) VALUES (?,?,?,?,?,?)");
#     $sth->execute($family_id,
#                   $average_pid,
#                   $overall_pid,
#                  $len,
#                  $nrd,
#                  $nsq);
#   }
# }

# sub _ensembl_alias_name {
#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   # taxon_id tree
#   my $newick_file = $self->{_ensembl_alias_name};
#   #parse newick into a new tree object structure
#   my $newick = '';
#   # print("load from file $newick_file\n") if($self->{verbose});
#   open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
#   while (<FH>) {
#     $newick .= $_;
#   }
#   close(FH);
#   my $newtree = '';
#   $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);

#   # named tree
#   my $newick_file2 = $self->{_inputfile};
#   #parse newick into a new tree object structure
#   my $newick2 = '';
#   # print("load from file $newick_file\n") if($self->{verbose});
#   open (FH2, $newick_file2) or $self->throw("Couldnt open newick file [$newick_file2]");
#   while (<FH2>) {
#     $newick2 .= $_;
#   }
#   close(FH2);
#   my $newtree2 = '';
#   $newtree2 = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick2);

#   foreach my $node ($newtree->get_all_subnodes) {
#     next unless ($node->is_leaf);
#     my $taxon_id = $node->name;
#     $taxon_id =~ s/\*//;
#     my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($taxon_id);
#     my $ensembl_alias_name = $taxon->get_tagvalue('ensembl alias name');
#     if (!defined $ensembl_alias_name || $ensembl_alias_name eq '') {
#       print "  ", $taxon_id, ",";
#       my $x = $taxon->get_tagvalue('genbank common name');
#       $x = join (",", @$x) if (ref($x) eq "ARRAY");
#       print $x, ",";
#       my $y = $taxon->get_tagvalue('common name');
#       $y = join (",", @$y) if (ref($y) eq "ARRAY");
#       print $y, ",";
#       print $taxon->name, "\n";
#       print "  insert into ncbi_taxa_name (taxon_id, name, name_class) values ($taxon_id,\"$x\",\"ensembl alias name\")\;\n";
#       print "  insert into ncbi_taxa_name (taxon_id, name, name_class) values ($taxon_id,\"$y\",\"ensembl alias name\")\;\n";
#     }
#   }

#   foreach my $node ($newtree->get_all_subnodes) {
#     next if ($node->is_leaf);
#     my $taxon_id = $node->name;
#     my $taxon = $self->{taxonDBA}->fetch_node_by_taxon_id($taxon_id);
#     my $ensembl_alias_name = $taxon->get_tagvalue('ensembl alias name');
#     if (defined $ensembl_alias_name && $ensembl_alias_name ne '') {
#       # print "$taxon_id,$ensembl_alias_name\n";
#     } else {
#       my $subtree = $newtree2->find_node_by_name($taxon->name);
#       $subtree->print_tree;
#       my $genbank_common_name = $taxon->get_tagvalue('genbank common name');
#       print "  $taxon_id,$genbank_common_name\n";
#       my $genbank_common_name2 = ucfirst($genbank_common_name);
#       print "  insert into ncbi_taxa_name (taxon_id, name, name_class) values ($taxon_id,\"$genbank_common_name2\",\"ensembl alias name\")\;\n" 
#         if (defined $genbank_common_name2 && $genbank_common_name2 ne '');
#       my @ancestor_like_array;
#       foreach my $leaf (@{$subtree->get_all_leaves}) {
#         my $name = $leaf->name;
#         $name =~ s/\_/\ /g;
#         my $taxon = $self->{taxonDBA}->fetch_node_by_name($name);
#         my $ensembl_alias_name = $taxon->get_tagvalue('ensembl alias name');
#         my $alias = $name;
#         if (defined $ensembl_alias_name && $ensembl_alias_name ne '') {
#           $alias = $ensembl_alias_name;
#         } else {
#           my $genbank_common_name = $taxon->get_tagvalue('genbank common name');
#           $alias = $genbank_common_name;
#         }
#         push @ancestor_like_array, $alias;
#       }
#       my $ancestor_like_string = join ("/",@ancestor_like_array);
#       $ancestor_like_string .= " ancestor";
#       print "  insert into ncbi_taxa_name (taxon_id, name, name_class) values ($taxon_id,\"$ancestor_like_string\",\"ensembl alias name\")\;\n";
#       print "  $taxon_id\n";
#     }
#   }
# }

# sub _genetreeview_mcv {

#   my $self = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;

#   my $gdb = $self->{gdba}->fetch_by_name_assembly("Homo sapiens");
#   my $taxon_id = $gdb->taxon_id;

#   my $taxonomy_leaf = $self->{taxonDBA}->fetch_node_by_name($gdb->name);
#   my $taxonomy_root = $taxonomy_leaf->subroot;
#   my $taxonomy_parent = $taxonomy_leaf;
#   my %taxonomy_hierarchy;
#   my $hierarchy_count = 0;
#   do {
#     $hierarchy_count++;
#     $hierarchy_count = sprintf("%03d",$hierarchy_count);
#     $taxonomy_hierarchy{$taxonomy_parent->name} = $hierarchy_count;
#     $taxonomy_parent = $taxonomy_parent->parent;
#   } while ($taxonomy_parent->dbID != $taxonomy_root->dbID);

#   my @members;
#   if (!$self->{debug}) {
#     @members = @{$self->{memberDBA}->fetch_all_by_source_taxon('ENSEMBLGENE',$taxon_id)};
#   } else {
#     push @members, $self->{memberDBA}->fetch_by_source_stable_id("ENSEMBLGENE","ENSG00000079819");
#   }

#   my $server = "dec2007.archive";

#   while ( my $member = splice(@members,rand(scalar(@members)),1) ) {
#     my $proteintree =  $self->{treeDBA}->fetch_by_Member_root_id($member);
#     if (defined $proteintree) {
#       my $member_stable_id = $member->stable_id;
#       # `sleep 1`;
#       # `firefox 'http://$server.ensembl.org/human/genetreeview?gene=$member_stable_id'`;
#       my $leaves =  $proteintree->get_all_leaves;
#       my $found_subnode = 0;
#       my $subtree;
#       foreach my $leaf (@$leaves) {
#         next unless ($leaf->gene_member->stable_id eq $member_stable_id);
#         last if ($found_subnode);
#         my $node = $leaf;
#         my $subnode;
#         while ($subnode = $node->parent) {
#           if ($self->{'_genetreeview_mcv'} < $subnode->num_leaves) {
#             $found_subnode = 1;
#           }
#           $node = $subnode; # parent loop
#           last if ($found_subnode);
#           $subtree = $subnode; # last
#         }
#       }
#       my $final_string = "http://$server.ensembl.org/Homo_sapiens/multicontigview?gene=$member_stable_id;context=10000;";

#       next unless (defined($subtree));
#       foreach my $leaf (@{$subtree->get_all_leaves}) {
#         next if ($leaf->gene_member->stable_id eq $member_stable_id);
#         my $stable_id = $leaf->gene_member->stable_id;
#         my @homologies = @{$self->{ha}->fetch_by_Member_Member_method_link_type($leaf->gene_member,$member,'ENSEMBL_ORTHOLOGUES')};
#         my $homology = $homologies[0];
#         next unless (defined $homology);
#         my $subtype = $homology->subtype;
#         my $species_name = $leaf->genome_db->name;
#         $species_name =~ s/\ /\_/g;
#         my $string = "g" . "LEVEL" . "=$stable_id;" . "s" . "LEVEL" . "=$species_name;";
#         $self->{_homology_list_taxonomy_hierarchy}{$taxonomy_hierarchy{$subtype}} = $string;
#       }
#       my $count = 1;
#       foreach my $hierarchy (sort keys %{$self->{_homology_list_taxonomy_hierarchy}}) {
#         my $string = $self->{_homology_list_taxonomy_hierarchy}{$hierarchy};
#         $string =~ s/LEVEL/$count/g;
#         $final_string .= $string;
#         $count++;
#       }

#       $final_string =~ s/\;$//;
#       print "$final_string\n";
#       # `firefox \"$final_string\"`;
#     }
#   }
# }

# sub _sitewise_stats {
#   my $self = shift;

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $tree_id = $self->{_sitewise_stats};
#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
#   my @sitewise_dnds_values = @{$tree->get_SitewiseOmega_values};
#   my $conservation_string;
#   my @intervals = map {$_->omega_upper - $_->omega_lower} @sitewise_dnds_values;
#   require Statistics::Descriptive;
#   my $std = std_dev_pm(@intervals) || 0;
#   print "$std\n";
# }

# sub _sitewise_stats_old {
#   my $self = shift;

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $tree_id = $self->{_sitewise_stats};
#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
#   my @sitewise_dnds_values = @{$tree->get_SitewiseOmega_values};
#   my $conservation_string;
#   my @intervals = map {$_->omega_upper - $_->omega_lower} @sitewise_dnds_values;
#   require Statistics::Descriptive;
#   my $std = std_dev_pm(@intervals) || 0;
#   print "$std\n";
# }

# sub _prank_test {
#   my $self = shift;

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $tree_id = $self->{_prank_test};
#   my $genetree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
#   my $num_leaves = $genetree->num_leaves;
#   exit if ($num_leaves < 15);
#   my $sa = $genetree->get_SimpleAlign(-exon_cased=>1);
#   my $io = new Bio::Root::IO();
#   my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => "/tmp"); #internal purposes
#   my $seqio = Bio::SeqIO->new
#     (-file => ">$tempfile",
#      -format => 'fasta');

#   my $tree_string = $genetree->newick_format;
#   open(my $fake_fh, "+<", \$tree_string);
#   my $treein = new Bio::TreeIO
#     (-fh => $fake_fh,
#      -format => 'newick');
#   my $tree = $treein->next_tree;
#   $treein->close;

#   my ($tmpfilefh2,$tempfile2) = $io->tempfile(-dir => "/tmp"); #internal purposes
#   my $treeout = new Bio::TreeIO
#     (-file => ">$tempfile2",
#      -format => 'newick');
#   $treeout->write_tree($tree);
#   $treeout->close;

#   my $treeout2 = new Bio::TreeIO
#     (-file => ">/lustre/work1/ensembl/avilella/prank_test/$tree_id.nh",
#      -format => 'newick');
#   $treeout2->write_tree($tree);
#   $treeout2->close;

#   $sa = $sa->sort_by_tree($tree); # Greg's method
#   $sa->set_displayname_flat(1);
#   my $alnioout = Bio::AlignIO->new
#     (-file => ">/lustre/work1/ensembl/avilella/prank_test/$tree_id.muscle.aln",
#      -format => 'fasta');

#   $alnioout->write_aln($sa);
#   $alnioout->close;

#   foreach my $aln_seq ($sa->each_seq) {
#     my $seq = $aln_seq->seq;
#     $seq =~ s/\-//g;
#     $aln_seq->seq($seq);
#     $seqio->write_seq($aln_seq);
#   }
#   $seqio->close;

# ##  my $cmd = "/nfs/acari/avilella/src/prank/src/prank -d=$tempfile -t=$tempfile2 -o=$tempfile.out -F -NX -noxml -notree -quiet -maxbranches=0.2 -gaprate=0.01 -gapext=0.9";
#   my $cmd = "/nfs/acari/avilella/src/prank/src/prank -d=$tempfile -t=$tempfile2 -o=$tempfile.out -F -NX -noxml -notree -quiet";
#   my $ret = system($cmd);
#   die "$!" if ($ret);

#   my $alnio = Bio::AlignIO->new
#     (-file => "$tempfile.out.1.fas",
#      -format => 'fasta');
#   my $new_aln = $alnio->next_aln;
#   $alnio->close;

#   my $palnioout = Bio::AlignIO->new
#     (-file => ">/lustre/work1/ensembl/avilella/prank_test/$tree_id.prank.aln",
#      -format => 'fasta');

#   $new_aln = $new_aln->sort_by_tree($tree); # Greg's method
#   $palnioout->write_aln($new_aln);
#   $palnioout->close;

#   unlink "$tempfile";
#   unlink "$tempfile2";
#   unlink "$tempfile.out.1.fas";
#   # `mv $tempfile.out.1.fas /lustre/work1/ensembl/avilella/prank_test/$tree_id.prank.aln`;
#   # unlink "/tmp/$tempfile.out.1.fas";
# }

# sub _remove_duplicates_orthotree {
#   my $self = shift;

#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $file = $self->{_remove_duplicates_orthotree};
#   open FILE, "$file" or die "$!";

#   my $trees;
#   my $count = 0;
#   my ($linenum,$filename) = split(" ", `wc -l $file`);
#   while (<FILE>) {
#     chomp $_;
#     my ($tree_node_id,$member_id1,$member_id2) = split ("\t", $_);
#     my $pair = $member_id1 . "_" . $member_id2;
#     $trees->{pairs}{$pair}{$tree_node_id} = 1;
#     $trees->{trees}{$tree_node_id}{$pair} = 1;
#     print STDERR "[$count / $linenum]\n" if (0 == ($count % 1000));
#     $count++;
#   }

#   my $visited_trees;
#   foreach my $pair (keys %{$trees->{pairs}}) {
#     if (2 > scalar keys %{$trees->{pairs}{$pair}}) {

#       my @tree_node_ids = keys %{$trees->{pairs}{$pair}};
#       my $tree_node_id = $tree_node_ids[0];
#       next if (defined $visited_trees->{found}{$tree_node_id});
#       $visited_trees->{single}{$tree_node_id} = 1;
#       $visited_trees->{found}{$tree_node_id} = 1;

#     } else {

#       foreach my $tree_node_id (keys %{$trees->{pairs}{$pair}}) {
#         next if (defined $visited_trees->{found}{$tree_node_id});
#         my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_node_id);
#         my $gene_count = $tree->get_tagvalue("gene_count");
#         $visited_trees->{multiple}{$gene_count}{$tree_node_id} = 1;
#         $visited_trees->{found}{$tree_node_id} = 1;
#       }

#     }
#   }

#   foreach my $gene_count (keys %{$visited_trees->{multiple}}) {
#     my @tree_ids = sort {$a<=>$b} keys %{$visited_trees->{multiple}{$gene_count}};
#     my $tree1 = $self->{treeDBA}->fetch_node_by_node_id($tree_ids[0]);
#     my $tree2 = $self->{treeDBA}->fetch_node_by_node_id($tree_ids[1]);

#     my $tree_node_id = $tree_ids[1];

#     my @homologies;
#     my $q_count = 0;
#     foreach my $pair (keys %{$trees->{trees}{$tree_node_id}}) {
#       my ($member_id1, $member_id2) = split("_",$pair);
#       my $sql = "select hm1.homology_id from homology_member hm1, homology_member hm2, homology h where h.tree_node_id=$tree_node_id and h.homology_id=hm1.homology_id and hm1.homology_id=hm2.homology_id and hm1.member_id=$member_id1 and hm2.member_id=$member_id2 order by hm1.homology_id";
#       my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#       $sth->execute();
#       my $homology_id  = $sth->fetchrow;
#       next unless (defined $homology_id);
#       push @homologies, $homology_id;
#       print STDERR "[$q_count]\n" if (0 == ($q_count % 10000));
#       $q_count++;
#     }

#     print STDERR "Single deleting $tree_node_id...\n";
#     next if (0 == scalar(@homologies));
#     my $arr_count = 0;
#     my $arr_total = scalar(@homologies)/1000;
#     while (my @arr = splice(@homologies,0,1000)) {
#       my $list = join(",",@arr);
#       my $sql = "delete from homology where homology_id in ($list)";
#       my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#       $sth->execute();

#       my $sql2 = "delete from homology_member where homology_id in ($list)";
#       my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#       $sth2->execute();
#       print STDERR "[$arr_count / $arr_total]\n" if (0 == ($arr_count % 10));
#       $arr_count++;
#     }

#     $tree2->adaptor->delete_node_and_under($tree2);
#   }

#   foreach my $tree_node_id (keys %{$visited_trees->{single}}) {
#     my @homologies;
#     my $q_count = 0;
#     print STDERR "Single $tree_node_id\n";
#     next if ($tree_node_id == 1486881);
#     foreach my $pair (keys %{$trees->{trees}{$tree_node_id}}) {
#       my ($member_id1, $member_id2) = split("_",$pair);

#       my $sql2 = "select hm1.homology_id from homology_member hm1, homology_member hm2 where hm1.homology_id=hm2.homology_id and hm1.member_id=$member_id1 and hm2.member_id=$member_id2 order by hm1.homology_id";
#       my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#       $sth2->execute();
#       my $res  = $sth2->fetchall_arrayref; my $duplicate_entry = scalar @$res;

#       my $sql = "select hm1.homology_id from homology_member hm1, homology_member hm2 where hm1.homology_id=hm2.homology_id and hm1.member_id=$member_id1 and hm2.member_id=$member_id2 order by hm1.homology_id desc limit 1,999999999";
#       my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#       $sth->execute();
#       my $homology_id  = $sth->fetchrow;
#       next unless (defined $homology_id);
#       unless (2 == $duplicate_entry) {
#         $DB::single=1;1;
#         next;
#       }
#       push @homologies, $homology_id;
#       print STDERR "[$q_count]\n" if (0 == ($q_count % 10000));
#       $q_count++;
#     }
#     $DB::single=1;1;

#     print STDERR "Single deleting $tree_node_id...\n";
#     next if (0 == scalar(@homologies));
#     my $arr_count = 0;
#     my $arr_total = scalar(@homologies)/1000;
#     while (my @arr = splice(@homologies,0,1000)) {
#       $DB::single=1;1;
#       my $list = join(",",@arr);
#       my $sql = "delete from homology where homology_id in ($list)";
#       my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#       $sth->execute();

#       my $sql2 = "delete from homology_member where homology_id in ($list)";
#       my $sth2 = $self->{comparaDBA}->dbc->prepare($sql2);
#       $sth2->execute();
#       print STDERR "[$arr_count / $arr_total]\n" if (0 == ($arr_count % 10));
#       $arr_count++;
#     }
#     print STDERR "Single Deleted $tree_node_id\n";
#     $DB::single=1;1;#
#   }
# }

# sub _remove_duplicates_genesets {
#   my $self = shift;

#   $self->{treeDBA}   = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{subsetDBA} = $self->{'comparaDBA'}->get_SubsetAdaptor;
#   my $tree_id = $self->{_remove_duplicates_genesets};
#   my $inputfile = $self->{_inputfile} || "/lustre/scratch1/ensembl/avilella/hive/avilella_compara_homology_51/remove_duplicates_genesets/subset_member_id.43.txt";
#     open INFILE, "$inputfile" or die;
#   while (<INFILE>) {
#     chomp $_;
#     $self->{subset}{$_} = 1;
#   }

#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
#   foreach my $member (@{$tree->get_all_leaves}) {
#     next if ($member->genome_db_id != 43);
#     my $member_id = $member->dbID;
#     if (!defined($self->{subset}{$member_id})) {
#       my $member_stable_id = $member->stable_id;
#       my $gene_count = $tree->get_tagvalue("gene_count");
#       my $filename = "/lustre/scratch1/ensembl/avilella/hive/avilella_compara_homology_51/remove_duplicates_genesets/" . $tree_id . "_" . $gene_count . "_" . $member_stable_id;
#       `touch $filename`;
#     }
#   }
# }

# sub _remove_duplicates_genesets_old {
#   my $self = shift;

#   $self->{treeDBA}   = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{subsetDBA} = $self->{'comparaDBA'}->get_SubsetAdaptor;
#   my $tree_id = $self->{_remove_duplicates_genesets};
#   my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_id);
#   my $list;
#   my @array;
#   foreach my $member (@{$tree->get_all_leaves}) {
#     my $description = $member->description;
#     $description =~ /Gene\:(\S+)/;
#     my $gene_member_id = $1;
#     $list->{$gene_member_id}{$member->stable_id} = $member->dbID;
#     push @array, $gene_member_id;
#   }

#   if (scalar keys %{$list} != scalar @array) {
#     $DB::single=1;1;
#     foreach my $gene_member_id (keys %{$list}) {
#       next if (1 >= scalar keys %{$list->{$gene_member_id}});
#       foreach my $member_id (keys %{$list->{$gene_member_id}}) {
#         my $dbid = $list->{$gene_member_id}{$member_id};
#         my $filename = "/lustre/scratch1/ensembl/avilella/hive/avilella_compara_homology_51/remove_duplicates_genesets/" . $tree_id . "_" . $gene_member_id . "_" . $member_id . "_" . $dbid;
#         `touch $filename`;
#         # print STDERR "$tree_id,$member_id,$gene_member_id,$dbid\n";
#         $DB::single=1;1;
#       }
#     }
#   }
# }

# sub _pep_splice_site {
#   my $self = shift;

#   my $member_id = $self->{_pep_splice_site};
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   my $peptide_member = $self->{memberDBA}->fetch_by_dbID($member_id);

#   my $sequence = $peptide_member->sequence;
#   my $trans = $peptide_member->transcript;
#   my @exons = @{$trans->get_all_translateable_Exons};
#   print $sequence if (1 == scalar @exons);

#   my %splice_site;
#   my $pep_len = 0;
#   my $overlap_len = 0;
#   for my $exon (@exons) {
#     my $exon_len = $exon->length;
#     my $pep_seq = $exon->peptide($trans)->length;
#     # remove the first char of seq if overlap ($exon->peptide()) return full overlapping exon seq
#     $pep_seq -= 1 if ($overlap_len);
#     $pep_len += $pep_seq;
#     if ($overlap_len = (($exon_len + $overlap_len ) %3)){          # if there is an overlap
#       $splice_site{$pep_len-1}{'overlap'} = $pep_len -1;         # stores overlapping aa-exon boundary
#     } else {
#       $overlap_len = 0;
#     }
#     $splice_site{$pep_len}{'phase'} = $overlap_len;                 # positions of exon boundary
#   }

#   my $seqsplice = '';
#   my $splice = 0;
#   foreach my $pep_len (sort {$b<=>$a} keys %splice_site) { # We start from the end
#     next if (defined($splice_site{$pep_len}{'overlap'}));
#     $splice++;
#     my $length = $pep_len;
#     $length-- if (defined($splice_site{$pep_len}{'phase'}) && 1 == $splice_site{$pep_len}{'phase'});
#     my $peptide = substr($sequence,$length,length($sequence),'');
#     $peptide = lc($peptide) unless ($splice % 2); # Even splice lower-cased
#     $seqsplice = $peptide . $seqsplice;
#   }
#   $seqsplice = $sequence . $seqsplice; # First exon AS IS
#   print $seqsplice . "\n";
# }


# sub _cafe_genetree {

#   my $self = shift;
#   my $species_set = $self->{'_cafe_genetree'};
#   $species_set =~ s/\_/\ /g;
#   my @species_set = split(":",$species_set);

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   my $clusterset = $self->{treeDBA}->fetch_node_by_node_id($self->{'clusterset_id'});

#   my @clusters = @{$clusterset->children};

#   my $totalnum_clusters = scalar(@clusters);
#   print STDERR "[loaded clusters $totalnum_clusters] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   my $cluster_count = 0;
#   foreach my $cluster (@clusters) {
#     $cluster_count++;
#     last if (100 == $cluster_count && $self->{debug});
#     my $canonical_description;
#     my $tree_id = $cluster->node_id;
#     foreach my $leaf (@{$cluster->get_all_leaves}) {
#       $self->{cafe_genetree}{$tree_id}{species_num}{$leaf->genome_db->short_name}++;
#       my $description = $leaf->gene_member->description;
#       if (defined($description)) {
#         if (!defined($canonical_description)) {
#           $canonical_description = $description if (length($description) > 0);
#         } else {
#           $canonical_description = $description if (length($description) > length($canonical_description));
#         }
#       }
#     }
#     $self->{cafe_genetree}{$tree_id}{canonical_description} = $canonical_description;
#     if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d clusters done] ", 
#         $cluster_count, $totalnum_clusters;
#       print STDERR $verbose_string;
#       print STDERR time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     }
#   }
#   print join ("\t",("description","tree_id",(@species_set))), "\n";

#   foreach my $tree_id (keys %{$self->{cafe_genetree}}) {
#     my @species = keys %{$self->{cafe_genetree}{$tree_id}{species_num}};
#     my $description = $self->{cafe_genetree}{$tree_id}{canonical_description} || "null";
#     my @nums;
#     foreach my $species (@species_set) {
#       my $spnum = 0;
#       if (defined($self->{cafe_genetree}{$tree_id}{species_num}{$species})) {
#         $spnum = $self->{cafe_genetree}{$tree_id}{species_num}{$species};
#       }
#       push @nums, $spnum;
#     }
#     print "$description\t$tree_id\t", join("\t",@nums), "\n";
#   }
# }

# sub _fel {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{starttime} = time();

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   my $file = $self->{_fel};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     $self->{_fel_ids}{$_} = 1;
#   }


#   $ENV{HYPHYDIR} = "/nfs/acari/avilella/src/hyphy_latest/HYPHY_Source";
#   foreach my $root_id (keys %{$self->{_fel_ids}}) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     $DB::single=1;1;
#     if (1000 == $self->{verbose}) {
#       my $subroot_id = $root->subroot->node_id;
#       $root->store_tag('Sitewise_dNdS_subroot_id', $subroot_id);
#       next;
#     }

#     # my $gene_count = $root->get_tagvalue("gene_count");
#     #     my $max_dist = 0;
#     #     foreach my $leaf (@{$root->get_all_leaves}) {
#     #       my $dist = $leaf->distance_to_root;
#     #       $max_dist = $dist if ($dist > $max_dist);
#     #     }
#     # next if ($max_dist > 4);
#     #     if (defined($gene_count) && $gene_count ne '') {
#     #       # next if ($gene_count > 50);
#     #       # next if ($gene_count < 4);
#     #     }
#     print STDERR "[root $root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     my $tmp = $root->get_SimpleAlign(-cdna => 1);
#     print STDERR "[displayname_safe ...] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     my ($cds_aln, $phylip_name) = $tmp->set_displayname_safe;
#     my %reverse_phylip = reverse %{$phylip_name};
#     my $newick_tree = $root->newick_format;
#     my $node_id = $root_id;
#     print STDERR "[aln $node_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     open TREE, ">$node_id.nh" or die "couldnt open $node_id.nh: $!\n"; print TREE "$newick_tree\n"; close TREE;
#     my $treeio = Bio::TreeIO->new
#       (-format => 'newick',-file   => "$node_id.nh");
#     my $tree = $treeio->next_tree;
#     foreach my $leaf ($tree->get_leaf_nodes) {
#       my $id = $leaf->id;
#       my $new_id = $reverse_phylip{$id};
#       $leaf->id($new_id);
#     }
#     unlink "$node_id.nh";
#     my $fel;
#     print STDERR "[displayname_safe] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     eval { require Bio::Tools::Run::Phylo::Hyphy::FEL; };
#     die "fel wrapper not found: $!\n" if ($@);
#     $fel = Bio::Tools::Run::Phylo::Hyphy::FEL->new
#       (
#        '-executable' => '/nfs/acari/avilella/src/hyphy_latest/HYPHY_Source/HYPHYMP',
#        '-alignment' => $cds_aln,
#        '-tree' => $tree);
#     next if ($@);
#     print STDERR "[fel ...] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     my ($rc,$results) = $fel->run();
#     print STDERR "[fel] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     unless (defined($results)) {
#       print "$node_id,na,na,na\n";
#       next;
#     }
#     my $summary; my $total;

#     my @pvalues = @{$results->{'p-value'}};
#     my @omegas = @{$results->{'dN/dS'}};
#     foreach my $site (0 .. (scalar@pvalues)-1) {
#       my $type = 'default';
#       my $omega = $omegas[$site];
#       if (0.05 > $pvalues[$site]) {
#         if ($omega >= 1 || $omega eq 'inf') {
#           $type = 'positive2';
#         }
#         if ($omega < 1) {
#           $type = 'negative2';
#         }
#       } else {
#         $type = 'default';
#       }
#       print STDERR "storing $site,$root_id,$omega,$omega,$omega,$type\n";
#       print STDERR "[storing ...] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#       my $sth = $self->{comparaDBA}->dbc->prepare
#         ("INSERT INTO sitewise_aln_fel
#                              (aln_position,
#                               node_id,
#                               omega,
#                               omega_lower,
#                               omega_upper,
#                               type) VALUES (?,?,?,?,?,?)");
#       $sth->execute($site,
#                     $root_id,
#                     $omega,
#                     $omega,
#                     $omega,
#                     $type);
#     }
#     print STDERR "[stored] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     $root->release_tree;
#   }
# }

# sub _summary_stats {
#   my $self = shift;

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees,%d\n", $totalnum_clusters);
#   my $outfile = "summary_stats.tree_size.". $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE "node_id,num_leaves,num_species,species_list\n";
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     my @leaves = @{$cluster->get_all_leaves};
#     my %species_in_tree;
#     foreach my $leaf (@leaves) {
#       $species_in_tree{$leaf->genome_db->short_name} = 1;
#     }
#     my $species_list = join ("_", sort keys %species_in_tree);
#     my $num_species = scalar(keys %species_in_tree);
#     print OUTFILE $cluster->node_id, ",", scalar(@leaves),",", $num_species,",", $species_list,"\n";
#   }
#   close OUTFILE;

#   my @gdbs = @{$self->{gdba}->fetch_all};

#   $outfile = "summary_stats.genes.". $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";

#   print OUTFILE "gdb_short_name,gene_count,num_orphans,coverage\n";
#   foreach my $gdb1 (@gdbs) {
#     my $gdb1_short_name = $gdb1->short_name;
#     my @orphans = @{$self->{ha}->fetch_all_orphans_by_GenomeDB($gdb1)};
#     my $num_orphans = scalar(@orphans);
#     my $gene_count = $self->{memberDBA}->get_source_taxon_count('ENSEMBLGENE',$gdb1->taxon_id);
#     my $perc_cov = sprintf("%.3f",100-($num_orphans/$gene_count*100));
#     print OUTFILE $gdb1_short_name, ",", $gene_count,",", scalar(@orphans),",",$perc_cov,"\n";
#     print STDERR $gdb1_short_name, ",", $gene_count,",", scalar(@orphans),",",$perc_cov,"\n";
#     @orphans = undef;
#   }
#   close OUTFILE;

#   $outfile = "summary_stats.pairs.". $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE "gdb1_short_name,gdb2_short_name,num_one2one,num_app_one2one,num_one2many,num_many2many,num_btw_para\n";
#   while (my $gdb1 = shift (@gdbs)) {
#     my $gdb1_short_name = $gdb1->short_name;
#     foreach my $gdb2 (@gdbs) {
#       my $gdb2_short_name = $gdb2->short_name;
#       my $mlss_orth = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$gdb1, $gdb2]);
#       my $mlss_para = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES',  [$gdb1, $gdb2]);
#       my @orth_one2one = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss_orth,"ortholog_one2one")};
#       my @orth_app_one2one = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss_orth,"apparent_ortholog_one2one")};
#       my @orth_one2many = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss_orth,"ortholog_one2many")};
#       my @orth_many2many = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss_orth, "ortholog_many2many")};
#       my @para = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss_para,"between_species_paralog")};
#       print OUTFILE $gdb1_short_name, ",",
#         $gdb2_short_name, ",",
#           scalar(@orth_one2one), ",",
#             scalar(@orth_app_one2one), ",",
#               scalar(@orth_one2many), ",",
#                 scalar(@orth_many2many), ",",
#                   scalar(@para),"\n";
#       @orth_one2one = undef; @orth_app_one2one = undef; @orth_one2many = undef; @orth_many2many = undef; @para = undef;
#     }
#   }
#   close OUTFILE;
# }

# sub _dnds_paralogs {
#   my $self = shift;
#   my $species = shift;

#   $species =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my $sp_short_name = $sp_gdb->get_short_name;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   my $taxonomy_leaf = $self->{taxonDBA}->fetch_node_by_name($sp_gdb->name);
#   my $taxonomy_root = $taxonomy_leaf->subroot;
#   my $taxonomy_parent = $taxonomy_leaf;
#   my %taxonomy_hierarchy;
#   my $hierarchy_count = 0;
#   do {
#     $hierarchy_count++;
#     $taxonomy_hierarchy{$taxonomy_parent->name} = $hierarchy_count;
#     $taxonomy_parent = $taxonomy_parent->parent;
#   } while ($taxonomy_parent->dbID != $taxonomy_root->dbID);

#   my $inputfile = $self->{_inputfile};
#   if (defined($inputfile) && $inputfile ne '') {
#     open INFILE, "$inputfile" or die;
#     while (<INFILE>) {
#       chomp $_;
#       $self->{ignore}{$_} = 1;
#     }
#   }

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "dnds_paralogs.". $sp_short_name ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   my $header = "ancestor_taxon_name,ancestor_taxon_hierarchy,sp_name,gene_stable_id1,gene_stable_id2,dn,ds,lnl,perc_id,perc_pos,score\n";
#   print OUTFILE "$header"; 
#   print "$header" if ($self->{verbose});
#   my $mlss;
#   my @homologies; 
#   $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp_gdb]);
#   @homologies = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss)};

#   foreach my $homology (@homologies) {
#     my $ancestor_taxon_name = $homology->subtype;
#     if ($self->{debug}) {
#       next unless ($ancestor_taxon_name eq $species);
#     }
#     my $ancestor_taxon_hierarchy = $taxonomy_hierarchy{$ancestor_taxon_name};
#     my $dn = $homology->dn(undef, 0) || 'NA';
#     my $ds = $homology->ds(undef, 0) || 'NA';
#     my $lnl = $homology->lnl         || 'NA';
#     #next unless (defined($dn) && defined($ds) && defined($lnl));
#     my ($gene1,$gene2) = @{$homology->gene_list};
#     my $sp_name = $self->{_species};
#     my $gene1_stable_id = $gene1->stable_id;
#     my $gene2_stable_id = $gene2->stable_id;
#     next if defined($self->{ignore}{$gene1_stable_id});
#     next if defined($self->{ignore}{$gene2_stable_id});
#     my @pafs = @{$self->{ppafa}->fetch_all_by_qmember_id_hmember_id($gene1->get_canonical_peptide_Member->dbID,$gene2->get_canonical_peptide_Member->dbID)};
#     my $perc_id = "NA";
#     my $perc_pos = "NA";
#     my $score = "NA";
#     if (0 < scalar @pafs) {
#       $perc_id = $pafs[0]->perc_ident;
#       $perc_pos = $pafs[0]->perc_pos;
#       $score = int($pafs[0]->score);
#     }
#     $DB::single=1;1;
# #     my $exons_string1 = 0; my $exons_string2 = 0;
# #     my $exon_num_gene1 = 0;
# #     my $exon_num_gene2 = 0;
# #     my $core_gene1 = $gene1->get_Gene;
# #     my $core_gene2 = $gene2->get_Gene;
# #     $exons_string1 = join (":",map {scalar @{$_->get_all_translateable_Exons}} @{$core_gene1->get_all_Transcripts});
# #     $exons_string2 = join (":",map {scalar @{$_->get_all_translateable_Exons}} @{$core_gene2->get_all_Transcripts});
# #     $exon_num_gene1 = scalar @{$core_gene1->get_all_Exons};
# #     $exon_num_gene2 = scalar @{$core_gene2->get_all_Exons};
#     # print STDERR "$ancestor_taxon_name,$ancestor_taxon_hierarchy,$sp_name,$gene1_stable_id,$exons_string1,$gene2_stable_id,$exons_string2,$dn,$ds,$lnl\n";
#     $DB::single=1;1;
#     print OUTFILE "$ancestor_taxon_name,$ancestor_taxon_hierarchy,$sp_name,$gene1_stable_id,$gene2_stable_id,$dn,$ds,$lnl,$perc_id,$perc_pos,$score\n";
#     print "$ancestor_taxon_name,$ancestor_taxon_hierarchy,$sp_name,$gene1_stable_id,$gene2_stable_id,$dn,$ds,$lnl\n" if ($self->{debug});
#   }
# }

# sub _dnds_pairs {
#   my $self = shift;
#   my $species1 = shift;
#   my $species2 = shift;

#   $species1 =~ s/\_/\ /g;
#   $species2 =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#   my $sp1_short_name = $sp1_gdb->get_short_name;
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#   my $sp2_short_name = $sp2_gdb->get_short_name;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   my $taxonomy_leaf = $self->{taxonDBA}->fetch_node_by_name($sp1_gdb->name);
#   my $taxonomy_root = $taxonomy_leaf->subroot;
#   my $taxonomy_parent = $taxonomy_leaf;
#   my %taxonomy_hierarchy;
#   my $hierarchy_count = 0;
#   do {
#     $hierarchy_count++;
#     $taxonomy_hierarchy{$taxonomy_parent->name} = $hierarchy_count;
#     $taxonomy_parent = $taxonomy_parent->parent;
#   } while ($taxonomy_parent->dbID != $taxonomy_root->dbID);

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "dnds_pairs.". $sp1_short_name ."." . $sp2_short_name ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   my $header = "tree_id1,ancestor_node_id,ancestor_taxon_name,ancestor_taxon_hierarchy,root_taxon1,peptide1_stable_id1,gene1_stable_id1,sp1_name1,peptide2_stable_id1,gene2_stable_id1,sp2_name1,dn1,ds1,lnl1,dups_to_ancestor1," . 
#     "root_taxon2,peptide1_stable_id2,gene1_stable_id2,sp1_name2,peptide2_stable_id2,gene2_stable_id2,sp2_name2,dn2,ds2,lnl2,dups_to_ancestor2\n";
#   print OUTFILE "$header"; 
#   print "$header" if ($self->{verbose});
#   my $mlss;
#   my @homologies; 
#   unless ($species1 eq $species2) {
#     $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
#     @homologies = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,'ortholog_one2one')};
#   } else {
#     $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp1_gdb]);
#     @homologies = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss)};
#   }
#   my $homology_count=0;
#   my $totalnum_homologies = scalar(@homologies);
#   my $sth;
#   my $root_id;

#   my $sql = "SELECT node_id,left_index,right_index FROM protein_tree_node WHERE parent_id = root_id";
#   $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   while (my ($root_id,$root_left_index,$root_right_index) = $sth->fetchrow) {
#     foreach my $index ($root_left_index .. $root_right_index) {
#       $self->{_hashed_indexes}{$index} = $root_id;
#     }
#   }
#   $sth->finish();

#   foreach my $homology (@homologies) {
#     my $homology_node_id = $homology->node_id;
#     $sql = "SELECT left_index, right_index FROM protein_tree_node WHERE node_id=$homology_node_id";
#     $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     my ($left_index,$right_index) = $sth->fetchrow;

#     if (defined($self->{_hashed_indexes}{$left_index})) {
#       $root_id = $self->{_hashed_indexes}{$left_index};
#     }
#     $self->{_homologies_by_cluster}{$root_id}{$homology->dbID} = $homology;
#     $homology_count++;
#     if ($self->{'verbose'} &&  ($homology_count % $self->{'verbose'} == 0)) {
#       my $verbose_string = sprintf "[%5d / %5d homologies done]\n", 
#         $homology_count, $totalnum_homologies;
#       print STDERR $verbose_string;
#     }
#   }
#   $sth->finish;

#   foreach my $root_id (keys %{$self->{_homologies_by_cluster}}) {
#     my @this_tree_homology_ids = keys %{$self->{_homologies_by_cluster}{$root_id}};
#     my $num_homologies = scalar(@this_tree_homology_ids);
#     next unless ($num_homologies != 1);
#     while (my $homology_id1 = shift (@this_tree_homology_ids)) {
#       foreach my $homology_id2 (@this_tree_homology_ids) {
#         my $homology1 = $self->{_homologies_by_cluster}{$root_id}{$homology_id1};
#         my $homology2 = $self->{_homologies_by_cluster}{$root_id}{$homology_id2};
#         my @homology1_member_ids;
#         @homology1_member_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology1->gene_list};
#         my @homology2_member_ids;
#         @homology2_member_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology2->gene_list};
#         my $node_a = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology1_member_ids[0],$self->{'clusterset_id'});
#         my $node_b = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology1_member_ids[1],$self->{'clusterset_id'});
#         my $node_c = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology2_member_ids[0],$self->{'clusterset_id'});
#         my $node_d = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($homology2_member_ids[1],$self->{'clusterset_id'});
#         my $root = $node_a->subroot;
#         $root->merge_node_via_shared_ancestor($node_c);
#         my $ancestor;
#         eval { $ancestor = $node_a->find_first_shared_ancestor($node_c); };
#         next unless (defined($ancestor));
#         my $ancestor_node_id = $ancestor->node_id;
#         my $ancestor_taxon_name = $ancestor->get_tagvalue("taxon_name");
#         my $ancestor_taxon_hierarchy = $taxonomy_hierarchy{$ancestor_taxon_name};
#         my $num_duplications_a=0;
#         my $num_duplications_c=0;
#         my $parent_a;
#         my $parent_c;
#         $parent_a = $node_a->parent;
#         next unless (defined($parent_a));
#         do {
#           my $duptag = $parent_a->get_tagvalue("Duplication");
#           next if ($duptag eq '');
#           my $sistag = $parent_a->get_tagvalue("duplication_confidence_score");
#           if ($duptag > 0) {
#             if ($sistag > 0) {
#               $num_duplications_a++;
#             }
#           }
#           $parent_a = $parent_a->parent;
#         } while ($parent_a->node_id != $ancestor_node_id);

#         $parent_c = $node_c->parent;
#         next unless (defined($parent_c));
#         do {
#           my $duptag = $parent_c->get_tagvalue("Duplication");
#           next if ($duptag eq '');
#           my $sistag = $parent_c->get_tagvalue("duplication_confidence_score");
#           if ($duptag > 0) {
#             if ($sistag > 0) {
#               $num_duplications_c++;
#             }
#           }
#           $parent_c = $parent_c->parent;
#         } while ($parent_c->node_id != $ancestor_node_id);

#         my $dn1 = $homology1->dn;
#         my $ds1 = $homology1->ds;
#         my $lnl1 = $homology1->lnl;
#         next unless (defined($dn1) && defined($ds1) && defined($lnl1));
#         my $peptide1_stable_id1 = $node_a->stable_id;
#         my $peptide2_stable_id1 = $node_b->stable_id;
#         my $gene1_stable_id1 = $node_a->gene_member->stable_id;
#         my $gene2_stable_id1 = $node_b->gene_member->stable_id;
#         my $temp1;
#         # Always match species order with species1 and
#         # species2 parameters in the output
#         if ($node_a->gene_member->genome_db->name eq $species2) {
#           $temp1 = $peptide1_stable_id1;
#           $peptide1_stable_id1 = $peptide2_stable_id1;
#           $peptide2_stable_id1 = $temp1;
#           $temp1 = $gene1_stable_id1;
#           $gene1_stable_id1 = $gene2_stable_id1;
#           $gene2_stable_id1 = $temp1;
#         }
#         my $taxonomy_level1 = $homology1->subtype;
#         my $dn2 = $homology2->dn;
#         my $ds2 = $homology2->ds;
#         my $lnl2 = $homology2->lnl;
#         next unless (defined($dn2) && defined($ds2) && defined($lnl2));
#         my $peptide1_stable_id2 = $node_c->stable_id;
#         my $peptide2_stable_id2 = $node_d->stable_id;
#         my $gene1_stable_id2 = $node_c->gene_member->stable_id;
#         my $gene2_stable_id2 = $node_d->gene_member->stable_id;
#         my $temp2;
#         # Always match species order with species1 and
#         # species2 parameters in the output
#         if ($node_c->gene_member->genome_db->name eq $species2) {
#           $temp2 = $peptide1_stable_id2;
#           $peptide1_stable_id2 = $peptide2_stable_id2;
#           $peptide2_stable_id2 = $temp2;
#           $temp2 = $gene1_stable_id2;
#           $gene1_stable_id2 = $gene2_stable_id2;
#           $gene2_stable_id2 = $temp2;
#         }
#         my $taxonomy_level2 = $homology2->subtype;
#         my $results = "$root_id,$ancestor_node_id,$ancestor_taxon_name,$ancestor_taxon_hierarchy,$taxonomy_level1," .
#           "$peptide1_stable_id1,$gene1_stable_id1,$sp1_short_name," .
#             "$peptide2_stable_id1,$gene2_stable_id1,$sp2_short_name," .
#               "$dn1,$ds1,$lnl1,$num_duplications_a,";
#         $results .= "$taxonomy_level2," .
#           "$peptide1_stable_id2,$gene1_stable_id2,$sp1_short_name," .
#             "$peptide2_stable_id2,$gene2_stable_id2,$sp2_short_name," .
#               "$dn2,$ds2,$lnl2,$num_duplications_c\n";
#         print "$results" if ($self->{verbose});
#         print OUTFILE "$results";
#       }
#     }
#   }
# }

# sub _size_clusters {
#   my $self = shift;

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "size_clusters.". 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE "tree_id,root_taxon_name,num_leaves\n";
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     my $tree_id = $cluster->node_id;
#     my $root_taxon_name = $cluster->get_tagvalue("taxon_name");
#     unless (defined($root_taxon_name) && 0 != length($root_taxon_name)) {
#       $root_taxon_name = $cluster->get_tagvalue("name");
#     }
#     my $size = scalar(@{$cluster->get_all_leaves});
#     print OUTFILE "$tree_id,$root_taxon_name,$size\n";
#   }
# }


# sub _old_dnds_pairs {
#   my $self = shift;
#   my $species1 = shift;
#   my $species2 = shift;

#   $species1 =~ s/\_/\ /g;
#   $species2 =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#   my $sp1_short_name = $sp1_gdb->get_short_name;
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#   my $sp2_short_name = $sp2_gdb->get_short_name;
#   my $sp1_pair_short_name_list = 
#     join ("_", sort ($sp1_short_name,$sp1_short_name));
#   my $sp2_pair_short_name_list = 
#     join ("_", sort ($sp2_short_name,$sp2_short_name));
#   my $sp_pair = 
#     join ("_", sort ($sp1_short_name,$sp2_short_name));

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "dnds_pairs.". $sp1_short_name ."." . $sp2_short_name ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id1,subtree_id1,root_taxon1,peptide1_stable_id1,gene1_stable_id1,sp1_name1,peptide2_stable_id1,gene2_stable_id1,sp2_name1,dn1,ds1,lnl1,",
#       "tree_id2,subtree_id2,root_taxon2,peptide1_stable_id2,gene1_stable_id2,sp1_name2,peptide2_stable_id2,gene2_stable_id2,sp2_name2,dn2,ds2,lnl2\n";
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     # next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
#     my %member;
#     my %species;
#     my %species1_is_present;
#     my %species2_is_present;
#     my $member_copy;
#     foreach my $member (@{$cluster->get_all_leaves}) {
#       my $member_species_short_name = $member->genome_db->get_short_name;
#       my $member_stable_id = $member->stable_id;
#       $member{$member_stable_id}{gdb_short_name} = $member_species_short_name;
#       $member{$member_stable_id}{gene_stable_id} = $member->gene_member->stable_id;
#       if ($sp1_short_name eq $member_species_short_name) {
#         $species1_is_present{$member_stable_id} = 1;
#       } elsif ($sp2_short_name eq $member_species_short_name) {
#         $species2_is_present{$member_stable_id} = 1;
#       }
#       if (2 == scalar(keys(%species1_is_present)) && 2 == scalar(keys(%species2_is_present))) {
#         $member_copy = $member;
#         last;
#       }
#     }
#     my $tetrad_node;
#     if (2 == scalar(keys(%species1_is_present)) && 2 == scalar(keys(%species2_is_present))) {
#       $tetrad_node = $member_copy->parent; # should never fail
#       my $found_pair1 = 0;
#       my $found_pair2 = 0;
#       do {
#         eval { $tetrad_node = $tetrad_node->parent;} ;
#         last if ($@);
#         my $this_cluster_short_name_sps_list = join ("_", sort map { $_->genome_db->get_short_name } @{$tetrad_node->get_all_leaves});
#         $found_pair1 = 1 if ($this_cluster_short_name_sps_list =~ /$sp1_pair_short_name_list/);
#         $found_pair2 = 1 if ($this_cluster_short_name_sps_list =~ /$sp2_pair_short_name_list/);
#       } while (1 != $found_pair1 || 1!= $found_pair2);
#       if (1 == $found_pair1 && 1 == $found_pair2) {
#         $self->{'keep_leaves'} = (join ",", (keys %species2_is_present, keys %species1_is_present));
#         my $tetrad_minimized_tree = $self->keep_leaves($tetrad_node);
#         my ($child_a,$child_b) = @{$tetrad_minimized_tree->children};
#         my $child_a_short_name_sps_list = join ("_", sort map { $_->genome_db->get_short_name } @{$child_a->get_all_leaves});
#         my $child_b_short_name_sps_list = join ("_", sort map { $_->genome_db->get_short_name } @{$child_b->get_all_leaves});
#         if (($sp_pair eq $child_a_short_name_sps_list) && ($sp_pair eq $child_b_short_name_sps_list)) {
#           my $results = '';
#           my $tree_id = $cluster->node_id;
#           my $subtree_id = $tetrad_minimized_tree->node_id;
#           my $count = 0;
#           foreach my $sub_node (@{$tetrad_minimized_tree->children}) {
#             my ($leaf1,$leaf2) = @{$sub_node->children};
#             my $leaf1_gene_member = $leaf1->gene_member;
#             my $leaf2_gene_member = $leaf2->gene_member;
#             my @homologies = @{$self->{ha}->fetch_by_Member_Member_method_link_type
#                                  ($leaf1_gene_member, $leaf2_gene_member, 'ENSEMBL_ORTHOLOGUES')};
#             push @homologies, @{$self->{ha}->fetch_by_Member_Member_method_link_type
#                                   ($leaf1_gene_member, $leaf2_gene_member, 'ENSEMBL_PARALOGUES')};
#             throw("we shouldnt be getting more than 1 homology here") if (1 < scalar(@homologies));
#             foreach my $homology (@homologies) {
#               my $dn = $homology->dn;
#               my $ds = $homology->ds;
#               my $lnl = $homology->lnl;
#               if (defined($dn) && defined($ds) && defined($lnl)) {
#                 my $peptide1_stable_id = $leaf1->stable_id;
#                 my $peptide2_stable_id = $leaf2->stable_id;
#                 my $gene1_stable_id = $leaf1_gene_member->stable_id;
#                 my $gene2_stable_id = $leaf2_gene_member->stable_id;
#                 my $temp;
#                 # Always match species order with species1 and
#                 # species2 parameters in the output
#                 if ($leaf1_gene_member->genome_db->name eq $species2) {
#                   $temp = $peptide1_stable_id;
#                   $peptide1_stable_id = $peptide2_stable_id;
#                   $peptide2_stable_id = $temp;
#                   $temp = $gene1_stable_id;
#                   $gene1_stable_id = $gene2_stable_id;
#                   $gene2_stable_id = $temp;
#                 }
#                 my $taxonomy_level = $homology->subtype;
#                 $results .= "$tree_id,$subtree_id,$taxonomy_level," .
#                   "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name," .
#                     "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name," .
#                       "$dn,$ds,$lnl";
#                 (0 == $count) ? ($results .= ",") : ($results .= "\n");
#                 print "$results" if ($self->{verbose} && (0 != $count));
#               }
#             }
#             $count++;
#           }
#         }
#       }
#     }
#   }
# }

# sub _duphop_subtrees {
#   my $self = shift;
#   my $species = shift;
#   my $subtree_subtype = shift;

#   my $regexp = qr/${subtree_subtype}/i;
#   $self->{starttime} = time();
#   $species =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my $sp_short_name = $sp_gdb->get_short_name;
#   my $gdb_id = $sp_gdb->dbID;
#   my $sp_gdb_taxon_id = $sp_gdb->taxon_id;
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   my $tree_node_id;
#   my @clusters;
#   my $sth;
#   unless ($self->{debug}) {
#     my $sql = "select distinct(h.tree_node_id) from species_set ss, method_link_species_set mlss, method_link ml, homology h where ss.genome_db_id=$gdb_id and ml.type in('ENSEMBL_ORTHOLOGUES','ENSEMBL_PARALOGUES') and ss.species_set_id=mlss.species_set_id and ml.method_link_id=mlss.method_link_id and h.method_link_species_set_id=mlss.method_link_species_set_id";
#     $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     print STDERR "[$sp_short_name trees] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     while ($tree_node_id = $sth->fetchrow_array()) {
#       my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_node_id);
#       next unless (defined($tree));
#       push @clusters, $tree;
#     }
#   } else {
#     my @all_clusters = @{$self->{'clusterset'}->children};
#     print STDERR "[filtering trees old way] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     foreach my $cluster (@all_clusters) {
#       foreach my $leaf (@{$cluster->get_all_leaves}) {
#         if ($leaf->taxon_id == $sp_gdb_taxon_id) {
#           push @clusters, $cluster;
#           last;
#         }
#       }
#     }
#     print STDERR "[filtering trees old way] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   }

#   print STDERR "[load trees] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   $sth->finish() unless ($self->{debug});
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "duphop_subtrees.". $sp_short_name ."." . $subtree_subtype . "." .
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id,root_taxon,gene_stable_id,sp_name,duphop,totalhop,consecdup\n";
#   print "tree_id,root_taxon,gene_stable_id,sp_name,duphop,totalhop,consecdup\n" if ($self->{verbose});
  
#   my %member;
#   my @subtrees;
#   my $printable_subtree_subtype = $subtree_subtype;
#   $printable_subtree_subtype =~ s/\//\_/g;$printable_subtree_subtype =~ s/\ /\_/g;

#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));

#     # Abusing a map here to do a first filtering of subtree_subtype
#     next unless (join (":",map { $_->get_tagvalue("taxon_name") unless ($_->is_leaf) } $cluster->get_all_subnodes) =~ /$regexp/);

#     foreach my $leaf (@{$cluster->get_all_leaves}) {
#       my $cluster_node_id = $cluster->node_id;
#       next unless ($leaf->taxon_id == $sp_gdb_taxon_id);
#       # Do the count for this gene if within subtree_subtype
#       my $parent = $leaf;
#       my $parent_of_subtree_subtype;
#       do {
#         $parent = $parent->parent;
#         my $taxon_name = $parent->get_tagvalue("taxon_name");
#         if ($taxon_name eq $subtree_subtype) {
#           $parent_of_subtree_subtype = $parent;
#         }
#         last if ($parent->node_id == $cluster_node_id);
#         eval {$self->{dummy} = $parent->parent->node_id;};
#         if ($@) {
#           print "error: ",$parent->node_id, "\n";
#           print "error: ",$cluster_node_id, "\n";
#         }
#         ;
#       } while ($parent->parent->node_id != $cluster_node_id);
#       # the root if it is of the right subtree_subtype
#       if ($parent->parent->get_tagvalue("taxon_name") eq $subtree_subtype) {
#         $parent_of_subtree_subtype = $parent->parent;
#       }

#       my $duphop = 0;
#       my $totalhop = 0;
#       my $consecutive_duphops = 0;
#       my $max_consecdups = 0;
#       if (defined($parent_of_subtree_subtype)) {
#         my $parent = $leaf;
#         my $done = 0;
#         do {
#           $parent = $parent->parent;
#           my $duplication = $parent->get_tagvalue("Duplication") || 0;
#           if (1 == $duplication || 2 == $duplication) {
#             $duphop++;
#             $consecutive_duphops++;
#           } else {
#             $max_consecdups = $consecutive_duphops if ($consecutive_duphops > $max_consecdups);
#             $consecutive_duphops = 0;
#           }
#           $totalhop++;
#           # This last is for cases where we only hop once -- subtype is unique and next to the root
#           if ($parent->node_id == $parent_of_subtree_subtype->node_id) {
#             $done = 1;
#           }
#         } while (1 != $done && ($parent->parent->node_id != $parent_of_subtree_subtype->node_id));
#         $member{$leaf->stable_id}{duphop} = $duphop;
#         $member{$leaf->stable_id}{totalhop} = $totalhop;
#         my $results = $cluster_node_id . 
#           "," . 
#             $printable_subtree_subtype . 
#               "," . 
#                 $leaf->gene_member->stable_id . 
#                   "," . 
#                     $sp_short_name . 
#                       "," . 
#                         $member{$leaf->stable_id}{duphop} . 
#                           "," . 
#                             $member{$leaf->stable_id}{totalhop} . 
#                               "," . 
#                                 $max_consecdups;
#         $duphop = 0;
#         $totalhop = 0;
#         print OUTFILE "$results\n";
#         print "$results\n" if ($self->{verbose});
#       }
#     }
#   }
# }

# sub _duphop_subtrees_global {
#   my $self = shift;
#   my $species = shift;
#   my $subtree_subtype = shift;

#   my $regexp = qr/${subtree_subtype}/i;
#   $self->{starttime} = time();
#   $species =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my $sp_short_name = $sp_gdb->get_short_name;
#   my $gdb_id = $sp_gdb->dbID;
#   my $sp_gdb_taxon_id = $sp_gdb->taxon_id;
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();

#   my $tree_node_id;
#   my @clusters;
#   my $sth;
#   unless ($self->{debug}) {
#     my $sql = "select distinct(h.tree_node_id) from species_set ss, method_link_species_set mlss, method_link ml, homology h where ss.genome_db_id=$gdb_id and ml.type in('ENSEMBL_ORTHOLOGUES','ENSEMBL_PARALOGUES') and ss.species_set_id=mlss.species_set_id and ml.method_link_id=mlss.method_link_id and h.method_link_species_set_id=mlss.method_link_species_set_id";
#     $sth = $self->{comparaDBA}->dbc->prepare($sql);
#     $sth->execute();
#     print STDERR "[$sp_short_name trees] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     while ($tree_node_id = $sth->fetchrow_array()) {
#       my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_node_id);
#       next unless (defined($tree));
#       push @clusters, $tree;
#     }
#   } else {
#     my @all_clusters = @{$self->{'clusterset'}->children};
#     print STDERR "[filtering trees old way] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#     foreach my $cluster (@all_clusters) {
#       foreach my $leaf (@{$cluster->get_all_leaves}) {
#         if ($leaf->taxon_id == $sp_gdb_taxon_id) {
#           push @clusters, $cluster;
#           last;
#         }
#       }
#     }
#     print STDERR "[filtering trees old way] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   }

#   print STDERR "[load trees] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#   $sth->finish() unless ($self->{debug});
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "duphop_subtrees_global.". $sp_short_name ."." . $subtree_subtype . "." .
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id,subtree_id,duphop,totalhop,mean_sistag,with_repr,gene_ids\n";
#   print "tree_id,subtree_id,duphop,totalhop,mean_sistag,gene_ids\n" if ($self->{verbose});

#   my $outfile2 = "duphop_subtrees_global.bygene.". $sp_short_name ."." . $subtree_subtype . "." .
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile2 .= ".csv";
#   open OUTFILE2, ">$outfile2" or die "error opening outfile: $!\n";
#   print OUTFILE2 
#     "gene_ids,duphop,totalhop,mean_sistag\n";


#   # Cache all the species-level names
#   foreach my $gdb (@{$self->{comparaDBA}->get_GenomeDBAdaptor->fetch_all}) {
#     $self->{gdbs}{$gdb->name} = 1;
#   }

#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));

#     my $subtype_count = 0;
#     my %subtree_index;
#     my %subtrees;
#     my %final_subtrees;
#     foreach my $subnode ($cluster->get_all_subnodes) {
#       next if ($subnode->is_leaf);
#       my $taxon_name = $subnode->get_tagvalue("taxon_name");
#       if ($taxon_name eq $subtree_subtype) {
#         $subtype_count++;
#         $subtree_index{left_index}{$subnode->left_index} = $subnode->node_id;
#         $subtree_index{right_index}{$subnode->right_index} = $subnode->node_id;
#         $subtree_index{diff}{$subnode->left_index}{$subnode->right_index - $subnode->left_index} = $subnode->node_id;
#         $subtrees{$subnode->node_id}{left_index} = $subnode->left_index;
#         $subtrees{$subnode->node_id}{right_index} = $subnode->right_index;
#         $subtrees{$subnode->node_id}{diff} = $subnode->right_index - $subnode->left_index;
#       }
#     }
#     next if (0 == $subtype_count);

#     if (1 == $subtype_count) {
#       my @dummy = keys %subtrees;
#       $final_subtrees{$dummy[0]} = 1;
#     }

#     if ($subtype_count > 1) {
#       my $final_subtree_left;
#       foreach my $left_index (sort {$a<=>$b} keys %{$subtree_index{left_index}}) {
#         my $subnode = $subtree_index{left_index}{$left_index};
#         my $right_index = $subtrees{$subnode}{right_index};
#         # Right now this is the final -- see if there is a smaller one
#         $final_subtree_left = $left_index;
#         foreach my $smaller_subtree_right 
#           (sort {$a<=>$b } map { if ($_ < $right_index) {$_} else {-1} } keys %{$subtree_index{right_index}}) {
#           # Dont look at non overlapping subtrees by right
#           next if (-1 == $smaller_subtree_right);
#           # Dont look at non overlapping subtrees by left
#           next if ($smaller_subtree_right < $left_index);
#           my $subnode = $subtree_index{right_index}{$smaller_subtree_right};
#           # Found a new smaller subtree within
#           $final_subtree_left = $subtrees{$subnode}{left_index};
#         }
#         my $final_subtree_id = $subtree_index{left_index}{$final_subtree_left};
#         # Store list of non-overlapping and minimal subtrees
#         $final_subtrees{$final_subtree_id} = 1;
#       }
#     }

#     foreach my $subtree (keys %final_subtrees) {
#       my $subcluster = $self->{treeDBA}->fetch_node_by_node_id($subtree);
#       die "$!\n" unless (defined($subcluster));
#       my $subcluster_node_id = $subcluster->node_id;
#       my $duphop = 0;
#       my $totalhop = 0;
#       my @species_ids;
#       my $mean_sistag = 0;
#       foreach my $this_node ($subcluster->get_all_subnodes) {
#         if ($this_node->is_leaf) {
#           my $taxon_name = $this_node->taxon->name;
#           if ($taxon_name eq $species) {
#             push @species_ids, $this_node->gene_member->stable_id;
#             next;
#           }
#         }
#         my $taxon_name = $this_node->get_tagvalue("taxon_name");
#         if (defined($self->{gdbs}{$taxon_name})) {
#           next;
#         }
#         my $duptag = $this_node->get_tagvalue("Duplication");
#         my $sistag = $this_node->get_tagvalue("duplication_confidence_score");
#         if ($duptag ne "") {
#           if ($duptag > 0) {
#             $DB::single=1;1;
#             if ($sistag > 0) {
#               $mean_sistag += $sistag;
#               $duphop++;
#             }
#           }
#         }
#         $totalhop++;
#       }
#       unless ($mean_sistag == 0) {
#         $mean_sistag = $mean_sistag/$duphop;
#       }
#       if ($duphop == 0) {
#         $mean_sistag = 1;
#       }

#       foreach my $id (@species_ids) {
#         print OUTFILE2 "$id,$duphop,$totalhop,$mean_sistag\n";
#       }
#       my $gene_ids_list = join(":",@species_ids);
#       my $with_repr = 0; $with_repr = 1 if (length($gene_ids_list)>0);
#       my $results = $cluster->node_id . 
#         "," . 
#           $subcluster_node_id . 
#             "," . 
#               $duphop . 
#                 "," . 
#                   $totalhop . 
#                     "," . 
#                       $mean_sistag . 
#                         "," . 
#                           $with_repr . 
#                             "," . 
#                               $gene_ids_list;
#       $duphop = 0;
#       $totalhop = 0;
#       print OUTFILE "$results\n";
#       print "$results\n" if ($self->{verbose});
#       $subcluster->release_tree;
#     }
#     $cluster->release_tree;
#   }
# }


# sub _duphop {
#   my $self = shift;
#   my $species = shift;

#   $species =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my $sp_short_name = $sp_gdb->get_short_name;

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "duphop.". $sp_short_name ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id,root_taxon,peptide_stable_id,gene_stable_id,gene_chr_name,sp_name,duphop,totalhop,consecdup\n";
#   print "tree_id,peptide_stable_id,gene_stable_id,gene_chr_name,sp_name,duphop,totalhop\n" if ($self->{verbose});
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     # next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
#     my %member;
#     my %species;
#     my $species_is_present = 0;
#     foreach my $member (@{$cluster->get_all_leaves}) {
#       my $member_species_short_name = $member->genome_db->get_short_name;
#       my $member_stable_id = $member->stable_id;
#       $member{$member_stable_id}{gdb_short_name} = $member_species_short_name;
#       my $gene_member = $member->gene_member;
#       $member{$member_stable_id}{gene_stable_id} = $gene_member->stable_id;
#       $member{$member_stable_id}{gene_chr_name} = $gene_member->chr_name;
#       if ($sp_short_name eq $member_species_short_name) {
#         $species_is_present = 1;
#         my $duphop = 0;
#         my $totalhop = 0;
#         my $consecutive_duphops = 0;
#         my $max_consecdups = 0;
#         my $parent = $member;
#         do {
#           $parent = $parent->parent;
#           my $duplication = $parent->get_tagvalue("Duplication");
#           if (1 == $duplication || 2 == $duplication) {
#             $duphop++;
#             $consecutive_duphops++;
#           } else {
#             $max_consecdups = $consecutive_duphops if ($consecutive_duphops > $max_consecdups);
#             $consecutive_duphops = 0;
#           }
#           $totalhop++;
#           $member{$member_stable_id}{duphop} = $duphop;
#           $member{$member_stable_id}{totalhop} = $totalhop;
#         } while ($parent->parent->node_id != $self->{'clusterset_id'});
#         my $root_taxon = $cluster->get_tagvalue("taxon_name");
#         $root_taxon =~ s/\//\_/g;$root_taxon =~ s/\ /\_/g;
#         my $results = $cluster->node_id . 
#           "," . 
#             $root_taxon . 
#               "," . 
#                 $member_stable_id . 
#                   "," . 
#                     $member{$member_stable_id}{gene_stable_id} . 
#                       "," . 
#                         $member{$member_stable_id}{gene_chr_name} . 
#                           "," . 
#                             $member{$member_stable_id}{gdb_short_name} . 
#                               "," . 
#                                 $member{$member_stable_id}{duphop} . 
#                                   "," . 
#                                     $member{$member_stable_id}{totalhop} . 
#                                       "," . 
#                                         $max_consecdups;
#         $duphop = 0;
#         $totalhop = 0;
#         print OUTFILE "$results\n";
#         print "$results\n" if ($self->{verbose});
#       }
#     }
#   }
# }


# # internal purposes
# sub _gap_contribution {
#   my $self = shift;
#   my $species = shift;

#   $species =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my $sp_short_name = $sp_gdb->get_short_name;

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "gap_contribution.". $sp_short_name ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id,peptide_stable_id,gene_stable_id,genome_db_id,gap_contribution,total_length\n";
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     next if ('2' eq $cluster->get_tagvalue('gene_count'));
#     next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
#     my %member;
#     my $species_is_present = 0;
#     foreach my $member (@{$cluster->get_all_leaves}) {
#       my $member_species_short_name = $member->genome_db->get_short_name;
#       $member{$member->stable_id}{gdb_short_name} = $member_species_short_name;
#       $member{$member->stable_id}{gene_stable_id} = $member->gene_member->stable_id;
#       $species_is_present = 1 if($sp_short_name eq $member_species_short_name);
#     }
#     next unless (1 == $species_is_present);
#     my $dummy_aln = $cluster->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 0,
#        -stop2x => 1
#       );

#     # Purge seqs one by one
#     my $before_length; my $after_length;
#     foreach my $dummy_seq ($dummy_aln->each_seq) {
#       next unless ($member{$dummy_seq->display_id}{gdb_short_name} eq $sp_short_name);
#       my $aln = $cluster->get_SimpleAlign
#         (
#          -id_type => 'STABLE',
#          -cdna => 0,
#          -stop2x => 1
#         );
#       my %seqs;
#       foreach my $seq ($aln->each_seq) {
#         $seqs{$seq->display_id} = $seq;
#       }
#       $before_length = $aln->length;
#       $aln->remove_seq($seqs{$dummy_seq->display_id});
#       $aln = $aln->remove_gaps('', 1);
#       $after_length = $aln->length;
#       my $display_id = $dummy_seq->display_id;
#       my $simple_seq_gap_contrib = 1 - ($after_length/$before_length);
#       my $results = 
#         $cluster->subroot->node_id . 
#           "," . 
#             $display_id . 
#               "," . 
#                 $member{$dummy_seq->display_id}{gene_stable_id} . 
#                   "," . 
#                     $member{$dummy_seq->display_id}{gdb_short_name} . 
#                       "," . 
#                         sprintf("%03f",$simple_seq_gap_contrib) . 
#                           "," . 
#                             $before_length . 
#                               "\n";
#       print OUTFILE $results;
#       print $results if ($self->{verbose});
#     }
#     1;
#   }
# }

# # internal purposes
# sub _per_residue_g_contribution {
#   my $self = shift;
#   my $species = shift;
#   my $gap_proportion = shift;
#   my $modula = shift;
#   my $farm = shift;

#   $species =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   my $sp_gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my $sp_short_name = $sp_gdb->get_short_name;

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $pmodula = sprintf("%04d",$modula);
#   my $outfile = "rgap_contribution." . $sp_short_name . "." . $pmodula . ".". 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id,peptide_stable_id,gene_stable_id,sp_name,aln_rgap_contribution,rgap_contribution,total_length\n";
#   my $tree_id;
#   foreach my $cluster (@clusters) {
#     $tree_id = $cluster->subroot->node_id;
#     next unless ($tree_id % $farm == ($modula-1)); # this divides the jobs by tree_id
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     next if ('2' eq $cluster->get_tagvalue('gene_count'));
#     next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
#     next if ();
#     my %member;
#     my $species_is_present = 0;
#     foreach my $member (@{$cluster->get_all_leaves}) {
#       my $member_species_short_name = $member->genome_db->get_short_name;
#       $member{$member->stable_id}{gdb_short_name} = $member_species_short_name;
#       $member{$member->stable_id}{gene_stable_id} = $member->gene_member->stable_id;
#       $species_is_present = 1 if($sp_short_name eq $member_species_short_name);
#     }
#     next unless (1 == $species_is_present);

#     my $dummy_aln = $cluster->get_SimpleAlign
#       (
#        -id_type => 'STABLE',
#        -cdna => 0,
#        -stop2x => 1
#       );
#     # Purge seqs one by one
#     my $before_length; my $after_length;
#     foreach my $dummy_seq ($dummy_aln->each_seq) {
#       next unless ($member{$dummy_seq->display_id}{gdb_short_name} eq $sp_short_name);
#       my $aln = $cluster->get_SimpleAlign
#         (
#          -id_type => 'STABLE',
#          -cdna => 0,
#          -stop2x => 1
#         );
#       my %seqs;
#       foreach my $seq ($aln->each_seq) {
#         $seqs{$seq->display_id} = $seq;
#       }

#       my $display_id = $dummy_seq->display_id;
#       my $seq_string = $dummy_seq->seq;
#       $seq_string =~ s/\-//g;
#       my $gap_count = 0;
#       my $aln_no_sequences = $aln->no_sequences;
#       my $aln_no_residues = $aln->no_residues;
#       $aln->verbose(-1);
#       for my $seq_coord (1..length($seq_string)) {
#         my $aln_coord = $aln->column_from_residue_number($display_id, $seq_coord);
#         my $column_aln = $aln->slice($aln_coord,$aln_coord);
#         my $column_no_gaps = $aln_no_sequences - $column_aln->no_residues;
#         my $column_aln_no_residues = $column_aln->no_residues;
#         my $residue_proportion = $column_aln_no_residues/$aln_no_sequences if (0 != $column_aln_no_residues);
#         $residue_proportion = 0 if (0 == $column_aln_no_residues);
#         if ($gap_proportion < (1-$residue_proportion)) {
#           $gap_count += $column_no_gaps;
#         }
#       }
#       my $aln_length = $aln->length;
#       my $per_residue_aln_gap_contrib = $gap_count/(($aln_length)*$aln_no_sequences) if (0 != $gap_count);
#       $per_residue_aln_gap_contrib = 0 if (0 == $gap_count);
#       my $per_residue_gap_contrib = $gap_count/(($aln_length*$aln_no_sequences)-$aln_no_residues) if (0 != $gap_count);
#       $per_residue_gap_contrib = 0 if (0 == $gap_count);
#       my $results = 
#         $tree_id .
#           "," . 
#             $display_id . 
#               "," . 
#                 $member{$dummy_seq->display_id}{gene_stable_id} . 
#                   "," . 
#                     $member{$dummy_seq->display_id}{gdb_short_name} . 
#                       "," . 
#                         sprintf("%03f",$per_residue_aln_gap_contrib) . 
#                           "," . 
#                             sprintf("%03f",$per_residue_gap_contrib) . 
#                               "," . 
#                                 $aln_length . 
#                                   "\n";
#       print OUTFILE $results;
#       print $results if ($self->{verbose});
#     }
#     1;
#   }
# }


# # internal purposes
# sub _count_dups_in_subtree {
#   my $node = shift;

#   my (@duptags) = 
#     map {$_->get_tagvalue('Duplication')} $node->get_all_subnodes;
#   my $duptags = 0; 
#   foreach my $duptag (@duptags) {
#     $duptags++ if (0 != $duptag);
#   }

#   return $duptags;
# }

# # internal purposes
# sub _distances_taxon_level {
#   my $self = shift;
#   my $species = shift;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

#   my $sp_db = $self->{gdba}->fetch_by_name_assembly($species);
#   my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs("ENSEMBL_PARALOGUES",[$sp_db]);
#   my $homologies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss);
#   print "root_tree_id,peptide_a,distance_a,peptide_b,distance_b,taxonomy_level\n";
#   foreach my $homology (@{$homologies}) {
#     my $hom_subtype = $homology->description;
#     next unless ($hom_subtype =~ /^within_species_paralog/);
#     my @two_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology->gene_list};
#     my $leaf_node_id = $homology->node_id;
#     my $tree = $self->{treeDBA}->fetch_node_by_node_id($leaf_node_id);
#     my $node_a = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($two_ids[0],$self->{'clusterset_id'});
#     my $node_b = $self->{treeDBA}->fetch_AlignedMember_by_member_id_root_id($two_ids[1],$self->{'clusterset_id'});
#     my $root = $node_a->subroot;
#     $root->merge_node_via_shared_ancestor($node_b);
#     my $ancestor = $node_a->find_first_shared_ancestor($node_b);
#     my $distance_a = $node_a->distance_to_ancestor($ancestor);
#     my $distance_b = $node_b->distance_to_ancestor($ancestor);
#     my $sorted_node_id_a = $node_a->stable_id;
#     my $sorted_node_id_b = $node_b->stable_id;
#     if ($distance_b < $distance_a) {
#       $distance_a = $distance_b;
#       my $temp;
#       $temp = $sorted_node_id_a;
#       $sorted_node_id_a = $sorted_node_id_b;
#       $sorted_node_id_b = $temp;
#     }
#     my $subtype = $homology->subtype;
#     $subtype =~ s/\///g; $subtype =~ s/\ /\_/g;
#     print $root->node_id, ",$sorted_node_id_a,$distance_a,$sorted_node_id_b,$distance_b,", $subtype, "\n";
#     $root->release_tree;
#   }
# }

# sub _consistency_orthotree {
#   my $self = shift;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   my $mlss = $self->{mlssa}->fetch_by_dbID($self->{_consistency_orthotree_mlss});
#   my @species_set_ids = map {$_->dbID} @{$mlss->species_set};
#   foreach my $leaf (@{$self->{tree}->get_all_leaves}) {
#     next unless ($leaf->genome_db->dbID == $species_set_ids[0] || $leaf->genome_db->dbID == $species_set_ids[1]);
#     my $leaf_name = $leaf->name;
#     $self->{'keep_leaves'} .= $leaf_name . ",";
#   }
#   $self->{keep_leaves} =~ s/\,$//;
#   keep_leaves($self);
#   $self->{tree}->print_tree(20) if ($self->{debug});
#   _run_orthotree($self);
# }

# sub _homologs_and_dnaaln {
#   my $self = shift;
#   my $species1 = shift;
#   my $species2 = shift;

#   $species1 =~ s/\_/\ /g;
#   $species2 =~ s/\_/\ /g;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   my $sp1_gdb = $self->{gdba}->fetch_by_name_assembly($species1);
#   my $sp1_short_name = $sp1_gdb->get_short_name;
#   my $sp2_gdb = $self->{gdba}->fetch_by_name_assembly($species2);
#   my $sp2_short_name = $sp2_gdb->get_short_name;
#   my $sp1_pair_short_name_list = 
#     join ("_", sort ($sp2_short_name,$sp2_short_name));
#   my $sp2_pair_short_name_list = 
#     join ("_", sort ($sp2_short_name,$sp2_short_name));

#   my @clusters = @{$self->{'clusterset'}->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $outfile = "h_dnaaln.". $sp1_short_name ."." . $sp2_short_name ."." . 
#     $self->{_mydbname} . "." . $self->{'clusterset_id'};
#   $outfile .= ".csv";
#   open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#   print OUTFILE 
#     "tree_id,subtree_id,root_taxon,peptide1_stable_id,gene1_stable_id,sp1_name,peptide2_stable_id,gene2_stable_id,sp2_name,present_in_aln,in_frame\n";
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     # next if ((51 <= $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
#     my %member;
#     my %species;
#     my %species1_is_present;
#     my %species2_is_present;
#     foreach my $member (@{$cluster->get_all_leaves}) {
#       my $member_species_short_name = $member->genome_db->get_short_name;
#       my $member_stable_id = $member->stable_id;
#       $member{$member_stable_id}{gdb_short_name} = $member_species_short_name;
#       $member{$member_stable_id}{gene_stable_id} = $member->gene_member->stable_id;
#       if ($sp1_short_name eq $member_species_short_name) {
#         $species1_is_present{$member_stable_id} = 1;
#       } elsif ($sp2_short_name eq $member_species_short_name) {
#         $species2_is_present{$member_stable_id} = 1;
#       }
#     }

#     if (1 <= scalar(keys(%species1_is_present)) && 1 <= scalar(keys(%species2_is_present))) {
#       foreach my $member (@{$cluster->get_all_leaves}) {
#         1;
#       }
#       #       my $peptide1_stable_id = $leaf1->stable_id;
#       #       my $peptide2_stable_id = $leaf2->stable_id;
#       #       my $gene1_stable_id = $leaf1_gene_member->stable_id;
#       #       my $gene2_stable_id = $leaf2_gene_member->stable_id;
#       #       my $taxonomy_level = $homology->subtype;
#       #       print OUTFILE "$tree_id,$subtree_id,$taxonomy_level,", 
#       #         "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name,",
#       #           "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name,",
#       #             "$dn,$ds,$lnl\n";
#       #       print "$tree_id,$subtree_id,$taxonomy_level,", 
#       #         "$peptide1_stable_id,$gene1_stable_id,$sp1_short_name,",
#       #           "$peptide2_stable_id,$gene2_stable_id,$sp2_short_name,",
#       #             "$dn,$ds,$lnl\n" if ($self->{verbose});
#     }
#   }
# }

# sub _run_gblocks_percent {
#   my $root = shift;
#   my $total_length = shift;

#   print STDERR $root->node_id,"\n";
#   my $aln = $root->get_SimpleAlign;
#   my $aln_length = $aln->length;
#   my $tree_id = $root->node_id;
#   my $filename = "/tmp/$tree_id.fasta";
#   my $tmpfile = Bio::AlignIO->new
#     (-file => ">$filename",
#      -format => 'fasta');
#   $tmpfile->write_aln($aln);
#   $tmpfile->close;
#   my $min_leaves_gblocks = ($root->num_leaves+1)/2;
#   my $cmd = "echo -e \"o\n$filename\nb\n2\n$min_leaves_gblocks\n5\n5\ng\nm\nq\n\" | /nfs/acari/avilella/src/gblocks/Gblocks_0.91b/Gblocks 2>/dev/null 1>/dev/null";
#   my $ret = system("$cmd");
#   #   my $flanks = `grep Flanks $filename-gb.htm`;
#   #   my $segments_string = $flanks;
#   #   $segments_string =~ s/Flanks\: //g;
#   my $aln_coef = $aln_length/$total_length;
#   my $percent_string = `grep original $filename-gb.htm`;
#   unlink </tmp/$tree_id.fasta*>;
#   $percent_string =~ /(\d+)% of the original/;
#   my $percent = $1;
#   $percent = $percent*$aln_coef;

#   return $percent;
# }


# sub _run_gblocks {
#   my $root = shift;
#   my $gmin = shift;

#   my $aln;
#   my $min_leaves_gblocks;
#   if ($root->isa('Bio::SimpleAlign')) {
#     $aln = $root;
#     $min_leaves_gblocks = int(($root->no_sequences+1) * $gmin + 0.5);
#   } else {
#     $aln = $root->get_SimpleAlign;
#     $min_leaves_gblocks = int(($root->num_leaves+1) * $gmin + 0.5);
#   }
#   my $aln_length = $aln->length;
#   my $filename = "/tmp/tmp.fasta";
#   my $tmpfile = Bio::AlignIO->new
#     (-file => ">$filename",
#      -format => 'fasta');
#   $tmpfile->write_aln($aln);
#   $tmpfile->close;
#   my $cmd = "echo -e \"o\n$filename\nb\n2\n$min_leaves_gblocks\n5\n5\ng\nm\nq\n\" | /nfs/acari/avilella/src/gblocks/Gblocks_0.91b/Gblocks 2>/dev/null 1>/dev/null";
#   my $ret = system("$cmd");
#   my $flanks = `grep Flanks $filename-gb.htm`;
#   my $segments_string = $flanks;
#   $segments_string =~ s/Flanks\: //g;
#   unlink </tmp/tmp.fasta*>;

#   return $segments_string;
# }

# sub _tree_bootstrap_dupconf {
#   my $self = shift;
#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   my $type = $self->{debug} || "SIS1";
#   my $gmin = $self->{_gmin} || 0.5;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $file = $self->{_tree_bootstrap_dupconf};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     next if ($_ eq '');
#     $self->{_ids}{$_} = 1;
#   }

#   print "tree_id,subnode_id,tree_dup,tree_subnodes,tree_spec,dupconf,bootstrap,min_dist_parent,dist_parent,dist_leaves,root_gblocks,subtree_gblocks,subtree_local_gblocks,num_leaves,gene_count,aln_length,global_hsap_mmus_dndses,hsap_mmus_dndses,genes,gene_link\n";
#   foreach my $root_id (keys %{$self->{_ids}}) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     next unless (defined($root));
#     next if ('1' eq $root->get_tagvalue('cluster_had_to_be_broken_down'));
#     my $aln = $root->get_SimpleAlign;
#     my $aln_length = $aln->length;
#     my $tree_id = $root->node_id;

#     my $flanks_gblocks = _run_gblocks($root,$gmin);
#     my $root_flank_length = 0;
#     foreach my $segment ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#       my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#       $root_flank_length += $end-$start+1;
#     }

#     my $gene_count = $root->get_tagvalue("gene_count");
#     my @genes;

#     my @has_human;
#     my @has_mouse;
#     my $average_dnds;
#     foreach my $leaf (@{$root->get_all_leaves}) {
#       my $taxon_name = $leaf->taxon->name;
#       if ($taxon_name eq 'Mus musculus') {
#         push @has_mouse, $leaf->stable_id;
#       }
#       if ($taxon_name eq 'Homo sapiens') {
#         push @has_human, $leaf;
#         push @genes, $leaf->stable_id;
#       }
#     }
#     if ( 0 < scalar(@has_mouse) && 0 < scalar(@has_human) ) {
#       my $homh;
#       foreach my $member (@has_human) {
#         foreach my $homology (@{$self->{ha}->fetch_all_by_Member_paired_species($member->gene_member, "Mus_musculus")}) {
#           $homh->{$homology->dbID} = $homology;
#         }
#         my $num_dnds = 0; my $den_dnds = 0;
#         foreach my $homology_id (keys %{$homh}) {
#           my $homology = $homh->{$homology_id};
#           my $dnds = $homology->dnds_ratio;
#           $num_dnds += $dnds if (defined($dnds));
#           $den_dnds++ if (defined($dnds));
#         }
#         if ($den_dnds > 0) {
#           $average_dnds->{$member->stable_id} = $num_dnds/$den_dnds;
#         }
#       }
#     }
#     my $tree_dup = 0;
#     my $tree_spec = 0;
#     my $tree_subnodes = 0;
#     foreach my $subnode ($root->get_all_subnodes) {
#       next if ($subnode->is_leaf);
#       $tree_subnodes++;
#       $tree_spec++;
#       my $subtree_flank_length = -1;

#       my $num_leaves = $subnode->num_leaves;
#       my $dupconf = $subnode->get_tagvalue($type);
#       my $bootstrap = $subnode->get_tagvalue("Bootstrap");
#       my $dupl = $subnode->get_tagvalue("Duplication");
#       my $dd = $subnode->get_tagvalue("dubious_duplication");
#       if ($dd ne '') {
#         next if (1 == $dd);
#       }
#       next unless ($dupl ne '');
#       next unless (0 != $dupl);
#       next unless (defined($dupconf) && $dupconf ne '');
#       $tree_dup++; $tree_spec--;
#       next unless (defined($bootstrap) && $bootstrap ne '');
#       my $subnode_id = $subnode->node_id;

#       # Run it on subnode
#       my $subnode_flanks_gblocks = _run_gblocks($subnode,$gmin);
#       my $subnode_flank_length = 0;
#       if ($subnode_flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#         foreach my $segment ($subnode_flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#           my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#           $subnode_flank_length += $end-$start+1;
#         }
#       }
#       # end subnode
#       my $dist_leaves;
#       my $leaf_count;
#       foreach my $leaf (@{$subnode->get_all_leaves}) {
#         $dist_leaves += $leaf->distance_to_ancestor($subnode);
#         $leaf_count++;
#       }
#       $dist_leaves = $dist_leaves/$leaf_count unless ($dist_leaves == 0);

#       my $dist_parent;
#       my $min_dist_parent = 999;
#       foreach my $subsubnode (@{$subnode->children}) {
#         my $dist = $subsubnode->distance_to_parent;
#         $dist_parent += $dist;
#         $min_dist_parent = $dist if ($dist < $min_dist_parent);
#         my $subsubtree_flank_length = 0;
#         my @leaves = @{$subsubnode->get_all_leaves};
#         # my @leaves = @{$subsubnode->get_all_leaves_indexed};
#         my $numseq = scalar(@leaves);
#         while (my $leaf = shift @leaves) {
#           my @seqs = $aln->each_seq_with_id($leaf->stable_id);
#           if ($flanks_gblocks =~ /\[\d+  \d+\]/g) {
#             foreach my $segment ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#               my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#               my $subseq = $seqs[0]->subseq($start,$end);
#               $subseq =~ s/\-//g;
#               $subsubtree_flank_length += length($subseq);
#             }
#           }
#         }
#         $subtree_flank_length = ($subsubtree_flank_length/$numseq) if ($subtree_flank_length < ($subsubtree_flank_length/$numseq));
#         # print STDERR "$subnode_id,$subtree_flank_length\n";
#       }
#       my $percent_gblocks = 0;
#       $dist_parent = $dist_parent/2 unless ($dist_parent == 0);
#       my @dndses;
#       my $global_dnds = 0; my $den_global_dnds = 0;
#       foreach my $gene (@genes) {
#         push @dndses, $average_dnds->{$gene};
#         $global_dnds += $average_dnds->{$gene};
#         $den_global_dnds++;
#       }
#       $global_dnds = $global_dnds/$den_global_dnds if ($den_global_dnds > 0);
#       my $dndses = join(":",@dndses); $dndses = 'na' if (0 == length($dndses));
#       my $genes = join(":",@genes); $genes = 'na' if (0 == length($genes));
#       my $gene_link;
#       if (0 == scalar(@genes)) {
#         $gene_link = 'na';
#       } else {
#         $gene_link = 'http://www.ensembl.org/human/genetreeview?peptide=' . shift(@genes);
#       }
#       print "$tree_id,$subnode_id,$tree_dup,$tree_subnodes,$tree_spec,$dupconf,$bootstrap,$min_dist_parent,$dist_parent,$dist_leaves,$root_flank_length,$subtree_flank_length,$subnode_flank_length,$num_leaves,$gene_count,$aln_length,$global_dnds,$dndses,$genes,$gene_link\n";
#     }
#     print STDERR "[$root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     $root->release_tree;
#   }
# }

sub _split_genes_stats {
  my $self = shift;
  $self->{starttime} = time();
  print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
  my $type = $self->{debug} || "SIS1";
  my $gmin = $self->{_gmin} || 0.5;

  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

  print "species_name,homology_key,taxonomy_level,prev_intron_length,next_intron_length,missing_intron_length\n";
  foreach my $gdb (@{$self->{gdba}->fetch_all}) {
    my $species_name = $gdb->name;
    $species_name =~ s/\ /\_/g;
    my $mlss = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$gdb]);
    print STDERR $mlss->name, "\n" if ($self->{debug});
    my @splits = @{$self->{ha}->fetch_all_by_MethodLinkSpeciesSet_orthology_type($mlss,"contiguous_gene_split")};
    foreach my $homology (@splits) {
      my ($member1, $member2) = @{$homology->gene_list};
      my $taxonomy_level = $homology->taxonomy_level; $taxonomy_level =~ s/\ /\_/g;
      my $temp; if ($member1->chr_start > $member2->chr_start) {$temp = $member1; $member1 = $member2; $member2 = $temp;}
      if ($member1->chr_start < $member2->chr_start && $member1->chr_end > $member2->chr_end) {
        print STDERR $homology->homology_key, ",contained gene split\n" if ($self->{debug});
        next;
      }
      my $transcript1 = $member1->get_canonical_peptide_Member->transcript;
      my $transcript2 = $member2->get_canonical_peptide_Member->transcript;
      my @prev_introns = @{$transcript1->get_all_Introns};
      my @next_introns = @{$transcript2->get_all_Introns};
      my $prev_intron_length = 'na'; $prev_intron_length = $prev_introns[-1]->length if (0 < scalar @prev_introns);
      my $next_intron_length = 'na'; $next_intron_length = $prev_introns[0]->length if (0 < scalar @prev_introns);
      my $last_exon1 = @{$transcript1->get_all_translateable_Exons}[-1];
      my $frst_exon2 = @{$transcript2->get_all_translateable_Exons}[0];
      my $missing_intron_length = $frst_exon2->start - $last_exon1->end;
      my $homology_key = $homology->homology_key;
      print "$species_name,$homology_key,$taxonomy_level,$prev_intron_length,$next_intron_length,$missing_intron_length\n";
    }
  }
}

# sub _split_genes {
#   my $self = shift;
#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   my $type = $self->{debug} || "SIS1";
#   my $gmin = $self->{_gmin} || 0.5;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   my $file = $self->{_split_genes};
#   open LIST, "$file" or die "couldnt open slr_list file $file: $!\n";
#   while (<LIST>) {
#     chomp $_;
#     next if ($_ eq '');
#     $self->{_ids}{$_} = 1;
#   }

#   print "tree_id,subnode_id,dupconf,bootstrap,min_dist_parent,dist_parent,dist_leaves,root_gblocks,subtree_gblocks,subtree_local_gblocks,num_leaves,gene_count,genes\n";
#   foreach my $root_id (keys %{$self->{_ids}}) {
#     my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
#     next unless (defined($root));
#     next if ('1' eq $root->get_tagvalue('cluster_had_to_be_broken_down'));
#     my $aln = $root->get_SimpleAlign;
#     my $aln_length = $aln->length;
#     my $tree_id = $root->node_id;

#     my $flanks_gblocks = _run_gblocks($root,$gmin);
#     my $root_flank_length = 0;
#     foreach my $segment ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#       my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#       $root_flank_length += $end-$start+1;
#     }

#     my $gene_count = $root->get_tagvalue("gene_count");
#     my $genes = 'na';

#     foreach my $subnode ($root->get_all_subnodes) {
#       my $subtree_flank_length = -1;
#       if ($subnode->is_leaf) {
#         my $taxon_name = $subnode->taxon->name;
#         if ($taxon_name eq 'Homo sapiens' && $genes eq 'na') {
#           $genes = ' http://staging.ensembl.org/Homo_sapiens/genetreeview?peptide=' . $subnode->stable_id;
#         }
#         next;
#       }

#       my $num_leaves = $subnode->num_leaves;
#       my $dupconf = $subnode->get_tagvalue($type);
#       my $bootstrap = $subnode->get_tagvalue("Bootstrap");
#       my $dupl = $subnode->get_tagvalue("Duplication");
#       my $dd = $subnode->get_tagvalue("dubious_duplication");
#       if ($dd ne '') {
#         next if (1 == $dd);
#       }
#       next unless ($dupl ne '');
#       next unless (0 != $dupl);
#       next unless (defined($dupconf) && $dupconf ne '');
#       next unless (defined($bootstrap) && $bootstrap ne '');
#       my $subnode_id = $subnode->node_id;

#       # Run it on subnode
#       my $subnode_flanks_gblocks = _run_gblocks($subnode,$gmin);
#       my $subnode_flank_length = 0;
#       if ($subnode_flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#         foreach my $segment ($subnode_flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#           my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#           $subnode_flank_length += $end-$start+1;
#         }
#       }
#       # end subnode
#       my $dist_leaves;
#       my $leaf_count;
#       foreach my $leaf (@{$subnode->get_all_leaves}) {
#         $dist_leaves += $leaf->distance_to_ancestor($subnode);
#         $leaf_count++;
#       }
#       $dist_leaves = $dist_leaves/$leaf_count unless ($dist_leaves == 0);

#       my $dist_parent;
#       my $min_dist_parent = 999;
#       foreach my $subsubnode (@{$subnode->children}) {
#         my $dist = $subsubnode->distance_to_parent;
#         $dist_parent += $dist;
#         $min_dist_parent = $dist if ($dist < $min_dist_parent);
#         my $subsubtree_flank_length = 0;
#         my @leaves = @{$subsubnode->get_all_leaves};
#         # my @leaves = @{$subsubnode->get_all_leaves_indexed};
#         my $numseq = scalar(@leaves);
#         while (my $leaf = shift @leaves) {
#           my @seqs = $aln->each_seq_with_id($leaf->stable_id);
#           if ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#             foreach my $segment ($flanks_gblocks =~ /(\[\d+  \d+\])/g) {
#               my ($start,$end) = $segment =~ /\[(\d+)  (\d+)\]/;
#               my $subseq = $seqs[0]->subseq($start,$end);
#               $subseq =~ s/\-//g;
#               $subsubtree_flank_length += length($subseq);
#             }
#           }
#         }
#         $subtree_flank_length = ($subsubtree_flank_length/$numseq) if ($subtree_flank_length < ($subsubtree_flank_length/$numseq));
#         # print STDERR "$subnode_id,$subtree_flank_length\n";
#       }
#       my $percent_gblocks = 0;
#       $dist_parent = $dist_parent/2 unless ($dist_parent == 0);
#       print "$tree_id,$subnode_id,$dupconf,$bootstrap,$min_dist_parent,$dist_parent,$dist_leaves,$root_flank_length,$subtree_flank_length,$subnode_flank_length,$num_leaves,$gene_count,$genes\n";
#     }
#     print STDERR "[$root_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     $root->release_tree;
#   }
# }

sub _merge_split_genes {
  my $self = shift;
  $self->{starttime} = time();
  print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

  $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
  $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{nsa} = $self->{'comparaDBA'}->get_NestedSetAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

  my $file = $self->{_merge_split_genes};
  open LIST, "$file" or die "couldnt open merge_split_genes file $file: $!\n";
  while (<LIST>) {
    chomp $_;
    next if ($_ eq '');
    $self->{_ids}{$_} = 1;
  }

  my $header = "root_node_id,gene_count,shortname,chr_m1,chr_m2,dist,gt1,gt2,mcv1\n";
  my $printed_header = 0;
  foreach my $root_id (keys %{$self->{_ids}}) {
    my $root = $self->{treeDBA}->fetch_node_by_node_id($root_id);
    next unless (defined($root));
    next if ('1' eq $root->get_tagvalue('cluster_had_to_be_broken_down'));
    my $aln = $root->get_SimpleAlign;
    my $root_node_id = $root->node_id;
    my $gene_count = $root->get_tagvalue('gene_count');
    my $sp_repr;
    foreach my $leaf (@{$root->get_all_leaves}) {
      my $shortname = $leaf->genome_db->short_name;
      $sp_repr->{$shortname}{$leaf->stable_id}  = 1;
    }
    foreach my $shortname (keys %$sp_repr) {
      my @ids = keys %{$sp_repr->{$shortname}};
      next unless (1 < scalar(@ids));
      while (my $stable_id1 = shift @ids) {
        foreach my $stable_id2 (@ids) {
          my @aln_seq1 = $aln->each_seq_with_id($stable_id1);
          my @aln_seq2 = $aln->each_seq_with_id($stable_id2);
          my $seq1 = $aln_seq1[0]->seq;
          $seq1 =~ s/\w/1/g; $seq1 =~ s/\-/0/g;
          my $seq2 = $aln_seq2[0]->seq;
          $seq2 =~ s/\w/1/g; $seq2 =~ s/\-/0/g;
          my $union_seq = sprintf($seq1 | $seq2);
          $union_seq =~ s/0//g;
          my $union_length = length($union_seq);
          my $isect_seq = sprintf($seq1 & $seq2);
          $isect_seq =~ s/0//g;
          my $isect_length = length($isect_seq);
          if (0 == $isect_length) {
            my $m1 = $self->{ma}->fetch_by_source_stable_id('ENSEMBLPEP',$stable_id1)->gene_member;
            my $m2 = $self->{ma}->fetch_by_source_stable_id('ENSEMBLPEP',$stable_id2)->gene_member;
            my $gene_stable_id1 = $m1->stable_id;            my $gene_stable_id2 = $m2->stable_id;
            my $chr_m1 = $m1->chr_name;                      my $chr_m2 = $m2->chr_name;
            my $strand_m1 = $m1->chr_strand;                 my $strand_m2 = $m2->chr_strand;
            my $chr1_start = $m1->chr_start; my $chr1_end = $m1->chr_end;
            my $temp1; if ($chr1_start > $chr1_end) {$temp1 = $chr1_start; $chr1_start = $chr1_end; $chr1_end = $temp1;}
            my $chr2_start = $m2->chr_start; my $chr2_end = $m2->chr_end;
            my $temp2; if ($chr2_start > $chr2_end) {$temp2 = $chr2_start; $chr2_start = $chr2_end; $chr2_end = $temp2;}
            my $dist = 'NA';  my $mcv = 'NA';
            my $sp_name = $m1->genome_db->name; $sp_name =~ s/\ /\_/g;
            if ( ($chr_m1 eq $chr_m2) && ($strand_m1 eq $strand_m2)) {
              my $dist1 = $chr2_end - $chr1_start; my $dist2 = $chr1_end - $chr2_start;
              $dist = ($dist1 > $dist2) ? $dist1 : $dist2; $dist = $dist*-1 if ($dist < 0);
              my $context = int(4*$dist);
              $mcv = "http://dec2007.archive.ensembl.org/$sp_name/multicontigview?gene=$gene_stable_id1;s1=$sp_name;g1=$gene_stable_id2;context=$context";
            }
            unless ($printed_header) {
              print $header; $printed_header = 1;
            }
            print "$root_node_id,$gene_count,$shortname,$chr_m1,$chr_m2,$dist, http://dec2007.archive.ensembl.org/$sp_name/genetreeview?gene=$gene_stable_id1, http://dec2007.archive.ensembl.org/$sp_name/genetreeview?gene=$gene_stable_id2, $mcv\n";
            # print STDERR "$isect_length/$union_length\n";
          }
        }
      }
    }
  }
}

# sub _phylogenomics_separate {
#   my $self = shift;

#   my $filename = $self->{_phylogenomics_separate};

#     my $culicini_num  = 0;
#     my $culicini_denom  = 0;
#     my $culicidae_num = 0;
#     my $culicidae_denom = 0;
#     my $cpip_num      = 0;
#     my $cpip_denom      = 0;
#     my $aaeg_num      = 0;
#     my $aaeg_denom      = 0;
#     my $agam_num      = 0;
#     my $agam_denom      = 0;
#     my $dmel_num      = 0;
#     my $dmel_denom      = 0;

#   my $wrong_topo;
#   open FILE, $filename or die "$!";
#   while (<FILE>) {
#     chomp $_;
#     my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($_);
#     # Check the topology
#     my ($node_a, $node_b) = @{$tree->children};
#     my $temp;    if ($node_b->is_leaf) {      $temp = $node_a;      $node_a = $node_b;      $node_b = $temp;    }
#     unless ($node_a->name =~ /CG\d+/) {
#       $wrong_topo->{droso_1st_outgroup}++;
#       next;
#     }
#     my ($subnode_a, $subnode_b) = @{$node_b->children};
#     my $subtemp;    if ($subnode_b->is_leaf) {      $subtemp = $subnode_a;      $subnode_a = $subnode_b;      $subnode_b = $subtemp;    }
#     unless ($subnode_a->name =~ /AGAP\d+/) {
#       $wrong_topo->{anopheles_2nd_outgroup}++;
#       next;
#     }
#     my ($cpip,$aaeg) = @{$subnode_b->children};
#     my $subsubtemp;    if ($cpip->name =~ /AAEL/) {      $subsubtemp = $cpip;      $cpip = $aaeg;      $aaeg = $subsubtemp;    }

#     my $culicini_this_distance  = $node_b->distance_to_node($subnode_b);
#     my $culicini_this_stderror  = $subnode_b->get_tagvalue('SE');
#     my $culicidae_this_distance = $node_b->distance_to_node($tree);
#     my $culicidae_this_stderror = $node_b->get_tagvalue('SE');
#     my $cpip_this_distance      = $cpip->distance_to_node($subnode_b);
#     my $cpip_this_stderror      = $cpip->get_tagvalue('SE');
#     my $aaeg_this_distance      = $aaeg->distance_to_node($subnode_b);
#     my $aaeg_this_stderror      = $aaeg->get_tagvalue('SE');
#     my $agam_this_distance      = $subnode_a->distance_to_node($node_b);
#     my $agam_this_stderror      = $subnode_a->get_tagvalue('SE');
#     my $dmel_this_distance      = $node_a->distance_to_node($tree);
#     my $dmel_this_stderror      = $node_a->get_tagvalue('SE');

#     $culicini_num     += $culicini_this_distance/($culicini_this_stderror*$culicini_this_stderror);
#     $culicini_denom   += 1/($culicini_this_stderror*$culicini_this_stderror);
#     $culicidae_num    += $culicidae_this_distance/($culicidae_this_stderror*$culicidae_this_stderror);
#     $culicidae_denom  += 1/($culicidae_this_stderror*$culicidae_this_stderror);
#     $cpip_num         += $cpip_this_distance/($cpip_this_stderror*$cpip_this_stderror);
#     $cpip_denom       += 1/($cpip_this_stderror*$cpip_this_stderror);
#     $aaeg_num         += $aaeg_this_distance/($aaeg_this_stderror*$aaeg_this_stderror);
#     $aaeg_denom       += 1/($aaeg_this_stderror*$aaeg_this_stderror);
#     $agam_num         += $agam_this_distance/($agam_this_stderror*$agam_this_stderror);
#     $agam_denom       += 1/($agam_this_stderror*$agam_this_stderror);
#     $dmel_num         += $dmel_this_distance/($dmel_this_stderror*$dmel_this_stderror);
#     $dmel_denom       += 1/($dmel_this_stderror*$dmel_this_stderror);

#     printf (STDERR "(%.4f) ",$culicini_num/$culicini_denom) if ($self->{verbose});
#     printf (STDERR "(%.4f) ",$culicidae_num/$culicidae_denom) if ($self->{verbose});
#     printf (STDERR "(%.4f) ",$cpip_num/$cpip_denom) if ($self->{verbose});
#     printf (STDERR "(%.4f) ",$aaeg_num/$aaeg_denom) if ($self->{verbose});
#     printf (STDERR "(%.4f) ",$agam_num/$agam_denom) if ($self->{verbose});
#     printf (STDERR "(%.4f)\n",$dmel_num/$dmel_denom) if ($self->{verbose});
#   }
#   my $culicini = ($culicini_num/$culicini_denom);
#   my $culicidae = ($culicidae_num/$culicidae_denom);
#   my $cpip = ($cpip_num/$cpip_denom);
#   my $aaeg = ($aaeg_num/$aaeg_denom);
#   my $agam = ($agam_num/$agam_denom);
#   my $dmel = ($dmel_num/$dmel_denom);

#   my $final_tree = "(((Culex pipiens:$cpip,Aedes aegypti:$aaeg)Culicini:$culicini,Anopheles gambiae:$agam)Culicidae:$culicidae,Drosophila melanogaster:$dmel)Diptera:0.01;";
#   print "$final_tree\n";
# }

# sub _phylogenomics {
#   my $self = shift;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   my $port = 3306;
#   if ($myhost =~ /(\S+)\:(\S+)/) {
#     $port = $2;
#     $myhost = $1;
#   }
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -port => "$port",
#         -verbose => "0" );

#   my $species_list = $self->{_species_list} || "Culex_pipiens:Aedes_aegypti:Anopheles_gambiae:Drosophila_melanogaster";
#   my $species_hash;
#   foreach my $species (split(":",$species_list)) {
#     $species =~ s/\_/\ /g;
#     $species_hash->{$species} = 1;
#   }

#   my $cluster_id = $self->{_phylogenomics};
#   my $cluster = $self->{treeDBA}->fetch_node_by_node_id($cluster_id);
#   my $broken = $cluster->get_tagvalue('cluster_had_to_be_broken_down');
#   exit if (defined($broken) && $broken ne '');

#   #$cluster->print_tree(10);
#   my @leaves = @{$cluster->get_all_leaves};
#   exit unless (scalar @leaves == scalar (keys %{$species_hash}));
#   my $genetree_hash;
#   foreach my $leaf (@leaves) {
#     $genetree_hash->{$leaf->taxon->name} = 1;
#   }
#   exit unless (scalar (keys %{$genetree_hash}) == scalar (keys %{$species_hash}));
#   my $cds_aln = $cluster->get_SimpleAlign('cdna'=>1);
#   my $tree_id = $cluster->node_id;
#   $cds_aln = $cds_aln->remove_gaps('', 1);
#   my $tree_string = $cluster->newick_simple_format;
#   open(my $fake_fh, "+<", \$tree_string);
#   my $treein = new Bio::TreeIO
#     (-fh => $fake_fh,
#      -format => 'newick');
#   my $tree = $treein->next_tree;
#   $treein->close;

#   eval { require Bio::Tools::Run::Phylo::PAML::Baseml; };
#   die "codeml wrapper not found: $!\n" if ($@);
#   # '-executable' => '/nfs/acari/avilella/src/slr/bin/Slr_64',
#   my $baseml = Bio::Tools::Run::Phylo::PAML::Baseml->new
#     (
#      '-executable' => '/nfs/acari/avilella/src/paml4b/src/baseml',
#      '-program_dir' => '/nfs/acari/avilella/src/paml4b/src/');

# # seqfile = YBR228W_DNA.phy
# # outfile = YBR228W.paml 
# # treefile = candidate_trees.txt
# # verbose = 0 
# # noisy = 1 
# # runmode = 0 
# # ndata = 1 
# # clock = 0 
# # model = 7			//this is the REV model, if you want to use something else have a look in the PAML doc 
# # Mgene = 0 			//if you run each one seperately not needed
# # fix_kappa = 0 		//estimate rate ratio params			
# # kappa = 2.5 		//initial value for TS/TV rate estimation, i think it's default
# # fix_alpha = 0 		//estimate gamma distribution shape param
# # alpha = 0.5 		//initial value for alpha
# # Malpha = 0 			//see Mgene
# # ncatG = 6 			//No of categories for discrete approximation of gamma distribution
# # nhomo = 0 			
# # getSE = 1 			//get standard errors, important if you want to calculate weighted means of param estimates!
# # RateAncestor = 0 
# # Small_Diff = .5e-6 
# # cleandata = 0 
# # fix_blength = 0 
# # method = 0 			


#   $baseml->alignment($cds_aln);
#   $baseml->tree($tree);
#   $baseml->no_param_checks(1);
#   $baseml->set_parameter("noisy","1");
#   $baseml->set_parameter("verbose","0");
#   $baseml->set_parameter("runmode","0");
#   #  $baseml->set_parameter("seqtype","1");
#   # baseml.c:194:char *codonfreqs[]={"Fequal", "F1x4", "F3x4", "Fcodon", "F1x4MG", "F3x4MG", "FMutSel0", "FMutSel"};
#   #                                        0       1       2         3         4         5           6          7
#   #  $baseml->set_parameter("CodonFreq","2");
#   $baseml->set_parameter("model","7");
#   #  $baseml->set_parameter("NSsites","1");
#   $baseml->set_parameter("ndata","1");
#   $baseml->set_parameter("clock","0");
#   # $baseml->set_parameter("icode","1");
#   $baseml->set_parameter("fix_kappa","0");
#   $baseml->set_parameter("kappa","2.5");
#   # $baseml->set_parameter("fix_omega","0");
#   # $baseml->set_parameter("omega","0.03162");
#   $baseml->set_parameter("fix_alpha","0");
#   $baseml->set_parameter("alpha","0.5");
#   $baseml->set_parameter("ncatG","6");
#   # $baseml->set_parameter("nhomo","0");
#   $baseml->set_parameter("getSE","1");
#   $baseml->set_parameter("RateAncestor","0");
#   $baseml->set_parameter("Small_Diff",".5e-6");
#   $baseml->set_parameter("cleandata","0");
#   $baseml->set_parameter("method","0");
#   $baseml->set_parameter("fix_blength","0");
#   my ($rc,$parser) = $baseml->run();
#   if ($rc == 0) {
#     $DB::single=1;1;
#   }
#   my $result;
#   eval{ $result = $parser->next_result };
#   unless( $result ){
#     if ( $@ ) { 
#       warn( "$@\n" );
#     }
#     warn( "Parser failed" );
#   }
#   my $resulting_tree = $result->next_tree;
#   my $tree_out = Bio::TreeIO->new(-file => ">/lustre/work1/ensembl/avilella/culex/sm/$tree_id.nhx", -format => 'nhx');
#   $tree_out->write_tree($resulting_tree);
#   $tree_out->close;
#   #
# }

# sub _phylogenomics_pc {
#   my $self = shift;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#   my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#   my $port = 3306;
#   if ($myhost =~ /(\S+)\:(\S+)/) {
#     $port = $2;
#     $myhost = $1;
#   }
#   Bio::EnsEMBL::Registry->load_registry_from_db
#       ( -host => "$myhost",
#         -user => "$myuser",
#         -db_version => "$mydbversion",
#         -port => "$port",
#         -verbose => "0" );

#   my $species_list = $self->{_species_list} || "Culex_pipiens:Aedes_aegypti:Anopheles_gambiae:Drosophila_melanogaster";
#   my $species_hash;
#   foreach my $species (split(":",$species_list)) {
#     $species =~ s/\_/\ /g;
#     $species_hash->{$species} = 1;
#   }

#   my $cluster_id = $self->{_phylogenomics_pc};
#   my $cluster = $self->{treeDBA}->fetch_node_by_node_id($cluster_id);
#   my $broken = $cluster->get_tagvalue('cluster_had_to_be_broken_down');
#   exit if (defined($broken) && $broken ne '');

#   #$cluster->print_tree(10);
#   my @leaves = @{$cluster->get_all_leaves};
#   exit unless (scalar @leaves == scalar (keys %{$species_hash}));
#   my $genetree_hash;
#   foreach my $leaf (@leaves) {
#     $genetree_hash->{$leaf->taxon->name} = 1;
#   }
#   exit unless (scalar (keys %{$genetree_hash}) == scalar (keys %{$species_hash}));
#   my $cds_aln = $cluster->get_SimpleAlign('cdna'=>1);
#   my $tree_id = $cluster->node_id;
#   $cds_aln = $cds_aln->remove_gaps('', 1);
#   my $aln_out = Bio::AlignIO->new
#     (-file => ">/lustre/scratch1/ensembl/avilella/culex/cm/$tree_id.aln.fasta",
#      -format => 'fasta');
#   $aln_out->write_aln($cds_aln);
#   $aln_out->close;
# }

# sub _phylogenomics_concat {
#   my $self = shift;
#   my @files = `find /lustre/scratch1/ensembl/avilella/culex/cm -name "*.aln.fasta"`;

#   my $aln_length = 0;
#   my $buffer_aln_length = 0;
#   my $lengths;

#   my $out_seq;

#   open CPIP, ">/tmp/cpip.tmp" or die "$!";
#   open AAEG, ">/tmp/aaeg.tmp" or die "$!";
#   open AGAM, ">/tmp/agam.tmp" or die "$!";
#   open DMEL, ">/tmp/dmel.tmp" or die "$!";
#   my $count = 0;
#   foreach my $file (@files) {
#     chomp $file;
#     my $aln_in = Bio::AlignIO->new
#       (-file => "$file",
#       -format => 'fasta');
#     my $aln = $aln_in->next_aln;
#     next unless (4 == scalar($aln->each_seq));
#     $aln_length += $aln->length;
#     $buffer_aln_length += $aln->length;
#     $lengths->{$count} = $aln->length;
#     $count++;
#     print STDERR "[ $count ]\n" if (0 == $count % 100);
#     $aln->sort_alphabetically;
#     foreach my $seq ($aln->each_seq) {
#       my $display_id = $seq->display_id;
#       my $id;
#       $id = 'Aaeg' if ($display_id =~ /AAEL/);
#       $id = 'Cpip' if ($display_id =~ /CPI/);
#       $id = 'Dmel' if ($display_id =~ /CG/);
#       $id = 'Agam' if ($display_id =~ /AGA/);
#       my $seq = $seq->seq;
#       $seq = lc($seq) if (0 == $count % 2);
#       $out_seq->{$id} .= $seq;
#     }

#     my $out_buffer;
#     while ($buffer_aln_length > 80) {
#       foreach my $id (sort keys %{$out_seq}) {
#         my $seq = substr($out_seq->{$id},0,80,'');
#         $out_buffer->{$id} .= "$seq\n";
#       }
#       $buffer_aln_length = $buffer_aln_length - 80;
#     }

#     print CPIP "Cpip\n" if (1 == $count);
#     print AAEG "Aaeg\n" if (1 == $count);
#     print AGAM "Agam\n" if (1 == $count);
#     print DMEL "Dmel\n" if (1 == $count);
#     print CPIP $out_buffer->{'Cpip'} if (defined($out_buffer));
#     print AAEG $out_buffer->{'Aaeg'} if (defined($out_buffer));
#     print AGAM $out_buffer->{'Agam'} if (defined($out_buffer));
#     print DMEL $out_buffer->{'Dmel'} if (defined($out_buffer));
#     # print STDERR $out_buffer if (defined($out_buffer));
#     last if ($count == $self->{_phylogenomics_concat});
#   }

#   my $out_buffer;
#   foreach my $id (sort keys %{$out_seq}) {
#     my $seq = substr($out_seq->{$id},0,80,'');
#     $out_buffer->{$id} .= "$seq\n";
#   }
#   print CPIP $out_buffer->{'Cpip'} if (defined($out_buffer));
#   print AAEG $out_buffer->{'Aaeg'} if (defined($out_buffer));
#   print AGAM $out_buffer->{'Agam'} if (defined($out_buffer));
#   print DMEL $out_buffer->{'Dmel'} if (defined($out_buffer));

#   close CPIP;
#   close AAEG;
#   close AGAM;
#   close DMEL;
#   `cp /tmp/*.tmp /lustre/scratch1/ensembl/avilella/culex/`;

#   my $pos_string;
#   foreach my $pos (1 .. ($aln_length/3)) {
#     $pos_string .= "123";
#   }
#   open HEADER, ">/lustre/scratch1/ensembl/avilella/culex/header.txt" or die "$!";
#   print HEADER "4 $aln_length G\n";
#   print HEADER "G 3\n";
#   print HEADER "$pos_string\n";
#   close HEADER;
#   open HEADERSIMPL, ">/lustre/scratch1/ensembl/avilella/culex/headersimpl.txt" or die "$!";
#   print HEADERSIMPL "4 $aln_length\n";
#   close HEADERSIMPL;
#   unlink "/tmp/*.tmp";
# }

# sub _phylogenomics_concat_intl {
#   my $self = shift;
#   my @files = `find /lustre/scratch1/ensembl/avilella/culex/cm -name "*.aln.fasta"`;

#   my $aln_length = 0;
#   my $buffer_aln_length = 0;
#   my $lengths;

#   my $out_seq;

#   open OUT, ">/tmp/concatenate.phy.tmp" or die "$!";
#   my $count = 0;
#   foreach my $file (@files) {
#     chomp $file;
#     my $aln_in = Bio::AlignIO->new
#       (-file => "$file",
#       -format => 'fasta');
#     my $aln = $aln_in->next_aln;
#     $aln_length += $aln->length;
#     $buffer_aln_length += $aln->length;
#     $lengths->{$count} = $aln->length;
#     $count++;
#     print STDERR "[ $count ]\n" if (0 == $count % 100);
#     $aln->sort_alphabetically;
#     foreach my $seq ($aln->each_seq) {
#       my $display_id = $seq->display_id;
#       my $id;
#       $id = 'Aaeg' if ($display_id =~ /AAEL/);
#       $id = 'Cpip' if ($display_id =~ /CPI/);
#       $id = 'Dmel' if ($display_id =~ /CG/);
#       $id = 'Agam' if ($display_id =~ /AGA/);
#       my $seq = $seq->seq;
#       $seq = lc($seq) if (0 == $count % 2);
#       if (1 == $count) {
#         $out_seq->{$id} .= "$id       " ;
#       }
#       $out_seq->{$id} .= $seq;
#     }

#     my $out_buffer;
#     while ($buffer_aln_length > 80) {
#       foreach my $id (sort keys %{$out_seq}) {
#         my $seq = substr($out_seq->{$id},0,80,'');
#         $out_buffer .= "$seq\n";
#       }
#       $out_buffer .= "\n";
#       $buffer_aln_length = $buffer_aln_length - 80;
#     }
#     # print STDERR $out_buffer if (defined($out_buffer));
#     print OUT $out_buffer if (defined($out_buffer));
#     # last if ($count == 100);
#   }

#   my $last_out_buffer;
#   foreach my $id (sort keys %{$out_seq}) {
#     my $seq = substr($out_seq->{$id},0,80,'');
#     $last_out_buffer .= "$seq\n";
#   }
#   $last_out_buffer .= "\n";
#   print OUT $last_out_buffer if (defined($last_out_buffer));

#   close OUT;
#   `cp /tmp/concatenate.phy.tmp /lustre/scratch1/ensembl/avilella/culex/concatenate.phy.tmp`;

#   my $pos_string;
#   foreach my $pos (1 .. ($aln_length/3)) {
#     $pos_string .= "123";
#   }
#   open HEADER, ">/lustre/scratch1/ensembl/avilella/culex/header.txt" or die "$!";
#   print HEADER "4 $aln_length G I\n";
#   print HEADER "G 3\n";
#   print HEADER "$pos_string\n";
#   close HEADER;
#   open HEADERSIMPL, ">/lustre/scratch1/ensembl/avilella/culex/headersimpl.txt" or die "$!";
#   print HEADERSIMPL "4 $aln_length I\n";
#   close HEADERSIMPL;
#   unlink "/tmp/concatenate.phy.tmp";
# }

# sub _fasta2phylip_disk {
#   my $self = shift;

#   my $aln_length = 0;
#   my $buffer_aln_length = 0;
#   my $lengths;

#   my $out_seq;

#   open OUT, ">/tmp/concatenate.phy.tmp" or die "$!";
#   my $count = 0;
#   foreach my $file (@files) {
#     chomp $file;
#     my $aln_in = Bio::AlignIO->new
#       (-file => "$file",
#       -format => 'fasta');
#     my $aln = $aln_in->next_aln;
#     $aln_length += $aln->length;
#     $buffer_aln_length += $aln->length;
#     $lengths->{$count} = $aln->length;
#     $count++;
#     print STDERR "[ $count ]\n" if (0 == $count % 100);
#     $aln->sort_alphabetically;
#     foreach my $seq ($aln->each_seq) {
#       my $display_id = $seq->display_id;
#       my $id;
#       $id = 'Aaeg' if ($display_id =~ /AAEL/);
#       $id = 'Cpip' if ($display_id =~ /CPI/);
#       $id = 'Dmel' if ($display_id =~ /CG/);
#       $id = 'Agam' if ($display_id =~ /AGA/);
#       my $seq = $seq->seq;
#       $seq = lc($seq) if (0 == $count % 2);
#       if (1 == $count) {
#         $out_seq->{$id} .= "$id       " ;
#       }
#       $out_seq->{$id} .= $seq;
#     }

#     my $out_buffer;
#     while ($buffer_aln_length > 80) {
#       foreach my $id (sort keys %{$out_seq}) {
#         my $seq = substr($out_seq->{$id},0,80,'');
#         $out_buffer .= "$seq\n";
#       }
#       $out_buffer .= "\n";
#       $buffer_aln_length = $buffer_aln_length - 80;
#     }
#     # print STDERR $out_buffer if (defined($out_buffer));
#     print OUT $out_buffer if (defined($out_buffer));
#     # last if ($count == 100);
#   }

#   my $last_out_buffer;
#   foreach my $id (sort keys %{$out_seq}) {
#     my $seq = substr($out_seq->{$id},0,80,'');
#     $last_out_buffer .= "$seq\n";
#   }
#   $last_out_buffer .= "\n";
#   print OUT $last_out_buffer if (defined($last_out_buffer));

#   close OUT;
#   `cp /tmp/concatenate.phy.tmp /lustre/scratch1/ensembl/avilella/culex/concatenate.phy.tmp`;

#   my $pos_string;
#   foreach my $pos (1 .. ($aln_length/3)) {
#     $pos_string .= "123";
#   }
#   open HEADER, ">/lustre/scratch1/ensembl/avilella/culex/header.txt" or die "$!";
#   print HEADER "4 $aln_length G I\n";
#   print HEADER "G 3\n";
#   print HEADER "$pos_string\n";
#   close HEADER;
#   open HEADERSIMPL, ">/lustre/scratch1/ensembl/avilella/culex/headersimpl.txt" or die "$!";
#   print HEADERSIMPL "4 $aln_length I\n";
#   close HEADERSIMPL;
#   unlink "/tmp/concatenate.phy.tmp";
# }

# sub _treefam_guess_name
# {
#   my $self = shift;
#   $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;

#   my $member_id = $self->{_treefam_guess_name};
#   my $member = $self->{memberDBA}->fetch_by_source_stable_id('ENSEMBLGENE',$member_id);
#   my $tree = $self->{treeDBA}->fetch_by_Member_root_id($member);
#   exit unless (defined ($tree));

#   my ($desc, $sym, $count, $cat_sym, $count_all, %hash, @array);
#   $count_all = $count = 0; $cat_sym = '';
#   foreach my $leaf (@{$tree->get_all_leaves}) {
#     next unless ($leaf->taxon->name eq 'Homo sapiens');
#     ++$count_all;
#     my $desc = $leaf->gene_member->description;
#     my $sym  = $leaf->gene_member->display_label;
#     next unless ($desc);
#     $desc =~ s/\[[^\[\]]+\]\s*$//; # chop source tag
#     $desc =~ s/'//g;
#     $desc =~ s/\B\([^\(\)]*\)\B//g;
#     $desc =~ s/\.\B//g;
#     $_ = $desc;
#     foreach my $p (split) {
#       if (defined($hash{$p})) {
#         ++$hash{$p};
#       } else {
#         $hash{$p} = 1;
#         push(@array, $p);
#       }
#     }
#     $cat_sym .= "$sym/" if ($sym && $sym !~ /^ENS/);
#     ++$count;
#   }
#   $desc = '';
#   chop($cat_sym);
#   foreach my $p (@array) {
#     $desc .= "$p " if ($hash{$p} / $count >= 0.50);
#   }
#   if (1 == scalar(keys %hash)) {
#     $desc = '';
#   }
#   unless ($desc) {
#     $desc = $cat_sym;
#   } else {
#     chop($desc);
#   }
#   if ($count >= 4) {          # otherwise the symbol will be too long.
#     print STDERR "($cat_sym) ";
#     $cat_sym = 'MIXED';
#   } 
#   $cat_sym = 'N/A' unless ($cat_sym);
#   $desc = 'N/A' unless ($desc);
#   print $tree->node_id, " $cat_sym %% $desc\n";
# }

# sub _phylowidget_tests
#   {
#     my $self = shift;
#     $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#     $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#     my @clusters = @{$self->{'clusterset'}->children};
#     my $totalnum_clusters = scalar(@clusters);
#     printf("totalnum_trees: %d\n", $totalnum_clusters);
#     $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#     $url =~ /mysql\:\/\/(\S+)\@(\S+)\/\S+\_(\d+)$/g;
#     my ($myuser,$myhost,$mydbversion) = ($1,$2,$3);
#     my $port = 3306;
#     if ($myhost =~ /(\S+)\:(\S+)/) {
#       $port = $2;
#       $myhost = $1;
#     }
#     Bio::EnsEMBL::Registry->load_registry_from_db
#         ( -host => "$myhost",
#           -user => "$myuser",
#           -db_version => "$mydbversion",
#           -port => "$port",
#           -verbose => "0" );
#     foreach my $cluster (@clusters) {
#       my $tree_id = $cluster->node_id;
#       next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#       next if ((50 > $cluster->get_tagvalue('gene_count')) && defined($self->{verbose}));
#       $DB::single=1;1;
#       my $nhx_format = $cluster->nhx_format("display_label");
#       $nhx_format =~ s/\///g;$nhx_format =~ s/\ //g;
#       #    my $url = "http://www.phylowidget.org/beta/index.html?tree='$nhx_format'";
#       # my $newick_format = $cluster->newick_simple_format();
#       # my $url = "http://www.phylowidget.org/beta/index.html?tree='$newick_format'";
#       open FILE, ">$tree_id.nhx" or die "$!";
#       print FILE "$nhx_format\n";
#       close FILE;
#     }

#   }

# sub _gene_bootstrap_coef
#   {
#     my $self = shift;
#     require Statistics::Descriptive;
#     $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#     printf("dbname: %s\n", $self->{'_mydbname'});
#     printf("gene_bootstrap_coef: %d\n", $self->{'clusterset_id'});

#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#     my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#     my $outfile = "gene_bootstrap_coef.". $self->{_mydbname} . "." . 
#       $self->{'clusterset_id'};
#     $outfile .= ".csv";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     print OUTFILE "root_id,gene_stable_id,protein_stable_id,species_short_name,chr_name,";
#     print OUTFILE "num_internal_sis,sis_mean,sis_mean_coef,";
#     print OUTFILE "num_internal_bootstraps,bootstrap_mean,bootstrap_std_dev,bootstrap_mean_coef\n";
#     my $cluster_count;

#     my @clusters = @{$clusterset->children};
#     my $totalnum_clusters = scalar(@clusters);
#     printf("totalnum_trees: %d\n", $totalnum_clusters);
#     foreach my $cluster (@clusters) {
#       my %member_totals;
#       $cluster_count++;
#       my $verbose_string = sprintf "[%5d / %5d trees done]\n", 
#         $cluster_count, $totalnum_clusters;
#       print STDERR $verbose_string 
#         if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
#       next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#       $treeDBA->fetch_subtree_under_node($cluster);

#       my $member_list = $cluster->get_all_leaves;
#       next unless (4 < scalar(@$member_list));
#       my $root_id = $cluster->node_id;
#       my @all_bootstraps;
#       my @all_sis;
#       foreach my $subnode ($cluster->get_all_subnodes) {
#         my $bootstrap = $subnode->get_tagvalue("Bootstrap");
#         my $sis = $subnode->get_tagvalue("duplication_confidence_score");
#         if (defined($bootstrap) && $bootstrap ne '') {
#           push @all_bootstraps, $bootstrap;
#         }
#         if (defined($sis) && $sis ne '') {
#           push @all_sis, $sis;
#         }
#       }
#       next unless (2 <= scalar(@all_bootstraps));
#       my $all_bootstrap_mean;
#       my $all_sis_mean;
#       $all_bootstrap_mean = mean_pm(@all_bootstraps);
#       $all_sis_mean = mean_pm(@all_sis);
#       foreach my $member (@$member_list) {
#         my $parent = $member;
#         do {
#           eval { $parent = $parent->parent; };
#           my $bootstrap = $parent->get_tagvalue("Bootstrap");
#           my $sis = $parent->get_tagvalue("duplication_confidence_score");
#           if (defined($bootstrap) && $bootstrap ne '') {
#             $member->{_bootstrap}{$parent->node_id} = $bootstrap;
#           }
#           if (defined($sis) && $sis ne '') {
#             $member->{_sis}{$parent->node_id} = $sis;
#           }
#         } while ($parent->node_id != $root_id);
#         my $num_internal_bootstraps = scalar(values %{$member->{_bootstrap}});
#         my $num_internal_sis = scalar(values %{$member->{_sis}});
#         my $bootstrap_mean = 0;
#         my $bootstrap_std_dev = 0;
#         my $bootstrap_mean_coef = 0;
#         my $sis_mean = 0;
#         my $sis_std_dev = 0;
#         my $sis_mean_coef = 0;
#         if (0 != $num_internal_bootstraps) {
#           $bootstrap_mean = mean_pm(values %{$member->{_bootstrap}});
#           $bootstrap_std_dev = std_dev_pm(values %{$member->{_bootstrap}}) || 0;
#           eval {$bootstrap_mean_coef = $bootstrap_mean/$all_bootstrap_mean};
#         }
#         if (0 != $num_internal_sis) {
#           $sis_mean = mean_pm(values %{$member->{_sis}});
#           #$sis_std_dev = std_dev_pm(values %{$member->{_sis}}) || 0;
#           eval {$sis_mean_coef = $sis_mean/$all_sis_mean};
#         }
#         my $results = 
#           $root_id .
#             "," . 
#               $member->gene_member->stable_id . 
#                 "," . 
#                   $member->stable_id . 
#                     "," . 
#                       $member->genome_db->short_name . 
#                         "," . 
#                           $member->chr_name . 
#                             "," . 
#                               $num_internal_sis . 
#                                 "," . 
#                                   sprintf("%.2f",$sis_mean) . 
#                                     "," . 
#                                       sprintf("%.2f",$sis_mean_coef) . 
#                                         "," . 
#                                           $num_internal_bootstraps . 
#                                             "," . 
#                                               sprintf("%.2f",$bootstrap_mean) . 
#                                                 "," . 
#                                                   sprintf("%.2f",$bootstrap_std_dev) . 
#                                                     "," . 
#                                                       sprintf("%.2f",$bootstrap_mean_coef) . 
#                                                         "\n";
#         print OUTFILE $results;
#         print $results if ($self->{verbose} || $self->{debug});
#       }
#       $cluster->release_tree;
#     }
#   }

# sub _loose_assoc {
#   my $self = shift;
#   my $species = shift;
#   $species =~ s/\_/\ /g;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#   my $gdb = $self->{gdba}->fetch_by_name_assembly($species);

#   print "query_member_stable_id,query_member_genome,hit_member_stable_id,hit_member_genome,evalue,exp_evalue,score,bs_ratio,hit_rank,perc_ident,perc_pos\n";

#   my $pafs;
# #   my $members = $self->{ha}->fetch_all_orphans_by_GenomeDB($gdb);
# #   my $sql = 
# #     "SELECT m.member_id FROM member LEFT JOIN protein_tree_member ptm ON m.member_id=ptm.member_id WHERE ptm.member_id iS NULL AND m.source_name=\"ENSEMBLGENE\"" .
# #       " AND m.genome_db_id=" . $gdb->dbID;
#   $DB::single=1;1;
# #   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
# #   $sth->execute();
#   my $members = $self->{ha}->fetch_all_orphans_by_GenomeDB($gdb);
#   my $gdb_name = $gdb->name;
#   print STDERR "# $gdb_name has ", scalar(@$members), " orphan members\n";
#   my $count = 0;
#   foreach my $member (@$members) {
#     $pafs = $self->{ppafa}->fetch_all_by_qmember_id($member->get_canonical_peptide_Member->dbID);
#     unless (0 != scalar(@$pafs)) {
#       print STDERR $member->stable_id, ",null,null,null,null,null,null,null,null,null,null\n";
#       next;
#     }
#     $count += scalar(@$pafs);
#     foreach my $paf (@$pafs) {
#       my $paf_hit_rank = $paf->hit_rank;
#       next unless ($paf_hit_rank <= $self->{debug});
#       my $paf_score = $paf->score;
#       my $paf_evalue = $paf->evalue;
#       my $paf_exp_evalue = $paf_evalue;
#       $paf_exp_evalue =~ s/.+e\-(.+)$/$1/g;

#       my $bs_ratio;
#       my $ref_score = $self->{ppafa}->fetch_selfhit_by_qmember_id($paf->query_member->dbID)->score;
#       my $ref2_score = $self->{ppafa}->fetch_selfhit_by_qmember_id($paf->hit_member->dbID)->score;
#       if (!defined($ref_score) or 
#           (defined($ref2_score) and ($ref2_score > $ref_score))) {
#         $ref_score = $ref2_score;
#       }
#       if (defined($ref_score)) {
#         $bs_ratio = $paf_score / $ref_score;
#       }

#       print 
#         $paf->query_member->stable_id, ",", 
#           $paf->query_member->genome_db->short_name, ",", 
#             $paf->hit_member->stable_id,  ",", 
#               $paf->hit_member->genome_db->short_name,  ",", 
#                 $paf_evalue, ",",
#                   $paf_exp_evalue, ",",
#                     sprintf("%.1f",$paf_score), ",", 
#                       sprintf("%.2f",$bs_ratio), ",", 
#                         $paf_hit_rank, ",", 
#                           $paf->perc_ident, ",", 
#                             $paf->perc_pos, "\n" if ($paf_hit_rank <= $self->{debug});
#     }
#   }
#   print STDERR "# There are $count hits below the E-10 threshold\n";
# }


# sub _paf_stats {
#   my $self = shift;
#   my $species = shift;
#   $species =~ s/\_/\ /g;

#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#   my $gdb = $self->{gdba}->fetch_by_name_assembly($species);
#   my %orphan_member_ids;
#   foreach my $orphan (@{$self->{ha}->fetch_all_orphans_by_GenomeDB($gdb)}) {
#     $orphan_member_ids{$orphan->member_id} = 1;
#   }

#   print "query_member_stable_id,query_member_genome,hit_member_stable_id,hit_member_genome,is_orphan,evalue,exp_evalue,score,bs_ratio,hit_rank,perc_ident,perc_pos\n";

#   my $all_dbs = $self->{gdba}->fetch_all;
#   foreach my $gdb_sps2 (@$all_dbs) {
#     next if ($gdb_sps2->dbID == $gdb->dbID);
#     my $pafs = $self->{ppafa}->fetch_all_besthit_by_qgenome_db_id_hgenome_db_id($gdb->dbID,$gdb_sps2->dbID);
#     foreach my $paf (@$pafs) {
#       my $paf_hit_rank = $paf->hit_rank;
#       next unless ($paf_hit_rank <= $self->{debug});
#       my $paf_score = $paf->score;
#       my $paf_evalue = $paf->evalue;
#       my $paf_exp_evalue = $paf_evalue;
#       $paf_exp_evalue =~ s/.+e\-(.+)$/$1/g;
#       my $paf_query_member_dbID = $paf->query_member->dbID;
#       my $paf_hit_member_dbID = $paf->hit_member->dbID;
#       my $is_orphan = 0;
#       $is_orphan = 1 if (defined($orphan_member_ids{$paf->query_member->gene_member->dbID}));
#       my $bs_ratio;
#       my $query_selfhit = $self->{ppafa}->fetch_selfhit_by_qmember_id($paf_query_member_dbID);
#       my $hit_selfhit = $self->{ppafa}->fetch_selfhit_by_qmember_id($paf_hit_member_dbID);
#       if (!defined($query_selfhit) && !defined($hit_selfhit)) {
#         $bs_ratio = 0;
#       } else {
#         my $ref_score = $query_selfhit->score if (defined($query_selfhit));
#         my $ref2_score = $hit_selfhit->score if (defined($hit_selfhit));
#         if (!defined($ref_score) or 
#             (defined($ref2_score) and ($ref2_score > $ref_score))) {
#           $ref_score = $ref2_score;
#         }
#         if (defined($ref_score)) {
#           $bs_ratio = $paf_score / $ref_score;
#         }
#       }

#       print 
#         $paf->query_member->stable_id, ",", 
#           $paf->query_member->genome_db->short_name, ",", 
#             $paf->hit_member->stable_id,  ",", 
#               $paf->hit_member->genome_db->short_name,  ",", 
#                 $is_orphan, ",",
#                   $paf_evalue, ",",
#                     $paf_exp_evalue, ",",
#                       sprintf("%.1f",$paf_score), ",", 
#                         sprintf("%.2f",$bs_ratio), ",", 
#                           $paf_hit_rank, ",", 
#                             $paf->perc_ident, ",", 
#                               $paf->perc_pos, "\n" if ($paf_hit_rank <= $self->{debug});
#     }
#   }
# }


# # internal purposes
# sub _homologs_and_paf_scores {
#   my $self = shift;
#   my $species = shift;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{mlssa} = $self->{comparaDBA}->get_MethodLinkSpeciesSetAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;

#   my $sp_db = $self->{gdba}->fetch_by_name_assembly($species);
#   my $all_dbs = $self->{gdba}->fetch_all;
#   my $orthologies;
#   print "query_peptide_stable_id\thit_peptide_stable_id\thomology_type\ttaxonomy_level\tscore\n";
#   foreach my $db (@$all_dbs) {
#     unless ($db->name eq $species) {
#       my $mlss_1 = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs("ENSEMBL_ORTHOLOGUES",[$sp_db,$db]);
#       $orthologies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss_1);
#       $self->print_homology_paf_scores(@$orthologies);
#     }
#   }
#   my $mlss_2 = $self->{mlssa}->fetch_by_method_link_type_GenomeDBs("ENSEMBL_PARALOGUES",[$sp_db]);
#   my $paralogies = $self->{ha}->fetch_all_by_MethodLinkSpeciesSet($mlss_2);
#   $self->print_homology_paf_scores(@$paralogies);
# }

# sub print_homology_paf_scores {
#   my $self = shift;
#   my @homologies = @_;
#   my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;

#   foreach my $homology (@homologies) {
#     my $homology_description = $homology->description;
#     my @two_ids = map { $_->get_canonical_peptide_Member->member_id } @{$homology->gene_list};
#     my $subtype = $homology->subtype;
#     my $pafs = $pafDBA->fetch_all_by_qmember_id_hmember_id($two_ids[0],$two_ids[1]);
#     $subtype =~ s/\///g; $subtype =~ s/\ /\_/g;
#     foreach my $self_paf (@$pafs) {
#       my $hit_peptide_stable_id = $self_paf->hit_member->stable_id;
#       my $query_peptide_stable_id = $self_paf->query_member->stable_id;
#       print "$query_peptide_stable_id\t$hit_peptide_stable_id\t$homology_description\t$subtype\t", $self_paf->score, "\n";
#     }
#   }
# }


#   sub _ncbi_tree_list_shortnames {
#     my $self = shift;
#     my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
#     my $root = $self->{'root'};
#     my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;

#     my %shortnames;
#     foreach my $shortname (split("_", $self->{_ncbi_tree_list_shortnames})) {
#       $shortnames{$shortname} = 1;
#     }

#     foreach my $gdb (@$gdb_list) {
#       next unless (defined($shortnames{$gdb->short_name}));
#       my $taxon = $taxonDBA->fetch_node_by_taxon_id($gdb->taxon_id);
#       $taxon->release_children;

#       $root = $taxon->root unless($root);
#       $root->merge_node_via_shared_ancestor($taxon);
#     }
#     $root = $root->minimize_tree;
#     my $newick = $root->newick_format;
#     my $newick_simple = $newick;
#     $newick_simple =~ s/\:\d\.\d+//g;
#     $newick_simple =~ s/\ /\_/g;
#     $newick_simple =~ s/\//\_/g;
#     print "$newick_simple\n" if ($self->{'print_newick'});
#   }

# sub _pafs {
#   my $self = shift;
#   my $gdb = shift;
#   my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
#   print STDERR "Fetching pafs 22,$gdb\n";
#   my $pafs = $pafDBA->fetch_all_by_qgenome_db_id_hgenome_db_id(22,$gdb);
#   print STDERR "Fetched pafs\n";
#   foreach my $self_paf (@$pafs) {
#     my $hit_peptide_stable_id = $self_paf->hit_member->stable_id;
#     my $query_peptide_stable_id = $self_paf->query_member->stable_id;
#     print "$hit_peptide_stable_id\t$query_peptide_stable_id\t", $self_paf->score, "\n";
#   }
# }


# # internal purposes
# sub _compare_topology {
#   my $gene_tree = shift;
#   my $species_tree = shift;
#   my $topology_matches = 0;

#   my ($g_child_a, $g_child_b) = @{$gene_tree->children};
#   my @g_gdb_a_tmp = map {$_->node_id} @{$g_child_a->get_all_leaves};
#   my @g_gdb_b_tmp = map {$_->node_id} @{$g_child_b->get_all_leaves};
#   my %g_seen = ();  my @g_gdb_a = grep { ! $g_seen{$_} ++ } @g_gdb_a_tmp;
#   %g_seen = ();  my @g_gdb_b = grep { ! $g_seen{$_} ++ } @g_gdb_b_tmp;
#   my ($s_child_a, $s_child_b) = @{$species_tree->children};
#   my @s_gdb_a_tmp = map {$_->node_id} @{$s_child_a->get_all_leaves};
#   my @s_gdb_b_tmp = map {$_->node_id} @{$s_child_b->get_all_leaves};
#   my %s_seen = ();  my @s_gdb_a = grep { ! $s_seen{$_} ++ } @s_gdb_a_tmp;
#   %s_seen = ();  my @s_gdb_b = grep { ! $s_seen{$_} ++ } @s_gdb_b_tmp;

#   # straight
#   my @isect_a = my @diff_a = my @union_a = (); my %count_a;
#   foreach my $e (@g_gdb_a, @s_gdb_a) {
#     $count_a{$e}++;
#   }
#   foreach my $e (keys %count_a) {
#     push(@union_a, $e); push @{ $count_a{$e} == 2 ? \@isect_a : \@diff_a }, $e;
#   }
#   my @isect_b = my @diff_b = my @union_b = (); my %count_b;
#   foreach my $e (@g_gdb_b, @s_gdb_b) {
#     $count_b{$e}++;
#   }
#   foreach my $e (keys %count_b) {
#     push(@union_b, $e); push @{ $count_b{$e} == 2 ? \@isect_b : \@diff_b }, $e;
#   }
#   # crossed
#   my @isect_ax = my @diff_ax = my @union_ax = (); my %count_ax;
#   foreach my $e (@g_gdb_a, @s_gdb_b) {
#     $count_ax{$e}++;
#   }
#   foreach my $e (keys %count_ax) {
#     push(@union_ax, $e); push @{ $count_ax{$e} == 2 ? \@isect_ax : \@diff_ax }, $e;
#   }
#   my @isect_bx = my @diff_bx = my @union_bx = (); my %count_bx;
#   foreach my $e (@g_gdb_b, @s_gdb_a) {
#     $count_bx{$e}++;
#   }
#   foreach my $e (keys %count_bx) {
#     push(@union_bx, $e); push @{ $count_bx{$e} == 2 ? \@isect_bx : \@diff_bx }, $e;
#   }

#   if ((0==scalar(@diff_a) && 0==scalar(@diff_b)) || (0==scalar(@diff_ax) && 0==scalar(@diff_bx))) {
#     $topology_matches = 1;
#   }
#   return $topology_matches;
# }


# # internal purposes
# sub _mark_for_topology_inspection {
#   my $node = shift;
#   my $nodes_to_inspect = 0;
#   my ($child_a, $child_b) = @{$node->children};
#   my @gdb_a_tmp = map {$_->genome_db_id} @{$child_a->get_all_leaves};
#   my @gdb_b_tmp = map {$_->genome_db_id} @{$child_b->get_all_leaves};
#   my %seen = ();  my @gdb_a = grep { ! $seen{$_} ++ } @gdb_a_tmp;
#   %seen = ();  my @gdb_b = grep { ! $seen{$_} ++ } @gdb_b_tmp;
#   my @isect = my @diff = my @union = (); my %count;
#   foreach my $e (@gdb_a, @gdb_b) {
#     $count{$e}++;
#   }
#   foreach my $e (keys %count) { 
#     push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
#   }
#   if (0 == scalar(@isect)) {
#     $node->add_tag('_inspect_topology','1'); $nodes_to_inspect++;
#   }
#   $nodes_to_inspect += _mark_for_topology_inspection($child_a) 
#     if (scalar(@gdb_a)>2);
#   $nodes_to_inspect += _mark_for_topology_inspection($child_b) 
#     if (scalar(@gdb_b)>2);
#   return $nodes_to_inspect;
# }


# # internal purposes
# sub _check_mfurc {
#   my $self = shift;
#   my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#   my $cluster_count;
#   foreach my $cluster (@{$clusterset->children}) {
#     $cluster_count++;
#     foreach my $subnode ($cluster->get_all_subnodes) {
#       my $child_count = scalar(@{$subnode->children});
#       print "multifurcation node_id\n", 
#         $cluster->node_id, if ($child_count > 2);
#       my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
#       print STDERR $verbose_string 
#         if ($self->{'verbose'} && ($cluster_count % $self->{'verbose'} == 0));
#     }
#   }
# }


# # internal purposes
# sub _analyzePattern
#   {
#     my $self = shift;
#     my $species_list_as_in_tree = $self->{species_list} || 
#       "22,10,21,23,3,14,15,19,11,16,9,13,4,18,5,24,12,7,17";
#     my @species_list_as_in_tree = split("\:",$species_list_as_in_tree);

#     printf("analyzePattern root_id: %d\n", $self->{'clusterset_id'});

#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#     #printf("%d clusters\n", $clusterset->get_child_count);

#     my $pretty_cluster_count=0;
#     my $outfile = "analyzePattern.". $self->{'clusterset_id'} . ".txt";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     my $badgenes = "analyzePattern.". $self->{'clusterset_id'} . ".strangepatterns" . ".txt";
#     open BADGENES, ">$badgenes" or die "error opening outfile: $!\n" if ($self->{'_badgenes'});
#     #  printf(OUTFILE "%7s, %10s, %10s, %7s", "node_id", "members", "has_gdb_dups", "time");
#     printf(OUTFILE "%7s, %7s, %7s, %7s, %10s, %8s, %9s", "node_id", "members", "nodes", "species", "has_gdb_dups", "duptags", "time");
#     foreach my $species (@species_list_as_in_tree) {
#       printf(OUTFILE ", %2d", $species);
#     }
#     printf(OUTFILE "\n");
#     my $cluster_count;
#     foreach my $cluster (@{$clusterset->children}) {
#       my %member_totals;
#       $cluster_count++;
#       my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
#       print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
#       my $starttime = time();
#       $treeDBA->fetch_subtree_under_node($cluster);

#       my $member_list = $cluster->get_all_leaves;
#       my %member_gdbs;
#       my $has_gdb_dups=0;

#       my (@duptags) = map {$_->get_tagvalue('Duplication')} $cluster->get_all_subnodes;
#       push @duptags, $cluster->get_tagvalue('Duplication');
#       my $duptags;
#       foreach my $duptag (@duptags) {
#         $duptags++ if (0 != $duptag);
#       }

#       foreach my $member (@{$member_list}) {
#         $has_gdb_dups=1 if($member_gdbs{$member->genome_db_id});
#         $member_gdbs{$member->genome_db_id} = 1;
#         #$member_totals{$member->genome_db_id}{$member->node_id} = scalar(@{$member_list});
#         $member_totals{$member->genome_db_id}++;
#       }
#       my $species_count = (scalar(keys %member_gdbs));
#       #     printf("%7d, %10d, %10d, %10.3f\n", $cluster->node_id, scalar(@{$member_list}), $has_gdb_dups, (time()-$starttime));
#       printf(
#              OUTFILE "%7d, %7d, %7d, %7d, %10d, %10d, %10.3f", 
#              $cluster->node_id, scalar(@{$member_list}), 
#              scalar(@duptags), 
#              $species_count, 
#              $has_gdb_dups, 
#              $duptags, 
#              (time()-$starttime)
#             );
#       #print the patterns
#       foreach my $species (@species_list_as_in_tree) {
#         my $value = 0;
#         $value = $member_totals{$species} if ($member_totals{$species});
#         printf(OUTFILE ", %2d", $value);
#       }
#       print OUTFILE "\n";

#       $pretty_cluster_count++ unless($has_gdb_dups);
#       #badgenes
#       if ($self->{'_badgenes'}) {
#         my $max = 0; my $min = 999; my $mean_num;
#         foreach my $species (keys %member_totals) {
#           $max = $member_totals{$species} if ($member_totals{$species}>$max);
#           $min = $member_totals{$species} if ($member_totals{$species}<$min);
#           $mean_num += $member_totals{$species};
#         }
#         my $mean = $mean_num/$species_count;
#         next unless ($max >= 10);
#         next unless ($max > (3*$mean));
#         # get number of "Un" genes
#         printf(BADGENES "%7d, %7d, %7d, %10d, %10.3f", 
#                $cluster->node_id, 
#                scalar(@{$member_list}), 
#                $species_count, 
#                $has_gdb_dups, 
#                (time()-$starttime));
#         print BADGENES "\n";
#       }
#       ### badgenes

#     }
#     printf("%d clusters without duplicates (%d total)\n", 
#            $pretty_cluster_count, 
#            $cluster_count);
#     close OUTFILE;
#   }

# sub analyzeClusters
#   {
#     my $self = shift;
#     my $species_list = [3,4,5,7,9,10,11,12,13,14,15,16,17,18,19,21,22,23,24];

#     printf("analyzeClusters root_id: %d\n", $self->{'clusterset_id'});

#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});

#     printf("%d clusters\n", $clusterset->get_child_count);

#     my $pretty_cluster_count=0;
#     my $outfile = "analyzeClusters.". $self->{'clusterset_id'} . ".txt";
#     open OUTFILE, ">$outfile" or die "error opening outfile: $!\n";
#     printf(OUTFILE "%7s, %10s, %10s, %7s", 
#            "node_id", 
#            "members", 
#            "has_gdb_dups", 
#            "time");
#     foreach my $species (sort {$a <=> $b} @{$species_list}) {
#       printf(OUTFILE ", %2d", $species);
#     }
#     printf(OUTFILE "\n");
#     #   my %member_totals;
#     foreach my $cluster (@{$clusterset->children}) {
#       my $starttime = time();
#       $treeDBA->fetch_subtree_under_node($cluster);

#       my $member_list = $cluster->get_all_leaves;
#       my %member_gdbs;
#       my $has_gdb_dups=0;
#       foreach my $member (@{$member_list}) {
#         $has_gdb_dups=1 if($member_gdbs{$member->genome_db_id});
#         $member_gdbs{$member->genome_db_id} = 1;
#       }
#       printf(OUTFILE "%7d, %10d, %10d, %10.3f", 
#              $cluster->node_id, 
#              scalar(@{$member_list}), 
#              $has_gdb_dups, 
#              (time()-$starttime));
#       foreach my $species (sort {$a <=> $b} @{$species_list}) {
#         my $value = 0;
#         $value = 1 if $member_gdbs{$species};
#         printf(OUTFILE ", %2d", $value);
#       }
#       print OUTFILE "\n";
#       $pretty_cluster_count++ unless($has_gdb_dups);
#     }
#     printf("%d clusters without duplicates (%d total)\n", 
#            $pretty_cluster_count, 
#            $clusterset->get_child_count);
#     close OUTFILE;
#   }


# sub analyzeClusters2
#   {
#     my $self = shift;
#     # this list should be ok for ensembl_38
#     # use mysql> select genome_db_id,name from genome_db order by genome_db_id;
#     # to check gdb ids
#     my $species_list = [3,4,5,7,9,10,11,12,13,14,15,16,17,18,19,21,22,23,24];
#     #my $species_list = [1,2,3,14];
  
#     $self->{'member_LSD_hash'} = {};
#     $self->{'gdb_member_hash'} = {};

#     my $ingroup = {};
#     foreach my $gdb (@{$species_list}) {
#       $ingroup->{$gdb} = 1;
#       $self->{'gdb_member_hash'}->{$gdb} = []
#     }
  
#     printf("analyzeClusters root_id: %d\n", $self->{'clusterset_id'});

#     my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#     my $clusterset = $self->{'clusterset'};  

#     printf("%d clusters\n", $clusterset->get_child_count);
  
#     my $total_members=0;
#     my $cluster_count=0;
#     my $rosette_count=0;
#     my $lsd_rosette_count=0;
#     my $geneLoss_rosette_count=0;
#     my $match_species_tree_count=0;
#     my %rosette_taxon_hash;
#     my %rosette_newick_hash;
#     foreach my $cluster (@{$clusterset->children}) {

#       $cluster_count++;
#       printf("clustercount $cluster_count\n") if($cluster_count % 100 == 0);
#       my $starttime = time();
#       $treeDBA->fetch_subtree_under_node($cluster);
#       $cluster->disavow_parent;

#       my $member_list = $cluster->get_all_leaves;

#       #test for flat tree
#       my $max_depth = $cluster->max_depth;

#       my $cluster_has_lsd=0;

#       if ($self->{'debug'}) {
#         printf("%s\t%10d, %10d, %7d\n", 'cluster',
#                $cluster->node_id, scalar(@{$member_list}), $max_depth);
#       }

#       if ($max_depth > 1) {
#         foreach my $member (@{$member_list}) {

#           push @{$self->{'gdb_member_hash'}->{$member->genome_db_id}},
#             $member->member_id;

#           # If already analyzed
#           next if(defined($self->{'member_LSD_hash'}->{$member->member_id}));
#           next unless($ingroup->{$member->genome_db_id});

#           my $rosette = find_ingroup_ancestor($self, $ingroup, $member);
#           #$rosette->print_tree;
#           $rosette_count++;
#           if ($self->{'debug'}) {
#             printf("    rosette: %10d, %10d, %10d, %10d\n",
#                    $rosette->node_id, scalar(@{$rosette->get_all_leaves}), 
#                    $cluster->node_id, scalar(@{$member_list}));
#           }

#           my $has_LSDup = test_rosette_for_LSD($self,$rosette);

#           if ($has_LSDup) {
#             print("    LinearSpecificDuplication\n") if($self->{'debug'});
#             #$rosette->print_tree;
#             $lsd_rosette_count++;
#             $rosette->add_tag('rosette_LSDup');
#           }

#           if (!$has_LSDup and $self->{'run_topo_test'}) {
#             if (test_rosette_matches_species_tree($self, $rosette)) {
#               $match_species_tree_count++;
#               $rosette->add_tag('rosette_species_topo_match');
#             } else {
#               $rosette->add_tag('rosette_species_topo_failed');
#             }

#           }

#           if (test_rosette_for_gene_loss($self, $rosette, $species_list)) {
#             $geneLoss_rosette_count++;
#             $rosette->add_tag('rosette_geneLoss');
#           }

#           #generate a taxon_id string
#           my @all_leaves = @{$rosette->get_all_leaves};
#           $total_members += scalar(@all_leaves);
#           my @taxon_list;
#           foreach my $leaf (@all_leaves) {
#             push @taxon_list, $leaf->taxon_id;
#           }
#           my $taxon_id_string = join("_", sort {$a <=> $b} @taxon_list);

#           #generate taxon unique newick string
#           my $taxon_newick_string = taxon_ordered_newick($rosette);

#           if (!$rosette->has_tag('rosette_LSDup')) {
#             $rosette_taxon_hash{$taxon_id_string} = 0 
#               unless (defined($rosette_taxon_hash{$taxon_id_string}));
#             $rosette_taxon_hash{$taxon_id_string}++;

#             $rosette_newick_hash{$taxon_newick_string} = 0 
#               unless (defined($rosette_newick_hash{$taxon_newick_string}));
#             $rosette_newick_hash{$taxon_newick_string}++;
#           }

#           printf("rosette, %d, %d, %d, %d",
#                  $rosette->node_id, scalar(@{$rosette->get_all_leaves}), 
#                  $cluster->node_id, scalar(@{$member_list}));
#           if ($rosette->has_tag("rosette_LSDup")) {
#             print(", LSDup");
#           } else {
#             print(", OK");
#           }
#           if ($rosette->has_tag("rosette_geneLoss")) {
#             print(", GeneLoss");
#           } else {
#             print(", OK");
#           }

#           if ($rosette->has_tag("rosette_species_topo_match")) {
#             print(", TopoMatch");
#           } elsif ($rosette->has_tag("rosette_species_topo_fail")) {
#             print(", TopoFail");
#           } else {
#             print(", -");
#           }

#           print(", $taxon_id_string");
#           print(",$taxon_newick_string");
#           print("\n");

#         }
#       }
#     }
#     printf("\n%d clusters analyzed\n", $cluster_count);
#     printf("%d ingroup rosettes found\n", $rosette_count);
#     printf("   %d rosettes w/o LSD\n", $rosette_count - $lsd_rosette_count);
#     printf("   %d rosettes with LSDups\n", $lsd_rosette_count);
#     printf("   %d rosettes with geneLoss\n", $geneLoss_rosette_count);
#     printf("   %d rosettes no_dups & match species tree\n", $match_species_tree_count);
#     printf("%d ingroup members\n", $total_members);
#     printf("%d members in hash\n", scalar(keys(%{$self->{'member_LSD_hash'}})));

#     foreach my $gdbid (@$species_list) {
#       my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdbid);
#       my $member_id_list = $self->{'gdb_member_hash'}->{$gdbid}; 

#       my $lsd_members=0;
#       foreach my $member_id (@{$member_id_list}) { 
#         $lsd_members++ if($self->{'member_LSD_hash'}->{$member_id});
#       }
#       my $mem_count = scalar(@$member_id_list);
#       printf("%30s(%2d), %7d members, %7d no_dup, %7d LSD,\n", 
#              $gdb->name, $gdbid, $mem_count, $mem_count-$lsd_members, $lsd_members);
#     }
  
#     printf("\nrosette member dists\n");
#     print_hash_bins(\%rosette_taxon_hash);
  
#     printf("\n\n\nrosette newick dists\n");
#     print_hash_bins(\%rosette_newick_hash);
#   }

# sub _analyzeHomologies {
#   my $self = shift;

#   eval {require Digest::MD5;};  die "$@ \n" if ($@);
#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   printf("dbname: %s\n", $self->{'_mydbname'});
#   printf("analyzeHomologies_: %d\n", $self->{'clusterset_id'});
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

#   my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
#   my @clusters = @{$clusterset->children};
#   my $totalnum_clusters = scalar(@clusters);
#   printf("totalnum_trees: %d\n", $totalnum_clusters);
#   foreach my $cluster (@clusters) {
#     next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
#     # my $string = $cluster->get_tagvalue("OrthoTree_types_hashstr");
#     my $cluster_node_id = $cluster->node_id;
#     foreach my $member (@{$cluster->get_all_leaves}) {
#       # my $homologies = $self->{ha}->fetch_by_Member($member->gene_member);
#       # Generate a md5sum string to compare among databases
#       1;                        #ONGOING
#       my $gene_stable_id = $member->gene_member->stable_id;
#       my $transcript_stable_id = $member->transcript->stable_id;
#       my $transcript_analysis_logic_name = $member->transcript->analysis->logic_name;
#       my $peptide_stable_id = $member->stable_id;
#       my $seq = $member->sequence;
#       my $md5sum = md5_hex($seq);
#       $self->{results_string} .= 
#         sprintf "$md5sum,$cluster_node_id,$transcript_analysis_logic_name,$peptide_stable_id,$transcript_stable_id,$gene_stable_id\n";
#     }
#     print $self->{results_string}; $self->{results_string} = '';
#   }
# }

# sub _merge_small_trees {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;

#   $species_set =~ s/\_/\ /g;
#   my ($sp1,$sp2) = split(":",$species_set);
#   my $set;
#   my @shortnames;
#   foreach my $species ($sp1,$sp2) {
#     $set->{$species} = 1;
#     my $genome_db = $self->{gdba}->fetch_by_name_assembly($species);
#     $set->{$species} = $genome_db->dbID;
#     push @shortnames, $genome_db->short_name;
#   }
#   my $cluster;
#   print STDERR "[children] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   my $gene_count = $self->{_merge_small_trees};
#   my $sql = 
#     "SELECT ptt1.node_id FROM protein_tree_tag ptt1, protein_tree_tag ptt2, protein_tree_node ptn ".
#       "WHERE ptn.node_id=ptt1.node_id AND ptn.node_id=ptt2.node_id AND ptt2.node_id=ptt1.node_id AND ptt2.tag='gene_count' AND ptt2.value<=$gene_count AND ptn.parent_id=1 AND ptt1.tag='taxon_name' AND ptt1.value in ".
#         "\(\'$sp1\',\'$sp2\'\)";
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   my ($node_id);
#   my $count;
#   my $totalcount;
#   my $cluster_ids;
#   print STDERR "[querying for small trees] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   while (($node_id) = $sth->fetchrow_array()) {
#     $cluster_ids->{$node_id} = 1;
#   }
#   $sth->finish;
#   my $cluster_count = 0;
#   my $small_trees_num = scalar keys %{$cluster_ids};

#   $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
#   my $filename = "merge_small_trees.".$self->{_mydbname}.".". join("\.",@shortnames).".csv";
#   open (OUT,">$filename") or die "$!\n";
#   print OUT "tree_id,sp,cross_hit_num,minevalue,maxevalue,stable_ids,mergeable,cross_tree_num\n";

#   my $out_string;
#   my $outs;
#   foreach my $cluster_id (keys %{$cluster_ids}) {
#     my $cluster = $self->{treeDBA}->fetch_node_by_node_id($cluster_id);
#     # print STDERR "[cluster] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     my $taxon = $cluster->get_tagvalue("taxon_name");
#     unless (defined($set->{$taxon})) {
#       $cluster->release_tree;
#       next;
#     }
#     ;
#     my $temp;
#     if ($taxon eq $sp2) {
#       $temp = $sp1; $sp1 = $sp2; $sp2 = $temp;
#     }
#     my $member;
#     my $hmember_ids;
#     my @leaves = @{$cluster->get_all_leaves};
#     my $mine = 999; my $maxe = -999;
#     $out_string .= $cluster->node_id . ",$taxon";
#     my @stable_ids;
#     foreach my $member (@leaves) {
#       my $pafs = $self->{ppafa}->fetch_all_by_qmember_id_hgenome_db_id($member->get_canonical_peptide_Member->dbID,$set->{$sp2});
#       my $paf;
#       my $member_id = $member->dbID;
#       my $member_stable_id = $member->stable_id;
#       $member_stable_id =~ s/\-PA//g;
#       push @stable_ids, $member_stable_id;
#       # print STDERR "[member $member_id] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); 
#       next unless (defined($pafs));
#       while ($paf = shift @$pafs) {
#         my $rank = $paf->hit_rank;
#         next unless (1 == $rank);
#         my $evalue = $paf->evalue;
#         $mine = $evalue if ($mine > $evalue);
#         $maxe = $evalue if ($maxe < $evalue);
#         $hmember_ids->{$paf->hit_member_id}++;
#         # print STDERR "[hit_rank $rank evalue $evalue] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose}); $self->{starttime} = time();
#       }
#     }
#     my $hit_num = scalar keys %{$hmember_ids};
#     $out_string .= ",".$hit_num;
#     $out_string .= ",".$mine;
#     $out_string .= ",".$maxe;
#     # print STDERR "[hit_num $hit_num] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     my @hit_member = keys %{$hmember_ids};
#     #     print "######################\n";
#     #     print "####  unispecies #####\n";
#     #    $cluster->print_tree(10);
#     foreach my $hit (@hit_member) {
#       my $member_id = $hit;
#       my $hit_member = $self->{ma}->fetch_by_dbID($member_id);
#       my $hit_cluster = $self->{treeDBA}->fetch_by_Member_root_id($hit_member,1);
#       unless (defined($hit_cluster)) {
#         next;
#       }                         # singletons in the other species
#       my $size = $hit_cluster->get_tagvalue('gene_count');
#       my $hit_node_id = $hit_cluster->node_id;
#       #       print "######################\n";
#       #       print "#### multispecies ####\n";
#       # $hit_cluster->print_tree(10);
#       if ($self->{debug}) {
#         my $aln = $cluster->get_SimpleAlign;
#         my $hit_aln = $hit_cluster->get_SimpleAlign;
#         my $tmp = '/tmp/tmp.fasta';
#         my $hit_tmp = '/tmp/hit_tmp.fasta';
#         my $both_tmp = '/tmp/both_tmp.fasta';
#         my $out = Bio::AlignIO->new(-file => ">$tmp", -format => 'fasta');
#         my $hit_out = Bio::AlignIO->new(-file => ">$hit_tmp", , -format => 'fasta');
#         $out->write_aln($aln);
#         $hit_out->write_aln($hit_aln);
#         my $cmd = "muscle -profile -in1 $tmp -in2 $hit_tmp -out $both_tmp 2>/dev/null";
#         system($cmd);
#         my $both = Bio::AlignIO->new(-file => "$both_tmp", -format => 'fasta');
#         next unless (defined($both));
#         my $both_aln = $both->next_aln;
#         next unless (defined($both_aln));
#         print sprintf("%.1f", $hit_aln->percentage_identity), ",";
#         print sprintf("%.1f",$aln->percentage_identity), ",";
#         print sprintf("%.1f",$both_aln->percentage_identity), "\n";
#         # my $tree_tmp = '/tmp/tree.phy';
#         #         $cmd = "muscle -cluster -in $both_tmp -tree1 $tree_tmp";
#         #         system($cmd);
#         #         my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree(`cat $tree_tmp`);
#         unlink "$tmp";      unlink "$hit_tmp"; unlink "$both_tmp";
#       }
#       $self->{_mergeable}{$cluster_id}{$hit_node_id}{$size} = 1;
#     }
#     $cluster->release_tree if (defined($cluster));
#     my $verbose_string = sprintf "[%5d / %5d trees done] ", $cluster_count, $small_trees_num;
#     if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0)) {
#       print STDERR $verbose_string;
#       print STDERR " ", time()-$self->{starttime}," secs...\n";
#     }
#     $cluster_count++;
#     $out_string .= ",".join("\:",@stable_ids);
#     $outs->{$cluster_id} = $out_string;
#     $out_string = '';
#   }
#   foreach my $cluster_id (keys %{$cluster_ids}) {
#     my $added;
#     if (defined($self->{_mergeable}{$cluster_id})) {
#       my @hit_cluster_nums = keys %{$self->{_mergeable}{$cluster_id}};
#       my $hit_cluster_num = scalar @hit_cluster_nums;
#       $added = ",M,". $hit_cluster_num;
#     } else {
#       $added = ",S,0";
#       $self->{_nohits}{$cluster_id} = 1;
#     }
#     print OUT $outs->{$cluster_id} . $added . "\n";
#   }
#   my $mergeable_num = scalar keys %{$self->{_mergeable}};
#   print "[mergeable $mergeable_num / $small_trees_num] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   foreach my $cluster (keys %{$self->{_mergeable}}) {
#     my @hit_cluster_nums = keys %{$self->{_mergeable}{$cluster}};
#     my $hit_cluster_num = scalar @hit_cluster_nums;
#     print "$cluster hit_cluster_num $hit_cluster_num - ", join("\:",@hit_cluster_nums), "\n";
#   }

#   $filename = "merge_small_trees.nohits.".$self->{_mydbname}.".". join("\.",@shortnames).".csv";
#   open (OUT2,">$filename") or die "$!\n";
#   print OUT2 "tree_id,peptide_stable_id,peptide_member_id\n";
#   foreach my $cluster_id (keys %{$self->{_nohits}}) {
#     my $cluster = $self->{treeDBA}->fetch_node_by_node_id($cluster_id);
#     my @leaves = @{$cluster->get_all_leaves};
#     my $member;
#     while ($member = shift @leaves) {
#       print OUT2 "$cluster_id,",$member->stable_id,",",$member->dbID,"\n";
#     }
#   }
# }

# sub _concatenation {
#   my $self = shift;
#   my $species_set = shift;

#   $self->{starttime} = time();
#   print STDERR "[init] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});

#   $self->{ppafa} = $self->{comparaDBA}->get_PeptideAlignFeatureAdaptor;
#   $self->{gdba} = $self->{comparaDBA}->get_GenomeDBAdaptor;
#   $self->{treeDBA} = $self->{comparaDBA}->get_ProteinTreeAdaptor;
#   $self->{ma} = $self->{comparaDBA}->get_MemberAdaptor;
#   $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
#   $DB::single=1;1;
#   $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;
#   $self->{fa} = $self->{comparaDBA}->get_FamilyAdaptor;

#   $species_set =~ s/\_/\ /g;
#   my @sps = split(":",$species_set);
#   my $deepest;


#   my $species_tree;
#   my $taxon_ids;
#   foreach my $sp (@sps) {
#     my $taxon = $self->{taxonDBA}->fetch_node_by_name($sp);
#     $taxon_ids->{$taxon->dbID} = 1;
#     my @class = split(" ",$taxon->classification);
#     my $tax_count = 0;
#     my $taxonomy;
#     while ($taxonomy = pop @class) {
#       $tax_count = sprintf("%05d",$tax_count);
#       $deepest->{$taxonomy} = $tax_count;
#       $tax_count++;
#     }

#     $taxon->release_children;
#     $species_tree = $taxon->root unless($species_tree);
#     $species_tree->merge_node_via_shared_ancestor($taxon);
#   }
#   $species_tree = $species_tree->minimize_tree;
#   print STDERR "[species tree] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   my $root_taxon = $species_tree->root->name;
#   my $gene_count = $self->{_concatenation};
#   my $sql = 
#     "SELECT ptt1.node_id FROM protein_tree_tag ptt1, protein_tree_tag ptt2, protein_tree_node ptn ".
#       "WHERE ptn.node_id=ptt1.node_id AND ptn.node_id=ptt2.node_id ".
#         "AND ptt2.node_id=ptt1.node_id AND ptt2.tag='gene_count' ".
#           "AND ptt2.value<=$gene_count AND ptn.parent_id=1 ".
#             "AND ptt1.tag='taxon_name' AND ptt1.value=\'$root_taxon\'";
#   my $sth = $self->{comparaDBA}->dbc->prepare($sql);
#   $sth->execute();
#   my $node_id;
#   my $count;
#   my $totalcount;
#   my $cluster_ids;
#   print STDERR "[querying for subtrees at $root_taxon] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#   while (($node_id) = $sth->fetchrow_array()) {
#     $cluster_ids->{$node_id} = 1;
#   }
#   $sth->finish;
#   foreach my $cluster_id (keys %$cluster_ids) {
#     my $cluster = $self->{treeDBA}->fetch_node_by_node_id($cluster_id);
#     my $leaf;
#     my $tax_count;
#     my $gene_count = $cluster->get_tagvalue("gene_count");
#     print STDERR "[$cluster_id - $gene_count] ",time()-$self->{starttime}," secs...\n" if ($self->{verbose});
#     print $cluster->print_tree(10) if ($self->{verbose});
#     my @leaves = @{$cluster->get_all_leaves};
#     while ($leaf = shift @leaves) {
#       my $taxon_id = $leaf->taxon_id;
#       next unless (defined($taxon_ids->{$taxon_id}));
#       $tax_count->{$taxon_id}{$leaf->dbID} = 1;
#     }
#     my $with_paralogues = 0;
#     foreach my $tax (keys %$tax_count) {
#       my @member_ids = keys %{$tax_count->{$tax}};
#       $with_paralogues = $tax if (1 < scalar(@member_ids));
#     }
#     if ($with_paralogues) {
#       my @member_ids = keys %{$tax_count->{$with_paralogues}};
#       $DB::single=1;1;
#       while (my $member_id1 = shift (@member_ids)) {
#         foreach my $member_id2 (@member_ids) {
#           my $paralogy = $self->{ha}->fetch_by_Member_id_Member_id($member_id1,$member_id2);
#         }
#       }
#     }
#     $cluster->release_tree;
#   }
# }

sub _print_as_species_ids {
  my $self = shift;
  $self->{_mydbname} = $self->{comparaDBA}->dbc->dbname;
  $self->{ha} = $self->{comparaDBA}->get_HomologyAdaptor;

  my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{taxonDBA} = $self->{comparaDBA}->get_NCBITaxonAdaptor;
  my $clusterset = $treeDBA->fetch_node_by_node_id($self->{'clusterset_id'});
  my @clusters = @{$clusterset->children};
  my $totalnum_clusters = scalar(@clusters);
  print STDERR "totalnum_trees: ", $totalnum_clusters, "\n";
  foreach my $cluster (@clusters) {
    next if ('1' eq $cluster->get_tagvalue('cluster_had_to_be_broken_down'));
    my $cluster_node_id = $cluster->node_id;
    print "# $cluster_node_id\n" if ($self->{debug});
    #    my $newick = $cluster->newick_format('species');
    my $newick = $cluster->newick_format('species_short_name');
    $newick =~ s/\;//;
    print "$newick\n";
  }
}


sub print_hash_bins
  {
    my $hash_ref = shift;
  
    my @bins;
    foreach my $key (keys %$hash_ref) {
      my $bin = {};
      $bin->{'count'} = $hash_ref->{$key};
      $bin->{'name'} = $key; 
      push @bins, $bin;
    }
    @bins = sort {$b->{'count'} <=> $a->{'count'}} @bins; 
    foreach my $bin (@bins) {
      printf("   %7d : %s\n", $bin->{'count'}, $bin->{'name'});
    }
  }

  sub find_ingroup_ancestor
  {
    my $self = shift;
    my $ingroup = shift;
    my $node = shift;
  
    my $ancestor = $node->parent;
    return $node unless($ancestor); #reached root, so all members are 'ingroup'
  
    my $has_outgroup=0;
    foreach my $member (@{$ancestor->get_all_leaves}) {
      if (!($ingroup->{$member->genome_db_id})) {
        $has_outgroup=1;
        last;
      }
    }
    return $node if($has_outgroup);
    return find_ingroup_ancestor($self, $ingroup, $ancestor);
  }


sub test_rosette_for_LSD
  {
    my $self = shift;
    my $rosette = shift;
  
    my $member_list = $rosette->get_all_leaves;
    my %gdb_hash;
    my $rosette_has_LSD = 0;
    foreach my $member (@{$member_list}) {
      $gdb_hash{$member->genome_db_id} = 0 
        unless (defined($gdb_hash{$member->genome_db_id}));
      $gdb_hash{$member->genome_db_id} += 1;
    }
    foreach my $member (@{$member_list}) {
      my $gdb_has_LSD = $gdb_hash{$member->genome_db_id} - 1;
      $rosette_has_LSD=1 if($gdb_has_LSD > 0);
      $self->{'member_LSD_hash'}->{$member->member_id} = $gdb_has_LSD;
    }
  
    return $rosette_has_LSD;
  }


sub test_rosette_for_gene_loss
  {
    my $self = shift;
    my $rosette = shift;
    my $species_list = shift;

    my $member_list = $rosette->get_all_leaves;
    my %gdb_hash;
    my $rosette_has_geneLoss = 0;
    foreach my $member (@{$member_list}) {
      $gdb_hash{$member->genome_db_id} = 0 
        unless (defined($gdb_hash{$member->genome_db_id}));
      $gdb_hash{$member->genome_db_id} += 1;
    }

    foreach my $gdb (@{$species_list}) {
      unless ($gdb_hash{$gdb}) {
        $rosette_has_geneLoss=1;
      }
    }

    return $rosette_has_geneLoss;
  }


sub test_rosette_matches_species_tree
  {
    my $self = shift;
    my $rosette = shift;

    return 0 unless($rosette);
    return 0 unless($rosette->get_child_count > 0);

    #$rosette->print_tree;

    #copy the rosette and replace the peptide_member leaves with taxon
    #leaves
    $rosette = $rosette->copy;
    my $leaves = $rosette->get_all_leaves;
    foreach my $member (@$leaves) {
      my $gene_taxon = new Bio::EnsEMBL::Compara::NCBITaxon;
      $gene_taxon->ncbi_taxid($member->taxon_id);
      $gene_taxon->distance_to_parent($member->distance_to_parent);
      $member->parent->add_child($gene_taxon);
      $member->disavow_parent;
    }
    #$rosette->print_tree;

    #build real taxon tree from NCBI taxon database
    my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
    my $species_tree = undef;
    foreach my $member (@$leaves) {
      my $ncbi_taxon = $taxonDBA->fetch_node_by_taxon_id($member->taxon_id);
      $ncbi_taxon->no_autoload_children;
      $species_tree = $ncbi_taxon->root unless($species_tree);
      $species_tree->merge_node_via_shared_ancestor($ncbi_taxon);
    }
    $species_tree = $species_tree->minimize_tree;
    #$species_tree->print_tree;

    #use set theory to test tree topology
    #foreach internal node of the tree, flatten all the leaves into sets.
    #if two trees have the same topology, then all these internal flattened sets
    #will be present.
    #print("BUILD GENE topology sets\n");
    my $gene_topo_sets = new Bio::EnsEMBL::Compara::NestedSet;
    foreach my $node ($rosette->get_all_subnodes) {
      next if($node->is_leaf);
      my $topo_set = $node->copy->flatten_tree;
      #$topo_set->print_tree;
      $gene_topo_sets->add_child($topo_set);
    }

    #print("BUILD TAXON topology sets\n");
    my $taxon_topo_sets = new Bio::EnsEMBL::Compara::NestedSet;
    foreach my $node ($species_tree->get_all_subnodes) {
      next if($node->is_leaf);
      #    my $topo_set = $node->copy->flatten_tree;
      my $topo_set = $node->flatten_tree;
      #$topo_set->print_tree;
      $taxon_topo_sets->add_child($topo_set);
    }

    #printf("TEST TOPOLOGY\n");
    my $topology_matches = 0;
    foreach my $taxon_set (@{$taxon_topo_sets->children}) {
      #$taxon_set->print_tree;
      #print("test\n");
      $topology_matches=0;
      foreach my $gene_set (@{$gene_topo_sets->children}) {
        #$gene_set->print_tree;
        if ($taxon_set->equals($gene_set)) {
          #print "  MATCH\n";
          $topology_matches=1;
          $gene_set->disavow_parent;
          last;
        }
      }
      unless($topology_matches) {
        #printf("FAILED to find a match -> topology doesn't match\n");
        last;
      }
    }
    if ($topology_matches) {
      #print("TREES MATCH!!!!");
    }

    #cleanup copies

    #printf("\n\n");
    return $topology_matches;
  }


###############################
# taxon ordered newick
###############################


sub min_taxon_id {
  my $node = shift;

  return $node->taxon_id if($node->is_leaf);
  return $node->{'_leaves_min_taxon_id'} 
    if (defined($node->{'_leaves_min_taxon_id'}));

  my $minID = undef;
  foreach my $child (@{$node->children}) {
    my $taxon_id = min_taxon_id($child);
    $minID = $taxon_id unless(defined($minID) and $taxon_id>$minID);
  }
  $node->{'_leaves_min_taxon_id'} = $minID;
  return $minID;
}


sub taxon_ordered_newick {
  my $node = shift;
  my $newick = "";

  if ($node->get_child_count() > 0) {
    $newick .= "(";

    my @sorted_children = 
      sort {min_taxon_id($a) <=> min_taxon_id($b)} @{$node->children};

    my $first_child=1;
    foreach my $child (@sorted_children) {
      $newick .= "," unless($first_child);
      $newick .= taxon_ordered_newick($child);
      $first_child = 0;
    }
    $newick .= ")";
  }

  $newick .= sprintf("%d", $node->taxon_id) if($node->is_leaf);
  return $newick;
}


#################################################
#
# tree manipulation algorithms
#
#################################################


sub balance_tree
  {
    my $self = shift;

    #$self->{'tree'}->print_tree($self->{'scale'});

    my $node = new Bio::EnsEMBL::Compara::NestedSet;
    $node->merge_children($self->{'tree'});
    $node->node_id($self->{'tree'}->node_id);

    # get a link
    my ($link) = @{$node->links};
    $link = Bio::EnsEMBL::Compara::Graph::Algorithms::find_balanced_link($link);
    #  print("balanced link is\n    ");
    #  $link->print_link;
    my $root = 
      Bio::EnsEMBL::Compara::Graph::Algorithms::root_tree_on_link($link);
    #$root->print_tree($self->{'scale'});

    #remove old root if it has become a redundant internal node
    $node->minimize_node;
    #$root->print_tree($self->{'scale'});

    #move tree back to original root node
    $self->{'tree'}->merge_children($root);
  }

# internal purposes
sub _compare_treefam
  {
    my $self = shift;
    my ($treefam_entry, $treefam_nhx) = '';
    #my $oneTonebigtrees = 0;
    my $infile = $self->{'_treefam_file'};
    my $outfile = $self->{'_treefam_file'};
    my ($infilebase,$path,$type) = fileparse($infile);
    $outfile .= ".gp.txt";
    my $io = new Bio::Root::IO();my ($tmpfilefh,$tempfile) = $io->tempfile(-dir => "/tmp"); #internal purposes
    #  open OUTFILE, ">$outfile" or die "couldnt open outfile: $!\n" if ($self->{'_orthotree_treefam'});
    print $tmpfilefh "tree_type,tree_id,gpair_link,type,sub_type\n" if ($self->{'_orthotree_treefam'});
    print("load from file ", $infile, "\n") if $self->{'debug'};
    _transfer_input_to_tmp($infile, "/tmp/$infilebase") if $self->{'_farm'};
    open (FH, "/tmp/$infilebase") 
      or die("Could not open treefam_nhx file [/tmp/$infile]") if $self->{'_farm'};
    open (FH, $infile) 
      or die("Could not open treefam_nhx file [$infile]") unless $self->{'_farm'};
    my $cluster_count = 0;

    while (<FH>) {
      $treefam_entry .= $_;
      next unless $treefam_entry =~ /;/;
      my ($treefamid, $treefam_nhx) = split ("\t",$treefam_entry);
      $treefam_entry = '';
      my $tf = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($treefam_nhx);
      $cluster_count++;
      my $verbose_string = sprintf "[%5d trees done]\n", $cluster_count;
      print STDERR $verbose_string if ($self->{'verbose'} &&  ($cluster_count % $self->{'verbose'} == 0));
      next unless (defined $tf);
      my %gsid_names;
      my %differ_leaves;
      my (@shared, @differ);
      my ($gt, $gt_node_id);
      my (%treeid_shared, %tf_gt_map, %tf_gt_keepleaves);
      my (@gt_genenames, @tf_genenames, @tf_genename_speciesname);

      my $starttime = time();

      # recalling a genetree for each leaf of treefam tree
      my @leaves = @{$tf->get_all_leaves};
      foreach my $leaf (@leaves) {
        my $genename = $leaf->get_tagvalue('G');
        push @tf_genenames, $genename unless (0 == length($genename));
        my $genename_speciesname = $genename . ", " . $leaf->get_tagvalue('S');
        push @tf_genename_speciesname, $genename_speciesname;
      }

      printf( STDERR "- end of loading foreach -- %10.3f\n", time()-$starttime) if ($self->{'debug'});
      $starttime = time();

      foreach my $leaf (@leaves) {
        my $leaf_name = $leaf->name;
        # treefam uses G NHX tag for genename
        my $genename = $leaf->get_tagvalue('G');
        next if (0==length($genename)); # for weird pseudoleaf tags with no gene name
        $leaf->name($genename);
        # Asking for a genetree given the genename of a treefam tree
        if (fetch_protein_tree_with_gene($self, $genename)) {
          next if ('1' eq $self->{'tree'}->get_tagvalue('cluster_had_to_be_broken_down'));
          $gt = $self->{'tree'};
          @gt_genenames = ();
          foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
            my $description = $leaf->description;
            $description =~ /Gene\:(\S+)/;
            push @gt_genenames, $1;
          }
          $gt_node_id = $self->{'tree'}->node_id;
          $treeid_shared{$self->{'tree'}->node_id} += 1;
          push @shared, $genename;
          $tf_gt_map{$treefamid}{$gt_node_id} = 1;
          ##
          my @isect = my @diff = my @union = ();
          my %count;
          foreach my $e (@tf_genenames, @gt_genenames) {
            $count{$e}++;
          }
          foreach my $e (keys %count) {
            push(@union, $e);
            push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
          }
          ##
          my $to_keep = join(",", @isect);
          $tf_gt_keepleaves{$treefamid}{$gt_node_id} = $to_keep;
          $gsid_names{$gt_node_id}{$leaf_name} = $genename;
        } else {
          $differ_leaves{$leaf_name} = 1;
        }
      }

      printf( STDERR "- end of first foreach -- %10.3f\n", time()-$starttime) if ($self->{'debug'});
      $starttime = time();

      unless (defined($gt)) {
        # this treefam tree doesnt overlap any of the genetrees
        $self->{'_tf_nomatch'}{$treefamid} = 1;
        foreach my $id (@tf_genename_speciesname) {
          $self->{'_tf_nomatch_genes'}{$treefamid}{$id} = 1;
        }
      }

      # Do this for every gt that has a match to our tf tree genesx
      foreach my $treeid (keys %{$tf_gt_map{$treefamid}}) {
        my $treeDBA = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
        $self->{'tree'} = $treeDBA->fetch_node_by_node_id($treeid);
        $gt = $self->{'tree'};

        my $incomparison_tf = 
          Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($treefam_nhx);
        # Only the shared leaves of the tree are kept. Renamed to gsids
        #$oneTonebigtrees++ if (2000 < scalar(@{$self->{'tree'}->get_all_leaves}));
        next if (2000 < scalar(@{$self->{'tree'}->get_all_leaves})); #avoid huge trees
        foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
          # This is to map the genename to the main identifier
          my $description = $leaf->description;
          $description =~ /Gene\:(\S+)/;
          my $desc_gsid = $1;
          $leaf->name($desc_gsid) unless (0 == length($desc_gsid));
        }
        $self->{'keep_leaves'} = $tf_gt_keepleaves{$treefamid}{$treeid};
        keep_leaves($self);
        $self->{_treefam} = 0;
        my %leaf_to_member;
        my %leaf_to_genome_db_id;
        foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
          $leaf_to_member{$leaf->name} = $leaf->member_id;
          $leaf_to_genome_db_id{$leaf->name} = $leaf->genome_db_id;
        }
        $self->{_gpresults} = '';
        _run_orthotree($self) if ($self->{'_orthotree_treefam'});

        my $gt_lc = scalar(@{$self->{'tree'}->get_all_leaves}) unless $self->{'_orthotree_treefam'};
        $incomparison_tf->node_id($self->{'tree'}->node_id);
        dumpTreeAsNewick($self, $self->{'tree'}) unless ($self->{'_orthotree_treefam'});

        # stuffing treefam tree into $self->{'tree'} -- caution
        $gt = $self->{'tree'};
        @leaves = @{$incomparison_tf->get_all_leaves};
        foreach my $leaf (@leaves) {
          my $genename = $leaf->get_tagvalue('G');
          next if (0==length($genename)); #for weird pseudoleaf tags with no gene name
          $leaf->name($genename);
        }
        $self->{'tree'} = $incomparison_tf;
        $self->{'keep_leaves'} = $tf_gt_keepleaves{$treefamid}{$treeid};
        # first round
        # With the rooting it should be ok
        my $tf_root = new Bio::EnsEMBL::Compara::NestedSet;
        $tf_root->add_child($tf->root, 0.0);
        keep_leaves($self);
        foreach my $leaf (@{$self->{'tree'}->get_all_leaves}) {
          my $name = $leaf->name;
          bless $leaf, "Bio::EnsEMBL::Compara::GeneTreeMember";
          $leaf->name($name);
          $leaf->{'_dbID'} = $leaf_to_member{$name};
          $leaf->{'_genome_db_id'} = $leaf_to_genome_db_id{$name};
        }
        $tf = $self->{'tree'};
        $self->{_treefam} = $treefamid;
        _run_orthotree($self) if ($self->{'_orthotree_treefam'});
        print $tmpfilefh $self->{_gpresults}; $self->{_gpresults} = '';
        my $tf_lc = scalar(@{$self->{'tree'}->get_all_leaves});
        # second round may be necessary for cleaning extra anonymous close-to-root leaves in tf
        print STDERR "gt leaves ", $gt_lc,"\n" unless $self->{'_orthotree_treefam'};
        print STDERR "tf leaves ", $tf_lc,"\n" unless $self->{'_orthotree_treefam'};
        dumpTreeAsNewick($self, $self->{'tree'}) unless ($self->{'_orthotree_treefam'});

        #$self->{'tree'} = 0;
        #$self->{'tree'}->release_tree;
      }

      printf( STDERR "- end of second foreach -- %10.3f\n", time()-$starttime) if ($self->{'debug'});
      $starttime = time();

      1;
    }
    _delete_input_from_tmp("/tmp/$infilebase") if $self->{'_farm'};
    #print STDERR "bigtrees (2000 limit) with one-one gt-tf = $oneTonebigtrees\n";
    _close_and_transfer($tmpfilefh,$outfile,$tempfile);

    # tf_nomatch results
    my $tf_nomatch_results_string = "";
    foreach my $treefamid (keys %{$self->{'_tf_nomatch'}}) {
      $tf_nomatch_results_string .= sprintf("$treefamid, null\n");
      foreach my $genename (keys %{$self->{'_tf_nomatch_genes'}{$treefamid}}) {
        $tf_nomatch_results_string .= sprintf("$genename\n");
      }
    }
    $outfile = $self->{'_treefam_file'};
    $outfile .= "_tf_nomatch.gp.txt";
    open (TFNOMATCH, ">$outfile") or die "couldnt open outfile: $!\n";
    print TFNOMATCH "$tf_nomatch_results_string";
    close TFNOMATCH;
  }


sub _run_orthotree {
  my $self = shift;
  # nasty nasty reblessing hack
  bless $self, "Bio::EnsEMBL::Compara::RunnableDB::OrthoTree";
  $self->{'protein_tree'} = $self->{'tree'};
  if (defined($self->{'_readonly'})) {
    if ($self->{'_readonly'} == 0) {
      1;
    }
  } else {
    $self->{'_readonly'} = 1;
  }
  $self->load_species_tree() unless($self->{_treefam}); #load only once
  $self->Bio::EnsEMBL::Compara::RunnableDB::OrthoTree::_treefam_genepairlink_stats;
  bless $self, "Bio::EnsEMBL::Compara::ProteinTree";
}


sub test7
  {
    my $self = shift;
  
    my $newick ="((1:0.110302,(3:0.104867,2:0.078911):0.265676):0.019461, 14:0.205267);";
    printf("newick string: $newick\n");
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
    print "tree_string1: ",$tree->newick_simple_format,"\n";
    $tree->print_tree;

    $tree->print_tree;
    my $node = $tree->find_node_by_name('3');
    $node->print_node;
    $node->disavow_parent;
    $tree->print_tree;
  
    $tree = $tree->minimize_tree;
    $tree->print_tree;
  
    $tree->release_tree;
    exit(1);
  }


sub chop_tree
  {
    my $self = shift;
  
    $self->{'tree'}->print_tree($self->{'scale'});
  
    my $node = new Bio::EnsEMBL::Compara::NestedSet;
    $node->merge_children($self->{'tree'});

    my ($link) = @{$node->links};
    $link->print_link;
  
    $link = Bio::EnsEMBL::Compara::Graph::Algorithms::find_balanced_link($link);
    my $root = Bio::EnsEMBL::Compara::Graph::Algorithms::root_tree_on_link($link);

    $root->print_tree($self->{'scale'});
    bless $node, "Bio::EnsEMBL::Compara::Graph::Node";
    $node->minimize_node;
    Bio::EnsEMBL::Compara::Graph::Algorithms::parent_graph($root);
    $root->print_tree($self->{'scale'});
  
    $self->{'tree'}->merge_children($root);
    $node->minimize_node;
  }

# this is really really only for internal purposes - kitten-killer
sub _close_and_transfer {
  my $tmpfilefh = shift;
  my $outfile = shift;
  my $tmpoutfile = shift;
  close $tmpfilefh;
  unless(system("lsrcp $tmpoutfile bc-9-1-03:$outfile") == 0) {
    warn ("warn lsrcp tempfile, $!\n");
    unless(system("cp $tmpoutfile $outfile") == 0) {
      warn ("warn cp tempfile, $!\n");
    }
  }
  unless(system("rm -f $tmpoutfile") == 0) {
    warn ("error deleting tempfile, $!\n");
  }
}

# this is really really only for internal purposes - kitten-killer
sub _transfer_input_to_tmp {
  my $infile = shift;
  my $tmpinfile = shift;
  unless(system("lsrcp bc-9-1-03:$infile $tmpinfile") == 0) {
    warn ("warn lsrcp tempfile, $!\n");
    unless(system("cp $infile $tmpinfile") == 0) {
      warn ("warn cp tempfile, $!\n");
    }
  }
}

sub _delete_input_from_tmp {
  my $tmpinfile = shift;
  unless(system("rm -f $tmpinfile") == 0) {
    warn ("error deleting tempfile, $!\n");
  }
}

sub mean_pm {
  my $stat = new Statistics::Descriptive::Sparse();
  $stat->add_data(@_);
  return $stat->mean();
}

sub median_pm {
  require Statistics::Descriptive;
  my $stat = new Statistics::Descriptive::Sparse();
  $stat->add_data(@_);
  return $stat->median();
}

sub std_dev_pm {
  my $stat = new Statistics::Descriptive::Sparse();
  $stat->add_data(@_);
  return $stat->standard_deviation();
}

sub add_tags {
  my $self = shift;
  my $node = shift;

  if ($node->get_tagvalue("Duplication") eq '1') {
    $node->add_tag('Duplication', 1);
  } else {
    $node->add_tag('Duplication', 0);
  }

  if (defined($node->get_tagvalue("B"))) {
    my $bootstrap_value = $node->get_tagvalue("B");
    if (defined($bootstrap_value) && $bootstrap_value ne '') {
      $node->add_tag('Bootstrap', $bootstrap_value);
    }
  }
  if (defined($node->get_tagvalue("DD"))) {
    my $dubious_dup = $node->get_tagvalue("DD");
    if (defined($dubious_dup) && $dubious_dup ne '') {
      $node->add_tag('dubious_duplication', $dubious_dup);
    }
  }
  if (defined($node->get_tagvalue("E"))) {
    my $n_lost = $node->get_tagvalue("E");
    $n_lost =~ s/.{2}//;        # get rid of the initial $-
    my @lost_taxa = split('-',$n_lost);
    my %lost_taxa;
    foreach my $taxon (@lost_taxa) {
      $lost_taxa{$taxon} = 1;
    }
    foreach my $taxon (keys %lost_taxa) {
      $node->add_tag('lost_taxon_id', $taxon);
    }
  }
  if (defined($node->get_tagvalue("SISi"))) {
    my $sis_score = $node->get_tagvalue("SISi");
    if (defined($sis_score) && $sis_score ne '') {
      $node->add_tag('SISi', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SISu"))) {
    my $sis_score = $node->get_tagvalue("SISu");
    if (defined($sis_score) && $sis_score ne '') {
      $node->add_tag('SISu', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS"))) {
    my $sis_score = $node->get_tagvalue("SIS");
    if (defined($sis_score) && $sis_score ne '') {
      $node->add_tag('species_intersection_score', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS1"))) {
    my $sis_score = $node->get_tagvalue("SIS1");
    if (defined($sis_score) && $sis_score ne '') {
      $node->add_tag('SIS1', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS2"))) {
    my $sis_score = $node->get_tagvalue("SIS2");
    if (defined($sis_score) && $sis_score ne '') {
      $node->add_tag('SIS2', $sis_score);
    }
  }
  #   if (defined($node->get_tagvalue("SIS3"))) {
  #     my $sis_score = $node->get_tagvalue("SIS3");
  #     if (defined($sis_score) && $sis_score ne '') {
  #       if ($self->debug) {
  #         printf("store SIS3 : $sis_score "); $node->print_node;
  #       }
  #       $node->add_tag('SIS3', $sis_score);
  #     }
  #  }

  foreach my $child (@{$node->children}) {
    $self->add_tags($child);
  }
}

sub dumpTreeToWorkdir {
    my $self = shift;
    my $tree = shift;
    my $tempdir = shift;
  
    my @leaves = @{$tree->get_all_leaves};
    my $leafcount = scalar(@leaves);
    if ($leafcount<3) {
      printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", $tree->node_id);
      return undef;
    }
    # printf("dumpTreeToWorkdir : %d members\n", $leafcount) if($self->debug);
  
    my $treeName = "proteintree_". $tree->node_id;
    $self->{'file_root'} = $tempdir. $treeName;
    #$self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

    my $rap_infile =  $self->{'file_root'} . ".rap_in";
    $self->{'rap_infile'} = $rap_infile;
    $self->{'rap_outfile'} = $self->{'file_root'} . ".rap_out";
  
    return $rap_infile if(-e $rap_infile);

    # print("rap_infile = '$rap_infile'\n") if($self->debug);

    open(OUTFILE, ">$rap_infile")
      or $self->throw("Error opening $rap_infile for write");

    printf(OUTFILE "$treeName\n[\n");
  
    foreach my $member (@leaves) {
      printf(OUTFILE "%s\"%s\"\n", $member->member_id, $member->genome_db->name);
    }
    print OUTFILE "]\n";
  
    print OUTFILE $self->rap_newick_format($tree);
    print OUTFILE ";\n";
  
    close OUTFILE;
  
    return $rap_infile;
}

# sub rap_newick_format {
#   my $self = shift;
#   my $tree_node = shift;
#   my $newick = "";
  
#   if ($tree_node->get_child_count() > 0) {
#     $newick .= "(";
#     my $first_child=1;
#     foreach my $child (@{$tree_node->sorted_children}) {  
#       $newick .= "," unless($first_child);
#       $newick .= $self->rap_newick_format($child);
#       $first_child = 0;
#     }
#     $newick .= ")";
#   }
  
#   if (!($tree_node->equals($self->{'protein_tree'}))) {
#     if ($tree_node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
#       $newick .= sprintf("%s", $tree_node->member_id,);
#     }
#     $newick .= sprintf(":%1.4f", $tree_node->distance_to_parent);
#   }

#   return $newick;
# }

# sub parse_RAP_output {
#     my $self = shift;
#     my $rap_outfile =  $self->{'rap_outfile'};
#     my $tree = $self->{'protein_tree'};
  
#     #cleanup old tree structure- 
#     #  flatten and reduce to only GeneTreeMember leaves
#     #  unset duplication tags
#     $tree->flatten_tree;
#     #  $tree->print_tree($self->{'tree_scale'}) if($self->debug>2);
#     foreach my $node (@{$tree->get_all_leaves}) {
#       $node->add_tag("Duplication", 0);
#       unless($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
#         $node->disavow_parent;
#       }
#     }
#     $tree->add_tag("Duplication", 0);

#     #parse newick into a new tree object structure
#     # print("load from file $rap_outfile\n") if($self->debug);
#     open (FH, $rap_outfile) or throw("Could not open newick file [$rap_outfile]");
#     my $chew_rap = 1;
#     while ($chew_rap>0) { 
#       my $line = <FH>;
#       chomp($line);
#       # printf("rap line %d : %s\n", $chew_rap, $line) if($self->debug>2);
#       if ($line =~ "^]") {
#         $chew_rap=0;
#       } else {
#         $chew_rap++;
#       }
#       ;
#     }
#     my $newick = <FH>;
#     chomp($newick);
#     close(FH);
#     # printf("rap_newick_like_string: '%s'\n", $newick) if($self->debug>1);
    
#     my $newtree = $self->parse_rap_newick_into_tree($newick);
#     #  $newtree->print_tree($self->{'tree_scale'}) if($self->debug > 1);
  
#     #leaves of newick tree are named with member_id of members from input tree
#     #move members (leaves) of input tree into newick tree to mirror the 'member_id' nodes
#     foreach my $member (@{$tree->get_all_leaves}) {
#       my $tmpnode = $newtree->find_node_by_name($member->member_id);
#       if ($tmpnode) {
#         $tmpnode->add_child($member, 0.0);
#         $tmpnode->minimize_node; #tmpnode is now redundant so it is removed
#       } else {
#         print("unable to find node in newick for member"); 
#         $member->print_member;
#       }
#     }
  
#     # merge the trees so that the children of the newick tree are now attached to the 
#     # input tree's root node
#     $tree->merge_children($newtree);
#     $tree->add_tag("Duplication", $newtree->get_tagvalue('Duplication'));

#     #newick tree is now empty so release it
#     $newtree->release_tree;

#     #  $tree->print_tree($self->{'tree_scale'}) if($self->debug);
#     return undef;
# }

# sub parse_rap_newick_into_tree {
#     my $self = shift;
#     my $newick = shift;

#     my $count=1;
#     my $debug = 0;
#     print("$newick\n") if($debug);
#     my $token = next_token(\$newick, "(;");
#     my $lastset = undef;
#     my $node = undef;
#     my $root = undef;
#     my $state=1;
#     my $bracket_level = 0;

#     while ($token) {
#       if ($debug) {
#         printf("state %d : '%s'\n", $state, $token);
#       }
#       ;

#       switch ($state) {

#         case 1 {
#           $node = new Bio::EnsEMBL::Compara::NestedSet;
#           $node->node_id($count++);
#           $lastset->add_child($node) if($lastset);
#           $root=$node unless($root);
#           if ($token eq '#') {
#             if ($debug) {
#               printf("   Duplication node\n");
#             }
#             ;
#             $node->add_tag("Duplication", 1);
#             $token = next_token(\$newick, "(");  
#             if ($debug) {
#               printf("state %d : '%s'\n", $state, $token);
#             }
#             ;
#             if ($token ne "(") {
#               throw("parse error: expected ( after #\n");
#             }
#           }
#           $node->print_node if($debug);

#           if ($token eq '(') {  #create new set
#             printf("    create set\n")  if($debug);
#             $token = next_token(\$newick, "\"/(:,)");
#             $state = 1;
#             $bracket_level++;
#             $lastset = $node;
#           } else {
#             $state = 2;
#           }
#         }
#           case 2 {
#             if ($token eq '/') {
#               printf("eat the /\n") if($debug);
#               $token = next_token(\$newick, "\"/(:,)"); #eat it
#             } elsif ($token eq '"') {
#               $token = next_token(\$newick, '"');
#               printf("got quoted name : %s\n", $token) if($debug);
#               $node->name($token);
#               $node->add_tag($token, "");
#               if ($debug) {
#                 print("    naming leaf"); $node->print_node;
#               }
#               $token = next_token(\$newick, "\""); #eat end "
#               unless($token eq '"') {
#                 throw("parse error: expected matching \"");
#               }
#               $token = next_token(\$newick, "/(:,)");   #eat it
#             } elsif (!($token =~ /[:,);]/)) {           #unquoted name
#               $node->name($token);
#               if ($debug) {
#                 print("    naming leaf"); $node->print_node;
#               }
#               $token = next_token(\$newick, "/:,);");
#             } else {
#               $state = 3;
#             }
#           }
#             case 3 {            # optional : and distance
#               if ($token eq ':') {
#                 $token = next_token(\$newick, ",);");
#                 $node->distance_to_parent($token);
#                 if ($debug) {
#                   print("set distance: $token\n   "); $node->print_node;
#                 }
#                 $token = next_token(\$newick, ",);"); #move to , or )
#               }
#               $state = 4;
#             }
#               case 4 {          # end node
#                 if ($token eq ')') {
#                   if ($debug) {
#                     print("end set : "); $lastset->print_node;
#                   }
#                   $node = $lastset;        
#                   $lastset = $lastset->parent;
#                   $token = next_token(\$newick, "\"/:,);");
#                   $state=2;
#                   $bracket_level--;
#                 } elsif ($token eq ',') {
#                   $token = next_token(\$newick, "\"/(:,)");
#                   $state=1;
#                 } elsif ($token eq ';') {
#                   #done with tree
#                   throw("parse error: unbalanced ()\n") if($bracket_level ne 0);
#                   $state=13;
#                   $token = next_token(\$newick, "(");
#                 } else {
#                   throw("parse error: expected ; or ) or ,\n");
#                 }
#               }

#                 case 13 {
#                   throw("parse error: nothing expected after ;");
#                 }
#               }
#     }
#     return $root;
# }

sub next_token {
  my $string = shift;
  my $delim = shift;

  $$string =~ s/^(\s)+//;

  return undef unless(length($$string));

  #print("input =>$$string\n");
  #print("delim =>$delim\n");
  my $index=undef;

  my @delims = split(/ */, $delim);
  foreach my $dl (@delims) {
    my $pos = index($$string, $dl);
    if ($pos>=0) {
      $index = $pos unless(defined($index));
      $index = $pos if($pos<$index);
    }
  }
  unless(defined($index)) {
    throw("couldn't find delimiter $delim\n");
  }

  my $token ='';

  if ($index==0) {
    $token = substr($$string,0,1);
    $$string = substr($$string, 1);
  } else {
    $token = substr($$string, 0, $index);
    $$string = substr($$string, $index);
  }

  #print("  token     =>$token\n");
  #print("  outstring =>$$string\n\n");

  return $token;
}

1;
