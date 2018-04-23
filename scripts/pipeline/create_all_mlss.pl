#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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


use warnings;
use strict;

=head1 NAME

create_all_mlss.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script reads an XML configuration file that describes which analyses
are performed in a given Compara database. It then creates all the
necessary MethodLinkSpeciesSet objects.

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--compara compara_db_name_or_alias]>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file. DEFAULT VALUE: compara_master

=item B<[--release]>

Mark all the objects that are created / used (GenomeDB, SpeciesSet, MethodLinkSpeciesSet)
as "current", i.e. with a first_release and an undefined last_release

=back

=cut

use Getopt::Long;
use XML::LibXML;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

my $help;
my $reg_conf;
my $compara = 'compara_master';
my $release;
my $xml_config;
my $xml_schema;
my $verbose;
my $dry_run;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'xml=s'         => \$xml_config,
    'schema=s'      => \$xml_schema,
    'release'       => \$release,
    'verbose'       => \$verbose,
    'dryrun|dry_run'=> \$dry_run,
);

# Print Help and exit if help is requested
if ($help) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

#################################################
## Get the adaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing') if $reg_conf;

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, 'compara');
}
if (!$compara_dba) {
  die "Cannot connect to compara database <$compara>.";
}

unless ($xml_schema) {
    die "Need to give the --schema option or set the ENSEMBL_CVS_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_CVS_ROOT_DIR};
    $xml_schema = $ENV{ENSEMBL_CVS_ROOT_DIR} . '/ensembl-compara/scripts/pipeline/compara_db_config.rng';
}
my $schema = XML::LibXML::RelaxNG->new(location => $xml_schema);

my $xml_parser   = XML::LibXML->new(line_numbers => 1);
my $xml_document = $xml_parser->parse_file($xml_config);    ## XML::LibXML::Document
eval { $schema->validate( $xml_document) };
if ($@) {
    die "'$xml_config' is not a valid XML file (compared against the schema '$xml_schema'):\n$@\n";
}
print "'$xml_config' valid. Now parsing ...\n";

my %collections;
my @mlsss;

sub find_genome_from_xml_node_attribute {
    my ($xml_node, $attribute_name) = @_;
    my $species_name = $xml_node->getAttribute($attribute_name);
    my $gdb = $compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($species_name) || throw("Cannot find $species_name in the available list of GenomeDBs");
    return $gdb;
}

sub find_collection_from_xml_node_attribute {
    my ($xml_node, $attribute_name, $purpose) = @_;
    my $collection_name = $xml_node->getAttribute($attribute_name);
    my $collection = $collections{$collection_name} || throw("Cannot find the collection named '$collection_name' for $purpose");
    return $collection;
}


sub make_species_set_from_XML_node {
    my ($xml_ss, $pool) = @_;

    my $genome_dba = $compara_dba->get_GenomeDBAdaptor;
    my @selected_gdbs;
    foreach my $xml_taxon (@{$xml_ss->getChildrenByTagName('taxonomic_group')}) {
        my $some_genome_dbs;
        if (my $taxon_id = $xml_taxon->getAttribute('taxon_id')) {
            $some_genome_dbs = $genome_dba->fetch_all_by_ancestral_taxon_id($taxon_id);
        } else {
            my $taxon_name = $xml_taxon->getAttribute('taxon_name');
            my $taxon = $compara_dba->get_NCBITaxonAdaptor->fetch_node_by_name($taxon_name);
            $some_genome_dbs = $genome_dba->fetch_all_by_ancestral_taxon_id($taxon->dbID);
        }
        if ($xml_taxon->hasAttribute('only_with_karyotype') and $xml_taxon->getAttribute('only_with_karyotype')) {
            $some_genome_dbs = [grep {$_->has_karyotype} @$some_genome_dbs];
        }

        if ($xml_taxon->hasAttribute('only_high_coverage') and $xml_taxon->getAttribute('only_high_coverage')) {
            $some_genome_dbs = [grep {$_->is_high_coverage} @$some_genome_dbs];
        }
        foreach my $xml_ref_taxon (@{$xml_taxon->getChildrenByTagName('ref_for_taxon')}) {
            my $gdb = find_genome_from_xml_node_attribute($xml_ref_taxon, 'name');
            my $taxon_id = $xml_ref_taxon->hasAttribute('taxon_id') ? $xml_ref_taxon->getAttribute('taxon_id') : undef;
            my $ref_taxon = $taxon_id ? $compara_dba->get_NCBITaxonAdaptor->fetch_by_dbID($taxon_id) : $gdb->taxon;
            $some_genome_dbs = [grep {(($_->taxon_id != $ref_taxon->dbID) && !$_->taxon->has_ancestor($ref_taxon)) || ($_->name eq $gdb->name)} @$some_genome_dbs];
        }
        push @selected_gdbs, @$some_genome_dbs;
    }
    foreach my $xml_genome (@{$xml_ss->getChildrenByTagName('genome')}) {
        my $gdb = find_genome_from_xml_node_attribute($xml_genome, 'name');
        push @selected_gdbs, $gdb;
    }
    my %selected_gdb_ids = map {$_->dbID => 1} @selected_gdbs;
    return [grep {$selected_gdb_ids{$_->dbID}} @$pool];
}

sub make_named_species_set_from_XML_node {
    my ($xml_ss_parent, $method, $pool) = @_;

    if ($xml_ss_parent->hasAttribute('collection')) {
        my $collection_name = $xml_ss_parent->getAttribute('collection');
        my $species_set = find_collection_from_xml_node_attribute($xml_ss_parent, 'collection', $method->type);
        return [$species_set, $collection_name];

    } else {
        my $collection;
        my ($xml_species_set) = $xml_ss_parent->getChildrenByTagName('species_set');
        if ($xml_species_set->hasAttribute('in_collection')) {
            $collection = find_collection_from_xml_node_attribute($xml_species_set, 'in_collection', $method->type);
        }
        my $genome_dbs = make_species_set_from_XML_node($xml_species_set, $collection ? $collection->genome_dbs : $pool);
        my $species_set = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set($genome_dbs, $xml_species_set->getAttribute('name'));
        my $display_name = $xml_species_set->getAttribute('display_name');
        return [$species_set, $display_name];
    }
}

# There can be a single 'compara_db' node in the document
my $division_node = $xml_document->documentElement();
my $division_name = $division_node->getAttribute('division');
my $division_species_set = $compara_dba->get_SpeciesSetAdaptor->fetch_collection_by_name($division_name);
$collections{$division_name} = $division_species_set;

foreach my $collection_node (@{$division_node->findnodes('collections/collection')}) {
    my $genome_dbs = make_species_set_from_XML_node($collection_node, $division_species_set->genome_dbs);
    my $collection_name = $collection_node->getAttribute('name');
    $collections{$collection_name} = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set($genome_dbs, "collection-$collection_name");
}

foreach my $xml_ref_to_all_node (@{$division_node->findnodes('pairwise_alignments/ref_to_all')}) {
    my $ref_gdb = find_genome_from_xml_node_attribute($xml_ref_to_all_node, 'ref_species');
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type( $xml_ref_to_all_node->getAttribute('method') );
    my $genome_dbs = make_species_set_from_XML_node($xml_ref_to_all_node->getChildrenByTagName('species_set')->[0], $division_species_set->genome_dbs);
    $genome_dbs = [grep {$_->dbID ne $ref_gdb->dbID} @$genome_dbs];
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_pairwise_wga_mlss($compara_dba, $method, $ref_gdb, $_) } for @$genome_dbs;
}

foreach my $xml_msa (@{$division_node->findnodes('multiple_alignments/multiple_alignment')}) {
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type($xml_msa->getAttribute('method'));
    my ($species_set, $display_name) = @{ make_named_species_set_from_XML_node($xml_msa, $method, $division_species_set->genome_dbs) };
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_multiple_wga_mlss($compara_dba, $method, $species_set, $display_name, ($xml_msa->getAttribute('gerp') // 0)) };
}

my $self_aln_method = $compara_dba->get_MethodAdaptor->fetch_by_type('LASTZ_NET');
foreach my $xml_self_aln (@{$division_node->findnodes('self_alignments/genome')}) {
    my $gdb = find_genome_from_xml_node_attribute($xml_self_aln, 'name');
    push @mlsss, Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_self_wga_mlss($self_aln_method, $gdb);
}

foreach my $xml_asm_patch (@{$division_node->findnodes('assembly_patches/genome')}) {
    my $gdb = find_genome_from_xml_node_attribute($xml_asm_patch, 'name');
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_assembly_patch_mlsss($compara_dba, $gdb) };
}

my $fam_method = $compara_dba->get_MethodAdaptor->fetch_by_type('FAMILY');
foreach my $fam_node (@{$division_node->findnodes('families/family')}) {
    my ($species_set, $display_name) = @{ make_named_species_set_from_XML_node($fam_node, $fam_method, $division_species_set->genome_dbs) };
    push @mlsss, Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($fam_method, $species_set, undef, $display_name);
}

foreach my $gt (qw(protein nc)) {
    my $gt_method = $compara_dba->get_MethodAdaptor->fetch_by_type((uc $gt).'_TREES');
    foreach my $gt_node (@{$division_node->findnodes("gene_trees/${gt}_trees")}) {
        my ($species_set, $display_name) = @{ make_named_species_set_from_XML_node($gt_node, $gt_method, $division_species_set->genome_dbs) };
        push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_homology_mlsss($compara_dba, $gt_method, $species_set, $display_name) }
    }
}

my $st_method = $compara_dba->get_MethodAdaptor->fetch_by_type('SPECIES_TREE');
foreach my $st_node (@{$division_node->findnodes('species_trees/species_tree')}) {
    my ($species_set, $display_name) = @{ make_named_species_set_from_XML_node($st_node, $st_method, $division_species_set->genome_dbs) };
    push @mlsss, Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($st_method, $species_set, undef, $display_name);
}

$compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {

        print "1. Collections that need to be created:\n\n";
        foreach my $collection_name (sort keys %collections) {
            my $collection = $collections{$collection_name};
            # Check if it is already in the database
            my $exist_set = $compara_dba->get_SpeciesSetAdaptor->fetch_by_GenomeDBs($collection->genome_dbs);
            if ($exist_set and $exist_set->is_current) {
                next;
            }
            if ($verbose) {
                print "COLLECTION: ", $collection->name, "\n";
                print $_->toString, "\n" for sort {$a->dbID <=> $b->dbID} @{$collection->genome_dbs};
                print "=", scalar(@{$collection->genome_dbs}), " genomes\n";
            }
            $compara_dba->get_SpeciesSetAdaptor->store($collection);
            $compara_dba->get_SpeciesSetAdaptor->make_object_current($collection);
            if ($verbose) {
                print "AFTER STORING: ", $collection->toString, "\n\n";
            }
        }

        print "2. MethodLinkSpeciesSets that need to be created:\n\n";
        foreach my $mlss (@mlsss) {
            my $exist_mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs($mlss->method->type, $mlss->species_set->genome_dbs);
            # Check if it is already in the database
            if ($exist_mlss and $exist_mlss->is_current) {
                $mlss->first_release($exist_mlss->first_release); # Needed for the check $methods_worth_reporting
                $mlss->dbID($exist_mlss->dbID); # Needed for the check $methods_worth_reporting
                next;
            }
            # Special case for LastZ alignments: we still have some equivalent BlastZ alignments
            if (!$exist_mlss and ($mlss->method->type eq 'LASTZ_NET')) {
                $exist_mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('BLASTZ_NET', $mlss->species_set->genome_dbs);
                # Check if it is already in the database
                if ($exist_mlss and $exist_mlss->is_current) {
                    $mlss->first_release($exist_mlss->first_release); # Needed for the check $methods_worth_reporting
                    $mlss->dbID($exist_mlss->dbID); # Needed for the check $methods_worth_reporting
                    next;
                }
            }
            if ($verbose) {
                print "MLSS: ", $mlss->name, "\n";
                print "METHOD: ", $mlss->method->type, "\n";
                print "SS: ", $mlss->species_set->name, "\n";
                print $_->toString, "\n" for sort {$a->dbID <=> $b->dbID} @{$mlss->species_set->genome_dbs};
                print "=", scalar(@{$mlss->species_set->genome_dbs}), "\n";
            }
            $compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
            $compara_dba->get_MethodLinkSpeciesSetAdaptor->make_object_current($mlss);
            if ($verbose) {
                print "AFTER STORING: ", $mlss->toString, "\n\n";
            }
        }
        die "Aborted: 'dry_run' mode requested\n" if $dry_run;
    } );


print "Summary:\n--------\n";
my $current_version = software_version();
my %methods_worth_reporting = map {$_ => 1} qw(EPO EPO_LOW_COVERAGE PECAN CACTUS_HAL GERP_CONSTRAINED_ELEMENT GERP_CONSERVATION_SCORE PROTEIN_TREES NC_TREES SPECIES_TREE);
foreach my $mlss (@mlsss) {
    if ($methods_worth_reporting{$mlss->method->type} and $mlss->first_release == $current_version) {
        print $mlss->toString, "\n";
    }
}

