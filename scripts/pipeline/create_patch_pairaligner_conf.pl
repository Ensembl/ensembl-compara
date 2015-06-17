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



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

create_patch_pairaligner_conf.pl

=head1 SYNOPSIS

 create_patch_pairaligner_conf.pl --help  

 create_patch_pairaligner_conf.pl --reg_conf path/to/production_reg.conf --ref_species homo_sapiens --dump_dir /lustre/scratch109/ensembl/kb3/scratch/hive/release_68/nib_files --patches chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1 > lastz.conf

=head1 DESCRIPTION

Create the lastz configuration script for just the reference species patches against a set of other species

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<--reg_conf>

Location of the ensembl compara registry configuration file. The file is expected to load all the relevant core databases and a master database.

=item B<--skip_species>
List of non-reference pair aligner species to skip from this pipeline because they are new species and will have the current set of patches present in the normal pairwise pipeline

=item B<--species>
List of non-reference pair aligner species. This is not normally required since the pairwise alignments to be run are determined automatically depending on whether the non-reference species has chromosomes. This will over-ride this mechanism and can be used for running human against the mouse patches using human as the reference.

=item B<[--ref_species]>
Reference species. Default homo_sapiens

=item B<[--dump_dir]>
Location to dump the nib files

=item B<--patches>
Patches for the reference species. Normal state is to set these. Do not set when doing human vs mouse patches
List of patches in the form: 
coord_system_name1:PATCH1,coord_system_name2:PATCH2,coord_system_name3:PATCH3
eg chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1

=item B<--non_ref_patches>
Patches for the non-ref species, used for doing human vs mouse patches
List of patches in the form: 
coord_system_name1:PATCH1,coord_system_name2:PATCH2,coord_system_name3:PATCH3
eg chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1

=item B<--ref_include_non_reference>
Set include_non_reference attribute for the reference species. Default 1. Set to 0 when doing human vs mouse patches.

=item B<--non_ref_include_non_reference>
Set include_non_reference attribute for the non-reference species. Default 0. Set to 1 when doing human vs mouse patches.

=back

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::URI qw/parse_uri/;
use Getopt::Long;

my $ref_species = "homo_sapiens";
my $reg_conf;
my $compara_master = "compara_master";
my $dump_dir;
my $patches;
my $non_ref_patches;
my $species = [];
my $skip_species = [];
my $exception_species = [];
my $ref_include_non_reference = 1;
my $non_ref_include_non_reference = 0;

#Which fields to print
my $print_species = 1;
my $print_dna_collection = 1;
my $print_pair_aligner = 1;
my $print_dna_collection2 = 1;
my $print_chain_config = 1;


GetOptions(
  'reg_conf=s' => \$reg_conf,
  'compara_master=s' => \$compara_master,
  'ref_species=s' => \$ref_species,
  'dump_dir=s' => \$dump_dir,
  'patches=s' => \$patches,
  'non_ref_patches=s' => \$non_ref_patches,
  'species=s@' => $species,
  'skip_species=s@' => $skip_species,
  'exception_species=s@' => $exception_species,
  'ref_include_non_reference=i' => \$ref_include_non_reference,
  'non_ref_include_non_reference=i' => \$non_ref_include_non_reference,
 );

#Load all the dbs via the registry
my $compara_dba;
if ($reg_conf) {
    -e $reg_conf || die "'$reg_conf' does not exist ...\n";
    Bio::EnsEMBL::Registry->load_all($reg_conf);
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara_master, "compara");
} else {
    throw("A registry file or a compara master database url must be defined");
}

#Check values of ref_include_non_reference and non_ref_include_non_reference
#Only one can be set
if ($ref_include_non_reference && $non_ref_include_non_reference) {
    throw("It is not advisable to find matches between patches of different species. Please only set either ref_include_non_reference or non_ref_include_non_reference");
}

my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

#Get list of genome_dbs from database
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
#my $all_genome_dbs = $genome_db_adaptor->fetch_all();

#find list of LASTZ_NET alignments in master
my $ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($ref_species);
my $pairwise_mlsss = $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB('LASTZ_NET', $ref_genome_db);
push @$pairwise_mlsss, @{$mlss_adaptor->fetch_all_by_method_link_type_GenomeDB('BLASTZ_NET', $ref_genome_db)};
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;

my $all_genome_dbs;
#add ref_genome_db
push @$all_genome_dbs, $ref_genome_db;

#Set default dump_dir
$dump_dir = "/lustre/scratch109/ensembl/" . $ENV{USER} ."/scratch/hive/release_" . $ref_genome_db->db_adaptor->get_MetaContainer->get_schema_version() . "/nib_files/" unless ($dump_dir);
print STDERR "NIB files will be dumped in $dump_dir\n";

my %unique_genome_dbs;
#If a set of species is set, use these else automatically determine which species to use depending on whether they
#are have chromosomes.
if ($species && @$species > 0) {
    my @species_with_comma = grep {$_ =~ /,/} @$species;
    push @$species, split(/,/, $_) for @species_with_comma;
    foreach my $spp (@$species) {
        next if $spp =~ /,/;
        my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($spp);
        $unique_genome_dbs{$genome_db->name} = $genome_db;
    }
} else {
    foreach my $mlss (@$pairwise_mlsss) {
        #print "name " . $mlss->name . " " . $mlss->dbID . "\n";
        my $genome_dbs = $mlss->species_set_obj->genome_dbs;
        
        foreach my $genome_db (@$genome_dbs) {
            #find non-reference species
            if ($genome_db->name ne $ref_genome_db->name) {
                #skip anything that isn't current
                next unless ($genome_db->assembly_default);
                my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db, 'chromosome');
                if (@$dnafrags > 1) {
                    #print "   found " . @$dnafrags . " chromosomes in " . $genome_db->name . "\n";
                    #find non-ref genome_dbs (may be present in blastz and lastz)
                    $unique_genome_dbs{$genome_db->name} = $genome_db;
                } else {
                    #print "   no chromosomes found in " . $genome_db->name . "\n";
                }
            }
        }
    }
}

#Allow species to be specified as either --species spp1 --species spp2 --species spp3 or --species spp1,spp2,spp3
@$skip_species = split(/,/, join(',', @$skip_species));
foreach my $name (keys %unique_genome_dbs) {
    #skip anything in the skip_species array 
    #next if ($name ~~ @$skip_species);
    next if (grep {$name eq $_}  @$skip_species); 
#    print $unique_genome_dbs{$name}->name . "\n";
    push @$all_genome_dbs, $unique_genome_dbs{$name};
}

#Allow exception_species to be specified as either --exception_species spp1 --exception_species spp2 --exception_species spp3 or --exception_species spp1,spp2,spp3
@$exception_species = split(/,/, join(',', @$exception_species));

#Set default exception_species for human if not already set
if ($ref_species eq "homo_sapiens" && @$exception_species == 0) {
    # 9443 is the taxon_id of Primates
    @$exception_species = map {$_->name} @{$genome_db_adaptor->fetch_all_by_ancestral_taxon_id(9443)};
}

my @common_gdbs;
my @exception_gdbs;

#Define dna_collections 
my $dna_collection;
%{$dna_collection->{homo_sapiens_exception}} = ('chunk_size' => 30000000,
					      'overlap'    => 0,
					      'include_non_reference' => $ref_include_non_reference, #include haplotypes
					      'masking_options' => '"{default_soft_masking => 1}"');

%{$dna_collection->{homo_sapiens_mammal}} = ('chunk_size' => 30000000,
					     'overlap'    => 0,
					     'include_non_reference' => $ref_include_non_reference, #include haplotypes
					     'masking_options_file' => "'" . $ENV{'ENSEMBL_CVS_ROOT_DIR'}."/ensembl-compara/scripts/pipeline/human36.spec'");

%{$dna_collection->{mus_musculus_exception}} = ('chunk_size' => 30000000,
					      'overlap'    => 0,
					      'include_non_reference' => $ref_include_non_reference, #include haplotypes
					      'masking_options' => '"{default_soft_masking => 1}"');

%{$dna_collection->{mus_musculus_mammal}} = ('chunk_size' => 30000000,
					     'overlap'    => 0,
					     'include_non_reference' => $ref_include_non_reference, #include haplotypes
					     'masking_options' => '"{default_soft_masking => 1}"');


%{$dna_collection->{exception}} = ('chunk_size' => 10100000,
                                   'group_set_size' => 10100000,
                                   'overlap' => 100000,
                                   'include_non_reference' => $non_ref_include_non_reference, 
                                   'masking_options' => '"{default_soft_masking => 1}"');

%{$dna_collection->{mammal}} = ('chunk_size' => 10100000,
				'group_set_size' => 10100000,
				'overlap' => 100000,
                                'include_non_reference' => $non_ref_include_non_reference, 
				'masking_options' => '"{default_soft_masking => 1}"');

my $pair_aligner;

my $primate_matrix = $ENV{'ENSEMBL_CVS_ROOT_DIR'}. "/ensembl-compara/scripts/pipeline/primate.matrix";
%{$pair_aligner->{exception}} = ('parameters' => "\"{method_link=>\'LASTZ_RAW\',options=>\'T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=$primate_matrix --ambiguous=iupac\'}\"");

%{$pair_aligner->{mammal}} = ('parameters' => "\"{method_link=>\'LASTZ_RAW\',options=>\'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac\'}\"");

my $ref_gdb;
my $genome_dbs;
foreach my $gdb (@$all_genome_dbs) {
    if ($gdb->name eq $ref_species) {
	$ref_gdb = $gdb;
	next;
    }
    #All genome_dbs except ref_gdb
    push @$genome_dbs, $gdb;

    if (grep $_ eq $gdb->name, @$exception_species) {
	#print "   exception " . $gdb->name . "\n";
	push @exception_gdbs, $gdb;
    } else {
	#print "   common " . $gdb->name . "\n";
	push @common_gdbs, $gdb;
    }
}


#
#Start of conf file
#
print "[\n";

if ($print_species) {
     
    # all the species
    foreach my $genome_db ($ref_gdb, sort {$a->dbID <=> $b->dbID} @$genome_dbs) {
	print "{TYPE => SPECIES,\n";
	print "  'abrev'          => '" . $genome_db->name . "',\n";
	print "  'genome_db_id'   => " . $genome_db->dbID . ",\n";
	print "  'taxon_id'       => " . $genome_db->taxon_id . ",\n";
	print "  'phylum'         => 'Vertebrata',\n";
	print "  'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',\n";
	print "  'host'           => '" . $genome_db->db_adaptor->dbc->host . "',\n";
	print "  'port'           => '" . $genome_db->db_adaptor->dbc->port . "',\n";
	print "  'user'           => '" . $genome_db->db_adaptor->dbc->user . "',\n";
	print "  'dbname'         => '" . $genome_db->db_adaptor->dbc->dbname . "',\n";
	print "  'species'        => '" . $genome_db->name . "',\n";
	print "},\n";
    }
}



if ($print_dna_collection) {
    my $ref_exception = $ref_species . '_exception';
    my $ref_mammal = $ref_species . '_mammal';

    #ref_species (exception (primate) options)
    print "{TYPE => DNA_COLLECTION,\n";
    print " 'collection_name'       => \'$ref_species exception\',\n";
    print " 'genome_db_id'          => " . $ref_gdb->dbID . ",\n";
    print " 'genome_name_assembly'  => \'" . $ref_gdb->name . ":" . $ref_gdb->assembly . "',\n";
    print " 'region'                => \'$patches\',\n" if ($patches);
    print " 'chunk_size'            => " . $dna_collection->{$ref_exception}{'chunk_size'} . ",\n";
    print " 'overlap'               => " . $dna_collection->{$ref_exception}{'overlap'} . ",\n";
    print " 'include_non_reference' => " . $dna_collection->{$ref_exception}{'include_non_reference'} . ",\n";  
    print " 'masking_options'       => " . $dna_collection->{$ref_exception}{'masking_options'} . "\n";
    print "},\n";

    #ref_species (mammals options)
    print "{TYPE => DNA_COLLECTION,\n";
    print " 'collection_name'       => \'$ref_species mammal\',\n";
    print " 'genome_db_id'          => " . $ref_gdb->dbID . ",\n";
    print " 'genome_name_assembly'  => \'" . $ref_gdb->name . ":" . $ref_gdb->assembly . "',\n";
    print " 'region'                => \'$patches\',\n" if ($patches);
    print " 'chunk_size'            => " . $dna_collection->{$ref_mammal}{'chunk_size'} . ",\n";
    print " 'overlap'               => " . $dna_collection->{$ref_mammal}{'overlap'} . ",\n";
    print " 'include_non_reference' => " . $dna_collection->{$ref_mammal}{'include_non_reference'} . ",\n";  
    if ($dna_collection->{$ref_mammal}{'masking_options_file'}) {
        print " 'masking_options_file'  => " . $dna_collection->{$ref_mammal}{'masking_options_file'} . "\n";
    } else {
        print " 'masking_options'       => " . $dna_collection->{$ref_exception}{'masking_options'} . "\n";
    }
    print "},\n";

    #Exceptions (primates)
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @exception_gdbs) {
    
	print "{ TYPE => DNA_COLLECTION,\n";
	print " 'collection_name'      => \'" . $genome_db->name . " all\',\n";
	print " 'genome_db_id'         => " . $genome_db->dbID . ",\n";
	print " 'genome_name_assembly' => \'" . $genome_db->name . ":" . $genome_db->assembly . "',\n";
        print " 'region'               => \'$non_ref_patches\',\n" if ($non_ref_patches);
	print " 'chunk_size'           => " . $dna_collection->{exception}{'chunk_size'} . ",\n";
	print " 'group_set_size'       => " . $dna_collection->{exception}{'group_set_size'} . ",\n";
	print " 'overlap'              => " . $dna_collection->{exception}{'overlap'} . ",\n";
	print " 'masking_options'      => " . $dna_collection->{exception}{'masking_options'} . ",\n";
	print "},\n";
    }


    #Mammalian species
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @common_gdbs) {
	print "{ TYPE => DNA_COLLECTION,\n";
	print " 'collection_name'      => '" . $genome_db->name . " all',\n";
	print " 'genome_db_id'         => " . $genome_db->dbID . ",\n";
	print " 'genome_name_assembly' => '" . $genome_db->name . ":" . $genome_db->assembly . "',\n";
        print " 'region'               => \'$non_ref_patches\',\n" if ($non_ref_patches);
	print " 'chunk_size'           => " . $dna_collection->{mammal}{'chunk_size'} . ",\n";
	print " 'group_set_size'       => " . $dna_collection->{mammal}{'group_set_size'} . ",\n";
	print " 'overlap'              => " . $dna_collection->{mammal}{'overlap'} . ",\n";
	print " 'masking_options'      => " . $dna_collection->{mammal}{'masking_options'} . ",\n";
        if ($dna_collection->{mammal}{'include_non_reference'}) {
            print " 'include_non_reference' => " . $dna_collection->{mammal}{'include_non_reference'} . ",\n";  
        }
	print "},\n";
    }
}



if ($print_pair_aligner) {
    
    #Exceptions (primates)
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @exception_gdbs) {
	print "{ TYPE => PAIR_ALIGNER,\n";
	print " 'logic_name_prefix'             => 'LastZ',\n";
	print " 'method_link'                   => [1001, 'LASTZ_RAW'],\n";
	print " 'analysis_template'             => {\n";
	print "    '-program'                   => 'lastz',\n";
	print "    '-parameters'                => " . $pair_aligner->{exception}{'parameters'} . ",\n";
	print "    '-module'                    => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::LastZ',\n";
	print " },\n";
	print " 'max_parallel_workers'          => 100,\n";
	print " 'batch_size'                    => 10,\n";
	print " 'non_reference_collection_name' => '" . $genome_db->name . " all',\n";
	print " 'reference_collection_name'     => '" . $ref_species . " exception',\n";
	print "},\n";
    }

    #Mammalian species
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @common_gdbs) {
	print "{ TYPE => PAIR_ALIGNER,\n";
	print " 'logic_name_prefix'             => 'LastZ',\n";
	print " 'method_link'                   => [1001, 'LASTZ_RAW'],\n";
	print " 'analysis_template'             => {\n";
	print "    '-program'                   => 'lastz',\n";
	print "    '-parameters'                => " . $pair_aligner->{mammal}{'parameters'} . ",\n";
	print "    '-module'                    => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::LastZ',\n";
	print " },\n";
	print " 'max_parallel_workers'          => 100,\n";
	print " 'batch_size'                    => 10,\n";
	print " 'non_reference_collection_name' => '" . $genome_db->name . " all',\n";
	print " 'reference_collection_name'     => '" . $ref_species . " mammal',\n";
	print "},\n";
    }
}

 #########second half of the pipeline ###########

if ($print_dna_collection2) {
    #ref_species
    my $ref_mammal = $ref_species . '_mammal';

    print "{ TYPE => DNA_COLLECTION,\n";
    print " 'collection_name'       => '" . $ref_gdb->name . " for chain',\n";
    print " 'genome_db_id'          => " . $ref_gdb->dbID . ",\n";
    print " 'genome_name_assembly'  => '" . $ref_gdb->name . ":" . $ref_gdb->assembly . "',\n";
    print " 'region'                => \'$patches\',\n" if ($patches);
    print " 'include_non_reference' => " . $dna_collection->{$ref_mammal}{'include_non_reference'} . ",\n";  #assume same for mammal or primate
    print " 'dump_loc'              => '" . $dump_dir . "/" . $ref_gdb->name . "_nib_for_chain'\n";
    print "},\n";

    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @$genome_dbs) {
	print "{ TYPE => DNA_COLLECTION,\n";
	print " 'collection_name'       => '" . $genome_db->name . " for chain',\n";
	print " 'genome_db_id'          => " . $genome_db->dbID . ",\n";
	print " 'genome_name_assembly'  => '" . $genome_db->name . ":" . $genome_db->assembly . "',\n";
        print " 'region'                => \'$non_ref_patches\',\n" if ($non_ref_patches);
        if ($dna_collection->{mammal}{'include_non_reference'}) {
            print " 'include_non_reference' => " . $dna_collection->{mammal}{'include_non_reference'} . ",\n";  
        }
	print " 'dump_loc'              => '" . $dump_dir . "/" . $genome_db->name . "_nib_for_chain'\n";
	print "},\n";
    }
}

if ($print_chain_config) {
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @$genome_dbs) {
	print "{TYPE                            => CHAIN_CONFIG,\n";
	print " 'input_method_link'             => [1001, 'LASTZ_RAW'],\n";
	print " 'output_method_link'            => [1002, 'LASTZ_CHAIN'],\n";
	print " 'reference_collection_name'     => '" . $ref_species . " for chain',\n";
	print " 'non_reference_collection_name' => '" . $genome_db->name . " for chain',\n";
	print " 'max_gap'                       => 50,\n";
	print " 'linear_gap'                    => 'medium'\n";
	print "},\n";
    }
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @$genome_dbs) {
	#Find existing method_link_type for these 2 species. Assume only have either BLASTZ_NET or LASTZ_NET.
	my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('LASTZ_NET', [$ref_gdb->dbID, $genome_db->dbID]);
	unless (defined $mlss) {
	    $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('BLASTZ_NET', [$ref_gdb->dbID, $genome_db->dbID]);
	}
	unless (defined $mlss) {
	    die "Unable to find ether BLASTZ_NET or LASTZ_NET for genomes " . $ref_gdb->dbID . " and " . $genome_db->dbID . "\n";
	}
	print "{ TYPE                           => NET_CONFIG,\n";
	print " 'input_method_link'             => [1002, 'LASTZ_CHAIN'],\n";
	print " 'output_method_link'            => [" . $mlss->method->dbID . ", '" . $mlss->method->type . "'],\n";
	print " 'reference_collection_name'     => '" . $ref_species . " for chain',\n";
	print " 'non_reference_collection_name' => '" . $genome_db->name ." for chain',\n";
	print " 'max_gap'                       => 50,\n";
	print " 'input_group_type'              => 'chain',\n";
	print " 'output_group_type'             => 'default',\n";
	print "},\n";
    }

}

print "{ TYPE => END }\n";
print "]\n";

