#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::GenomicAlign;
#use Bio::EnsEMBL::Utils::Exception qw(verbose);
#verbose("INFO");


my $ucsc_dbname;
my $dbname;

my $tSpecies;
my $tName;
my $qSpecies;
my $reg_conf;
my $start_net_index = 0;
my $method_link_type = "BLASTZ_GROUP";
my $max_gap_size = 50;
my $matrix_file;
my $show_matrix_to_be_used = 0;
my $help = 0;
my $check_length = 0;

my $usage = "
$0
  [--help]                    this menu
   --ucsc_dbname string       (e.g. ucscMm33Rn3) one of the ucsc source database Bio::EnsEMBL::Registry aliases
   --dbname string            (e.g. compara25) one of the compara destination database Bio::EnsEMBL::Registry aliases
   --tName string             (e.g. chr15) one of the chromosome name used by UCSC on their target species (tSpecies)
                              on the base of which alignments will be retrieved
   --tSpecies string          (e.g. mouse) the UCSC target species (i.e. a Bio::EnsEMBL::Registry alias)
                              to which tName refers to
   --qSpecies string          (e.g. Rn3) the UCSC query species (i.e. a Bio::EnsEMBL::Registry alias)
  [--check_length]            check the chromosome length between ucsc and ensembl, then exit
  [--method_link_type string] (e.g. BLASTZ_NET) type of alignment queried (default: BLASTZ_NET)
  [--reg_conf filepath]       the Bio::EnsEMBL::Registry configuration file. If none given, 
                              the one set in ENSEMBL_REGISTRY will be used if defined, if not
                              ~/.ensembl_init will be used.
  [--matrix filepath]         matrix file to be used to score each individual alignment
                              Format should be something like
                              A    C    G    T
                              100 -200  -100 -200
                              -200  100 -200  -100
                              -100 -200  100 -200
                              -200  -100 -200   100
                              O = 2000, E = 50
                              default will choose on the fly the right matrix for the species pair considered.
  [--show_matrix]             Shows the scoring matrix that will be used and exit. Does not start the process
                              loading a compara database. **WARNING** can only be used with the other compulsory 
                              arguments
  [--max_gap_size integer]    default: 50
  [start_net_index integer]   default: 0

\n";

GetOptions('help' => \$help,
           'ucsc_dbname=s' => \$ucsc_dbname,
	   'dbname=s' => \$dbname,
           'method_link_type=s' => \$method_link_type,
           'tSpecies=s' => \$tSpecies,
           'tName=s' => \$tName,
           'qSpecies=s' => \$qSpecies,
           'check_length' => \$check_length,
	   'reg_conf=s' => \$reg_conf,
           'start_net_index=i' => \$start_net_index,
           'max_gap_size=i' => \$max_gap_size,
           'matrix=s' => \$matrix_file,
           'show_matrix' => \$show_matrix_to_be_used);

$| = 1;

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $primates_matrix_string = "A C G T
 100 -300 -150 -300
-300  100 -300 -150
-150 -300  100 -300
-300 -150 -300  100
O = 400, E = 30
";

my $mammals_matrix_string = "A C G T
  91 -114  -31 -123
-114  100 -125  -31
 -31 -125  100 -114
-123  -31 -114   91
O = 400, E = 30
";

my $mammals_vs_other_vertebrates_matrix_string = "A C G T
  91  -90  -25 -100
 -90  100 -100  -25
 -25 -100  100  -90
-100  -25  -90   91
O = 400, E = 30
";

my $tight_matrix_string = "A C G T
 100 -200 -100 -200
-200  100 -200 -100
-100 -200  100 -200
-200 -100 -200  100
O = 2000, E = 50
";

my %undefined_combinaisons;
print STDERR $ucsc_dbname,"\n";
my $ucsc_dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($ucsc_dbname, 'compara')->dbc;

my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomeDB') or die "Can't get ($dbname,'compara','GenomeDB')\n";
my $dfa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','DnaFrag') or die "Can't get ($dbname,'compara','DnaFrag')\n";
my $gaba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomicAlignBlock') or die " Can't get ($dbname,'compara','GenomicAlignBlock')\n";
my $gaga = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomicAlignGroup') or die " Can't get($dbname,'compara','GenomicAlignGroup')\n";
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MethodLinkSpeciesSet') or die " Can't($dbname,'compara','MethodLinkSpeciesSet')\n";

# cache all tSpecies dnafrag from compara
my $tBinomial = get_binomial_name($tSpecies);
my $tTaxon_id = get_taxon_id($tSpecies);
my $tgdb = $gdba->fetch_by_name_assembly($tBinomial) or die " Can't get fetch_by_name_assembly($tBinomial)\n";
my %tdnafrags;
foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($tgdb)}) {
  $tdnafrags{$df->name} = $df;
}

# cache all qSpecies dnafrag from compara
my $qBinomial = get_binomial_name($qSpecies);
my $qTaxon_id = get_taxon_id($qSpecies);
my $qgdb = $gdba->fetch_by_name_assembly($qBinomial) or die " Can't get fetch_by_name_assembly($qBinomial)\n";
my %qdnafrags;
foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($qgdb)}) {
  $qdnafrags{$df->name} = $df;
}

check_length() if ($check_length);

my $matrix_hash = choose_matrix($matrix_file);

if ($show_matrix_to_be_used) {
  print_matrix($matrix_hash);
  exit 0;
}

my $sql;
my $sth;

my $chromosome_specific_chain_tables = 1;

$sql = "show tables like 'chain$qSpecies%'";
$sth = $ucsc_dbc->prepare($sql);
$sth->execute;

my ($table_name);

$sth->bind_columns(\$table_name);

my $table_count = 0;

while( $sth->fetch() ) {
  if ($table_name eq "chain$qSpecies") {
    $table_count++;
  }
  if ($table_name eq "chain$qSpecies"."Link") {
    $table_count++;
  }
}

$chromosome_specific_chain_tables = 0 if ($table_count == 2);

$sth->finish;

if (defined $tName) {
  $sql = "select bin, level, tName, tStart, tEnd, strand, qName, qStart, qEnd, chainId, ali, score from net$qSpecies where type!=\"gap\" and  tName = ? order by tStart, chainId";
  $sth = $ucsc_dbc->prepare($sql);
  $sth->execute($tName);
} else {
  $sql = "select bin, level, tName, tStart, tEnd, strand, qName, qStart, qEnd, chainId, ali, score from net$qSpecies where type!=\"gap\" order by tStart, chainId";
  $sth = $ucsc_dbc->prepare($sql);
  $sth->execute();
}

my ($n_bin, $n_level, $n_tName, $n_tStart, $n_tEnd, $n_strand, $n_qName, $n_qStart, $n_qEnd, $n_chainId, $n_ali, $n_score);

$sth->bind_columns
  (\$n_bin, \$n_level, \$n_tName, \$n_tStart, \$n_tEnd, \$n_strand, \$n_qName, \$n_qStart, \$n_qEnd, \$n_chainId, \$n_ali, \$n_score);

my $nb_of_net = 0;
my $nb_of_daf_loaded = 0;
my $net_index = 0;



while( $sth->fetch() ) {
  $net_index++;
  next if ($net_index < $start_net_index);
  print STDERR "net_index: $net_index, tStart: $n_tStart, chainId: $n_chainId\n";
  $nb_of_net++;
  $n_strand = 1 if ($n_strand eq "+");
  $n_strand = -1 if ($n_strand eq "-");
  $n_tStart++;
  $n_qStart++;

  $n_tName =~ s/^chr//;
  $n_qName =~ s/^chr//;
  $n_qName =~ s/^pt0\-//;

  my ($tdnafrag, $qdnafrag);
  unless (defined $tdnafrag) {
    $tdnafrag = $tdnafrags{$n_tName};
    unless (defined $tdnafrag) {
      print STDERR "daf not stored because seqname ",$n_tName," not in dnafrag table, so not in core\n";
      print STDERR "$n_bin, $n_level, $n_tName, $n_tStart, $n_tEnd, $n_strand, $n_qName, $n_qStart, $n_qEnd, $n_chainId, $n_ali, $n_score\n";
      next;
    }
  }
  unless (defined $qdnafrag) {
    $qdnafrag = $qdnafrags{$n_qName};
    unless (defined $qdnafrag) {
      print STDERR "daf not stored because hseqname ",$n_qName," not in dnafrag table, so not in core\n";
      print STDERR "$n_bin, $n_level, $n_tName, $n_tStart, $n_tEnd, $n_strand, $n_qName, $n_qStart, $n_qEnd, $n_chainId, $n_ali, $n_score\n";
      next;
    }
  }

  my ($c_table, $cl_table);
  if ($chromosome_specific_chain_tables) {
    $c_table = "chr" . $n_tName . "_chain" . $qSpecies;
    $cl_table = "chr" .$n_tName . "_chain" . $qSpecies . "Link";

    $sql = "select c.bin,c.score,c.tName,c.tSize,c.tStart,c.tEnd,c.qName,c.qSize,c.qStrand,c.qStart,c.qEnd,cl.chainId,cl.tStart,cl.tEnd,cl.qStart,cl.qStart+cl.tEnd-cl.tStart as qEnd from $c_table c, $cl_table cl where c.id=cl.chainId and cl.chainId = ?";    

  } else {
    $c_table = "chain" . $qSpecies;
    $cl_table = "chain" . $qSpecies . "Link";
    # as a chainId seems to be specific to a tName, it should be  no need to add an additional constraint on tName in the sql,
    # but for safe keeping let's add it.

    $sql = "select c.bin,c.score,c.tName,c.tSize,c.tStart,c.tEnd,c.qName,c.qSize,c.qStrand,c.qStart,c.qEnd,cl.chainId,cl.tStart,cl.tEnd,cl.qStart,cl.qStart+cl.tEnd-cl.tStart as qEnd from $c_table c, $cl_table cl where c.id=cl.chainId and cl.chainId = ? and c.tName = cl.tName and c.tName = $n_tName";
  }

  my $sth2 = $ucsc_dbc->prepare($sql);
  $sth2->execute($n_chainId);

  my ($c_bin,$c_score,$c_tName,$c_tSize,$c_tStart,$c_tEnd,$c_qName,$c_qSize,$c_qStrand,$c_qStart,$c_qEnd,$cl_chainId,$cl_tStart,$cl_tEnd,$cl_qStart,$cl_qEnd);

  $sth2->bind_columns
    (\$c_bin,\$c_score,\$c_tName,\$c_tSize,\$c_tStart,\$c_tEnd,\$c_qName,\$c_qSize,\$c_qStrand,\$c_qStart,\$c_qEnd,\$cl_chainId,\$cl_tStart,\$cl_tEnd,\$cl_qStart,\$cl_qEnd);

  my ($previous_cl_tEnd, $previous_cl_qStart, $previous_cl_qEnd);
  my @fps;
  my @dafs;
  while( $sth2->fetch() ) {
    # Checking the chromosome length from UCSC with Ensembl.
    unless ($tdnafrag->length == $c_tSize) {
      print STDERR "tSize = $c_tSize for tName = $c_tName and Ensembl has dnafrag length of ",$tdnafrag->length,"\n";
      print STDERR "net_index is $net_index\n";
      exit 2;
    }
    unless ($qdnafrag->length == $c_qSize) {
      	print STDERR "qSize = $c_qSize for qName = $c_qName and Ensembl has dnafrag length of ",$qdnafrag->length,"\n";
      	print STDERR "net_index is $net_index\n";
      		exit 3;
    }
    
    $c_qStrand = 1 if ($c_qStrand eq "+");
    $c_qStrand = -1 if ($c_qStrand eq "-");
    $c_tStart++;
    $c_qStart++;
    $cl_tStart++;
    $cl_qStart++;
    $c_tName =~ s/^chr//;
    $c_qName =~ s/^chr//;
    $c_qName =~ s/^pt0\-//;
    

    if ($c_qStrand < 0) {
      my $length = $cl_qEnd - $cl_qStart;
      $cl_qStart = $c_qSize - $cl_qEnd + 1;
      $cl_qEnd = $cl_qStart + $length;
    }

#    print "$c_bin,$c_score,$c_tName,$c_tSize,$c_tStart,$c_tEnd,$c_qName,$c_qSize,$c_qStrand,$c_qStart,$c_qEnd,$cl_chainId,$cl_tStart,$cl_tEnd,$cl_qStart,$cl_qEnd\n";
    my $fp = new  Bio::EnsEMBL::FeaturePair(-seqname  => $c_tName,
                                            -start    => $cl_tStart,
                                            -end      => $cl_tEnd,
                                            -strand   => 1,
                                            -hseqname  => $c_qName,
                                            -hstart   => $cl_qStart,
                                            -hend     => $cl_qEnd,
                                            -hstrand  => $c_qStrand,
                                            -score    => $c_score);

    unless (defined $previous_cl_tEnd && defined $previous_cl_qEnd) {
      $previous_cl_tEnd = $cl_tEnd;
      $previous_cl_qStart = $cl_qStart;
      $previous_cl_qEnd = $cl_qEnd;
      push @fps, $fp;
      next;
    }

    if ($cl_tStart - $previous_cl_tEnd > 1 && 
        ((($c_qStrand > 0 && $cl_qStart - $previous_cl_qEnd > 1)) ||
         (($c_qStrand < 0 && $previous_cl_qStart - $cl_qEnd > 1)))) {
      # Means there are gaps in both sequence, so need a new DnaAlignFeature;
      my $daf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@fps);
      $daf->group_id($n_chainId);
      $daf->level_id(($n_level + 1)/2);
      push @dafs, $daf;
      @fps = ();
    } elsif ($cl_tStart - $previous_cl_tEnd > $max_gap_size ||
             ((($c_qStrand > 0 && $cl_qStart - $previous_cl_qEnd > $max_gap_size)) ||
              (($c_qStrand < 0 && $previous_cl_qStart - $cl_qEnd > $max_gap_size)))) {
      # Means there are gaps in both sequence, so need a new DnaAlignFeature;
      my $daf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@fps);
      $daf->group_id($n_chainId);
      $daf->level_id(($n_level + 1)/2);
      push @dafs, $daf;
      @fps = ();
    }
    $previous_cl_tEnd = $cl_tEnd;
    $previous_cl_qStart = $cl_qStart;
    $previous_cl_qEnd = $cl_qEnd;
    push @fps, $fp;
  }
  if (scalar @fps) {
    my $daf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@fps);
    $daf->group_id($n_chainId);
    $daf->level_id(($n_level + 1)/2);
    push @dafs, $daf;
  }

  my @new_dafs;
  while (my $daf = shift @dafs) {
    my $daf = $daf->restrict_between_positions($n_tStart,$n_tEnd,"SEQ");
    next unless (defined $daf);
    push @new_dafs, $daf;
  }
  next unless (scalar @new_dafs);
#  print STDERR "Loading ",scalar @new_dafs,"...\n";
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->species_set([$tgdb, $qgdb]);
  $mlss->method_link_type($method_link_type);
  $mlssa->store($mlss);
  
  foreach my $daf (@new_dafs) {
    my ($tcigar_line, $qcigar_line, $length) = parse_daf_cigar_line($daf);

    my $tga = new Bio::EnsEMBL::Compara::GenomicAlign;
    $tga->dnafrag($tdnafrag);
    $tga->dnafrag_start($daf->start);
    $tga->dnafrag_end($daf->end);
    $tga->dnafrag_strand($daf->strand);
    $tga->cigar_line($tcigar_line);
    $tga->level_id($daf->level_id);

    my $qga = new Bio::EnsEMBL::Compara::GenomicAlign;
    $qga->dnafrag($qdnafrag);
    $qga->dnafrag_start($daf->hstart);
    $qga->dnafrag_end($daf->hend);
    $qga->dnafrag_strand($daf->hstrand);
    $qga->cigar_line($qcigar_line);
    $qga->level_id($daf->level_id);

    my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
    $gab->method_link_species_set($mlss);
    # We need to add here something to rescore the gab.
    # at the moment the score is the one from the whole chain, which is huge and not very sensible to put there.

    my ($score, $percent_id) = score_and_identity($qga->aligned_sequence, $tga->aligned_sequence, $matrix_hash);
    $gab->score($score);
    $gab->perc_id($percent_id);
    $gab->length($length);
    $gab->genomic_align_array([$tga, $qga]);

    my $gag = new Bio::EnsEMBL::Compara::GenomicAlignGroup;
    $gag->dbID($daf->group_id);
    $gag->type("default");
    $gag->genomic_align_array([$tga, $qga]);

    $gaba->store($gab);
    $gaga->store($gag);
  }

  $nb_of_daf_loaded = $nb_of_daf_loaded + scalar @new_dafs;
}

print STDERR "nb_of_net: ", $nb_of_net,"\n";
print STDERR "nb_of_daf_loaded: ", $nb_of_daf_loaded,"\n";

print STDERR "Here is a statistic summary of nucleotides matching not defined in the scoring matrix used\n";
foreach my $key (sort {$a cmp $b} keys %undefined_combinaisons) {
  print STDERR $key," ",$undefined_combinaisons{$key},"\n";
}

$sth->finish;

print STDERR "\n";


=head2 get_binomial_name

  Arg[1]     : string $species_name
  Example    : $human_binomial_name = get_binomial_name("human");
  Description: This method get the binomial name from the core database.
               It takes a Registry alias as an input and return the
               binomial name for that species.
  Returntype : string

=cut

sub get_binomial_name {
  my ($species) = @_;
  my $binomial_name;

  my $meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'MetaContainer');
  if (!defined($meta_container_adaptor)) {
    die("Cannot get the MetaContainerAdaptor for species <$species>\n");
  }
  $binomial_name = $meta_container_adaptor->get_Species->binomial;
  if (!$binomial_name) {
    die("Cannot get the binomial name for species <$species>\n");
  }

  return $binomial_name;
}


=head2 get_taxon_id

  Arg[1]     : string $species_name
  Example    : $human_taxon_id = get_taxon_id("human");
  Description: This method get the taxon ID from the core database.
               It takes a Registry alias as an input and return the
               taxon ID for that species.
  Returntype : int

=cut

sub get_taxon_id {
  my ($species) = @_;
  my $taxon_id;

  my $meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'MetaContainer');
  if (!defined($meta_container_adaptor)) {
    die("Cannot get the MetaContainerAdaptor for species <$species>\n");
  }
  $taxon_id = $meta_container_adaptor->get_taxonomy_id;
  if (!$taxon_id) {
    die("Cannot get the taxon ID for species <$species>\n");
  }

  return $taxon_id;
}


=head2 parse_daf_cigar_line

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub parse_daf_cigar_line {
  my ($daf) = @_;
  my ($cigar_line, $hcigar_line, $length);

  my @pieces = split(/(\d*[DIMG])/, $daf->cigar_string);

  my $counter = 0;
  my $hcounter = 0;
  foreach my $piece ( @pieces ) {
    next if ($piece !~ /^(\d*)([MDI])$/);
    
    my $num = ($1 or 1);
    my $type = $2;
    
    if( $type eq "M" ) {
      $counter += $num;
      $hcounter += $num;
      
    } elsif( $type eq "D" ) {
      $cigar_line .= (($counter == 1) ? "" : $counter)."M";
      $counter = 0;
      $cigar_line .= (($num == 1) ? "" : $num)."D";
      $hcounter += $num;
      
    } elsif( $type eq "I" ) {
      $counter += $num;
      $hcigar_line .= (($hcounter == 1) ? "" : $hcounter)."M";
      $hcounter = 0;
      $hcigar_line .= (($num == 1) ? "" : $num)."D";
    }
    $length += $num;
  }
  $cigar_line .= (($counter == 1) ? "" : $counter)."M"
    if ($counter);
  $hcigar_line .= (($hcounter == 1) ? "" : $hcounter)."M"
    if ($hcounter);
  
  return ($cigar_line, $hcigar_line, $length);
}


=head2 choose_matrix

  Arg[1]     : string $matrix_filename
  Example    : $matrix_hash = choose_matrix();
  Example    : $matrix_hash = choose_matrix("this_matrix.txt");
  Description: reads the matrix from the file provided or get the right matrix
               depending on the pair of species.
  Returntype : ref. to a hash

=cut

sub choose_matrix {
  my ($matrix_file) = @_;
  my $matrix_hash;

  if ($matrix_file) {
    my $matrix_string = "";
    open M, $matrix_file ||
      die "Can not open $matrix_file file\n";
    while (<M>) {
      next if (/^\s*$/);
      $matrix_string .= $_;
    }
    close M;
    $matrix_hash = get_matrix_hash($matrix_string);
    print STDERR "Using customed scoring matrix from $matrix_file file\n";
    print STDERR "\n$matrix_string\n";
  
  } elsif ( grep(/^$tTaxon_id$/, (9606, 9598)) &&
      grep(/^$qTaxon_id$/, (9606, 9598)) ) {
    $matrix_hash = get_matrix_hash($primates_matrix_string);
    print STDERR "Using primates scoring matrix\n";
    print STDERR "\n$primates_matrix_string\n";
  
  } elsif ( grep(/^$tTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913)) &&
            grep(/^$qTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913)) ) {
    $matrix_hash = get_matrix_hash($mammals_matrix_string);
    print STDERR "Using mammals scoring matrix\n";
    print STDERR "\n$mammals_matrix_string\n";
  
  } elsif ( (grep(/^$tTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913, 9031)) &&
            grep(/^$qTaxon_id$/, (31033, 7955, 9031, 99883, 8364)))
            ||
            (grep(/^$qTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913, 9031)) &&
            grep(/^$tTaxon_id$/, (31033, 7955, 9031, 99883, 8364)))) {
    $matrix_hash = get_matrix_hash($mammals_vs_other_vertebrates_matrix_string);
    print STDERR "Using mammals_vs_other_vertebrates scoring matrix\n";
    print STDERR "\n$mammals_vs_other_vertebrates_matrix_string\n";
  
  } else {
    die "taxon_id undefined or matrix not set up for this pair of species $tTaxon_id, $qTaxon_id)\n";
  }

  return $matrix_hash;
}

=head2 get_matrix_hash

  Arg[1]     : string $matrix_string
  Example    : $matrix_hash = get_matrix_hash($matrix_string);
  Description: transform the matrix string into a hash
  Returntype : ref. to a hash

=cut

sub get_matrix_hash {
  my ($matrix_string) = @_;
  
  my %matrix_hash;

  my @lines = split /\n/, $matrix_string;
  my @letters = split /\s+/, shift @lines;

  foreach my $letter (@letters) {
    my $line = shift @lines;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    my @penalties = split /\s+/, $line;
    die "Size of letters array and penalties array are different\n" unless (scalar @letters == scalar @penalties);
    for (my $i=0; $i < scalar @letters; $i++) {
      $matrix_hash{uc $letter}{uc $letters[$i]} = $penalties[$i];
      $matrix_hash{uc $letters[$i]}{uc $letter} = $penalties[$i];
    }
  }
  while (my $line = shift @lines) {
    if ($line =~ /^\s*O\s*=\s*(\d+)\s*,\s*E\s*=\s*(\d+)\s*$/) {
      my $gap_opening_penalty = $1;
      my $gap_extension_penalty = $2;

      $gap_opening_penalty *= -1 if ($gap_opening_penalty > 0);
      $matrix_hash{'gap_opening_penalty'} = $gap_opening_penalty;

      $gap_extension_penalty *= -1 if ($gap_extension_penalty > 0);
      $matrix_hash{'gap_extension_penalty'} = $gap_extension_penalty;
    }
  }

  return \%matrix_hash;
}


=head2 print_matrix

  Arg[1]     : hashref $matix_hash 
  Example    : print_matrix($matrix_hash)
  Description: print the weight matrix to the STDERR
  Returntype : -none-

=cut

sub print_matrix {
  my ($matrix_hash) = @_;

  print STDERR "Here is the matrix hash structure\n";
  foreach my $key1 (sort {$a cmp $b} keys %{$matrix_hash}) {
    if ($key1 =~ /[ACGT]+/) {
      print STDERR "$key1 :";
      foreach my $key2 (sort {$a cmp $b} keys %{$matrix_hash->{$key1}}) {
        printf STDERR "   $key2 %5d",$matrix_hash->{$key1}{$key2};
      }
      print STDERR "\n";
    } else {
      print STDERR $key1," : ",$matrix_hash->{$key1},"\n";
    }
  }
  print STDERR "\n";
}


=head2 score_and_identity

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub score_and_identity {
  my ($qy_seq, $tg_seq, $matrix_hash) = @_;

  my $length = length($qy_seq);

  unless (length($tg_seq) == $length) {
    warn "qy sequence length ($length bp) and tg sequence length (".length($tg_seq)." bp) should be identical
exit 1\n";
    exit 1;
  }

  my @qy_seq_array = split //, $qy_seq;
  my @tg_seq_array = split //, $tg_seq;

  my $score = 0;
  my $number_identity = 0;
  my $opened_gap = 0;
  for (my $i=0; $i < $length; $i++) {
    if ($qy_seq_array[$i] eq "-" || $tg_seq_array[$i] eq "-") {
      if ($opened_gap) {
        $score += $matrix_hash->{'gap_extension_penalty'};
      } else {
        $score += $matrix_hash->{'gap_opening_penalty'};
        $opened_gap = 1;
      }
    } else {
      # maybe check for N letter here
      if (uc $qy_seq_array[$i] eq uc $tg_seq_array[$i]) {
        $number_identity++;
      }
      unless (defined $matrix_hash->{uc $qy_seq_array[$i]}{uc $tg_seq_array[$i]}) {
        unless (defined $undefined_combinaisons{uc $qy_seq_array[$i] . ":" . uc $tg_seq_array[$i]}) {
          $undefined_combinaisons{uc $qy_seq_array[$i] . ":" . uc $tg_seq_array[$i]} = 1;
        } else {
          $undefined_combinaisons{uc $qy_seq_array[$i] . ":" . uc $tg_seq_array[$i]}++;
        }
#        print STDERR uc $qy_seq_array[$i],":",uc $tg_seq_array[$i]," combination not defined in the matrix\n";
      } else {
        $score += $matrix_hash->{uc $qy_seq_array[$i]}{uc $tg_seq_array[$i]};
      }
      $opened_gap = 0;
    }
  }

  return ($score, int($number_identity/$length*100));
}


=head2 check_length

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub check_length {

  my $sql = "show tables like '"."%"."chain$qSpecies'";
  my $sth = $ucsc_dbc->prepare($sql);
  $sth->execute();

  my ($table);
  $sth->bind_columns(\$table);
  
  my (%tNames,%qNames);
  
  while( $sth->fetch() ) {
    $sql = "select tName,tSize from $table group by tName,tSize";
    
    my $sth2 = $ucsc_dbc->prepare($sql);
    $sth2->execute();
    
    my ($tName,$tSize);
    
    $sth2->bind_columns(\$tName,\$tSize);

    while( $sth2->fetch() ) {
      $tName =~ s/^chr//;
      $tNames{$tName} = $tSize;
    }
    $sth2->finish;

    $sql = "select qName,qSize from $table group by qName,qSize";

    $sth2 = $ucsc_dbc->prepare($sql);
    $sth2->execute();

    my ($qName,$qSize);
    
    $sth2->bind_columns(\$qName,\$qSize);

    while( $sth2->fetch() ) {
      $qName =~ s/^chr//;
      $qNames{$qName} = $qSize;
    }
    $sth2->finish;
  }

  $sth->finish;

  # Checking the chromosome length from UCSC with Ensembl.
  foreach my $tName (keys %tNames) {
    my $tdnafrag = $tdnafrags{$tName};
    next unless (defined $tdnafrag);
    unless ($tdnafrag->length == $tNames{$tName}) {
      print STDERR "tSize = " . $tNames{$tName} ." for tName = $tName and Ensembl has dnafrag length of ",$tdnafrag->length . "\n";
    }
  }
  # Checking the chromosome length from UCSC with Ensembl.
  foreach my $qName (keys %qNames) {
    my $qdnafrag = $qdnafrags{$qName};
    next unless (defined $qdnafrag);
    unless ($qdnafrag->length == $qNames{$qName}) {
      print STDERR "qSize = " . $qNames{$qName} ." for qName = $qName and Ensembl has dnafrag length of ",$qdnafrag->length . "\n";
    }
  }
  exit 0;
}
