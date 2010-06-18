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
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::SimpleAlign;


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'speciesList'} = ();
$self->{'removeXedSeqs'} = undef;
$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

GetOptions('help'     => \$help,
           'url=s'    => \$url,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'fasta=s'  => \$self->{'outputFasta'},
           'noX=i'    => \$self->{'removeXedSeqs'},
           'nosplit'  => \$self->{'noSplitSeqLines'},
           'gab_id=i' => \$self->{'print_align_GAB_id'},
          );

if ($help) { usage(); }

parse_conf($self, $conf_file);

if($host)   { $self->{'compara_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'compara_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'compara_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'compara_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'compara_conf'}->{'-pass'}   = $pass; }

$self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url . ';type=compara') if($url);
if(defined($self->{'comparaDBA'})) {
  print("URL OK!!!\n");
} else {
  unless(defined($self->{'compara_conf'}->{'-host'})
         and defined($self->{'compara_conf'}->{'-user'})
         and defined($self->{'compara_conf'}->{'-dbname'}))
  {
    print "\nERROR : must specify host, user, and database to connect to compara\n\n";
    usage();
  }
  $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_conf'}});
}

if($self->{'print_align_GAB_id'}) {
  my $GAB = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor->
               fetch_by_dbID($self->{'print_align_GAB_id'});
  print_simple_align($GAB->get_SimpleAlign, 80);
}

#compare_homologies($self); 

#test_longest($self); exit(0);

#test_core_genes($self); exit(1);

#test_core($self); exit(1);

#test_paf($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaTest.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -fasta <path>          : file where fasta dump happens\n";
  print "  -noX <num>             : don't dump if <num> 'X's in a row in sequence\n";
  print "  -nosplit               : don't split sequence lines into readable format\n";
  print "comparaTest.pl v1.1\n";
  
  exit(1);  
}


sub parse_conf {
  my $self      = shift;
  my $conf_file = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      #print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'COMPARA') {
        $self->{'compara_conf'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'BLAST_TEMPLATE') {
        $self->{'analysis_template'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @{$self->{'speciesList'}}, $confPtr;
      }
    }
  }
}


sub original_tests {
  my $self = shift;

  $self->{'pipelineDBA'} = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

  my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID(66454);
  $member->print_member() if($member);

  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $paf_list = $pafDBA->fetch_all_RH_by_member_genomedb(66454, 3);
  foreach my $paf (@{$paf_list}) {
    $paf->display_short() if($paf);
    my $rpaf = $pafDBA->fetch_by_dbID($paf->rhit_dbID) if($paf->rhit_dbID);
    $rpaf->display_short() if($rpaf);
  }


  my $coreDBA = $self->{'comparaDBA'}->get_db_adaptor("Mus musculus", "NCBIM32");
  $self->{'comparaDBA'}->add_db_adaptor($coreDBA);

  #sleep(1000000);
}


sub dump_fasta {
  my $self = shift;

  my $sql = "SELECT member.stable_id, member.description, sequence.sequence " .
            " FROM member, sequence, source " .
            " WHERE member.source_id=source.source_id ".
            " AND source.source_name='ENSEMBLPEP' ".
            " AND member.sequence_id=sequence.sequence_id " .
            " GROUP BY member.member_id ORDER BY member.stable_id;";

  my $fastafile = $self->{'outputFasta'};
  open FASTAFILE, ">$fastafile"
    or die "Could open $fastafile for output\n";
  print("writing fasta to loc '$fastafile'\n");

  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();

  my ($stable_id, $description, $sequence);
  $sth->bind_columns( undef, \$stable_id, \$description, \$sequence );

  while( $sth->fetch() ) {
    $sequence =~ s/(.{72})/$1\n/g  unless($self->{'noSplitSeqLines'});

    #if removedXedSeqs defined then it contains the minimum num of
    # Xs in a row that is not acceptable, the regex X{#,}? says
    # if X occurs # or more times (not exhaustive search)
    unless($self->{'removeXedSeqs'} and
          ($sequence =~ /X{$self->{'removeXedSeqs'},}?/)) {
      print FASTAFILE ">$stable_id $description\n$sequence\n";
    }
  }
  close(FASTAFILE);

  $sth->finish();
}

sub test_paf {
  my $self = shift;

  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;

  my $pafs = $pafDBA->fetch_all_by_qmember_id(1245);
  foreach my $paf (@$pafs) { $paf->display_short; };


  exit(1);
}

sub test_core {
  my $self = shift;

  my $humanGenomeDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_name_assembly("Homo sapiens", "NCBI35");
  my $humanDBA = $humanGenomeDB->db_adaptor;

  my $transcript = $humanDBA->get_TranscriptAdaptor->fetch_by_stable_id("ENST00000356199");
  print($transcript->stable_id, " ", $transcript->translation->stable_id, "\n");

  if($transcript->translate->seq) {
    print($transcript->translate->seq,"\n");
  } else {
    print("NO SEQUENCE!!\n");
  }
}


sub test_core_genes {
  my $self = shift;

  my $humanGenomeDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_name_assembly("Homo sapiens", "NCBI35");
  my $humanDBA = $humanGenomeDB->db_adaptor;

  my @slices;
  push @slices, $humanDBA->get_SliceAdaptor->fetch_by_region('toplevel', 'Y');
  my $count = 0;
  SLICE: foreach my $slice (@slices) {
    print("slice " . $slice->name . "\n");
    foreach my $gene (@{$slice->get_all_Genes}) {
      my $desc = $gene->stable_id. " " .
                 $gene->seq_region_name . ":".
                 $gene->seq_region_start . "-".
                 $gene->seq_region_end;

      if((lc($gene->type) ne 'pseudogene') and
         (lc($gene->type) ne 'bacterial_contaminant') and
         ($gene->type !~ /RNA/i))
      {
        $count++;
        print("$desc\n");
      }
    }
  }
  print("pulled $count genes\n");
}

sub test_longest {
  my $self = shift;

  print("test LONGEST\n");

  my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', 'ENSG00000198125');
  $member->print_member() if($member);

  my $longest = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_longest_peptide_member_for_gene_member_id($member->dbID);
  $longest->print_member() if($longest);

  my $pafs = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->fetch_all_by_qmember_id($longest->dbID);

  foreach my $paf (@$pafs) {
    $paf->display_short;
  }  
}


sub compare_homologies {
  my $self = shift;

  print("pull all homologies for species 1,2 via API\n");
  my $start_time = time();
  my $all_homologies = $self->{'comparaDBA'}->get_HomologyAdaptor->fetch_all_by_genome_pair(1,2);
  print(time()-$start_time, " secs to grab ", scalar(@$all_homologies), " using API\n");
  exit(0);
}




sub print_simple_align
{
  my $alignment = shift;
  my $aaPerLine = shift;
  $aaPerLine=40 unless($aaPerLine and $aaPerLine > 0);

  my ($seq1, $seq2)  = $alignment->each_seq;
  my $seqStr1 = "|".$seq1->seq().'|';
  my $seqStr2 = "|".$seq2->seq().'|';

  my $enddiff = length($seqStr1) - length($seqStr2);
  while($enddiff>0) { $seqStr2 .= " "; $enddiff--; }
  while($enddiff<0) { $seqStr1 .= " "; $enddiff++; }

  my $label1 = sprintf("%40s : ", $seq1->id);
  my $label2 = sprintf("%40s : ", "");
  my $label3 = sprintf("%40s : ", $seq2->id);

  my $line2 = "";
  for(my $x=0; $x<length($seqStr1); $x++) {
    if(substr($seqStr1,$x,1) eq substr($seqStr2, $x,1)) { $line2.='|'; } else { $line2.=' '; }
  }

  my $offset=0;
  my $numLines = (length($seqStr1) / $aaPerLine);
  while($numLines>0) {
    printf("$label1 %s\n", substr($seqStr1,$offset,$aaPerLine));
    printf("$label2 %s\n", substr($line2,$offset,$aaPerLine));
    printf("$label3 %s\n", substr($seqStr2,$offset,$aaPerLine));
    print("\n\n");
    $offset+=$aaPerLine;
    $numLines--;
  }
}
