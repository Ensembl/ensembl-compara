#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

 create_patch_pairaligner_conf.pl --reg_conf path/to/production_reg.conf --patched_species homo_sapiens --dump_dir /lustre/scratch109/ensembl/kb3/scratch/hive/release_68/nib_files --patches chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1 > lastz.conf

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

=item B<[--patched_species]>
Reference species. Default homo_sapiens

=item B<[--dump_dir]>
Location to dump the nib files

=item B<--patches>
Patches to run the PairAligner on.
List of patches in the form: 
coord_system_name1:PATCH1,coord_system_name2:PATCH2,coord_system_name3:PATCH3
eg chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1

=item B<--patched_species_is_alignment_reference>

Boolean. Tells the script whether the patched species is the reference species in the pairwise alignment. This is 1 by default, and (in Ensembl production) should only be set to 0 for mouse patches vs human.
Note that setting this option to 0 implies that --species contains a single species, and --skip_species is not populated

=back

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $patched_species;
my $reg_conf;
my $compara_master = "compara_master";
my $dump_dir;
my $patches;
my $species = [];
my $skip_species = [];
my $exception_species = [];
my $patched_species_is_alignment_reference = 1;

#Which fields to print
my $print_species = 1;
my $print_dna_collection = 1;
my $print_pair_aligner = 1;
my $print_dna_collection2 = 1;
my $print_chain_config = 1;


GetOptions(
  'reg_conf=s' => \$reg_conf,
  'compara_master=s' => \$compara_master,
  'patched_species=s' => \$patched_species,
  'dump_dir=s' => \$dump_dir,
  'patches=s' => \$patches,
  'species=s@' => $species,
  'skip_species=s@' => $skip_species,
  'exception_species=s@' => $exception_species,
  'patched_species_is_alignment_reference=i' => \$patched_species_is_alignment_reference,
 );

#Load all the dbs via the registry
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");
my $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara_master, "compara") || die "Cannot find '$compara_master' in the Registry.\n";

die "Patches must be given with --patches.\n" unless $patches;

#Get list of genome_dbs from database
die "The name of the patched species must be given with --patched_species.\n" unless $patched_species;
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
my $patched_genome_db = $genome_db_adaptor->fetch_by_registry_name($patched_species);
my @all_genome_dbs = ($patched_genome_db);
print STDERR "Generating a configuration file for $patched_species\n";

#Set default dump_dir
$dump_dir = "/hps/nobackup/production/ensembl/" . $ENV{USER} ."/release_" . $patched_genome_db->db_adaptor->get_MetaContainer->get_schema_version() . "_patches/nib_files/" unless ($dump_dir);
print STDERR "NIB files will be dumped in $dump_dir\n";

#find list of LASTZ_NET alignments in master
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
my @pairwise_mlsss;
push @pairwise_mlsss, @{ $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB('LASTZ_NET', $patched_genome_db) };
push @pairwise_mlsss, @{ $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB('BLASTZ_NET', $patched_genome_db) };

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
    die "Only 1 species can be given to --species when the patched species is not the reference in the alignment.\n" if scalar(keys %unique_genome_dbs) > 1 and not $patched_species_is_alignment_reference;
} else {
    die "When the patched species is not the reference in the alignment, you must give --species with 1 species.\n" if not $patched_species_is_alignment_reference;
    foreach my $mlss (@pairwise_mlsss) {
        #print "name " . $mlss->name . " " . $mlss->dbID . "\n";
        my $genome_dbs = $mlss->species_set->genome_dbs;
        
        foreach my $genome_db (@$genome_dbs) {
            #find non-reference species
            if ($genome_db->name ne $patched_species) {
                #skip anything that isn't current
                next unless ($genome_db->is_current);
                print STDERR $genome_db->name, " has a karyotype ? ", $genome_db->has_karyotype, "\n";
                if ($genome_db->has_karyotype) {
                    #find non-ref genome_dbs (may be present in blastz and lastz)
                    $unique_genome_dbs{$genome_db->name} = $genome_db;
                }
            }
        }
    }
}

#Allow species to be specified as either --species spp1 --species spp2 --species spp3 or --species spp1,spp2,spp3
@$skip_species = split(/,/, join(',', @$skip_species));
die "--skip_species is forbidden twhen the patched species is not the reference in the alignment.\n" if @$skip_species and not $patched_species_is_alignment_reference;
foreach my $name (keys %unique_genome_dbs) {
    #skip anything in the skip_species array 
    next if (grep {$name eq $_}  @$skip_species); 
#    print $unique_genome_dbs{$name}->name . "\n";
    push @all_genome_dbs, $unique_genome_dbs{$name};
}

#Allow exception_species to be specified as either --exception_species spp1 --exception_species spp2 --exception_species spp3 or --exception_species spp1,spp2,spp3
@$exception_species = split(/,/, join(',', @$exception_species));

#Set default exception_species for human if not already set
if ($patched_species eq "homo_sapiens" && @$exception_species == 0) {
    # 9443 is the taxon_id of Primates
    @$exception_species = map {$_->name} grep {$_->is_current} @{$genome_db_adaptor->fetch_all_by_ancestral_taxon_id(9443)};
}

#Define dna_collections 
my $dna_collection;
%{$dna_collection->{homo_sapiens_exception}} = ('chunk_size' => 30000000,
					      'overlap'    => 0,
					      'include_non_reference' => ($patched_species_is_alignment_reference ? 1 : 0), #include haplotypes
					      'masking_options' => '"{default_soft_masking => 1}"');

%{$dna_collection->{homo_sapiens_mammal}} = ('chunk_size' => 30000000,
					     'overlap'    => 0,
					     'include_non_reference' => ($patched_species_is_alignment_reference ? 1 : 0), #include haplotypes
					     'masking_options_file' => "'" . $ENV{'ENSEMBL_CVS_ROOT_DIR'}."/ensembl-compara/scripts/pipeline/human36.spec'");

%{$dna_collection->{mus_musculus_exception}} = ('chunk_size' => 30000000,
					      'overlap'    => 0,
					      'include_non_reference' => ($patched_species_is_alignment_reference ? 1 : 0), #include haplotypes
					      'masking_options' => '"{default_soft_masking => 1}"');

%{$dna_collection->{mus_musculus_mammal}} = ('chunk_size' => 30000000,
					     'overlap'    => 0,
					     'include_non_reference' => ($patched_species_is_alignment_reference ? 1 : 0), #include haplotypes
					     'masking_options' => '"{default_soft_masking => 1}"');


%{$dna_collection->{exception}} = ('chunk_size' => 10100000,
                                   'group_set_size' => 10100000,
                                   'overlap' => 100000,
                                   'include_non_reference' => ($patched_species_is_alignment_reference ? 0 : 1), # when the patched species is not the reference
                                   'masking_options' => '"{default_soft_masking => 1}"');

%{$dna_collection->{mammal}} = ('chunk_size' => 10100000,
				'group_set_size' => 10100000,
				'overlap' => 100000,
                                'include_non_reference' => ($patched_species_is_alignment_reference ? 0 : 1), # when the patched species is not the reference
				'masking_options' => '"{default_soft_masking => 1}"');

my $pair_aligner;

my $primate_matrix = $ENV{'ENSEMBL_CVS_ROOT_DIR'}. "/ensembl-compara/scripts/pipeline/primate.matrix";
%{$pair_aligner->{exception}} = ('parameters' => "\"{method_link=>\'LASTZ_RAW\',options=>\'T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=$primate_matrix --ambiguous=iupac\'}\"");

%{$pair_aligner->{mammal}} = ('parameters' => "\"{method_link=>\'LASTZ_RAW\',options=>\'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac\'}\"");

my $ref_gdb;
my @all_but_ref_gdbs;
my @common_gdbs;
my @exception_gdbs;

foreach my $gdb (@all_genome_dbs) {
    if (not $ref_gdb) {
        # The reference species is the patched species unless $patched_species_is_alignment_reference is set
        if ($patched_species_is_alignment_reference xor ($gdb->name ne $patched_species)) {
            $ref_gdb = $gdb;
            next;
        }
    }
    push @all_but_ref_gdbs, $gdb;

    if (grep $_ eq $gdb->name, @$exception_species) {
	#print "   exception " . $gdb->name . "\n";
	push @exception_gdbs, $gdb;
    } else {
	#print "   common " . $gdb->name . "\n";
	push @common_gdbs, $gdb;
    }
}

my $ref_species = $ref_gdb->name;

#
#Start of conf file
#
print "[\n";

if ($print_species) {
     
    # all the species
    foreach my $genome_db ($ref_gdb, sort {$a->dbID <=> $b->dbID} @all_but_ref_gdbs) {
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
    print " 'region'                => \'$patches\',\n" if $patched_species_is_alignment_reference;
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
    print " 'region'                => \'$patches\',\n" if $patched_species_is_alignment_reference;
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
        print " 'region'               => \'$patches\',\n" if not $patched_species_is_alignment_reference;
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
        print " 'region'               => \'$patches\',\n" if not $patched_species_is_alignment_reference;
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
    print " 'region'                => \'$patches\',\n" if $patched_species_is_alignment_reference;
    print " 'include_non_reference' => " . $dna_collection->{$ref_mammal}{'include_non_reference'} . ",\n";  #assume same for mammal or primate
    print " 'dump_loc'              => '" . $dump_dir . "/" . $ref_gdb->name . "_nib_for_chain'\n";
    print "},\n";

    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @all_but_ref_gdbs) {
	print "{ TYPE => DNA_COLLECTION,\n";
	print " 'collection_name'       => '" . $genome_db->name . " for chain',\n";
	print " 'genome_db_id'          => " . $genome_db->dbID . ",\n";
	print " 'genome_name_assembly'  => '" . $genome_db->name . ":" . $genome_db->assembly . "',\n";
        print " 'region'                => \'$patches\',\n" if not $patched_species_is_alignment_reference;
        if ($dna_collection->{mammal}{'include_non_reference'}) {
            print " 'include_non_reference' => " . $dna_collection->{mammal}{'include_non_reference'} . ",\n";  
        }
	print " 'dump_loc'              => '" . $dump_dir . "/" . $genome_db->name . "_nib_for_chain'\n";
	print "},\n";
    }
}

if ($print_chain_config) {
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @all_but_ref_gdbs) {
	print "{TYPE                            => CHAIN_CONFIG,\n";
	print " 'input_method_link'             => [1001, 'LASTZ_RAW'],\n";
	print " 'output_method_link'            => [1002, 'LASTZ_CHAIN'],\n";
	print " 'reference_collection_name'     => '" . $ref_species . " for chain',\n";
	print " 'non_reference_collection_name' => '" . $genome_db->name . " for chain',\n";
	print " 'max_gap'                       => 50,\n";
	print " 'linear_gap'                    => 'medium'\n";
	print "},\n";
    }
    foreach my $genome_db (sort {$a->dbID <=> $b->dbID} @all_but_ref_gdbs) {
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

