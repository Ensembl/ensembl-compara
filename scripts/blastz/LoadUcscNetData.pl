#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::GenomicAlign;

my $ucsc_host;
my $ucsc_port;
my $ucsc_dbuser = "ensro";
my $ucsc_dbname;

my $host;
my $port;
my $dbuser;
my $dbpass;
my $dbname;

my $alignment_type;
my $tSpecies;
my $tName;
my $tgenome_db_id;
my $qgenome_db_id;
my $conf_file;#= "/nfs/acari/abel/src/ensembl_main/ensembl-compara/Compara.conf";
my $start_index = 0;

my $max_gap_size = 50;

GetOptions('ucsc_host=s' => \$ucsc_host,
	   'ucsc_port=i' => \$ucsc_port,
	   'ucsc_dbname=s' => \$ucsc_dbname,
	   'ucsc_dbuser=s' => \$ucsc_dbuser,
           'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
           'alignment_type=s' => \$alignment_type,
           'tSpecies=s' => \$tSpecies,
           'tName=s' => \$tName,
           'tgenome_db_id=i' => \$tgenome_db_id,
           'qgenome_db_id=i' => \$qgenome_db_id,
	   'conf_file=s' => \$conf_file,
           'start_index=i' => \$start_index,
           'max_gap_size=i' => \$max_gap_size);

my $ucsc_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $ucsc_host,
                                                          -port   => $ucsc_port,
                                                          -user   => $ucsc_dbuser,
                                                          -dbname => $ucsc_dbname);

my $compara = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                          -port   => $port,
                                                          -user   => $dbuser,
                                                          -pass   => $dbpass,
                                                          -dbname => $dbname,
                                                          -conf_file => $conf_file);

my $gdba = $compara->get_GenomeDBAdaptor;
my $dfa = $compara->get_DnaFragAdaptor;
my $gala = $compara->get_GenomicAlignAdaptor;
my $gdb = $gdba->fetch_by_dbID($tgenome_db_id);

my %dnafrags;
foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($gdb)}) {
  $dnafrags{$df->name} = $df;
}

my $hgdb = $gdba->fetch_by_dbID($qgenome_db_id);
my %hdnafrags;
foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($hgdb)}) {
  $hdnafrags{$df->name} = $df;
}

#my $sql = "select bin, level, tName, tStart, tEnd, strand, qName, qStart, qEnd, chainId, ali, score from net$tSpecies where type!=\"gap\"";

my $sql = "select bin, level, tName, tStart, tEnd, strand, qName, qStart, qEnd, chainId, ali, score from net$tSpecies where type!=\"gap\" and  tName = ? order by tStart, chainId";

#606815
#9891834
#3638

my $sth = $ucsc_db->prepare($sql);
#$sth->execute();
$sth->execute($tName);

my ($n_bin, $n_level, $n_tName, $n_tStart, $n_tEnd, $n_strand, $n_qName, $n_qStart, $n_qEnd, $n_chainId, $n_ali, $n_score);

$sth->bind_columns
  (\$n_bin, \$n_level, \$n_tName, \$n_tStart, \$n_tEnd, \$n_strand, \$n_qName, \$n_qStart, \$n_qEnd, \$n_chainId, \$n_ali, \$n_score);

my $nb_of_net = 0;
my $nb_of_daf_loaded = 0;
my $net_index = 0;

while( $sth->fetch() ) {
  $net_index++;
  next if ($net_index < $start_index);
  print STDERR "net_index: $net_index, tStart: $n_tStart, chainId: $n_chainId\n";
  $nb_of_net++;
  $n_strand = 1 if ($n_strand eq "+");
  $n_strand = -1 if ($n_strand eq "-");
  $n_tStart++;
  $n_qStart++;



  $n_tName =~ s/^chr//;
  $n_qName =~ s/^chr//;
  $n_qName =~ s/^pt0\-//;

  my ($dnafrag, $hdnafrag);
  unless (defined $dnafrag) {
    $dnafrag = $dnafrags{$n_tName};
    unless (defined $dnafrag) {
      print STDERR "daf not stored because seqname ",$n_tName," not in dnafrag table, so not in core\n";
      print STDERR "$n_bin, $n_level, $n_tName, $n_tStart, $n_tEnd, $n_strand, $n_qName, $n_qStart, $n_qEnd, $n_chainId, $n_ali, $n_score\n";
      next;
    }
  }
  unless (defined $hdnafrag) {
    $hdnafrag = $hdnafrags{$n_qName};
    unless (defined $hdnafrag) {
      print STDERR "daf not stored because hseqname ",$n_qName," not in dnafrag table, so not in core\n";
      print STDERR "$n_bin, $n_level, $n_tName, $n_tStart, $n_tEnd, $n_strand, $n_qName, $n_qStart, $n_qEnd, $n_chainId, $n_ali, $n_score\n";
      next;
    }
  }

  my $c_table = "chr" . $n_tName . "_chain" . $tSpecies;
  my $cl_table = "chr" .$n_tName . "_chain" . $tSpecies . "Link";

  $sql = "select c.bin,c.score,c.tName,c.tSize,c.tStart,c.tEnd,c.qName,c.qSize,c.qStrand,c.qStart,c.qEnd,cl.chainId,cl.tStart,cl.tEnd,cl.qStart,cl.qStart+cl.tEnd-cl.tStart as qEnd from $c_table c, $cl_table cl where c.id=cl.chainId and cl.chainId = ?";

  my $sth2 = $ucsc_db->prepare($sql);
  $sth2->execute($n_chainId);

  my ($c_bin,$c_score,$c_tName,$c_tSize,$c_tStart,$c_tEnd,$c_qName,$c_qSize,$c_qStrand,$c_qStart,$c_qEnd,$cl_chainId,$cl_tStart,$cl_tEnd,$cl_qStart,$cl_qEnd);

  $sth2->bind_columns
    (\$c_bin,\$c_score,\$c_tName,\$c_tSize,\$c_tStart,\$c_tEnd,\$c_qName,\$c_qSize,\$c_qStrand,\$c_qStart,\$c_qEnd,\$cl_chainId,\$cl_tStart,\$cl_tEnd,\$cl_qStart,\$cl_qEnd);

  my ($previous_cl_tEnd, $previous_cl_qStart, $previous_cl_qEnd);
  my @fps;
  my @dafs;
  while( $sth2->fetch() ) {
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
      $daf->level_id($n_level);
      push @dafs, $daf;
      @fps = ();
    } elsif ($cl_tStart - $previous_cl_tEnd > $max_gap_size ||
             ((($c_qStrand > 0 && $cl_qStart - $previous_cl_qEnd > $max_gap_size)) ||
              (($c_qStrand < 0 && $previous_cl_qStart - $cl_qEnd > $max_gap_size)))) {
      # Means there are gaps in both sequence, so need a new DnaAlignFeature;
      my $daf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@fps);
      $daf->group_id($n_chainId);
      $daf->level_id($n_level);
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
    $daf->level_id($n_level);
    push @dafs, $daf;
  }

  my @new_dafs;
  while (my $daf = shift @dafs) {
    my $daf = $daf->restrict_between_positions($n_tStart,$n_tEnd,"seqname");
    next unless (defined $daf);
    push @new_dafs, $daf;
  }
  next unless (scalar @new_dafs);
  $gala->store_daf(\@new_dafs,$dnafrag, $hdnafrag, $alignment_type);
  $nb_of_daf_loaded = $nb_of_daf_loaded + scalar @new_dafs;
}

print STDERR "nb_of_net: ", $nb_of_net,"\n";
print STDERR "nb_of_daf_loaded: ", $nb_of_daf_loaded,"\n";
