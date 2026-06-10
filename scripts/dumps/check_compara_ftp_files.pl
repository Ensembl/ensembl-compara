#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

check_compara_ftp_files.pl

=head1 DESCRIPTION

Check Compara FTP dump files and report any issues.

=head1 EXAMPLES

    $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/dumps/check_compara_ftp_files.pl \
        -reg_conf $COMPARA_REG_PATH -dump_dir /path/to/ftp_dumps -outfile issues.tsv

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--reg_conf PATH]>

Compara FTP dump pipeline registry config file.
Mutually exclusive with '--pipeline_url'.

=item B<[--pipeline_url STR]>

Compara FTP dump pipeline URL. If this option is specified, the dump registry is
fetched from the Compara FTP dump pipeline. Mutually exclusive with '--reg_conf'.

=item B<[--compara_db STR]>

Compara database.

=item B<[--division STR]>

Division name. By default, this is obtained from the Compara database.

=item B<[--release INT]>

Ensembl release. By default, this is obtained from the Ensembl software version.

=item B<[--dump_dir PATH]>

Directory under which Compara flat files have been dumped.

=item B<[--outfile PATH]>

Output TSV file listing issues with the given Compara FTP dump files.

If there are no issues, no file is output.

=item B<[--follow_symlinks]>

Flag indicating if symlinks should be checked.

This is typically recommended only after files
have been placed in their final location.

=item B<[--include_mysql]>

Flag indicating if MySQL database dumps should be checked.

This option is not recommended prior to MySQL database dumps.

=back

=cut


use strict;
use warnings;

use Array::Utils qw(array_minus intersect);
use Cwd qw(getcwd);
use File::Spec::Functions qw(catdir catfile file_name_is_absolute splitpath);
use File::Temp qw(tempfile);
use Getopt::Long;
use List::Util qw(all);
use Net::FTP;
use Pod::Usage;
use Text::CSV;

use File::Temp qw(tempfile);
use File::Spec::Functions qw(catdir catfile file_name_is_absolute splitpath);

use Bio::EnsEMBL::ApiVersion qw(software_version);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::RunCommand;
use Bio::EnsEMBL::Compara::Utils::Test;
use Bio::EnsEMBL::Hive::Utils qw(go_figure_dbc);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::IO qw(spurt);


my $PAN_REDUB_RELEASE = 114;
my $PER_GDB_HOM_TSV_META_RELEASE = 116;
my $SPECIES_TREE_LABEL_FIX_RELEASE = 112;

my %ftp_path_prefix_map = (
    'CONSTRAINED_ELEMENT' => {
        'bb' => 'bed/ensembl-compara',
    },
    'CONSERVATION_SCORE' => {
        'bw' => 'compara/conservation_scores',
    },
    'HMM_LIBRARY' => {
        'hmm' => 'compara',
    },
    'SPECIES_TREE' => {
        'nh' => 'compara/species_trees',
    },
    'ANCESTRAL_ALLELES' => {
        'fasta' => 'fasta/ancestral_alleles',
    },
    'HOMOLOGIES' => {
        'emf' => 'emf/ensembl-compara/homologies',
        'tsv' => 'tsv/ensembl-compara/homologies',
        'xml' => 'xml/ensembl-compara/homologies',
    },
    'MSA' => {
        'emf' => 'emf/ensembl-compara/multiple_alignments',
        'maf' => 'maf/ensembl-compara/multiple_alignments',
    },
    'LASTZ_NET' => {
        'maf' => 'maf/ensembl-compara/pairwise_alignments',
    },
    'TRANSLATED_BLAT_NET' => {
        'maf' => 'maf/ensembl-compara/pairwise_alignments',
    },
    'DB' => {
        'mysql' => 'mysql',
    }
);


sub ftp_is_dir {
    # Check if the specified path on the given FTP host is a directory.
    my ($ftp, $path) = @_;

    # We want to check if the path refers to a directory using the
    # 'cwd' method, but without actually changing the directory. So
    # we store the $pwd and change back to it as soon as we're done.
    my $pwd = $ftp->pwd();
    my $is_dir = $ftp->cwd($path);
    $ftp->cwd($pwd);

    return $is_dir ? 1 : 0;
}


sub ftp_listdir {
    # List items at the specified path on the given FTP host.
    my ($ftp, $path) = @_;

    my $pwd = $ftp->pwd();
    my $is_dir = $ftp->cwd($path);
    my $items;

    if ($is_dir) {
        $items = $ftp->ls();
    }

    $ftp->cwd($pwd);

    if (!$is_dir) {
        throw(
            sprintf(
                "cannot obtain FTP directory listing; path '%s' on host '%s' is not a directory",
                $path,
                $ftp->host,
            )
        );
    }

    return $items;
}


sub ftp_path_url {
    # Return HTTPS URL for the given FTP host and path.
    my ($ftp, $path) = @_;
    return sprintf('https://%s/%s', $ftp->host, $path);
}


sub get_compara_schema_table_names {
    my ($release) = @_;

    my ($fh, $compara_schema_file) = tempfile(UNLINK => 1);
    my $url = "https://raw.githubusercontent.com/Ensembl/ensembl-compara/release/${release}/sql/table.sql";
    my $cmd = ['wget', $url, '--quiet', '--output-document', $compara_schema_file];
    Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, { die_on_failure => 1 });
    my $compara_schema_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls($compara_schema_file);
    close($fh);

    my @exp_compara_table_names;
    foreach my $entry (@{$compara_schema_statements}) {
        my ($title, $sql) = @{$entry};
        if ($title =~ /^CREATE TABLE (?:IF NOT EXISTS )?(`)?(?<table_name>.+)(?(1)\g1|)$/) {
            push(@exp_compara_table_names, $+{table_name});
        }
    }

    return \@exp_compara_table_names;
}


sub get_ftp_site_info {
    my ($compara_division, $ensembl_release) = @_;

    my $ftp_host_name;
    my $ftp_base_path;
    if ($compara_division eq 'vertebrates') {

        $ftp_host_name = 'ftp.ensembl.org';
        $ftp_base_path = "pub/release-${ensembl_release}";

    } else {

        my $div_path_part = $compara_division eq 'pan' && $ensembl_release < $PAN_REDUB_RELEASE
                          ? 'pan_ensembl'
                          : $compara_division
                          ;

        my $eg_release = $ensembl_release - 53;

        $ftp_host_name = 'ftp.ensemblgenomes.ebi.ac.uk';
        $ftp_base_path = "pub/release-${eg_release}/${div_path_part}"
    }

    return {
        'host' => $ftp_host_name,
        'base_path' => $ftp_base_path,
    }
}


sub get_msa_part_names {
    my ($mlss) = @_;

    my $mlss_dba = $mlss->adaptor;
    my $helper = $mlss_dba->dbc->sql_helper;
    my $genome_dba = $mlss_dba->db->get_GenomeDBAdaptor();
    my $dnafrag_dba = $mlss_dba->db->get_DnaFragAdaptor();

    my %default_dump_ref_genomes = (
        'amniotes' => 'homo_sapiens',
        'fish' => 'oryzias_latipes',
        'mammals' => 'homo_sapiens',
        'murinae' => 'mus_musculus',
        'pig_breeds' => 'sus_scrofa',
        'primates' => 'homo_sapiens',
        'rice' => 'oryza_sativa',
        'sauropsids' => 'gallus_gallus',
    );

    my $unprefixed_ss_name = $mlss->species_set->name =~ s/^collection-//r;
    my $default_dump_ref_genome = $default_dump_ref_genomes{$unprefixed_ss_name};
    my $dump_ref_genome = $mlss->get_value_for_tag('dump_reference_species', $default_dump_ref_genome);

    my $ref_gdb = $genome_dba->fetch_by_name_assembly($dump_ref_genome);

    my $karyo_dnafrags = $dnafrag_dba->fetch_all_karyotype_DnaFrags_by_GenomeDB($ref_gdb);
    my $non_ref_dnafrags = $dnafrag_dba->fetch_all_by_GenomeDB($ref_gdb, -IS_REFERENCE => 0);
    my %chrom_dnafrag_id_set = map { $_->dbID => 1 } (@{$karyo_dnafrags}, @{$non_ref_dnafrags});

    my $ref_df_sql = q/
        SELECT DISTINCT
            dnafrag_id,
            name,
            coord_system_name
        FROM
            genomic_align
        JOIN
            dnafrag USING (dnafrag_id)
        WHERE
           method_link_species_set_id = ?
        AND
           genome_db_id = ?
    /;

    my $ref_df_results = $helper->execute(
        -SQL => $ref_df_sql,
        -USE_HASHREFS => 1,
        -PARAMS => [$mlss->dbID, $ref_gdb->dbID]
    );

    my @chrom_dnafrag_names;
    my %coord_system_name_set;
    foreach my $row (@{$ref_df_results}) {
        if (exists $chrom_dnafrag_id_set{$row->{'dnafrag_id'}}) {
            push(@chrom_dnafrag_names, $row->{'name'});
        } else {
            $coord_system_name_set{$row->{'coord_system_name'}} = 1;
        }
    }

    # As well as dnafrag-level and coordinate-system
    # files, we assume there will be an 'other' file.
    my @msa_part_names = (@chrom_dnafrag_names, keys %coord_system_name_set, 'other');

    return \@msa_part_names;
}


sub load_registry_from_dump_pipeline {
    my ($pipeline_url) = @_;

    my $registry_sql = q/
        SELECT
            msg
        FROM
            msg
        WHERE
            logic_name = 'final_registry_backup'
        AND
            message_class = 'INFO'
    /;

    my $pipeline_dbc = go_figure_dbc($pipeline_url);
    my $messages = $pipeline_dbc->sql_helper->execute_simple( -SQL => $registry_sql );

    my $dump_reg_conf_text;
    if (scalar(@$messages) == 1) {
        $dump_reg_conf_text = $messages->[0];
    } else {
        throw("failed to load dump registry from pipeline [$pipeline_url]; multiple final_registry_backup log entries found");
    }

    my ($fh, $dump_reg_conf_file) = tempfile(UNLINK => 1);
    spurt($dump_reg_conf_file, $dump_reg_conf_text);
    Bio::EnsEMBL::Registry->load_all($dump_reg_conf_file, 0, 0, 0, 'throw_if_missing');
}


my ( $help, $reg_conf, $pipeline_url, $division, $release, $dump_dir, $outfile );
my $compara_db = 'compara_curr';
my $follow_symlinks = 0;
my $include_mysql = 0;
GetOptions(
    'help|?'          => \$help,
    'reg_conf=s'      => \$reg_conf,
    'pipeline_url=s'  => \$pipeline_url,
    'compara_db=s'    => \$compara_db,
    'division=s'      => \$division,
    'release=i'       => \$release,
    'dump_dir=s'      => \$dump_dir,
    'outfile=s'       => \$outfile,
    'follow_symlinks' => \$follow_symlinks,
    'include_mysql'   => \$include_mysql,
) or pod2usage(-verbose => 2);

pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$outfile;


if ($pipeline_url && $reg_conf) {
    throw("only one of parameters 'pipeline_url' or 'reg_conf' can be specified");
} elsif ($pipeline_url) {
    load_registry_from_dump_pipeline($pipeline_url);
} elsif ($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing');
} else {
    throw("one of parameters 'pipeline_url' or 'reg_conf' must be specified");
}

my %registry_name_set = map { $_ => 1 } @{Bio::EnsEMBL::Registry->get_all_species()};

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($compara_db);

if (!defined $division) {
    $division = $compara_dba->get_division();
}

if (!defined $release) {
    $release = software_version();
}

my $mlss_dba = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $helper = $compara_dba->dbc->sql_helper;

print STDERR "Checking for FTP dump expectations from database '$compara_db' ... \n";

my %expectations;

print STDERR "Checking for CONSTRAINED_ELEMENT expectations ... \n";

my $const_elem_mlsses = $mlss_dba->fetch_all_by_method_link_type('GERP_CONSTRAINED_ELEMENT');
foreach my $mlss (@{$const_elem_mlsses}) {

    my @bigbed_file_names;
    foreach my $gdb (@{$mlss->species_set->genome_dbs}) {
        my $bigbed_file_name = sprintf('gerp_constrained_elements.%s.bb', $gdb->name);
        push(@bigbed_file_names, $bigbed_file_name);
    }

    push(@{$expectations{'CONSTRAINED_ELEMENT'}{'bb'}}, {
        'dir_path' => $mlss->_get_unique_filename(),
        'meta_file_names' => ['MD5SUM', 'README'],
        'data_file_names' => \@bigbed_file_names,
    });
}

print STDERR "Checking for CONSERVATION_SCORE expectations ... \n";

my $cons_score_mlsses = $mlss_dba->fetch_all_by_method_link_type('GERP_CONSERVATION_SCORE');
foreach my $mlss (@{$cons_score_mlsses}) {

    my @bigwig_file_names;
    foreach my $gdb (@{$mlss->species_set->genome_dbs}) {
        my $bigwig_file_name = sprintf('gerp_conservation_scores.%s.%s.bw', $gdb->name, $gdb->assembly);
        push(@bigwig_file_names, $bigwig_file_name);
    }

    push(@{$expectations{'CONSERVATION_SCORE'}{'bw'}}, {
        'dir_path' => $mlss->_get_unique_filename(),
        'meta_file_names' => ['MD5SUM', 'README'],
        'data_file_names' => \@bigwig_file_names,
    });
}

print STDERR "Checking for SPECIES_TREE expectations ... \n";

my $species_tree_label = $release >= $SPECIES_TREE_LABEL_FIX_RELEASE
                       ? q/REPLACE(label, ' ', '_')/
                       : q/label/
                       ;

my $species_tree_sql = qq/
    SELECT
        CONCAT(
            CONCAT_WS(
                '_',
                REPLACE(name, ' ', '_'),
                $species_tree_label
            ),
            '.nh'
        ) AS species_tree_file_name
    FROM
        species_tree_root
    JOIN
        method_link_species_set
    USING
        (method_link_species_set_id)
/;

my $species_tree_file_names = $helper->execute_simple( -SQL => $species_tree_sql );

if (@{$species_tree_file_names}) {
    push(@{$expectations{'SPECIES_TREE'}{'nh'}}, {
        'data_file_names' => $species_tree_file_names,
    });
}

print STDERR "Checking for ANCESTRAL_ALLELES expectations ... \n";

if ($division eq 'vertebrates') {
    my $primates_epo_mlss = $mlss_dba->fetch_by_method_link_type_species_set_name('EPO', 'primates');
    my $gdbs = $primates_epo_mlss->species_set->genome_dbs;

    my @anc_allele_file_names;
    foreach my $gdb (@{$gdbs}) {
        my $anc_allele_file_name = sprintf('%s_ancestor_%s.tar.gz', $gdb->name, $gdb->assembly);
        push(@anc_allele_file_names, $anc_allele_file_name);
    }

    push(@{$expectations{'ANCESTRAL_ALLELES'}{'fasta'}}, {
        'meta_file_names' => ['MD5SUM'],
        'data_file_names' => \@anc_allele_file_names,
    });
}

print STDERR "Checking for HOMOLOGIES expectations ... \n";

my @common_xml_suffixes = (
    '.allhomologies.orthoxml.xml.gz',
    '.allhomologies_strict.orthoxml.xml.gz',
    '.alltrees.orthoxml.xml.gz',
    '.tree.orthoxml.xml.tar',
    '.tree.phyloxml.xml.tar',
);

my %emf_suffixes_by_member_type = (
    'ncrna' => [
        '.aln.emf.gz',
        '.nh.emf.gz',
        '.nhx.emf.gz',
        '.nt.fasta.gz'
    ],

    'protein' => [
        '.aa.fasta.gz',
        '.aln.emf.gz',
        '.cds.fasta.gz',
        '.nh.emf.gz',
        '.nhx.emf.gz'
    ],
);

my $clusterset_sql = q/
    SELECT DISTINCT method_link_species_set_id, clusterset_id, member_type
    FROM gene_tree_root
    WHERE tree_type = 'tree'
    AND ref_root_id IS NULL
/;

my $clusterset_results = $helper->execute( -SQL => $clusterset_sql );

my @hom_emf_file_names;
my @hom_tsv_file_names;
my @hom_tsv_file_paths;
my @hom_tsv_meta_file_paths;
my @hom_xml_file_names;
foreach my $row (@{$clusterset_results}) {
    my ($mlss_id, $clusterset_id, $member_type) = @{$row};

    my $hom_file_prefix = sprintf('Compara.%d.%s_%s', $release, $member_type, $clusterset_id);
    my $mlss = $mlss_dba->fetch_by_dbID($mlss_id);

    my @emf_suffixes = @{$emf_suffixes_by_member_type{$member_type}};
    foreach my $emf_suffix (@emf_suffixes) {
        push(@hom_emf_file_names, $hom_file_prefix . $emf_suffix);
    }

    # Homology TSV file concatenated per gene-tree collection.
    my $hom_tsv_file_name = $hom_file_prefix . '.homologies.tsv.gz';
    push(@hom_tsv_file_names, $hom_tsv_file_name);

    foreach my $gdb (@{$mlss->species_set->genome_dbs}) {
        my $gdb_name = $gdb->name;

        my $genome_rel_path;
        if (exists $registry_name_set{$gdb_name}) {
            $genome_rel_path = $gdb->_get_ftp_dump_relative_path();
        } else {
            print STDERR "GenomeDB '$gdb_name' missing from registry; taking GenomeDB name as path ... \n";
            $genome_rel_path = $gdb_name;
        }

        # Homology TSV file concatenated per genome.
        my $hom_tsv_file_path = $genome_rel_path . '/' . $hom_tsv_file_name;
        push(@hom_tsv_file_paths, $hom_tsv_file_path);

        next if $release < $PER_GDB_HOM_TSV_META_RELEASE;
        my $hom_tsv_md5sum_file_path = $genome_rel_path . '/' . 'MD5SUM';
        my $hom_tsv_readme_file_path = $genome_rel_path . '/' . 'README.gene_trees.tsv_dumps.txt';
        push(@hom_tsv_meta_file_paths, ($hom_tsv_md5sum_file_path, $hom_tsv_readme_file_path));
    }

    my $mlss_has_cafe = $mlss->get_value_for_tag('has_cafe', 0);
    my @xml_suffixes = @common_xml_suffixes;
    push(@xml_suffixes, '.tree.cafe_phyloxml.xml.tar') if $mlss_has_cafe;
    foreach my $xml_suffix (@xml_suffixes) {
        push(@hom_xml_file_names, $hom_file_prefix . $xml_suffix);
    }
}

if (@hom_emf_file_names) {
    push(@{$expectations{'HOMOLOGIES'}{'emf'}}, {
        'meta_file_names' => ['MD5SUM', 'README.gene_trees.emf_dumps.txt'],
        'data_file_names' => \@hom_emf_file_names,
    });
}

if (@hom_tsv_file_names || @hom_tsv_file_paths) {
    push(@{$expectations{'HOMOLOGIES'}{'tsv'}}, {
        'meta_file_names' => ['MD5SUM', 'README.gene_trees.tsv_dumps.txt'],
        'meta_file_paths' => \@hom_tsv_meta_file_paths,
        'data_file_names' => \@hom_tsv_file_names,
        'data_file_paths' => \@hom_tsv_file_paths,
    });
}

if (@hom_xml_file_names) {
    push(@{$expectations{'HOMOLOGIES'}{'xml'}}, {
        'meta_file_names' => ['MD5SUM', 'README.gene_trees.xml_dumps.txt'],
        'data_file_names' => \@hom_xml_file_names,
    });
}

print STDERR "Checking for HMM_LIBRARY expectations ... \n";

if (@hom_emf_file_names) {
    push(@{$expectations{'HMM_LIBRARY'}{'hmm'}}, {
        'data_file_patterns' => ['multi_division_hmm_lib(?:\.[0-9]{4,}-[0-9]{2}-[0-9]{2})?\.tar\.gz'],
    });
}

print STDERR "Checking for MSA expectations ... \n";

my $msa_mlsses;
foreach my $method_type ('EPO', 'EPO_EXTENDED', 'PECAN') {
    foreach my $mlss (@{$mlss_dba->fetch_all_by_method_link_type($method_type)}) {
        my $msa_part_names = get_msa_part_names($mlss);
        my $mlss_filename = $mlss->_get_unique_filename();

        foreach my $format ('emf', 'maf') {
            my @file_patterns;
            my %file_affixes;
            foreach my $msa_part_name (@{$msa_part_names}) {
                my $file_pattern = "${mlss_filename}\.${msa_part_name}_(?<serial_number>[0-9]+)\.${format}\.gz";
                my $file_affix_pair = ["${mlss_filename}.${msa_part_name}_", ".${format}.gz"];
                $file_affixes{$file_pattern} = $file_affix_pair;
                push(@file_patterns, $file_pattern);
            }

            push(@{$expectations{'MSA'}{$format}}, {
                'dir_path' => $mlss_filename,
                'meta_file_names' => ['MD5SUM', "README.${format}", "README.$mlss_filename"],
                'data_file_patterns' => \@file_patterns,
                'data_file_affixes' => \%file_affixes,
            });
        }
    }
}

print STDERR "Checking for LASTZ_NET expectations ... \n";

my @lastz_file_names;
foreach my $mlss (@{$mlss_dba->fetch_all_by_method_link_type('LASTZ_NET')}) {
    push(@lastz_file_names, $mlss->_get_unique_filename() . '.tar.gz');
}

if (@lastz_file_names) {
    push(@{$expectations{'LASTZ_NET'}{'maf'}}, {
        'data_file_names' => \@lastz_file_names,
    });
}

print STDERR "Checking for TRANSLATED_BLAT_NET expectations ... \n";

my @tblat_net_file_names;
foreach my $mlss (@{$mlss_dba->fetch_all_by_method_link_type('TRANSLATED_BLAT_NET')}) {
    push(@tblat_net_file_names, $mlss->_get_unique_filename() . '.tar.gz');
}

if (@tblat_net_file_names) {
    push(@{$expectations{'TRANSLATED_BLAT_NET'}{'maf'}}, {
        'data_file_names' => \@tblat_net_file_names,
    });
}


if ($include_mysql) {
    print STDERR "Checking for DB expectations ... \n";

    my $mysql_table_names = get_compara_schema_table_names($release);
    my $compara_db_name = $compara_dba->dbc->dbname;

    my @mysql_dump_file_paths = ("${compara_db_name}.sql.gz");
    foreach my $table_name (@{$mysql_table_names}) {
        push(@mysql_dump_file_paths, "${table_name}.txt.gz");
    }

    if (@mysql_dump_file_paths) {
        push(@{$expectations{'DB'}{'mysql'}}, {
            'dir_path' => $compara_db_name,
            'data_file_names' => \@mysql_dump_file_paths,
        });
    }
}

my $ftp;
my $ftp_base_path;
if ($dump_dir) {

    print STDERR "Checking Ensembl FTP dump directory ... \n";
    if (! -d $dump_dir) {
        throw(sprintf("cannot access Ensembl FTP dump directory at '%s'", $dump_dir));
    }

} else {
    my $ftp_info = get_ftp_site_info($division, $release);
    $ftp_base_path = $ftp_info->{'base_path'};
    $ftp = Net::FTP->new($ftp_info->{'host'}) or throw("Failed to connect to FTP host: $@");
    $ftp->login;

    print STDERR "Checking Ensembl FTP site; symlink checks will be skipped ... \n";
    if (!ftp_is_dir($ftp, $ftp_base_path)) {
        throw(sprintf("cannot access Ensembl FTP site at '%s'", ftp_path_url($ftp, $ftp_base_path)));
    }
}

my %issues;
foreach my $data_type (sort keys %expectations) {

    print STDERR "Checking observed vs expected $data_type ... \n";

    foreach my $format (sort keys %{$expectations{$data_type}}) {
        next if $data_type eq 'ANCESTRAL_ALLELES' && $division ne 'vertebrates';
        next if !$include_mysql && $format eq 'mysql';

        my $path_prefix = $ftp_path_prefix_map{$data_type}{$format};
        my $data_path;
        if ($ftp) {
            $data_path = $ftp_base_path . '/' . $path_prefix;
            if (!ftp_is_dir($ftp, $data_path)) {
                push(@{$issues{'missing directory'}}, $data_path);
                next;
            }

        } else {
            $data_path = catdir($dump_dir, $path_prefix);
            if (! -d $data_path) {
                push(@{$issues{'missing directory'}}, $data_path);
                next;
            }
        }

        foreach my $dset_expectations (@{$expectations{$data_type}{$format}}) {

            my $dset_data_path = $data_path;
            if (exists $dset_expectations->{'dir_path'}) {
                if ($ftp) {
                    $dset_data_path = $dset_data_path . '/' . $dset_expectations->{'dir_path'};
                    if (!ftp_is_dir($ftp, $dset_data_path)) {
                        push(@{$issues{'missing directory'}}, $dset_data_path);
                        next;
                    }
                } else {
                    $dset_data_path = catdir($dset_data_path, $dset_expectations->{'dir_path'});
                    if (! -d $dset_data_path) {
                        push(@{$issues{'missing directory'}}, $dset_data_path);
                        next;
                    }
                }
            }

            my @exp_file_names;
            foreach my $file_set ('meta_file_names', 'data_file_names') {
                if (exists $dset_expectations->{$file_set}) {
                    push(@exp_file_names, @{$dset_expectations->{$file_set}});
                }
            }

            my @obs_file_names;
            if ($ftp) {
                @obs_file_names = grep  {
                    ! ( ftp_is_dir($ftp, $dset_data_path . '/' . $_) || $_ =~ /^\./ || $_ =~ /^CHECKSUMS$/ )
                } @{ftp_listdir($ftp, $dset_data_path)};
            } else {
                opendir(my $dh, $dset_data_path) or throw("can't opendir [$dset_data_path]: $!");
                @obs_file_names = grep {
                    ! ( -d catdir($dset_data_path, $_) || $_ =~ /^\./ || $_ =~ /^CHECKSUMS$/ )
                } readdir($dh);
                closedir($dh);
            }

            my @missing_file_names = array_minus(@exp_file_names, @obs_file_names);
            my @surplus_file_names = array_minus(@obs_file_names, @exp_file_names);
            my @matched_file_names = intersect(@obs_file_names, @exp_file_names);

            if (exists $dset_expectations->{'data_file_patterns'}) {
                my @exp_file_patterns = @{$dset_expectations->{'data_file_patterns'}};

                my %files_by_pattern;
                my %file_series_by_pattern;
                FILE: foreach my $surplus_file_name (@surplus_file_names) {
                    foreach my $file_pattern (@exp_file_patterns) {
                        if ($surplus_file_name =~ $file_pattern) {
                            if (exists $+{'serial_number'}) {
                                # This assumes that the serial number is the only
                                # variable part of the given filename pattern.
                                $file_series_by_pattern{$file_pattern}{$+{'serial_number'}} = $surplus_file_name;
                            } else {
                                push(@{$files_by_pattern{$file_pattern}}, $surplus_file_name);
                            }

                            # File patterns should be specific enough so that
                            # we can move on as soon as we hit a match.
                            next FILE;
                        }
                    }
                }

                my @pattern_matched_file_names;
                foreach my $file_pattern (sort keys %files_by_pattern) {
                    my @matching_file_names = @{$files_by_pattern{$file_pattern}};
                    if (scalar(@matching_file_names) == 1) {
                        push(@pattern_matched_file_names, $matching_file_names[0]);
                    } else {
                        push(@{$issues{'ambiguously identified files'}}, join(':', @matching_file_names));
                    }
                }

                foreach my $file_pattern (sort keys %file_series_by_pattern) {
                    my @serial_numbers = sort { $a <=> $b } keys %{$file_series_by_pattern{$file_pattern}};
                    if ($serial_numbers[0] == 1 &&
                            all { $serial_numbers[$_] == $serial_numbers[$_ - 1] + 1 } 1 .. $#serial_numbers) {
                        my @serial_file_names = values %{$file_series_by_pattern{$file_pattern}};
                        push(@pattern_matched_file_names, @serial_file_names);
                    } else {
                        foreach my $serial_number (1 .. $serial_numbers[-1]) {
                            if (exists $file_series_by_pattern{$file_pattern}{$serial_number}) {
                                my $serial_file_name = $file_series_by_pattern{$file_pattern}{$serial_number};
                                push(@pattern_matched_file_names, $serial_file_name);
                            } else {
                                my ($file_prefix, $file_suffix) = @{$dset_expectations->{'data_file_affixes'}{$file_pattern}};
                                my $missing_file_name = $file_prefix . $serial_number . $file_suffix;
                                push(@missing_file_names, $missing_file_name);
                            }
                        }
                    }
                }

                @surplus_file_names = array_minus(@surplus_file_names, @pattern_matched_file_names);
                push(@matched_file_names, @pattern_matched_file_names);
            }

            my @missing_file_paths = map { catfile($dset_data_path, $_) } @missing_file_names;
            my @surplus_file_paths = map { catfile($dset_data_path, $_) } @surplus_file_names;
            my @matched_file_paths = map { catfile($dset_data_path, $_) } @matched_file_names;

            my @not_missing_file_paths;
            my @not_surplus_file_paths;
            my %missing_file_path_set = map { $_ => 1 } @missing_file_paths;
            foreach my $surplus_file_path (@surplus_file_paths) {
                my $gztar_file_path = "${surplus_file_path}.tar.gz";
                my $gz_file_path = "${surplus_file_path}.gz";
                if (exists $missing_file_path_set{$gz_file_path}) {
                    push(@{$issues{'uncompressed file'}}, $surplus_file_path);
                    push(@not_surplus_file_paths, $surplus_file_path);
                    push(@not_missing_file_paths, $gz_file_path);
                } elsif (exists $missing_file_path_set{$gztar_file_path}) {
                    push(@{$issues{'unarchived directory'}}, $surplus_file_path);
                    push(@not_surplus_file_paths, $surplus_file_path);
                    push(@not_missing_file_paths, $gztar_file_path);
                }
            }

            @missing_file_paths = array_minus(@missing_file_paths, @not_missing_file_paths);
            @surplus_file_paths = array_minus(@surplus_file_paths, @not_surplus_file_paths);

            foreach my $missing_file_path (@missing_file_paths) {
                push(@{$issues{'missing file'}}, $missing_file_path);
            }

            foreach my $surplus_file_path (@surplus_file_paths) {
                push(@{$issues{'surplus file'}}, $surplus_file_path);
            }

            if (@matched_file_paths && !$ftp) {
                my $cwd = getcwd();
                chdir($dset_data_path);

                foreach my $matched_file_path (@matched_file_paths) {
                    if ( -l $matched_file_path ) {
                        my $target_file_path = readlink($matched_file_path);
                        if ( file_name_is_absolute($target_file_path) ) {
                            push(@{$issues{'absolute symlink'}}, $matched_file_path);
                        } elsif ($follow_symlinks && ! -e $target_file_path) {
                            push(@{$issues{'broken symlink'}}, $matched_file_path);
                        }
                    }
                }

                chdir($cwd);
            }

            if (exists $dset_expectations->{'data_file_paths'}) {

                my %exp_items_by_dir;
                foreach my $data_file_path (@{$dset_expectations->{'data_file_paths'}}) {
                    my ($vol, $rel_dir_path, $data_file_name) = splitpath($data_file_path);
                    $rel_dir_path =~ s|/$||;
                    push(@{$exp_items_by_dir{$rel_dir_path}}, $data_file_name);
                }

                if (exists $dset_expectations->{'meta_file_paths'}) {
                    foreach my $meta_file_path (@{$dset_expectations->{'meta_file_paths'}}) {
                        my ($vol, $rel_dir_path, $meta_file_name) = splitpath($meta_file_path);
                        $rel_dir_path =~ s|/$||;
                        if (! grep { $_ eq $meta_file_name} @{$exp_items_by_dir{$rel_dir_path}}) {
                            push(@{$exp_items_by_dir{$rel_dir_path}}, $meta_file_name);
                        }
                    }
                }

                foreach my $rel_dir_path (sort keys %exp_items_by_dir) {
                    my $subdir_path = catdir($dset_data_path, $rel_dir_path);

                    if ($ftp) {
                        if (!ftp_is_dir($ftp, $subdir_path)) {
                            push(@{$issues{'missing directory'}}, $subdir_path);
                            next;
                        }
                    } else {
                        if (! -d $subdir_path) {
                            push(@{$issues{'missing directory'}}, $subdir_path);
                            next;
                        }
                    }

                    my @exp_item_names = @{$exp_items_by_dir{$rel_dir_path}};

                    my @obs_item_names;
                    if ($ftp) {
                        @obs_item_names = grep { ! ($_ =~ /^\./ || $_ =~ /^CHECKSUMS$/) } @{ftp_listdir($ftp, $subdir_path)};
                    } else {
                        opendir(my $dh, $subdir_path) or throw("can't opendir [$subdir_path]: $!");
                        @obs_item_names = grep { ! ($_ =~ /^\./ || $_ =~ /^CHECKSUMS$/) } readdir($dh);
                        closedir($dh);
                    }

                    my @missing_item_paths = map { catfile($subdir_path, $_) } array_minus(@exp_item_names, @obs_item_names);
                    my @surplus_item_paths = map { catfile($subdir_path, $_) } array_minus(@obs_item_names, @exp_item_names);
                    my @matched_item_paths = map { catfile($subdir_path, $_) } intersect(@obs_item_names, @exp_item_names);

                    my @not_missing_item_paths;
                    my @not_surplus_item_paths;
                    my %missing_item_path_set = map { $_ => 1 } @missing_item_paths;
                    foreach my $surplus_item_path (@surplus_item_paths) {
                        my $gztar_item_path = "${surplus_item_path}.tar.gz";
                        my $gz_item_path = "${surplus_item_path}.gz";
                        if (exists $missing_item_path_set{$gz_item_path}) {
                            push(@{$issues{'uncompressed file'}}, $surplus_item_path);
                            push(@not_surplus_item_paths, $surplus_item_path);
                            push(@not_missing_item_paths, $gz_item_path);
                        } elsif (exists $missing_item_path_set{$gztar_item_path}) {
                            push(@{$issues{'unarchived directory'}}, $surplus_item_path);
                            push(@not_surplus_item_paths, $surplus_item_path);
                            push(@not_missing_item_paths, $gztar_item_path);
                        }
                    }

                    @missing_item_paths = array_minus(@missing_item_paths, @not_missing_item_paths);
                    @surplus_item_paths = array_minus(@surplus_item_paths, @not_surplus_item_paths);

                    foreach my $missing_item_path (@missing_item_paths) {
                        push(@{$issues{'missing file'}}, $missing_item_path);
                    }

                    foreach my $surplus_item_path (@surplus_item_paths) {
                        push(@{$issues{'surplus file'}}, $surplus_item_path);
                    }

                    if (@matched_item_paths && !$ftp) {
                        my $cwd = getcwd();
                        chdir($subdir_path);

                        foreach my $matched_item_path (@matched_item_paths) {
                            if ( -l $matched_item_path ) {
                                my $target_item_path = readlink($matched_item_path);
                                if ( file_name_is_absolute($target_item_path) ) {
                                    push(@{$issues{'absolute symlink'}}, $matched_item_path);
                                } elsif ($follow_symlinks && ! -e $target_item_path) {
                                    push(@{$issues{'broken symlink'}}, $matched_item_path);
                                }
                            }
                        }

                        chdir($cwd);
                    }
                }
            }
        }
    }
}

if (%issues) {

    print STDERR "Writing issues to '$outfile' ... \n";

    my $csv = Text::CSV->new ({ sep_char => "\t" });
    open my $fh, '>', $outfile or throw("Failed to open [$outfile]: $!");

    $csv->say($fh, ['issue', 'path']);
    foreach my $issue (sort keys %issues) {
        foreach my $path (sort @{$issues{$issue}}) {
            $path = ftp_path_url($ftp, $path) if ($ftp);
            $csv->say($fh, [$issue, $path]);
        }
    }

    close $fh or throw("Failed to close [$outfile]: $!");

} else {
    print STDERR "No issues found ... \n";
}

$ftp->quit if ($ftp);

print STDERR "Done.\n";
