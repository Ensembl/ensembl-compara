#!/usr/bin/env perl

=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

 create_patch_pairaligner_conf.pl

=head1 SYNOPSIS

 create_patch_pairaligner_conf.pl --help  

 create_patch_pairaligner_conf.pl --master_url mysql://ensro@compara1:3306/sf5_ensembl_compara_master --ref_species homo_sapiens --species rattus_norvegicus,macaca_mulatta,pan_troglodytes,gallus_gallus,ornithorhynchus_anatinus,monodelphis_domestica,pongo_abelii,equus_caballus,bos_taurus,sus_scrofa,gorilla_gorilla,callithrix_jacchus,oryctolagus_cuniculus --ref_url mysql://ensro@ens-staging1:3306/homo_sapiens_core_68_37 --ensembl_version 68 --host ens-livemirror --dump_dir /lustre/scratch109/ensembl/kb3/scratch/hive/release_68/nib_files --haplotypes chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1 > lastz.conf

=head1 DESCRIPTION

Create the lastz configuration script for just the reference species patches against a set of other species

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=head2 GENERAL CONFIGURATION

=over

=item B<--master_url>

Location of the ensembl compara master database containing the new patches. Must be of the format:
mysql://user@host:port/ensembl_compara_master

=item B<--species>
List of non-reference pair aligner species 

=item B<[--ref_species]>
Reference species. Default homo_sapiens

=item B<--ref_url>
Location of the core database for the reference species which has the newest patches

=item B<--ensembl_version>
New ensembl_version. The non-reference species core databases will be taken from --host and be of the previous ensembl version

=item B<[--host]>
Host containing the core databases for the non-reference species core databases. Default ens-livemirror

=item B<[--port]>
Port number. Default 3306

=item B<[--user]>
Readonly user name. Default ensro

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


my $reg = "Bio::EnsEMBL::Registry";
$reg->no_version_check(1);

use Getopt::Long;

my $ref_species = "homo_sapiens";
my $master_url;
my $ref_url;
my $host = "ens-livemirror";
my $port = "3306";
my $user = "ensro";
my $ensembl_version = 62;
my $dump_dir = "/lustre/scratch109/ensembl/" . $ENV{USER} ."/scratch/hive/release_" . $ensembl_version . "/nib_files/";
my $patches;
my $non_ref_patches;
my $species = [];
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
  'ref_species=s' => \$ref_species,
  'ref_url=s' => \$ref_url,
  'ensembl_version=i' => \$ensembl_version,
  'host=s' => \$host,
  'port=i' => \$port,
  'user=s' => \$user,
  'dump_dir=s' => \$dump_dir,
  'patches=s' => \$patches,
  'non_ref_patches=s' => \$non_ref_patches,
  'species=s@' => $species,
  'master_url=s' => \$master_url,
  'exception_species=s@' => $exception_species,
  'ref_include_non_reference=i' => \$ref_include_non_reference,
  'non_ref_include_non_reference=i' => \$non_ref_include_non_reference,
 );

#Load pipeline db
my $compara_dba;
if ($master_url) {
    $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$master_url);
} else {
    throw("A compara master database url must be defined");
}

#Check values of ref_include_non_reference and non_ref_include_non_reference
#Only one can be set
if ($ref_include_non_reference && $non_ref_include_non_reference) {
    throw("It is not advisable to find matches between patches of different species. Please only set either ref_include_non_reference or non_ref_include_non_reference");
}


#Parse ref_url 
my $uri = parse_uri($ref_url);
my %ref_core = $uri->generate_dbsql_params();

my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

#Get list of genome_dbs from database
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
#my $all_genome_dbs = $genome_db_adaptor->fetch_all();

#Allow species to be specified as either --species spp1 --species spp2 --species spp3 or --species spp1,spp2,spp3
@$species = split(/,/, join(',', @$species));

#Add ref_species to list of species
push @$species, $ref_species;

my $all_genome_dbs;
foreach my $spp (@$species) {
    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($spp);
    push @$all_genome_dbs, $genome_db;
}

#Allow exception_species to be specified as either --exception_species spp1 --exception_species spp2 --exception_species spp3 or --exception_species spp1,spp2,spp3
@$exception_species = split(/,/, join(',', @$exception_species));

#Set default exception_species for human if not already set
if ($ref_species eq "homo_sapiens" && @$exception_species == 0) {
    @$exception_species = ("gorilla_gorilla", "macaca_mulatta", "pan_troglodytes", "pongo_abelii", "callithrix_jacchus");
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

#find core databases
my $core_dbs = list_core_dbs($host, $port, $user, $ensembl_version);

#
#Start of conf file
#
print "[\n";

if ($print_species) {
     
    #ref_species
    print "{TYPE => SPECIES,\n";
    print "  'abrev'          => '" . $ref_gdb->name . "',\n";
    print "  'genome_db_id'   => " . $ref_gdb->dbID . ",\n";
    print "  'taxon_id'       => " . $ref_gdb->taxon_id . ",\n";
    print "  'phylum'         => 'Vertebrata',\n";
    print "  'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',\n";
    print "  'host'           => '" . $ref_core{-HOST} . "',\n";
    print "  'port'           => " . $ref_core{-PORT} . ",\n";
    print "  'user'           => '" . $ref_core{-USER} . "\',\n";
    print "  'dbname'         => '" . $ref_core{-DBNAME} . "',\n";
    print "  'species'        => '" . $ref_gdb->name . "',\n";
    print "},\n";

    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @$genome_dbs) {
	print "{TYPE => SPECIES,\n";
	print "  'abrev'          => '" . $genome_db->name . "',\n";
	print "  'genome_db_id'   => " . $genome_db->dbID . ",\n";
	print "  'taxon_id'       => " . $genome_db->taxon_id . ",\n";
	print "  'phylum'         => 'Vertebrata',\n";
	print "  'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',\n";
	print "  'host'           => '" . $core_dbs->{$genome_db->name}{host} . "',\n";
	print "  'port'           => $port,\n";
	print "  'user'           => '$user',\n";
	print "  'dbname'         => '" . $core_dbs->{$genome_db->name}{db} . "',\n";
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


sub list_core_dbs {
    my ($host, $port, $user, $ensembl_version) = @_;
    my $core_dbs;

    #special case to go through both ens-staging1 and ens-staging2
    if ($host =~ /ens-staging/) {
	my @dbs1 = `mysql -u $user -P $port -h ens-staging1 -e "show databases like '%core_$ensembl_version%'"`;
	my @dbs2 = `mysql -u $user -P $port -h ens-staging2 -e "show databases like '%core_$ensembl_version%'"`;
	foreach my $db (@dbs1) {
            next if ($db =~ /Database/);
	    chomp $db;
	    my ($species) = $db =~ /(\w+)_core_.*/;
	    $core_dbs->{$species}{db} = $db;
	    $core_dbs->{$species}{host} = "ens-staging1";
	}
	foreach my $db (@dbs2) {
            next if ($db =~ /Database/);
	    chomp $db;
	    my ($species) = $db =~ /(\w+)_core_.*/;
	    $core_dbs->{$species}{db} = $db;
	    $core_dbs->{$species}{host} = "ens-staging2";
	}


    } else {
	$ensembl_version--;
	my @dbs = `mysql -u $user -P $port -h $host -N -e "show databases like '%core_$ensembl_version%'"`;
	foreach my $db (@dbs) {
	    chomp $db;
	    my ($species) = $db =~ /(\w+)_core_.*/;
	    $core_dbs->{$species}{db} = $db;
	    $core_dbs->{$species}{host} = $host;
	}
    }

    return $core_dbs;
}
