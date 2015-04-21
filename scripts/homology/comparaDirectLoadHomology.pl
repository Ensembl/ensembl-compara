#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::Homology;
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
  my $geneMemberDBA = $self->{'comparaDBA'}->get_GeneMemberAdaptor();

  my $build_homology_idx=1;

  my $fileCount=0;
  my $loadCount=0;
  open ORTHOS, $self->{'orthoFile'};
  while(<ORTHOS>) {
    $fileCount++;
    my ($stable_id1, $stable_id2) = split;
    #print("$stable_id1 <=> $stable_id2\n");
    my $gene1 = $geneMemberDBA->fetch_by_stable_id($stable_id1);
    my $gene2 = $geneMemberDBA->fetch_by_stable_id($stable_id2);
    if(!defined($gene1)) {
      warn("WARNING couldn't find member for stable_id = $stable_id1\n");
      next;
    }
    if(!defined($gene2)) {
      warn("WARNING couldn't find member for stable_id = $stable_id2\n");
      next;
    }

    my $pep_member1 = $gene1->get_canonical_SeqMember();
    my $pep_member2 = $gene2->get_canonical_SeqMember();
    if(!defined($pep_member1)) {
      warn("WARNING: no peptides for gene $stable_id1\n");
      next;
    }
    if(!defined($pep_member2)) {
      warn("WARNING: no peptides for gene $stable_id2\n");
      next;
    }

    #get MethodLinkSpeciesSet
    my $gdbs = [$gene1->genome_db];
    push @$gdbs, $gene2->genome_db if $gene1->genome_db->dbID ne $gene2->genome_db->dbID;
    my $mlss = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', $gdbs);
    if(!defined($mlss)) {
      # create method_link_species_set
      $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -method => $self->{'comparaDBA'}->get_MethodAdaptor->fetch_by_type('ENSEMBL_ORTHOLOGUES'),
        -species_set_obj => $self->{'comparaDBA'}->get_SpeciesSetAdaptor->fetch_by_GenomeDBs( $gdbs )
        );
      $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    }
            
    #create an Homology object
    my $homology = new Bio::EnsEMBL::Compara::Homology;
    my $stable_id = $gene1->taxon_id() . "_" . $gene2->taxon_id . "_";
    $stable_id .= sprintf ("%011.0d",$build_homology_idx++);
    $homology->stable_id($stable_id);
    $homology->description("DWGA");
    $homology->method_link_species_set($mlss);
    bless $pep_member1, 'Bio::EnsEMBL::Compara::AlignedMember';
    $homology->add_Member($pep_member1); 
    bless $pep_member2, 'Bio::EnsEMBL::Compara::AlignedMember';
    $homology->add_Member($pep_member2); 

    #print($homology->stable_id . "\n");
    $homologyDBA->store($homology);
    $loadCount++;
  }

  print("$fileCount homologies in file\n");
  print("$loadCount homologies stored in db\n");

}
