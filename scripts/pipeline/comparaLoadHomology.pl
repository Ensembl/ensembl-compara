#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

my $usage = "

$0 -host ecs2d.internal.sanger.ac.uk -dbuser ensadmin -dbpass xxxx -dbname ensembl_compara_13_1 \
-conf_file /nfs/acari/abel/src/ensembl_main/ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf
-genome_db_id1 7 -genome_db_id2 8 -prefix1 ENSCELP input_file

";

my $help = 0;
my ($host,$dbname,$dbuser,$dbpass,$conf_file);
my ($genome_db_id1,$genome_db_id2);
my ($prefix1,$prefix2);
my $method_link_type = "HOMOLOGOUS_GENE";

GetOptions('help' => \$help,
           'host=s' => \$host,
           'dbuser=s' => \$dbuser,
           'dbpass=s' => \$dbpass,
           'dbname=s' => \$dbname,
           'conf_file=s' => \$conf_file,
           'genome_db_id1=i' => \$genome_db_id1,
	   'prefix1=s' => \$prefix1,
           'genome_db_id2=i' => \$genome_db_id2,
	   'prefix2=s' => \$prefix2);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-conf_file => $conf_file,
                                                     -host => $host,
                                                     -dbname => $dbname,
                                                     -user => $dbuser,
                                                     -pass => $dbpass);

my $MemberAdaptor = $db->get_MemberAdaptor;

my $genome_db1 = $db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id1);
my $GeneAdaptor1 = $genome_db1->db_adaptor->get_GeneAdaptor;
my $TranscriptAdaptor1 = $genome_db1->db_adaptor->get_TranscriptAdaptor;

my $genome_db2 = $db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id2);
my $GeneAdaptor2 = $genome_db2->db_adaptor->get_GeneAdaptor;
my $TranscriptAdaptor2 = $genome_db2->db_adaptor->get_TranscriptAdaptor;

# We are using here direct insert command because the compara api for homologous pair really
# need to be cleaned and rewritten. There is no store method, and the actual object model have
# to be rethink.

my $sth_method_link = $db->prepare("SELECT method_link_id FROM method_link WHERE type = ?");
$sth_method_link->execute($method_link_type);
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
