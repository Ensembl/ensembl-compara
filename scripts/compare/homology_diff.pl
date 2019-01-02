#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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


=head1
  this script does homology dumps generated with this SQL statement from two different
  compara databases and compares them for differences.  

  perl ~/ensembl-compara/scripts/compare/homology_diff.pl --url1 mysql://ensro@mysql-ensembl-mirror:4240/ensembl_compara_93 --url2 file:///compare_reference_datasets/zebrafish_homology_homo_sapiens_e93.out --conf ~/ensembl-compara/scripts/compare/homology_diff.conf -gdb1 236 -gdb2 150
=cut

use strict;
use warnings;

use Getopt::Long;
use Time::HiRes qw { time };
use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Production::GeneSet;
use Bio::EnsEMBL::Compara::Production::HomologySet;
use Bio::EnsEMBL::Compara::Utils::Preloader;
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::GeneMember;

$| = 1;

Bio::EnsEMBL::Registry->no_version_check(1);

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_ref_hash'}    = {};
$self->{'compara_ref_missing'} = {};
$self->{'compara_new_hash'} = {};
$self->{'conversion_hash'} = {};
$self->{'allTypes'} = {};

$self->{'refDups'} = 0;
$self->{'newDups'} = 0;

my $help;
my $url1 = undef;
my $url2 = undef;
my $gdb1 = undef;
my $gdb2 = undef;
my $conf = undef;
my $best = 0;

GetOptions('help'   => \$help,
           'url1=s' => \$url1,
           'url2=s' => \$url2,
           'gdb1=i' => \$gdb1,
           'gdb2=i' => \$gdb2,
           'conf=s' => \$conf,
           'best'   => \$best);

if ($help) { usage(); }

unless($url1 && $url2) {
  print "\nERROR : must specify --url1 anf --url2 it can be a compara database url [-url1 mysql://user:paswd\@server:port/database] or a file [-url2 file://path_to_file/file] \n\n";
  usage();
}

unless ($conf) {
  print "\nERROR : must provide a homology description scoring file with --conf\n\n";
  usage();
}

  my ($homology_description_ranking_set1, $homology_description_ranking_set2) = @{do($conf)};

my @para_desc = qw(within_species_paralog other_paralog gene_split);
my @orthopara_desc = qw(apparent_ortholog_one2one possible_ortholog between_species_paralog);

my %homology_set_holder;

my $homology_set1 = new Bio::EnsEMBL::Compara::Production::HomologySet;
my $homology_set2 = new Bio::EnsEMBL::Compara::Production::HomologySet;

#Set 1
if ( $url1 =~ "^mysql://" ) {
    $self->{$url1} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url1 );
    my $counter_set = 1;
    load_homology_sets_from_url($counter_set, $url1);
    $homology_set1 = $homology_set_holder{$counter_set};
}
elsif( $url1 =~ "^file://" ){
    my $file_1 = substr($url1,7);
    my $counter_set = 1;
    load_homology_sets_from_file($counter_set, $file_1);
    $homology_set1 = $homology_set_holder{$counter_set};
}


#Set 2
if ( $url2 =~ "^mysql://" ) {
    $self->{$url2} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url2 );
    my $counter_set = 2;
    load_homology_sets_from_url($counter_set, $url2);
    $homology_set2 = $homology_set_holder{$counter_set};
}
elsif( $url2 =~ "^file://" ){
    my $file_2 = substr($url2,7);
    my $counter_set = 2;
    load_homology_sets_from_file($counter_set, $file_2);
    $homology_set2 = $homology_set_holder{$counter_set};
}

print STDERR "\nranking for homology description of set 1\n";
foreach my $desc (sort {$homology_description_ranking_set1->{$a} <=> $homology_description_ranking_set1->{$b}} keys %$homology_description_ranking_set1) {
  print STDERR " ",$homology_description_ranking_set1->{$desc}," ",$desc,"\n";
}

print STDERR "\nranking for homology description of set 2\n";
foreach my $desc (sort {$homology_description_ranking_set2->{$a} <=> $homology_description_ranking_set2->{$b}} keys %$homology_description_ranking_set2) {
  print STDERR " ",$homology_description_ranking_set2->{$desc}," ",$desc,"\n";
}

compare_homology_sets($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "\nhomology_diff.pl [options]\n";
  print " --help                  : print this help\n";
  print " --url1 <str>            : url of reference compara DB\n";
  print " --url2 <str>            : url of compara DB \n";
  print " --gdb1 <int>            : genome_db_id of first genome\n";
  print " --gdb2 <int>            : genome_db_id of second genome\n";
  print " --conf <str>            : path to configuration file. An example is given\n";
  print "                           ensembl-compara/scripts/compare/homology_diff.conf\n";
  print " --best                  : will print out numbers on the basis of gene counts,\n";
  print "                           not only homologies (or gene pairs)";
  print "\n";

  exit(1);
}


##################################
#
# HomologySet testing
#
##################################

sub load_homology_sets_from_file {

    my $counter_set = shift;
    my $file        = shift;

    #Reading homologies from files
    my %homology_list;

    #Hash with all the raw homologies
    my %homologies_from_file;
    my %species_list;
    my %genome_db_ids;
    my %species_stable_id_map;

    my $homology_count = 0;
    open my $fh, "<", $file || die "Could not open $file";
    while (<$fh>) {
        chomp($_);
        my @tok           = split( /\t/, $_ );
        #my $homology_id   = $tok[0];
        my $stable_id_1   = $tok[0];
        my $stable_id_2   = $tok[1];
        my $species_1     = $tok[2];
        my $species_2     = $tok[3];
        my $homology_type = $tok[4];

        $species_stable_id_map{$stable_id_1} = $species_1;
        $species_stable_id_map{$stable_id_2} = $species_2;

        #$species_list{$species_1}       = 1;
        #$species_list{$species_2}       = 1;
        $genome_db_ids{$species_1} = 1;
        $genome_db_ids{$species_2} = 2;

        #print ">>>$species_1|".$genome_db_ids{$species_1}."|<<<>>>$species_2|".$genome_db_ids{$species_2}."|<<<\n";
        #print "|$stable_id_1|$species_1=$stable_id_2|$species_2|$homology_type|\n";


        my $stable_ids;
        push(@{$stable_ids}, $stable_id_1);
        push(@{$stable_ids}, $stable_id_2);

        $homologies_from_file{$counter_set}{$homology_count}{'homology_type'} = $homology_type;
        $homologies_from_file{$counter_set}{$homology_count}{'stable_ids'} = $stable_ids;
        $homology_count++;
    }
    close($fh);

    foreach my $set ( keys %homologies_from_file ) {

        foreach my $homology_count ( keys %{ $homologies_from_file{$set} } ) {
        #foreach my $homology_type ( keys %{ $homologies_from_file{$set} } ) {

            my ( $stable_id_1, $stable_id_2 ) = @{ $homologies_from_file{$set}{$homology_count}{'stable_ids'} };
            my $homology_type = $homologies_from_file{$set}{$homology_count}{'homology_type'};

            die "Missing stable_id for homology in set: $set" if ( !$stable_id_1 || !$stable_id_2 );

            #We have no genome_db_ids when reading homologies from files.
            #Here we add these values in order to correctly build the objects.
            if (!$gdb1){
                $gdb1 = $genome_db_ids{ $species_stable_id_map{$stable_id_1} };
            }
            if (!$gdb2){
                $gdb2 = $genome_db_ids{ $species_stable_id_map{$stable_id_2} };
            }

            my $gene_member_1 = Bio::EnsEMBL::Compara::GeneMember->new( -stable_id => $stable_id_1, -source_name => 'EXTERNALGENE', -genome_db_id => $gdb1 );
            my $gene_member_2 = Bio::EnsEMBL::Compara::GeneMember->new( -stable_id => $stable_id_2, -source_name => 'EXTERNALGENE', -genome_db_id => $gdb2 );

            #Create new AlignedMembers to attach the the homologies
            my $aligned_member_1 = Bio::EnsEMBL::Compara::AlignedMember->new( -stable_id => $stable_id_1, -source_name => 'EXTERNALGENE', -genome_db_id => $gdb1, );
            my $aligned_member_2 = Bio::EnsEMBL::Compara::AlignedMember->new( -stable_id => $stable_id_2, -source_name => 'EXTERNALGENE', -genome_db_id => $gdb2, );

            $aligned_member_1->gene_member($gene_member_1);
            $aligned_member_2->gene_member($gene_member_2);

            #Create the homology and add its 2 members and description
            my $homology = new Bio::EnsEMBL::Compara::Homology;
            $homology->add_Member($aligned_member_1);
            $homology->add_Member($aligned_member_2);
            $homology->description($homology_type);

            #use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
            #my $method;
            #if ($gdb1 eq $gdb2){
                #$method = "ENSEMBL_PARALOGUES";
            #}
            #else{
                #$method = "ENSEMBL_ORTHOLOGUES";
            #}
            #my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(-method => $method, -species_set => 1234);
            #$homology->method_link_species_set($mlss);
            #$homology->method_link_species_set_id(999);


            #Add the homology to the homology_list array
            push( @{ $homology_list{$set} }, $homology );
        } ## end foreach my $homology_id ( keys...)
    } ## end foreach my $set ( keys %homologies_from_file)

    print "Homologies in set_$counter_set:" . scalar( @{ $homology_list{$counter_set} } ) . "\n";

    #Create the HomologySets
    my $homology_set = new Bio::EnsEMBL::Compara::Production::HomologySet;

    #HOMOLOGY SET
    $homology_set->add( @{ $homology_list{$counter_set} } );
    $homology_set_holder{$counter_set} = $homology_set;

} ## end sub load_homology_sets_from_file

sub load_homology_set
{
  my $self = shift;
  my $method_link_type = shift;
  my $species = shift;
  my $url = shift;

  my $mlssDBA = $self->{$url}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{$url}->get_HomologyAdaptor;
 
  my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids($method_link_type, $species);

  unless (defined $mlss) {
    return undef;
  }

  my $starttime = time();
  my $homology_list = $homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss);
  printf("%1.3f sec to fetch %d homology objects\n", 
         (time() - $starttime), scalar(@{$homology_list}));

  $starttime = time();
  my $sms_homology = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $homology_list->[0]->adaptor->db->get_AlignedMemberAdaptor, $homology_list );
  Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers( $homology_list->[0]->adaptor->db->get_GeneMemberAdaptor, $sms_homology );
  my $homology_set = new Bio::EnsEMBL::Compara::Production::HomologySet;
  $homology_set->add(@{$homology_list});
  printf("%1.3f sec to load HomologySet\n", (time() - $starttime));

  return $homology_set;
}

sub load_homology_sets_from_url {

    my $counter_set = shift;
    my $url         = shift;

    my $url_needs_para      = scalar( grep { $homology_description_ranking_set1->{$_} } @para_desc );
    my $url_needs_orthopara = scalar( grep { $homology_description_ranking_set1->{$_} } @orthopara_desc );

    print "\n$url -- in the final table shown in left down\n";
    my $homology_set = load_homology_set( $self, 'ENSEMBL_ORTHOLOGUES', [ $gdb1, $gdb2 ], $url );
    $homology_set->merge( load_homology_set( $self, 'ENSEMBL_PARALOGUES', [ $gdb1, $gdb2 ], $url ) ) if $url_needs_orthopara;
    $homology_set->merge( load_homology_set( $self, 'ENSEMBL_PARALOGUES', [$gdb1], $url ) ) if $url_needs_para;
    $homology_set->merge( load_homology_set( $self, 'ENSEMBL_PARALOGUES', [$gdb2], $url ) ) if $url_needs_para;

    $homology_set_holder{$counter_set} = $homology_set;
}

sub compare_homology_sets
{
  my $self = shift;

        print "\n===========================\n";
        print "Printing Stats set_1:\n";
        $homology_set1->print_stats;
        print "\nPrinting Stats set_2:\n";
        $homology_set2->print_stats;
        print "===========================\n";

  my $missing1 = $homology_set2->gene_set->relative_complement($homology_set1->gene_set);
  printf("\n%d genes in set1 not in set2\n", $missing1->size);

  my $missing2 = $homology_set1->gene_set->relative_complement($homology_set2->gene_set);
  printf("%d genes in set2 not in set1\n", $missing2->size);

  my $cross_hash = crossref_homologies_by_type($homology_set1, $homology_set2);
  print_conversion_stats($homology_set1, $homology_set2, $cross_hash);

if ( $best && ( ( $url1 =~ "^mysql://") && ($url2 =~ "^mysql://" ) ) ) {
    printf("\nBest homology for gene\n");
    my $genememberDBA = $self->{$url1}->get_GeneMemberAdaptor;
    my $gdba = $self->{$url1}->get_GenomeDBAdaptor;
    my $geneset1 = new Bio::EnsEMBL::Compara::Production::GeneSet;
    my $genome_db1 = $gdba->fetch_by_dbID($gdb1);
    $geneset1->add(@{$genememberDBA->fetch_all_by_GenomeDB($genome_db1, 'ENSEMBLGENE')});
    printf("   %d genes for genome_db_id=%d\n", $geneset1->size, $gdb1);
    $cross_hash = crossref_genes_to_best_homology($geneset1, $homology_set1, $homology_set2);
    print_conversion_stats($homology_set1, $homology_set2, $cross_hash);
    
    printf("\nBest homology for gene\n");
    my $geneset2 = new Bio::EnsEMBL::Compara::Production::GeneSet;
    my $genome_db2 = $gdba->fetch_by_dbID($gdb2);
    $geneset2->add(@{$genememberDBA->fetch_all_by_GenomeDB($genome_db2, 'ENSEMBLGENE')});
    printf("   %d genes for genome_db_id=%d\n", $geneset2->size, $gdb2);
    $cross_hash = crossref_genes_to_best_homology($geneset2, $homology_set1, $homology_set2);
    print_conversion_stats($homology_set1, $homology_set2, $cross_hash);
  }
    elsif($best){
        print "--best can only be used when providing DB urls\n";
    }
}


sub crossref_homologies_by_type {
  my $homologyset1 = shift;
  my $homologyset2 = shift;
  
  my $conversion_hash = {};
  my $other_homology;
  
  foreach my $type (@{$homologyset1->types}) { $conversion_hash->{$type} = {} };
  $conversion_hash->{'_missing'} = {};

  foreach my $type1 (@{$homologyset1->types}, '_missing', 'TOTAL') {
    foreach my $type2 (@{$homologyset2->types}, '_new', 'TOTAL') {
      $conversion_hash->{$type1}->{$type2} = new Bio::EnsEMBL::Compara::Production::HomologySet;
    }
  }
  
  foreach my $homology (@{$homologyset1->list}) {

    my $type1 = $homology->description;

    if ( $homology->method_link_species_set ) {
        if ( scalar @{ $homology->method_link_species_set->species_set->genome_dbs } == 1 ) {
            my $gdb = $homology->method_link_species_set->species_set->genome_dbs->[0];
            $type1 .= "_" . $gdb->dbID;
            unless ( defined $homology_description_ranking_set1->{$type1} ) {
                $homology_description_ranking_set1->{$type1} = $homology_description_ranking_set1->{ $homology->description };
            }
        }
    }

    $other_homology = $homologyset2->find_homology_like($homology);
    if($other_homology) {
      my $other_type = $other_homology->description;
    if ( ( $homology->method_link_species_set ) && ($other_homology->method_link_species_set) ){
        if ( scalar @{ $other_homology->method_link_species_set->species_set->genome_dbs } == 1 ) {
            my $gdb = $other_homology->method_link_species_set->species_set->genome_dbs->[0];
            $other_type .= "_" . $gdb->dbID;
            unless ( defined $homology_description_ranking_set2->{$other_type} ) {
                $homology_description_ranking_set2->{$other_type} = $homology_description_ranking_set2->{ $other_homology->description };
            }
        }
    }
      $conversion_hash->{$type1}->{$other_type}->add($homology);
    } else {
      $conversion_hash->{$type1}->{'_new'}->add($homology);
      $conversion_hash->{'TOTAL'}->{'_new'}->add($homology);
    }
    
    $conversion_hash->{$type1}->{'TOTAL'}->add($homology);
    $conversion_hash->{'TOTAL'}->{'TOTAL'}->add($homology);
  }
  
  foreach my $homology (@{$homologyset2->list}) {
    my $type2 = $homology->description;
    if ( $homology->method_link_species_set ) {
        if ( scalar @{ $homology->method_link_species_set->species_set->genome_dbs } == 1 ) {
            my $gdb = $homology->method_link_species_set->species_set->genome_dbs->[0];
            $type2 .= "_" . $gdb->dbID;
            unless ( defined $homology_description_ranking_set2->{$type2} ) {
                $homology_description_ranking_set2->{$type2} = $homology_description_ranking_set2->{ $homology->description };
            }
        }
    }
    unless($homologyset1->has_homology($homology)) {
      $conversion_hash->{'_missing'}->{$type2}->add($homology);
      $conversion_hash->{'_missing'}->{'TOTAL'}->add($homology);
    }
    $conversion_hash->{'TOTAL'}->{$type2}->add($homology);
    $conversion_hash->{'TOTAL'}->{'TOTAL'}->add($homology);
  }
  
  return $conversion_hash;
}

sub crossref_genes_to_best_homology {
  #this is a hacked method.  Do not try to reuse for it will likely break.
  my $geneset = shift;
  my $homologyset1 = shift;
  my $homologyset2 = shift;

  my $conversion_hash = {};
  my $other_homology;

  foreach my $type (@{$homologyset1->types}) { $conversion_hash->{$type} = {} };
  $conversion_hash->{'_missing'} = {};

  foreach my $type1 (@{$homologyset1->types}, '_missing', 'TOTAL') {
    foreach my $type2 (@{$homologyset2->types}, '_new', 'TOTAL') { 
      $conversion_hash->{$type1}->{$type2} = new Bio::EnsEMBL::Compara::Production::GeneSet;
    }
  }

  foreach my $gene (@{$geneset->list}) {
    my $homology1 = $homologyset1->best_homology_for_gene($gene, $homology_description_ranking_set1);
    my $homology2 = $homologyset2->best_homology_for_gene($gene, $homology_description_ranking_set2);

    my $type1 = '_missing';
    my $type2 = '_new';
    if (defined $homology1) {
      $type1 = $homology1->description;
        if ( $homology1->method_link_species_set ) {
            if ( scalar @{ $homology1->method_link_species_set->species_set->genome_dbs } == 1 ) {
                my ($gdb) = @{ $homology1->method_link_species_set->species_set->genome_dbs };
                $type1 .= "_" . $gdb->dbID;
                unless ( defined $homology_description_ranking_set1->{$type1} ) {
                    $homology_description_ranking_set1->{$type1} = $homology_description_ranking_set1->{ $homology1->description };
                }
            }
        }
    }
    if (defined $homology2) {
      $type2 = $homology2->description;
        if ( $homology2->method_link_species_set ) {
            if ( scalar @{ $homology2->method_link_species_set->species_set->genome_dbs } == 1 ) {
                my ($gdb) = @{ $homology2->method_link_species_set->species_set->genome_dbs };
                $type2 .= "_" . $gdb->dbID;
                unless ( defined $homology_description_ranking_set2->{$type2} ) {
                    $homology_description_ranking_set2->{$type2} = $homology_description_ranking_set2->{ $homology2->description };
                }
            }
        }
    }
    $conversion_hash->{$type1}->{$type2}->add($gene);

    $conversion_hash->{'TOTAL'}->{$type2}->add($gene);
    $conversion_hash->{$type1}->{'TOTAL'}->add($gene);

    $conversion_hash->{'TOTAL'}->{'TOTAL'}->add($gene);
  }

  return $conversion_hash;
}


sub print_conversion_stats
{
  my $set1 = shift;
  my $set2 = shift;
  my $conversion_hash = shift;

  my @set1Types = (sort({$homology_description_ranking_set1->{$a} <=> $homology_description_ranking_set1->{$b} || $a cmp $b} @{$set1->types}), '_missing', 'TOTAL');
  my @set2Types = (sort({$homology_description_ranking_set2->{$a} <=> $homology_description_ranking_set2->{$b} || $a cmp $b} @{$set2->types}), '_new', 'TOTAL');

  my $longest_type_string_length = 0;
  foreach my $type1 (@set1Types) {
    $longest_type_string_length = length($type1) if (length($type1) > $longest_type_string_length);
  }

  printf("\n%".$longest_type_string_length."s", "");
  foreach my $type2 (@set2Types) {
    foreach my $type1 (@set1Types) {
      next unless(defined($conversion_hash->{$type1}->{$type2}));
      my $l = length($type2) + 1;
      $l = 8 if ($l < 8);
      printf("%".$l."s", $type2);
      last;
    }
  }
  print("\n");
  
  foreach my $type1 (@set1Types) {
    next unless(defined($conversion_hash->{$type1}));
    printf("%".$longest_type_string_length."s", $type1);
    foreach my $type2 (@set2Types) {
      next unless($conversion_hash->{$type1}->{$type2});
      my $l = length($type2) + 1;
      $l = 8 if ($l < 8);
      my $size = $conversion_hash->{$type1}->{$type2}->size;
      printf("%".$l."s", $size);
    }
    print("\n");
  }
}

1;


