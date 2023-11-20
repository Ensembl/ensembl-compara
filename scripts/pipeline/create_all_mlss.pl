#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

=head1 DESCRIPTION

This script reads an XML configuration file that describes which analyses
are performed in a given Compara database. It then creates all the
necessary MethodLinkSpeciesSet objects.

=head1 SYNOPSIS

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/create_all_mlss.pl --help

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/create_all_mlss.pl \
         --compara $(mysql-ens-compara-prod-1 details url ensembl_compara_master) \
         --xml $ENSEMBL_ROOT_DIR/ensembl-compara/conf/vertebrates/mlss_conf.xml --release

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
the L<--compara> option must be a URL.

=item B<[--compara compara_db_name_or_alias]>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file. DEFAULT VALUE: compara_master
(assumes the L<--reg_conf> option is given).

=item B<--xml xml_configuration_file>

The XML configuration file of the analyses to define in the Compara database.
See conf/vertebrates/mlss_conf.xml for an example

=item B<[--schema rng_schema_file]>

The RelaxNG definition of the XML files. Defaults to $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/compara_db_config.rng

=item B<[--output_file output_file]>

Optional. Print report in the given file instead of STDOUT.

=back

=head2 BEHAVIOUR CONFIGURATION

=over

=item B<[--release]>

Mark all the objects that are created / used (GenomeDB, SpeciesSet, MethodLinkSpeciesSet)
as "current", i.e. with a first_release and an undefined last_release.
Default: not set

=item B<[--retire_unmatched]>

Retire the MethodLinkSpeciesSets that are not defined by the XML file.
Default: not set

=item B<[--dry-run]>

When given, the script will not store / update anything in the database.
Default: not set (i.e. the database *will* be updated)

=item B<[--verbose|--debug]>

Print more details about the MLSSs that are being defined.

=back

=cut

use Getopt::Long;
use XML::LibXML;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use JSON;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

my $help;
my $reg_conf;
my $compara = 'compara_master';
my $release;
my $retire_unmatched;
my $xml_config;
my $xml_schema;
my $verbose;
my $dry_run;
my $output_file;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'xml=s'         => \$xml_config,
    'schema=s'      => \$xml_schema,
    'release'       => \$release,
    'verbose|debug' => \$verbose,
    'output_file=s' => \$output_file,
    'retire_unmatched'          => \$retire_unmatched,
    'dryrun|dry_run|dry-run'    => \$dry_run,
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
my $genome_dba = $compara_dba->get_GenomeDBAdaptor;

unless ($xml_schema) {
    die "Need to give the --schema option or set the ENSEMBL_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_ROOT_DIR};
    $xml_schema = $ENV{ENSEMBL_ROOT_DIR} . '/ensembl-compara/scripts/pipeline/compara_db_config.rng';
}
my $schema = XML::LibXML::RelaxNG->new(location => $xml_schema);

my $xml_parser   = XML::LibXML->new(line_numbers => 1);
my $xml_document = $xml_parser->parse_file($xml_config);    ## XML::LibXML::Document
eval { $schema->validate( $xml_document) };
if ($@) {
    die "'$xml_config' is not a valid XML file (compared against the schema '$xml_schema'):\n$@\n";
}
print "'$xml_config' valid. Now parsing ...\n";

my %unstored_collection_names;
my %collections;
my @mlsss;

sub find_genome_from_xml_node_attribute {
    my ($xml_node, $attribute_name, $assembly_name) = @_;
    my $species_name = $xml_node->getAttribute($attribute_name);
    my $gdb;
    if (defined $assembly_name && $xml_node->hasAttribute($assembly_name)) {
        my $species_assembly = $xml_node->getAttribute($assembly_name);
        $gdb = $genome_dba->fetch_by_name_assembly($species_name, $species_assembly) || throw("Cannot find $species_name (assembly $species_assembly) in the available list of GenomeDBs");
    } else {
        $gdb = $genome_dba->fetch_by_name_assembly($species_name) || throw("Cannot find $species_name in the available list of GenomeDBs");
    }
    die "Cannot find any current genomes matching '$species_name'. Please check that this name is still correct" unless (defined $assembly_name || $gdb->is_current);
    return $gdb;
}

sub find_collection_from_xml_node_attribute {
    my ($xml_node, $attribute_name, $purpose) = @_;
    my $collection_name = $xml_node->getAttribute($attribute_name);
    my $collection = $collections{$collection_name} || throw("Cannot find the collection named '$collection_name' for $purpose");
    return $collection;
}

sub intersect_with_pool {
    my ($genome_dbs, $pool) = @_;
    my %selected_gdb_ids = map {$_->dbID => 1} @$genome_dbs;
    return [grep {$selected_gdb_ids{$_->dbID}} @$pool];
}

sub fetch_genome_dbs_by_taxon_id {
    my ($taxon_id, $pool) = @_;
    my $genome_dbs = $genome_dba->fetch_all_by_ancestral_taxon_id($taxon_id);
    return intersect_with_pool($genome_dbs, $pool);
}

sub fetch_genome_dbs_by_taxon_name {
    my ($taxon_name, $pool) = @_;
    my $taxon = $compara_dba->get_NCBITaxonAdaptor->fetch_node_by_name($taxon_name) || throw "Cannot find a taxon named '$taxon_name' in the database";
    return fetch_genome_dbs_by_taxon_id($taxon->dbID, $pool);
}

sub fetch_most_recent_current_collection_by_name {
    my ($ss_adaptor, $collection) = @_;

    assert_ref($ss_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor', 'ss_adaptor');
    throw('$collection is required') unless $collection;

    my @matching_ss = @{$ss_adaptor->fetch_all_by_name($collection =~ /^collection-/ ? $collection : "collection-$collection")};

    my @matching_current_ss = grep { $_->is_current() } @matching_ss;

    return $ss_adaptor->_find_most_recent(\@matching_current_ss);
}

sub make_species_set_from_XML_node {
    my ($xml_ss, $pool) = @_;

    if ($xml_ss->hasAttribute('in_collection')) {
        my $collection = find_collection_from_xml_node_attribute($xml_ss, 'in_collection', 'species-set');
        $pool = $collection->genome_dbs;
    }

    my @selected_gdbs;
    foreach my $child ($xml_ss->childNodes()) {
      my $some_genome_dbs;
      if ($child->nodeName eq 'taxonomic_group') {
        my $xml_taxon = $child;
        if ($xml_taxon->hasAttribute('taxon_id')) {
            my $taxon_id = $xml_taxon->getAttribute('taxon_id');
            $some_genome_dbs = fetch_genome_dbs_by_taxon_id($taxon_id, $pool);
        } else {
            my $taxon_name = $xml_taxon->getAttribute('taxon_name');
            $some_genome_dbs = fetch_genome_dbs_by_taxon_name($taxon_name, $pool);
        }
        if ($xml_taxon->hasAttribute('only_with_karyotype') and $xml_taxon->getAttribute('only_with_karyotype')) {
            $some_genome_dbs = [grep {$_->has_karyotype} @$some_genome_dbs];
        }

        if ($xml_taxon->hasAttribute('only_good_for_alignment') and $xml_taxon->getAttribute('only_good_for_alignment')) {
            $some_genome_dbs = [grep {$_->is_good_for_alignment} @$some_genome_dbs];
        }

        foreach my $xml_ref_taxon (@{$xml_taxon->getChildrenByTagName('ref_for_taxon')}) {
            my $gdb = find_genome_from_xml_node_attribute($xml_ref_taxon, 'name');
            my $taxon_id = $xml_ref_taxon->hasAttribute('taxon_id') ? $xml_ref_taxon->getAttribute('taxon_id') : undef;
            my $ref_taxon = $taxon_id ? $compara_dba->get_NCBITaxonAdaptor->fetch_by_dbID($taxon_id) : $gdb->taxon;
            $some_genome_dbs = [grep {(($_->taxon_id != $ref_taxon->dbID) && !$_->taxon->has_ancestor($ref_taxon)) || ($_->name eq $gdb->name)} @$some_genome_dbs];
        }
      } elsif ($child->nodeName eq 'genome') {
        my $gdb = find_genome_from_xml_node_attribute($child, 'name', 'assembly');
        # If the genome is not current, warn the user and do not add it to the species set
        warn "The genome matching '" . $gdb->name . "' (assembly " . $gdb->assembly . ") is not current. Skipped" unless $gdb->is_current;
        next unless $gdb->is_current;
        # Matching GenomeDB by name ensures we draw its genome components from the pool.
        $some_genome_dbs = [grep {$_->name eq $gdb->name} @$pool];
      } elsif ($child->nodeName =~ /^#(comment|text)$/) {
        next;
      } elsif ($child->nodeName eq 'base_collection') {
        # include all genomes in this base collection
        my $base_collection = find_collection_from_xml_node_attribute($child, 'name', 'base collection');
        $some_genome_dbs = $base_collection->genome_dbs;
      } else {
        throw(sprintf('Unknown child: %s (line %d)', $child->nodeName, $child->line_number));
      }
      if ($child->hasAttribute('exclude') and $child->getAttribute('exclude')) {
        my %gdb_ids_to_remove = map {$_->dbID => 1} @$some_genome_dbs;
        @selected_gdbs = grep {!$gdb_ids_to_remove{$_->dbID}} @selected_gdbs;
      } else {
        push @selected_gdbs, @$some_genome_dbs;
      }
    }
    return intersect_with_pool(\@selected_gdbs, $pool);
}

sub make_named_species_set_from_XML_node {
    my ($xml_ss_parent, $method, $pool, $allow_components) = @_;

    if ($xml_ss_parent->hasAttribute('collection')) {
        my $collection_name = $xml_ss_parent->getAttribute('collection');
        my $species_set = find_collection_from_xml_node_attribute($xml_ss_parent, 'collection', $method->type);

        if (!$allow_components && grep {$_->genome_component} @{$species_set->genome_dbs}) {
            throw(sprintf("Cannot use the collection named '%s' because it contains component GenomeDBs, which are not allowed for %s",
                          $collection_name, $method->type));
        }

        return $species_set;

    } else {
        my $collection;
        my ($xml_species_set) = $xml_ss_parent->getChildrenByTagName('species_set');
        if ($xml_species_set->hasAttribute('in_collection')) {
            $collection = find_collection_from_xml_node_attribute($xml_species_set, 'in_collection', $method->type);
        }
        my $genome_dbs = make_species_set_from_XML_node($xml_species_set, $collection ? $collection->genome_dbs : $pool);

        if (!$allow_components) {
            $genome_dbs = [grep {!$_->genome_component} @$genome_dbs];
        }

        my $species_set = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set($genome_dbs, $xml_species_set->getAttribute('name'));
        $species_set->add_tag('display_name', $xml_species_set->getAttribute('display_name')) if $xml_species_set->hasAttribute('display_name');
        return $species_set;
    }
}

# There can be a single 'compara_db' node in the document
my $division_node = $xml_document->documentElement();
my $division_name = $division_node->getAttribute('division');

my $ss_adaptor = $compara_dba->get_SpeciesSetAdaptor;
my $division_species_set = fetch_most_recent_current_collection_by_name($ss_adaptor, $division_name);
if (!defined $division_species_set) {
    $division_species_set = fetch_most_recent_current_collection_by_name($ss_adaptor, 'default');

    if (!defined $division_species_set) {
        throw("Cannot find a current division collection named '$division_name' or 'default'");
    }
}

$collections{$division_name} = $division_species_set;
my $division_genome_dbs = [sort {$a->dbID <=> $b->dbID} @{$division_species_set->genome_dbs}];
foreach my $collection_node (@{$division_node->findnodes('collections/collection')}) {
    my $no_release = $collection_node->getAttribute('no_release') || 0;
    my $genome_dbs = make_species_set_from_XML_node($collection_node, $division_genome_dbs);

    my $no_components = $collection_node->getAttribute('no_components') // 0;
    if ($no_components) {
        $genome_dbs = [grep {!$_->genome_component} @$genome_dbs];
    }

    my $collection_name = $collection_node->getAttribute('name');
    $collections{$collection_name} = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set($genome_dbs, "collection-$collection_name", $no_release);

    my $no_store = $collection_node->getAttribute('no_store') // 0;
    if ($no_store) {
        $unstored_collection_names{$collection_name} = 1;
    }
}

foreach my $xml_one_vs_all_node (@{$division_node->findnodes('pairwise_alignments/pairwise_alignment')}) {
    my $ref_gdb = find_genome_from_xml_node_attribute($xml_one_vs_all_node, 'ref_genome');
    my $target_gdb = find_genome_from_xml_node_attribute($xml_one_vs_all_node, 'target_genome');
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type( $xml_one_vs_all_node->getAttribute('method') );
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_pairwise_wga_mlsss($compara_dba, $method, $ref_gdb, $target_gdb) };
}

# @refs will contain triplets: reference_genome_db, alignment_method, target_taxon_gdb_ids
my @refs;
foreach my $xml_one_vs_all_node (@{$division_node->findnodes('pairwise_alignments/one_vs_all')}) {
    my $ref_gdb = find_genome_from_xml_node_attribute($xml_one_vs_all_node, 'ref_genome');
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type( $xml_one_vs_all_node->getAttribute('method') );
    my $genome_dbs;
    if ($xml_one_vs_all_node->hasAttribute('against')) {
        my $taxon_name = $xml_one_vs_all_node->getAttribute('against');
        $genome_dbs = fetch_genome_dbs_by_taxon_name($taxon_name, $division_genome_dbs);
    } else {
        $genome_dbs = make_species_set_from_XML_node($xml_one_vs_all_node->getChildrenByTagName('species_set')->[0], $division_genome_dbs);
    }
    $genome_dbs = [grep {$_->dbID ne $ref_gdb->dbID && !$_->genome_component} @$genome_dbs];
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_pairwise_wga_mlsss($compara_dba, $method, $ref_gdb, $_) } for @$genome_dbs;
    my $target_ref_gdbs;
    if ($xml_one_vs_all_node->hasAttribute('ref_amongst')) {
        my $taxon_name = $xml_one_vs_all_node->getAttribute('ref_amongst');
        $target_ref_gdbs = fetch_genome_dbs_by_taxon_name($taxon_name, $division_genome_dbs);
    } elsif (my ($xml_ref_set) = $xml_one_vs_all_node->getChildrenByTagName('ref_genome_set')) {
        $target_ref_gdbs = make_species_set_from_XML_node($xml_ref_set, $division_genome_dbs);
    }
    $target_ref_gdbs = [grep {!$_->genome_component} @$target_ref_gdbs];
    if ($target_ref_gdbs and scalar(@$target_ref_gdbs)) {
        push @refs, [$ref_gdb, $method, {map {$_->dbID => 1} @$target_ref_gdbs}];
    }
}

foreach my $xml_all_vs_one_node (@{$division_node->findnodes('pairwise_alignments/all_vs_one')}) {
    my $target_gdb = find_genome_from_xml_node_attribute($xml_all_vs_one_node, 'target_genome');
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type( $xml_all_vs_one_node->getAttribute('method') );
    my $genome_dbs = make_species_set_from_XML_node($xml_all_vs_one_node->getChildrenByTagName('species_set')->[0], $division_genome_dbs);
    $genome_dbs = [grep {$_->dbID ne $target_gdb->dbID && !$_->genome_component} @$genome_dbs];
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_pairwise_wga_mlsss($compara_dba, $method, $_, $target_gdb) } for @$genome_dbs;
}

foreach my $xml_all_vs_all_node (@{$division_node->findnodes('pairwise_alignments/all_vs_all')}) {
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type( $xml_all_vs_all_node->getAttribute('method') );
    my $genome_dbs = make_species_set_from_XML_node($xml_all_vs_all_node->getChildrenByTagName('species_set')->[0], $division_genome_dbs);
    $genome_dbs = [grep {!$_->genome_component} @$genome_dbs];
    while (my $ref_gdb = shift @$genome_dbs) {
        push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_pairwise_wga_mlsss($compara_dba, $method, $ref_gdb, $_) } for @$genome_dbs;
    }
}

# References between themselves
while (my $aref1 = shift @refs) {
    my ($gdb1, $method1, $pool1) = @$aref1;
    foreach my $aref2 (@refs) {
        my ($gdb2, $method2, $pool2) = @$aref2;
        # As long as each genome is in the target scope of the other
        if ($pool1->{$gdb2->dbID} and $pool2->{$gdb1->dbID}) {
            push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_pairwise_wga_mlsss($compara_dba, $method1, $gdb1, $gdb2) };
        }
    }
}

foreach my $xml_msa (@{$division_node->findnodes('multiple_alignments/multiple_alignment')}) {
    my $no_release = $xml_msa->getAttribute('no_release') || 0;
    if ($xml_msa->getAttribute('method') =~ /(.*)\+(.*)/) {
        # Assume we combine two pipelines (presumably EPO and EPO_EXTENDED)
        my $method1 = $compara_dba->get_MethodAdaptor->fetch_by_type($1);
        my $method2 = $compara_dba->get_MethodAdaptor->fetch_by_type($2);
        my $species_set2 = make_named_species_set_from_XML_node($xml_msa, $method2, $division_genome_dbs, 0);
        my @good_gdbs = grep {$_->is_good_for_alignment} @{$species_set2->genome_dbs};
        if (scalar(@good_gdbs) < 3) {
            throw(sprintf('Only %d "good for alignment" genomes in the "%s" set. Need 3 or more for %s.', scalar(@good_gdbs), $species_set2->name, $method1->type));
        } elsif (scalar(@good_gdbs) == $species_set2->size) {
            throw(sprintf('All the genomes of the "%s" set are "good for alignment". No need to require %s', $species_set2->name, $method2->type));
        }
        my $species_set1 = Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_species_set(\@good_gdbs, $species_set2->name);
        push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_multiple_wga_mlsss($compara_dba, $method1, $species_set1, undef, $no_release) };
        push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_multiple_wga_mlsss($compara_dba, $method2, $species_set2, ($xml_msa->getAttribute('gerp') // 0), $no_release) };
        next;
    }
    my $method = $compara_dba->get_MethodAdaptor->fetch_by_type($xml_msa->getAttribute('method'));
    my $species_set = make_named_species_set_from_XML_node($xml_msa, $method, $division_genome_dbs);
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_multiple_wga_mlsss($compara_dba, $method, $species_set, ($xml_msa->getAttribute('gerp') // 0), $no_release, undef, $xml_msa->getAttribute('url')) };
}

foreach my $xml_self_aln (@{$division_node->findnodes('self_alignments/genome')}) {
    my $gdb = find_genome_from_xml_node_attribute($xml_self_aln, 'name');
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_self_wga_mlsss($compara_dba, $gdb) };
}

foreach my $xml_asm_patch (@{$division_node->findnodes('assembly_patches/genome')}) {
    my $gdb = find_genome_from_xml_node_attribute($xml_asm_patch, 'name');
    push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_assembly_patch_mlsss($compara_dba, $gdb) };
}

my $fam_method = $compara_dba->get_MethodAdaptor->fetch_by_type('FAMILY');
foreach my $fam_node (@{$division_node->findnodes('families/family')}) {
    my $species_set = make_named_species_set_from_XML_node($fam_node, $fam_method, $division_genome_dbs, 0);
    push @mlsss, Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($fam_method, $species_set);
}

foreach my $gt (qw(protein nc)) {
    my $gt_method = $compara_dba->get_MethodAdaptor->fetch_by_type((uc $gt).'_TREES');
    foreach my $gt_node (@{$division_node->findnodes("gene_trees/${gt}_trees")}) {
        my $allow_components = $gt eq 'protein';
        my $species_set = make_named_species_set_from_XML_node($gt_node, $gt_method, $division_genome_dbs, $allow_components);
        push @mlsss, @{ Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_homology_mlsss($compara_dba, $gt_method, $species_set) }
    }
}

my $st_method = $compara_dba->get_MethodAdaptor->fetch_by_type('SPECIES_TREE');
foreach my $st_node (@{$division_node->findnodes('species_trees/species_tree')}) {
    my $species_set = make_named_species_set_from_XML_node($st_node, $st_method, $division_genome_dbs, 1);
    push @mlsss, Bio::EnsEMBL::Compara::Utils::MasterDatabase::create_mlss($st_method, $species_set);
}

my $method_adaptor = $compara_dba->get_MethodAdaptor;
my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
my %mlss_ids_to_find = map {$_->dbID => $_} @{$mlss_adaptor->fetch_all_current};
my @genome_db_without_comp = grep {!$_->genome_component} @{$division_genome_dbs};

my @mlsss_created;
my @mlsss_existing;
my @mlsss_retired;

$compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {

        if ($verbose) {
            print "\n0. Division:\n\n" if $verbose;
            print "DIVISION: ", $division_name, "\n";
            print $_->toString, "\n" for sort {$a->dbID <=> $b->dbID} @genome_db_without_comp;
            print "=", scalar(@genome_db_without_comp), " genomes\n\n";
            print "1. Collections that need to be created:\n\n";
        }

        foreach my $collection_name (sort keys %collections) {
            next if exists $unstored_collection_names{$collection_name};
            next if $collection_name eq $division_name;
            my $collection = $collections{$collection_name};
            # Check if it is already in the database
            my $exist_set = $compara_dba->get_SpeciesSetAdaptor->fetch_by_GenomeDBs($collection->genome_dbs);
            if ($exist_set and ($exist_set->is_current || $collection->{_no_release})) {
                next;
            }
            if ($verbose) {
                print "COLLECTION: ", $collection->name, "\n";
                print $_->toString, "\n" for sort {$a->dbID <=> $b->dbID} @{$collection->genome_dbs};
                print "=", $collection->size, " genomes\n";
            }
            unless ($dry_run) {
                $compara_dba->get_SpeciesSetAdaptor->store($collection);
                $compara_dba->get_SpeciesSetAdaptor->make_object_current($collection) if $release && !$collection->{_no_release};
            }
            if ($verbose) {
                print "AFTER STORING: ", $collection->toString, "\n\n";
            }
        }

        print "2. MethodLinkSpeciesSets that need to be created:\n" if $verbose;
        foreach my $mlss (@mlsss) {
            # Check if it is already in the database
            my $exist_mlss = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs($mlss->method->type, $mlss->species_set->genome_dbs);
            # Special case for LastZ alignments: we still have some equivalent BlastZ alignments
            if (!$exist_mlss and ($mlss->method->type eq 'LASTZ_NET')) {
                # allow for cases where BLASTZ_NET is not in the method_link table - this is the case for EG
                $exist_mlss = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs('BLASTZ_NET', $mlss->species_set->genome_dbs) if ($compara_dba->get_MethodAdaptor->fetch_by_type('BLASTZ_NET'));
            }
            if (!$exist_mlss) {
                # Check if either the method or the species_set are already in the database
                my $exist_method = $method_adaptor->fetch_by_type($mlss->method->type);
                $mlss->method($exist_method) if $exist_method;
                my $exist_ss = $ss_adaptor->fetch_by_GenomeDBs($mlss->species_set->genome_dbs);
                $mlss->species_set($exist_ss) if $exist_ss;
            }
            if ($exist_mlss and !$dry_run) {
                # Update the names if they differ
                if ($exist_mlss->name ne $mlss->name) {
                    $compara_dba->dbc->do('UPDATE method_link_species_set SET name = ? WHERE method_link_species_set_id = ?', undef, $mlss->name, $exist_mlss->dbID);
                }
                if ($exist_mlss->species_set->name ne $mlss->species_set->name) {
                    $compara_dba->dbc->do('UPDATE species_set_header SET name = ? WHERE species_set_id = ?', undef, $mlss->species_set->name, $exist_mlss->species_set->dbID);
                }

                # handle re-release : when an object was retired, but is being made current again.
                # if we don't set this, it gets set to current release value and history is lost.
                $mlss->first_release($exist_mlss->first_release);
                $mlss->species_set->first_release($exist_mlss->species_set->first_release);
            }
            if ($exist_mlss and ($exist_mlss->is_current || $mlss->{_no_release})) {
                push @mlsss_existing, $exist_mlss;
                delete $mlss_ids_to_find{$exist_mlss->dbID};
                next;
            }
            if ($verbose) {
                print "\nMLSS: ", $mlss->name, "\n";
                print "METHOD: ", $mlss->method->type, "\n";
                print "SS: ", $mlss->species_set->name, "(", $mlss->species_set->size, ")\n";
                print $_->toString, "\n" for sort {$a->dbID <=> $b->dbID} @{$mlss->species_set->genome_dbs};
            }
            # Special case for syntenies: when the synteny has already been tried and failed (due to low coverage), we don't need to try again
            if (!$exist_mlss and ($mlss->method->type eq 'SYNTENY')) {
                my $lastz_mlss = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs('LASTZ_NET', $mlss->species_set->genome_dbs);
                if ($lastz_mlss and $lastz_mlss->has_tag('low_synteny_coverage')) {
                    print "DISCARDED (low_synteny_coverage)\n" if $verbose;
                    next;
                }
            }
            push @mlsss_created, $mlss;
            unless ($dry_run) {
                $mlss_adaptor->store($mlss);
                push @mlsss_retired, @{$mlss_adaptor->make_object_current($mlss)} if $release && !$mlss->{_no_release};
            }
            if ($verbose) {
                print "NEW MLSS:", $mlss->toString, "\n";
            }
        }

        if ($retire_unmatched) {
            print "\n";
            foreach my $mlss (sort {$a->dbID <=> $b->dbID} values %mlss_ids_to_find) {
                push @mlsss_retired, $mlss;
                unless ($dry_run) {
                    $mlss_adaptor->retire_object($mlss);
                }
                if ($verbose) {
                    print "UNJUSTIFIED MLSS: ", $mlss->toString, "\n";
                }
            }
        }
    } );


my $current_version = software_version();
my %methods_not_worth_reporting = map {$_ => 1} qw(SYNTENY ENSEMBL_ORTHOLOGUES ENSEMBL_PARALOGUES ENSEMBL_HOMOEOLOGUES ENSEMBL_PROJECTIONS CACTUS_HAL_PW GERP_CONSTRAINED_ELEMENT GERP_CONSERVATION_SCORE);

sub mlss2hash {
    my $self = shift;
    my $res = {
        db_id            => $self->dbID,
        name             => ($self->name ? $self->name : '(unnamed)'),
        method_type      => $self->method->type,
        species_set_name => $self->species_set->name,
        species_set_id   => $self->species_set->dbID
    };
    if ($self->{'url'}) {
        $res->{url} = $self->{'url'};
    }
    return $res;
}

my $mlss_ids_fh;
if ($output_file) {
    open($mlss_ids_fh, '>', $output_file) or die "Cannot open file '$output_file'\n";
} else {
    $mlss_ids_fh = \*STDOUT;
}

my $mlss_summary;

$mlss_summary .= "\nWhat has ".($dry_run ? '(not) ' : '')."been created ?\n-----------------------".($dry_run ? '------' : '')."\n";
my $n = 0;
my $summary_created = [];
foreach my $mlss (@mlsss_created) {
    push @$summary_created, mlss2hash($mlss);
    unless ($methods_not_worth_reporting{$mlss->method->type}) {
        $mlss_summary .= $mlss->toString ."\n";
    } else {
        $n++
    }
}
$mlss_summary .= "(and $n derived MLSS".($n > 1 ? 's' : '').")\n" if $n;

$mlss_summary .= "\nWhat has ".($dry_run ? '(not) ' : '')."been retired ?\n-----------------------".($dry_run ? '------' : '')."\n";
my $summary_retired = [];
$n = 0;
foreach my $mlss (@mlsss_retired) {
    push @$summary_retired, mlss2hash($mlss);
    unless ($methods_not_worth_reporting{$mlss->method->type}) {
        $mlss_summary .= $mlss->toString . "\n";
    } else {
        $n++
    }
}
$mlss_summary .= "(and $n derived MLSS".($n > 1 ? 's' : '').")\n" if $n;

$mlss_summary .= "\nWhat else is new in e$current_version ?\n-------------------------\n";
my $summary_existing = [];
$n = 0;
foreach my $mlss (@mlsss_existing) {
    next if !$mlss->first_release || $mlss->first_release != $current_version;
    push @$summary_existing, mlss2hash($mlss);
    unless ($methods_not_worth_reporting{$mlss->method->type}) {
        $mlss_summary .= $mlss->toString . "\n";
    } else {
        $n++
    }
}
$mlss_summary .= "(and $n derived MLSS".($n > 1 ? 's' : '').")\n" if $n;

my $out = [ {"mlss_summary" => $mlss_summary},
            {"created" => $summary_created, "retired" => $summary_retired, "existing" => $summary_existing}
          ];

my $json = JSON->new->utf8;
my $encoded = $json->pretty->encode( $out );
print $mlss_ids_fh $encoded;
