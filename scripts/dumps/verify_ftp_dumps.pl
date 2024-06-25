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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use File::Spec::Functions;
use Getopt::Long;

my ( $help, $reg_conf, $compara_db, $ftp_root, $release, $eg_release, $division );
GetOptions(
    "help"         => \$help,
    "reg_conf=s"   => \$reg_conf,
    "compara_db=s" => \$compara_db,
    "ftp_root=s"   => \$ftp_root,
    "release=i"    => \$release,
    "eg_release=i" => \$eg_release,
    "division=s"   => \$division,
);

$reg_conf = $ENV{COMPARA_REG_PATH} unless $reg_conf;
$release  = $ENV{CURR_ENSEMBL_RELEASE} unless $release;
$eg_release = $ENV{CURR_EG_RELEASE} unless $eg_release;
$division = $ENV{COMPARA_DIV} unless $division;

if (! $ftp_root) {
    if ($division eq 'vertebrates') {
        $ftp_root = $ENV{ENSEMBL_FTP} . "/release-$release/";
    } else {
        $ftp_root = $ENV{ENSEMBL_FTP} . "/release-$eg_release/$division";
        $ftp_root .= '_ensembl' if ($division =~ /^pan($|[^a-z])/);
    }
}

die &helptext if ( $help || !($reg_conf && $compara_db && $division) );
die "FTP root '$ftp_root' does not exist\n" unless -e $ftp_root;

my %glob_exp_per_mlss = (
	LASTZ_NET                => 'maf/ensembl-compara/pairwise_alignments/#mlss_filename#*.tar*',
	EPO                      => 'maf/ensembl-compara/multiple_alignments/#mlss_filename#/*',
	EPO_EXTENDED             => 'maf/ensembl-compara/multiple_alignments/#mlss_filename#/*',
	PECAN                    => 'maf/ensembl-compara/multiple_alignments/#mlss_filename#/*',
	GERP_CONSTRAINED_ELEMENT => 'bed/ensembl-compara/#mlss_filename#/*',
	GERP_CONSERVATION_SCORE  => 'compara/conservation_scores/#mlss_filename#/*',
    PROTEIN_TREES            => "xml/ensembl-compara/homologies/Compara.$release.protein_#clusterset_id#.alltrees.orthoxml.xml.gz",
    NC_TREES                 => "xml/ensembl-compara/homologies/Compara.$release.ncrna_#clusterset_id#.alltrees.orthoxml.xml.gz",
    ENSEMBL_ORTHOLOGUES      => 'tsv/ensembl-compara/homologies/#species_name#/*.tsv.gz tsv/ensembl-compara/homologies/*_collection/#species_name#/*.tsv.gz',
    ENSEMBL_PARALOGUES       => 'tsv/ensembl-compara/homologies/#species_name#/*.tsv.gz tsv/ensembl-compara/homologies/*_collection/#species_name#/*.tsv.gz',
    SPECIES_TREE             => 'compara/species_trees/*.nh',
    CACTUS_HAL               => 'compara/species_trees/*.nh',
    CACTUS_DB                => 'compara/species_trees/*.nh',
);

# Prepend ftp_root to each segment of the glob expression
while (my ($method_type, $glob_exp) = each %glob_exp_per_mlss) {
    $glob_exp_per_mlss{$method_type} = join(' ', map { catfile($ftp_root, $_) } split(/\s+/, $glob_exp));
}

# Get every dumped file present in the ftp_root
my %existing_files;
foreach my $glob_exp (values %glob_exp_per_mlss) {
    $glob_exp =~ s/#\w+#\*?/*/g;
    $existing_files{$_} = 1 foreach glob $glob_exp;
}

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;
my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db );
my $mlsses = $dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_current;

# Remove from the list of existing files those corresponding to each current MLSS
foreach my $mlss ( @$mlsses ) {
    my $glob_exp_for_type = $glob_exp_per_mlss{$mlss->method->type};
    next unless defined $glob_exp_for_type;
    
    if ( $glob_exp_for_type =~ /#mlss_filename#/ ) {
        my $mlss_filename = $mlss->filename;
        $glob_exp_for_type =~ s/#mlss_filename#/$mlss_filename/ig;
        my @files = glob $glob_exp_for_type;
        if ( (!defined $files[0] || !-e $files[0]) && $mlss->method->type eq 'LASTZ_NET' ) {
            # try different order of species
            my $orig_mlss_filename = $mlss_filename;
            $mlss_filename =~ /(.+)\.v\.(.+)\.lastz_net/;
            $mlss_filename = "$2.v.$1.lastz_net";
            $glob_exp_for_type =~ s/$orig_mlss_filename/$mlss_filename/g;
            @files = glob $glob_exp_for_type;
        }
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $glob_exp_for_type" unless scalar(@files) && -e $files[0];
        delete @existing_files{@files};
    } elsif ( $glob_exp_for_type =~ /#collection_name#/ ) {
        my $collection_name = $mlss->species_set->name;
        $collection_name =~ s/collection-//;
        $glob_exp_for_type =~ s/#collection_name#/$collection_name/g;
        my @files = glob $glob_exp_for_type;
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $glob_exp_for_type" unless scalar(@files) && -e $files[0];
        delete @existing_files{@files};
    } elsif ( $glob_exp_for_type =~ /#clusterset_id#/ ) {
        my $clusterset_id = 'default';
        if ( $division eq 'vertebrates' ) {
            my $collection_name = $mlss->species_set->name;
            $collection_name =~ s/collection-//;
            $clusterset_id = $collection_name;
        }
        $glob_exp_for_type =~ s/#clusterset_id#/$clusterset_id/g;
        my @files = glob $glob_exp_for_type;
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $glob_exp_for_type" unless scalar(@files) && -e $files[0];
        delete @existing_files{@files};
    } elsif ( $glob_exp_for_type =~ /#species_name#/ ) {
        foreach my $gdb ( @{ $mlss->species_set->genome_dbs } ) {
            my $this_species_glob_exp_for_type = $glob_exp_for_type;
            my $this_species_name = $gdb->name;
            $this_species_glob_exp_for_type =~ s/#species_name#/$this_species_name/g;
            my @files = glob $this_species_glob_exp_for_type;
            unless (scalar(@files) && -e $files[0]) {
                # Try with a collection
                my $this_collection_species_glob_exp_for_type = $glob_exp_for_type;
                $this_collection_species_glob_exp_for_type =~ s/#species_name#/*_collection\/$this_species_name/g;
                @files = glob $this_collection_species_glob_exp_for_type;
                die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $this_collection_species_glob_exp_for_type" unless scalar(@files) && -e $files[0];
            }
            delete @existing_files{@files};
        }
    } else {
        my @files = glob $glob_exp_for_type;
        die "Could not find file for MethodLinkSpeciesSet dbID " . $mlss->dbID . " (" . $mlss->name . "): $glob_exp_for_type" unless scalar(@files) && -e $files[0];
        delete @existing_files{@files};
    }
}

if (scalar(keys %existing_files)) {
    die "Some FTP dump files do not belong to any MethodLinkSpeciesSet:\n" . join("\n", keys %existing_files), "\n\n";
}

print "All MethodLinkSpeciesSets found in FTP\n\n";

sub helptext {
	my $msg = <<HELPEND;

Usage: perl verify_ftp_dumps.pl --compara_db <alias or url> [--reg_conf <registry config> --division <division> --release <release number> --eg_release <eg release number> --ftp_root <path to FTP root>]

HELPEND
	return $msg;
}
