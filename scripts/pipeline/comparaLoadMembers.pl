#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
#use Bio::EnsEMBL::Compara::DBSQL::SubsetAdaptor;


my $help = 0;
my ($host,$port,$dbname,$dbuser,$dbpass,$compara_conf,$conf_file,$fastafile);
my ($genome_db_id);
my ($prefix);
my $method_link_type = "HOMOLOGOUS_GENE";
my $mp_store_gene = 1;


GetOptions('help' => \$help,
           'host=s' => \$host,
	   'port=i' => \$port,
           'user=s' => \$dbuser,
           'pass=s' => \$dbpass,
           'dbname=s' => \$dbname,
           'compara=s' => \$compara_conf,	   
           'conf=s' => \$conf_file,
           'genome_db_id=i' => \$genome_db_id,
	   'prefix=s' => \$prefix,
	   'fasta=s' => \$fastafile
	  );

if ($help) { usage(); }

if(-e $compara_conf) {	  
  my %conf = %{do $compara_conf};

  $host = $conf{'host'};
  $port = $conf{'port'};
  $dbuser = $conf{'user'};
  $dbpass = $conf{'pass'};
  $dbname = $conf{'dbname'};
  #$adaptor = $conf{'adaptor'};
}


unless(defined($host) and defined($dbuser) and defined($dbname)) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}
unless(defined($genome_db_id)) { 
  print "\nERROR : must specify genome_db_id or assembly to connect to coreDB\n\n";
  usage(); 
}
unless(defined($conf_file)) { 
  print "\nERROR : must specify -conf <config_file> of external core genomes\n\n";
  usage(); 
}


my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-conf_file => $conf_file,
                                                     -host => $host,
                                                     -port => $port,
                                                     -dbname => $dbname,
                                                     -user => $dbuser,
                                                     -pass => $dbpass);

my $MemberAdaptor = $db->get_MemberAdaptor;
my $SubsetAdaptor = $db->get_SubsetAdaptor;


my $genome_db = $db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
my $coreDBAdaptor = $genome_db->db_adaptor;

my $SliceAdaptor = $coreDBAdaptor->get_SliceAdaptor;
my $GeneAdaptor = $coreDBAdaptor->get_GeneAdaptor;
my $TranscriptAdaptor = $coreDBAdaptor->get_TranscriptAdaptor;

if(defined($fastafile)) {
  if($fastafile ne "stdout") {
    open FASTA_FP,">$fastafile";
  } else {
    open FASTA_FP,">-";
  }
}


my @slices = @{$SliceAdaptor->fetch_all('toplevel')};

my $sliceCount=0;
my $geneCount=0;
my $realGeneCount=0;
my $transcriptCount = 0;
my $longestCount=0;
my $member;

my $pepSubset = Bio::EnsEMBL::Compara::Subset->new(-name=>$genome_db->name . ' longest translations');
$SubsetAdaptor->store($pepSubset);
my $geneSubset = Bio::EnsEMBL::Compara::Subset->new(-name=>$genome_db->name . ' genes');
$SubsetAdaptor->store($geneSubset);


SLICE: foreach my $slice (@slices) {
  $sliceCount++;
  #print(STDERR "slice " . $slice->name . "\n");
  foreach my $gene (@{$slice->get_all_Genes}) {
    $geneCount++;
    if((lc($gene->type) ne 'pseudogene') and 
       (lc($gene->type) ne 'bacterial_contaminant') and
       ($gene->type !~ /RNA/i)) {
      $realGeneCount++;
      store_gene_and_all_transcripts($gene);
    }
    #if($transcriptCount >= 1000) { last SLICE; }
    #if($geneCount >= 1000) { last SLICE; }
  }
  #last SLICE;
}

close(FASTA_FP);

print("loaded $sliceCount slices\n");
print("       $geneCount genes\n");
print("       $realGeneCount real genes\n");
print("       $transcriptCount transscripts\n");
print("       $longestCount longest transscripts\n");

my $count = $pepSubset->count;
print("       $count in Subset\n");
exit(0);

######################################
#
# subroutines
#
#####################################

sub usage {
  print "comparaLoadMembers.pl -pass {-compara | -host -user -dbname} -genome_db_id [options]\n";
  print "  -help             : print this help\n";
  print "  -compara <path>   : read compara DB connection info from config file <path>\n";
  print "                      which is perl hash file with keys 'host' 'port' 'user' 'dbname'\n";
  print "  -conf <path>      : config file describing the multiple external core databases for the different genomes\n";
  print "  -host <machine>   : set <machine> as location of compara DB\n";
  print "  -port <port#>     : use <port#> for mysql connection\n";
  print "  -user <name>      : use user <name> to connect to compara DB\n";
  print "  -pass <pass>      : use password to connect to compara DB\n";
  print "  -dbname <name>    : use database <name> to connect to compara DB\n";
  print "  -genome_db_id <#> : dump member associated with genome_db_id\n";
  print "  -fasta <path>     : dump fasta to file location\n";
  print "  -prefix <string>  : use <string> as prefix for sequence names in fasta file\n";
  print "comparaLoadMembers.pl v1.0\n";
  
  exit(1);  
}


sub store_gene_and_all_transcripts
{
  my($gene) = @_;
  my @longestPeptideMember;
  my $maxLength=0;
  my $gene_member;

  if($mp_store_gene) {  
    print(STDERR "     gene       " . $gene->stable_id );
    $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(-gene=>$gene, -genome_db=>$genome_db);
    print(STDERR " => member " . $gene_member->stable_id);

    $MemberAdaptor->store($gene_member);    
    print(STDERR " : stored");

    $geneSubset->add_member($gene_member);
    print(STDERR "\n");
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    $transcriptCount++;
    #print(STDERR "gene " . $gene->stable_id . "\n");
    print(STDERR "     transcript " . $transcript->stable_id );

    unless (defined $transcript->translation) {
      die "COREDB error: No translation for transcript transcript_id" . $transcript->dbID . "EXIT 1\n";
    }

    unless (defined $transcript->translation->stable_id) {
      die "COREDB error: $dbname does not contain translation stable id for translation_id ".$transcript->translation->dbID."EXIT 2\n";
    }

    my $description = fasta_description($gene, $transcript);
    my $pep_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
	 -genome_db=>$genome_db,
	 -translate=>'yes',
	 -description=>$description);

    print(STDERR " => member " . $pep_member->stable_id);

    $MemberAdaptor->store($pep_member);
    $MemberAdaptor->store_gene_peptide_link($gene_member->dbID, $pep_member->dbID);
    print(STDERR " : stored");
    
    
    if($pep_member->seq_length > $maxLength) {
      $maxLength = $pep_member->seq_length;
      @longestPeptideMember = ($transcript, $pep_member);
    }

    print(STDERR "\n");
  }
  
  if(@longestPeptideMember) {
    my ($transcript, $member) = @longestPeptideMember;
    #fasta_output($gene, @longestPeptideMember);
    $pepSubset->add_member($member);
    #print(STDERR "     LONGEST " . $transcript->stable_id . "\n");
    $longestCount++;
  }
  #if($longestCount >= 1000) { last SLICE; }
}
 
sub fasta_description {
  my ($gene, $transcript) = @_; 

  my $description = "Transcript:" . $transcript->stable_id .
		    " Gene:" .       $gene->stable_id .
		    " Chr:" .        $gene->seq_region_name .
		    " Start:" .      $gene->seq_region_start .
		    " End:" .        $gene->seq_region_end;
}



 
=head3
 
sub store_gene
{
  my($gene) = @_;

  print(STDERR "     gene       " . $gene->stable_id );
  
  my $member = Bio::EnsEMBL::Compara::Member->new_from_gene(-gene=>$gene, -genome_db=>$genome_db);
  print(STDERR " => member " . $member->stable_id);

  $MemberAdaptor->store($member);
  print(STDERR " : stored");
  
  $geneSubset->add_member($member);
  print(STDERR "\n");
}

sub fasta_output {
  my ($gene, $transcript, $member) = @_; 
  
  if(not defined($fastafile)) { return; }

  my $description = fasta_description($gene, $transcript);
  print FASTA_FP ">$prefix" .     $transcript->translation->stable_id .
                 $description . 
 		 "\n" .
		 $member->sequence . "\n";
}

sub store_longest_transcript {
  my ($gene) = @_;

  return 1 if (lc($gene->type) eq 'pseudogene');

  my $transcript = return_transcript_with_longest_translation($gene);

  unless (defined $transcript) {
    die "COREDB error: No transcript with longest translation for gene_id" . $gene->dbID . "EXIT 1\n";
  }

  my $translation = $transcript->translation;
  unless (defined $translation->stable_id) {
    die "COREDB error: $dbname does not contain translation stable id for translation_id ".$translation->dbID."EXIT 2\n";
  }

  print(STDERR "transcript " . $transcript->stable_id);
  $member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
      -transcript => $transcript, 
      -genome_db => $genome_db,
      -translate => 'yes');
  print(STDERR " => member " . $member->stable_id);
  $MemberAdaptor->store($member);
  print(STDERR " : stored");
  print(STDERR "\n");
  #if($transcriptCount >= 10) { last SLICE; }

  $transcriptCount++;
}


sub return_transcript_with_longest_translation {
  my ($gene) = @_;
  
  my $max_peptide_length = 0;
  my $transcript_with_longest_translation;

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    if (defined $transcript->translation) {
      my $peptide_length = $transcript->translation()->length();
      if ($peptide_length > $max_peptide_length) {
        $max_peptide_length  = $peptide_length;
        $transcript_with_longest_translation = $transcript;
      }
    }
  }
  return $transcript_with_longest_translation;
}

sub update_method_link
{
  # We are using here direct insert command because the compara api for homologous pair really
  # need to be cleaned and rewritten. There is no store method, and the actual object model have
  # to be rethink.

  my $sth_method_link = $db->prepare("SELECT method_link_id FROM method_link WHERE type = ?");
  my ($method_link_id) = $sth_method_link->fetchrow_array();

  unless (defined $method_link_id) {
    warn "There is no type $method_link_type in the method_link table of compara db.
  EXIT 1";
    exit 1;
  }

  my $sth_method_link_species = $db->prepare("
  SELECT ml.method_link_id 
  FROM method_link_species mls1, method_link_species mls2, method_link ml 
  WHERE mls1.method_link_id = ml.method_link_id AND 
	mls2.method_link_id = ml.method_link_id AND 
	mls1.genome_db_id = ? AND
	mls2.genome_db_id = ? AND
	mls1.species_set = mls2.species_set AND
	ml.method_link_id = ?");

  $sth_method_link_species->execute($genome_db_id1,$genome_db_id2,$method_link_id);
  my ($already_stored) = $sth_method_link_species->fetchrow_array();

  unless (defined $already_stored) {
    $sth_method_link_species = $db->prepare("select max(species_set) from method_link_species where method_link_id = ?");
    $sth_method_link_species->execute($method_link_id);
    my ($max_species_set) = $sth_method_link_species->fetchrow_array();

    $max_species_set = 0 unless (defined $max_species_set);

    $sth_method_link_species = $db->prepare("insert into method_link_species (method_link_id,species_set,genome_db_id) values (?,?,?)");
    $sth_method_link_species->execute($method_link_id,$max_species_set + 1,$genome_db_id1);
    $sth_method_link_species->execute($method_link_id,$max_species_set + 1,$genome_db_id2);
  }
}
=cut 

=head2
sub processHomologies
{
  my %homologies;
  my $idx = 1;

  while (my $line = <>) {
    my ($translation_stable_id1, $translation_stable_id2, $type,
	$chr_name1, $chr_start1, $chr_end1, $cigar_start1, $cigar_end1, $pcov1, $pid1, $pos1,
	$chr_name2, $chr_start2, $chr_end2, $cigar_start2, $cigar_end2, $pcov2, $pid2, $pos2,
	$cigar_line, $score, $pid, $pos) = split /\s+/, $line;

    next unless ($type eq "SEED" || $type eq "PIP");

    if (defined $prefix1) {
      $translation_stable_id1 =~ s/^$prefix1//;
    }
    if (defined $prefix2) {
      $translation_stable_id2 =~ s/^$prefix2//;
    }

    my $gene1 = $GeneAdaptor1->fetch_by_translation_stable_id($translation_stable_id1);
    my $gene2 = $GeneAdaptor2->fetch_by_translation_stable_id($translation_stable_id2);

    unless (defined $gene1) {
      print STDERR "translation_stable_id $translation_stable_id1 not define in core\n";
    }
    unless (defined $gene2) {
      print STDERR "translation_stable_id $translation_stable_id2 not define in core\n";
    }
    next unless (defined $gene1 && defined $gene2);

    # get or create/load member1
    my $member1 = return_member($gene1, $genome_db1);
    # get or create/load peptide_member1
    my $peptide_member1 = return_peptide_member($translation_stable_id1, $genome_db1, $TranscriptAdaptor1);
    # create attribute1
    my $attribute1 = return_attribute($peptide_member1,
                                      $cigar_line, $cigar_start1, $cigar_end1,
                                      $pcov1, $pid1, $pos1);

    # get or create/load member2
    my $member2 = return_member($gene2, $genome_db2);
    # get or create/load peptide_member2
    my $peptide_member2 = return_peptide_member($translation_stable_id2, $genome_db2, $TranscriptAdaptor2);
    # create attribute2
    my $inverse_cigar_line = $cigar_line;
    $inverse_cigar_line =~ s/D/X/g;
    $inverse_cigar_line =~ s/I/D/g;
    $inverse_cigar_line =~ s/X/I/g;
    my $attribute2 = return_attribute($peptide_member2,
                                      $inverse_cigar_line, $cigar_start2, $cigar_end2,
                                      $pcov2, $pid2, $pos2);

    # create an Homology object
    my $homology = new Bio::EnsEMBL::Compara::Homology;
    my $stable_id = $genome_db1->taxon_id . "_" . $genome_db2->taxon_id . "_";
    $stable_id .= sprintf ("%011.0d",$idx);
    $homology->stable_id($stable_id);
    $homology->source_name("ENSEMBL_HOMOLOGS");
    $homology->description($type);
    $homology->add_Member_Attribute([$member1, $attribute1]);
    $homology->add_Member_Attribute([$member2, $attribute2]);

    if (defined $homologies{$member1->stable_id . "_" . $member2->stable_id}) {
      # As we are running build_pairs.pl symmetrically, we can get more than one
      # alignment result for the same pair. We need to get the best one.
      if ( better_homology($homologies{$member1->stable_id . "_" . $member2->stable_id}, $homology) ) {
	$homologies{$member1->stable_id . "_" . $member2->stable_id} = $homology;
      }
    } else {
      $homologies{$member1->stable_id . "_" . $member2->stable_id} = $homology;
    }
    print STDERR "Seen homology $stable_id\n";
    $idx++;
  }

  # Now we load the homology in the database
  my $ha = $db->get_HomologyAdaptor;

  foreach my $homology (values %homologies) {
    $ha->store($homology);
    print STDERR "Loaded ",$homology->stable_id," homology_id ",$homology->dbID,"\n";
  }
}

sub better_homology {
  my ($current_homology,$new_homology) = @_;
  # Not implemented yet :(
  #  foreach my $member_attribute ($current_homology->get_all_Member_Attribute) {
  #   
  #  }
  return 0;
}

sub return_member {
  my ($gene, $genome_db) = @_;
  
  my $member = $MemberAdaptor->fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id); 
  
  unless (defined $member) { 
    $member = Bio::EnsEMBL::Compara::Member->new_fast
      ({'_stable_id' => $gene->stable_id,
        '_taxon_id' => $genome_db->taxon_id,
        '_description' => "NULL",
        '_genome_db_id' => $genome_db->dbID,
        '_chr_name' => $gene->seq_region_name,
        '_chr_start' => $gene->seq_region_start,
        '_chr_end' => $gene->seq_region_end,
        '_sequence' => "NULL",
        '_source_name' => "ENSEMBLGENE"});
    
    $MemberAdaptor->store($member); 
  }
  
  return $member;
}

sub return_peptide_member {
  my ($translation_stable_id, $genome_db, $TranscriptAdaptor) = @_;

  my $peptide_member = $MemberAdaptor->fetch_by_source_stable_id("ENSEMBLPEP",$translation_stable_id);
  
  unless (defined $peptide_member) {
    my $transcript = $TranscriptAdaptor->fetch_by_translation_stable_id($translation_stable_id);
    
    $peptide_member = Bio::EnsEMBL::Compara::Member->new_fast
      ({'_stable_id' => $transcript->translation->stable_id,
        '_taxon_id' => $genome_db->taxon_id,
        '_description' => "NULL",
        '_genome_db_id' => $genome_db->dbID,
        '_chr_name' => $transcript->seq_region_name,
        '_chr_start' => $transcript->coding_region_start,
        '_chr_end' => $transcript->coding_region_end,
        '_sequence' => $transcript->translate->seq,
        '_source_name' => "ENSEMBLPEP"});
    
    $MemberAdaptor->store($peptide_member);
  }

  return $peptide_member;
}

sub return_attribute {
  my ($peptide_member, $cigar_line, $cigar_start, $cigar_end,$pcov,$pid,$pos) = @_;
  
  my $attribute = Bio::EnsEMBL::Compara::Attribute->new_fast
      ({'peptide_member_id' => $peptide_member->dbID});
  my @pieces = ( $cigar_line =~ /(\d*[MDI])/g );
  my @new_pieces = ();
  foreach my $piece (@pieces) { 
    $piece =~ s/I/M/;
    if (! scalar @new_pieces || $piece =~ /D/) {
      push @new_pieces, $piece;
      next;
    }
    if ($piece =~ /\d*M/ && $new_pieces[-1] =~ /\d*M/) {
      my ($matches1) = ($piece =~ /(\d*)M/);
      my ($matches2) = ($new_pieces[-1] =~ /(\d*)M/); 
      if (! defined $matches1 || $matches1 eq "") {
        $matches1 = 1;
      } 
      if (! defined $matches2 || $matches2 eq "") { 
        $matches2 = 1; 
      } 
      $new_pieces[-1] = $matches1 + $matches2 . "M";
    } else {
      push @new_pieces, $piece;
    }
  }
  my $new_cigar_line = join("", @new_pieces);
  $attribute->cigar_line($new_cigar_line);
  $attribute->cigar_start($cigar_start);
  $attribute->cigar_end($cigar_end);
  $attribute->perc_cov($pcov);
  $attribute->perc_id($pid);
  $attribute->perc_pos($pos);

  return $attribute;
}
=cut

