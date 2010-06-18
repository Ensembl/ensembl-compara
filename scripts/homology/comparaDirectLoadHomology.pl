#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'speciesList'} = ();
$self->{'orthoFile'} = undef;

my $url;
my $help;

GetOptions('help'     => \$help,
           'url=s'    => \$url,
           'file=s'   => \$self->{'orthoFile'},
          );

if ($help) { usage(); }

unless($url) {
  print "\nERROR : must specify url to connect to compara databases\n\n";
  usage();
}

$self->{'comparaDBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($url . ';type=compara');

load_orthos($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaDirectLoadHomology.pl [options]\n";
  print "  -help           : print this help\n";
  print "  -url <str>      : url of compara DB \n";
  print "  -file <path>    : file containing homology pairs (as gene_stable_ids)\n";
  print "comparaDirectLoadHomology.pl v1.3\n";
  
  exit(1);  
}


sub load_orthos {
  my $self = shift;
 
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor();
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor();

  my $build_homology_idx=1;

  my $fileCount=0;
  my $loadCount=0;
  open ORTHOS, $self->{'orthoFile'};
  while(<ORTHOS>) {
    $fileCount++;
    my ($stable_id1, $stable_id2) = split;
    #print("$stable_id1 <=> $stable_id2\n");
    my $gene1 = $memberDBA->fetch_by_source_stable_id('ENSEMBLGENE', $stable_id1);
    my $gene2 = $memberDBA->fetch_by_source_stable_id('ENSEMBLGENE', $stable_id2);
    if(!defined($gene1)) {
      warn("WARNING couldn't find member for stable_id = $stable_id1\n");
      next;
    }
    if(!defined($gene2)) {
      warn("WARNING couldn't find member for stable_id = $stable_id2\n");
      next;
    }

    my $pep_member1 = $memberDBA->fetch_longest_peptide_member_for_gene_member_id($gene1->dbID);
    my $pep_member2 = $memberDBA->fetch_longest_peptide_member_for_gene_member_id($gene2->dbID);
    if(!defined($pep_member1)) {
      warn("WARNING: no peptides for gene $stable_id1\n");
      next;
    }
    if(!defined($pep_member2)) {
      warn("WARNING: no peptides for gene $stable_id2\n");
      next;
    }

    #get MethodLinkSpeciesSet
    my $mlss = $self->{'comparaDBA'}
                    ->get_MethodLinkSpeciesSetAdaptor
                    ->fetch_by_method_link_type_GenomeDBs(
                        "ENSEMBL_ORTHOLOGUES",
                        [$gene1->genome_db,$gene2->genome_db]);
    if(!defined($mlss)) {
      # create method_link_species_set

      $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
      $mlss->method_link_type("ENSEMBL_ORTHOLOGUES");
      $mlss->species_set([$gene1->genome_db,$gene2->genome_db]);
      $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    }
            
    #create an Homology object
    my $homology = new Bio::EnsEMBL::Compara::Homology;
    my $stable_id = $gene1->taxon_id() . "_" . $gene2->taxon_id . "_";
    $stable_id .= sprintf ("%011.0d",$build_homology_idx++);
    $homology->stable_id($stable_id);
    $homology->description("DWGA");
    $homology->method_link_species_set($mlss);
    
    my $attribute1 = new Bio::EnsEMBL::Compara::Attribute;
    $attribute1->peptide_member_id($pep_member1->dbID);
    $homology->add_Member_Attribute([$gene1, $attribute1]);

    my $attribute2 = new Bio::EnsEMBL::Compara::Attribute;
    $attribute2->peptide_member_id($pep_member2->dbID);
    $homology->add_Member_Attribute([$gene2, $attribute2]);

    #print($homology->stable_id . "\n");
    $homologyDBA->store($homology);
    $loadCount++;
  }

  print("$fileCount homologies in file\n");
  print("$loadCount homologies stored in db\n");

}
