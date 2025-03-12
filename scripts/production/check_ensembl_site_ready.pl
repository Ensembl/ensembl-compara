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

=head1 NAME

check_ensembl_site_ready.pl

=head1 DESCRIPTION

This script does rudimentary checks on the specified Ensembl website(s),
to help establish whether they are ready for manual checks.

It can check species and/or Compara data, as configured by the
--check_species and --check_compara options, respectively.

=head1 SYNOPSIS

    perl check_ensembl_site_ready.pl --division ${COMPARA_DIV} --release ${CURR_ENSEMBL_RELEASE} \
        --web_url <ensembl_website_url> --check_species --check_compara

=head1 EXAMPLES

    # Vertebrates
    perl check_ensembl_site_ready.pl --division vertebrates --release ${CURR_ENSEMBL_RELEASE} \
        --web_url https://staging.ensembl.org/ \
        --check_species --check_compara

    # Pan Compara
    perl check_ensembl_site_ready.pl --division pan --release ${CURR_ENSEMBL_RELEASE} \
        --web_url https://staging-fungi.ensembl.org/ \
        --web_url https://staging-metazoa.ensembl.org/ \
        --web_url https://staging-plants.ensembl.org/ \
        --web_url https://staging-protists.ensembl.org/ \
        --check_species --check_compara

    # Non-vertebrate divisions except Pan
    perl check_ensembl_site_ready.pl --division $COMPARA_DIV --release ${CURR_ENSEMBL_RELEASE} \
        --web_url "https://staging-${COMPARA_DIV}.ensembl.org/" \
        --check_species --check_compara

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--division STR]>

(Optional) Ensembl division. If not specified, this is set from the environment variable ${COMPARA_DIV}.

=item B<[--release INT]>

(Optional) Ensembl release. If not specified, this is set from the environment variable ${CURR_ENSEMBL_RELEASE}.

=item B<[--web_url STR]>

Ensembl website URL of the relevant division.

This may be specified multiple times when checking Pan Compara.

=item B<[--check_species]>

(Optional) Check species views.

=item B<[--check_compara]>

(Optional) Check Compara views.

=back

=cut

use strict;
use warnings;

use File::Spec::Functions;
use Getopt::Long;
use HTML::Parser;
use JSON qw(decode_json);
use List::Util qw(min sum);
use LWP::UserAgent;
use Pod::Usage;
use Test::More;
use Time::HiRes qw(usleep gettimeofday tv_interval);
use URI;
use XML::LibXML '1.70';

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::IO qw(slurp);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


sub fetch_alignment_test_cases {
    my ($compara_dba, $web_base_url) = @_;

    my $stats_url_path = 'info/genome/compara/mlss.html';

    my $sql = q/
        SELECT
            method_link_species_set_id,
            name
        FROM
            method_link_species_set
        JOIN
            method_link USING (method_link_id)
        WHERE
            method_link.type IN (
                'CACTUS_DB',
                'CACTUS_HAL',
                'EPO',
                'EPO_EXTENDED',
                'LASTZ_NET',
                'PECAN'
            )
        ORDER BY
            method_link_species_set_id DESC
    /;

    my $helper = $compara_dba->dbc->sql_helper;
    my $results = $helper->execute( -SQL => $sql );

    my @test_cases;
    foreach my $result (@{$results}) {
        my ($mlss_id, $mlss_name) = @{$result};

        my $test_url = $web_base_url . $stats_url_path . "?mlss=$mlss_id";
        push(@test_cases, [$mlss_name, $test_url]);
    }

    return \@test_cases;
}

sub fetch_homology_test_cases {
    my ($compara_dba, $compara_division, $species_name_to_web_info) = @_;

    my $helper = $compara_dba->dbc->sql_helper;

    my $sql1 = q/
        SELECT DISTINCT
            TRIM(LEADING "collection-" FROM ssh.name) AS collection_name,
            IF(sst.tag = 'strain_type', 1, 0) AS strain_status
        FROM
            method_link_species_set mlss
        JOIN
            method_link ml USING (method_link_id)
        JOIN
            species_set ss USING (species_set_id)
        JOIN
            species_set_header ssh USING (species_set_id)
        LEFT JOIN
            species_set_tag sst USING (species_set_id)
        WHERE
            ml.type in ('PROTEIN_TREES', 'NC_TREES')
        AND
            (sst.tag IS NULL OR sst.tag = 'strain_type');
    /;

    my $results1 = $helper->execute( -SQL => $sql1, -USE_HASHREFS => 1 );

    my %is_strain_collection;
    foreach my $row (@{$results1}) {
        $is_strain_collection{$row->{'collection_name'}} = $row->{'strain_status'};
    }

    my @rel_gdb_names = keys %{$species_name_to_web_info};
    my $rel_gdb_name_placeholders = '(' . join(',', ('?') x @rel_gdb_names) . ')';

    my $sql2 = qq/
        SELECT
            genome_db.name AS gdb_name,
            MAX(gene_member_id) AS max_gene_member_id
        FROM
            gene_member
        JOIN
            genome_db USING (genome_db_id)
        JOIN
            gene_member_hom_stats USING (gene_member_id)
        WHERE
            collection = ?
        AND
            genome_db.name IN $rel_gdb_name_placeholders
        AND
            orthologues > 0
        GROUP BY
            genome_db.name
        ORDER BY
            genome_db.name
    /;

    my $sql3 = q/
        SELECT
            stable_id
        FROM
            gene_member
        WHERE
            gene_member_id = ?
    /;

    my @collection_names = sort keys %is_strain_collection;

    my @test_cases;
    foreach my $collection_name (@collection_names) {

        my $action;
        if ($compara_division eq 'pan') {
            $action = 'Compara_Ortholog/pan_compara';
        } elsif ($is_strain_collection{$collection_name}) {
            $action = 'Strain_Compara_Ortholog';
        } else {
            $action = 'Compara_Ortholog';
        }

        my $results2 = $helper->execute( -SQL => $sql2, -PARAMS => [$collection_name, @rel_gdb_names], -USE_HASHREFS => 1 );

        my %collection_info;
        foreach my $row (@{$results2}) {
            my $gdb_name = $row->{'gdb_name'};

            my $stable_id = $helper->execute_single_result( -SQL => $sql3, -PARAMS => [$row->{'max_gene_member_id'}] );
            my $test_key = "$gdb_name gene $stable_id";

            my $web_base_url = $species_name_to_web_info->{$gdb_name}{'base_url'};
            my $species_url = $species_name_to_web_info->{$gdb_name}{'species_url'};
            my $hom_url_path = $species_url . '/Component/Gene/' . $action . '/orthologues';
            my $test_url = $web_base_url . $hom_url_path . "?g=$stable_id";

            push(@test_cases, [$test_key, $test_url]);
        }
    }

    return \@test_cases;
}

sub fetch_pan_gene_tree_test_cases {
    my ($compara_dba, $tree_species_count_threshold, $web_url_info) = @_;

    my $helper = $compara_dba->dbc->sql_helper;

    my $sql = q/
        SELECT
            gtr.stable_id,
            COUNT(DISTINCT genome_db_id) AS tree_species_count
        FROM
            gene_tree_root gtr
        JOIN
            gene_tree_node gtn USING (root_id)
        JOIN
            seq_member sm USING (seq_member_id)
        WHERE
            ref_root_id IS NULL
        GROUP BY
            root_id HAVING tree_species_count >= ?
        ORDER BY
            tree_species_count DESC LIMIT 1
    /;

    my $tree_stable_id = $helper->execute_single_result( -SQL => $sql, -PARAMS => [$tree_species_count_threshold] );

    my $file_name = "Multi_GeneTree_Image_pan_compara_${tree_stable_id}.svg";

    my $url_path = 'Multi/ImageExport/ImageOutput';
    my %param_hash = (
        'align' => 'tree',
        'cdb' => 'compara_pan_ensembl',
        'component' => 'ComparaTree',
        'data_action' => 'Image',
        'data_type' => 'GeneTree',
        'db' => 'core',
        'decodeURL' => 1,
        'exons' => 'off',
        'filename' => $file_name,
        'format' => 'custom',
        'gt' => $tree_stable_id,
        'image_format' => 'svg',
    );
    my @param_pairs = map { join('=', $_, $param_hash{$_}) } keys %param_hash;
    my $url_param_str = '?' . join('&', @param_pairs);

    my @test_cases;
    foreach my $website_division (keys %{$web_url_info}) {
        my $test_key = sprintf('Ensembl%s tree %s', ucfirst $website_division, $tree_stable_id);
        my $base_url = $web_url_info->{$website_division}{'base_url'};

        my $test_url = $base_url . $url_path . $url_param_str;
        push(@test_cases, [$test_key, $test_url]);
    }

    return \@test_cases;
}

sub fetch_species_test_cases {
    my ($compara_dba, $species_name_to_web_info) = @_;

    my @species_names = sort keys %{$species_name_to_web_info};

    my @test_cases;
    foreach my $species_name (@species_names) {
        my $base_url = $species_name_to_web_info->{$species_name}{'base_url'};
        my $species_url = $species_name_to_web_info->{$species_name}{'species_url'};
        my $test_url = $base_url . $species_url . '/Info/Index';
        push(@test_cases, [$species_name, $test_url]);
    }

    return \@test_cases;
}

sub fetch_website_division {
    my ($homepage_url) = @_;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($homepage_url);

    my $website_title;
    if ($response->is_success) {
        my $title_element;
        my $title_parser = HTML::Parser->new(
            api_version => 3,
            start_h => [ sub { $title_element = 1 if $_[0] eq 'title' }, 'tagname' ],
            text_h => [ sub { $website_title = $_[0] if $title_element }, 'text' ],
            end_h => [ sub { $title_element = 0 if $_[0] eq 'title' }, 'tagname' ],
        );
        $title_parser->report_tags(('title'));
        $title_parser->parse($response->decoded_content);
    }
    else {
        throw(sprintf('failed to fetch Ensembl homepage "%s": %s', $homepage_url, $response->status_line));
    }

    my $eg_homepage_title_re = qr/^Ensembl (?<division>Bacteria|Fungi|Metazoa|Plants|Protists).*$/;
    my $ensembl_homepage_title_re = qr/^Ensembl .+ (?<release>[1-9][0-9]+)$/;

    my $division;
    if ($website_title =~ $eg_homepage_title_re) {
        $division = lc $+{'division'};
    } elsif ($website_title =~ $ensembl_homepage_title_re) {
        $division = 'vertebrates';
    } else {
        throw(sprintf('failed to detect division of Ensembl homepage "%s"', $homepage_url));
    }

    return $division;
}


my $help;
my $compara_division = $ENV{'COMPARA_DIV'};
my $release  = $ENV{'CURR_ENSEMBL_RELEASE'};
my $compara_db = 'compara_curr';
my @web_urls = ();
my $check_species = 0;
my $check_compara = 0;
my $verbose = 0;

GetOptions(
    'help|?'        => \$help,
    'division=s'    => \$compara_division,
    'release=i'     => \$release,
    'compara_db=s'  => \$compara_db,
    'web_url=s'     => \@web_urls,
    'check_species' => \$check_species,
    'check_compara' => \$check_compara,
    'verbose'       => \$verbose,
);
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$compara_division or !$release or !$compara_db or !@web_urls or !($check_species or $check_compara);


Test::More->builder->output('/dev/null') unless ($verbose);

my $config_dir = catfile($ENV{'ENSEMBL_ROOT_DIR'}, 'ensembl-compara', 'conf', $compara_division);
my $reg_conf = catfile($config_dir, 'production_reg_conf.pl');

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing');

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($compara_db);
my $genome_dba = $compara_dba->get_GenomeDBAdaptor();

my %web_url_info;
foreach my $web_url (@web_urls) {
    my $web_uri = URI->new($web_url)->canonical;

    my $base_url = $web_uri->scheme . '://' . $web_uri->host . ':' . $web_uri->port . '/';
    my $home_url = $base_url . 'index.html';

    my $website_division = fetch_website_division($home_url);

    if ($website_division eq $compara_division || ($compara_division eq 'pan' && $website_division ne 'vertebrates')) {
        $web_url_info{$website_division} = {
            'home_url' => $home_url,
            'base_url' => $base_url,
        };
    }
}

my %species_names_by_division;
my $tree_species_count_threshold;
if ($compara_division eq 'pan') {

    my $additional_species_file = catfile($config_dir, 'additional_species.json');
    my %additional_species = %{decode_json(slurp($additional_species_file))};

    my @div_species_counts;
    while (my ($division_name, $division_species_names) = each %additional_species) {
        $species_names_by_division{$division_name} = $division_species_names;
        push(@div_species_counts, scalar(@{$division_species_names}));
    }

    # Trees with at least this number of genomes must
    # have at least one member from each division.
    $tree_species_count_threshold = sum(@div_species_counts) - min(@div_species_counts) + 1;

    # Pan Compara is not available on the Ensembl Vertebrates site.
    delete $species_names_by_division{'vertebrates'};

} else {

    my $allowed_species_file = catfile($config_dir, 'allowed_species.json');
    $species_names_by_division{$compara_division} = decode_json(slurp($allowed_species_file));
}

my %species_name_to_web_info;
while (my ($division_name, $division_species_names) = each %species_names_by_division) {
    next unless exists $web_url_info{$division_name};

    foreach my $species_name (@{$division_species_names}) {

        $species_name_to_web_info{$species_name} = { %{$web_url_info{$division_name}} };

        my $gdb = $genome_dba->fetch_by_name_assembly($species_name);
        my $meta_container = $gdb->db_adaptor->get_MetaContainer();
        $species_name_to_web_info{$species_name}{'species_url'} = $meta_container->single_value_by_key('species.url');
    }
}

if (scalar(keys(%species_name_to_web_info)) == 0) {
    throw("division $compara_division is not represented in the specified website(s)");
}

my $min_time_between_requests = 0.333;
my $forty_winks = 40_000;
my @latest_request_time;

my $ua = LWP::UserAgent->new();
my $json = JSON->new();

if ($check_species) {
    subtest "Check species", sub {
        my $species_test_cases = fetch_species_test_cases($compara_dba, \%species_name_to_web_info);

        foreach my $test_case (@{$species_test_cases}) {
            my ($test_key, $test_url) = @{$test_case};

            usleep($forty_winks) while (tv_interval(\@latest_request_time) < $min_time_between_requests);
            @latest_request_time = gettimeofday();
            my $response = $ua->get($test_url);

            ok($response->is_success, "$test_key species homepage accessibility")
               || diag $json->pretty->encode({"status" => $response->status_line,
                                              "url" => $test_url});
        }

        done_testing();
    };
}

if ($check_compara) {

    subtest "Check Compara homologies", sub {
        my $homology_test_cases = fetch_homology_test_cases($compara_dba, $compara_division, \%species_name_to_web_info);

        foreach my $test_case (@{$homology_test_cases}) {
            my ($test_key, $test_url) = @{$test_case};


            usleep($forty_winks) while (tv_interval(\@latest_request_time) < $min_time_between_requests);
            @latest_request_time = gettimeofday();
            my $response = $ua->get($test_url);

            ok($response->is_success, "$test_key orthology view accessibility")
                || diag $json->pretty->encode({"status" => $response->status_line,
                                               "url" => $test_url});

            if ($response->is_success) {

                my $orthologies_accessibility = 0;
                my $message;

                if ($response->decoded_content) {
                    my $dom = XML::LibXML->load_html(
                        string => $response->decoded_content,
                        recover => 1,
                        suppress_errors => 1
                    );

                    my ($ortho_panel_node) = @{$dom->findnodes('//div[@id="ComparaOrthologs"]')};

                    my $ortho_table_row_xpath = '//div[contains(@class, "selected_orthologues_table")]//table[@id="orthologues"]//tbody//tr';
                    my @ortho_table_rows = @{$ortho_panel_node->findnodes($ortho_table_row_xpath)};

                    if (@ortho_table_rows) {
                        $orthologies_accessibility = 1;

                        if (scalar(@ortho_table_rows) == 1) {
                            my @first_row_cols = @{$ortho_table_rows[0]->findnodes('//td')};
                            if (scalar(@first_row_cols) == 1
                                    && $first_row_cols[0]->textContent eq 'No data available in table') {
                                $message = 'No data available in table';
                                $orthologies_accessibility = 0;
                            }
                        }

                    } else {
                        my $orthologs_missing = $ortho_panel_node->findnodes('//p[@text="No orthologues have been identified for this gene"]');
                        if (defined $orthologs_missing) {
                            $message = 'No orthologues have been identified for this gene';
                        }
                    }
                } else {
                    $message = 'Empty response';
                }

                ok($orthologies_accessibility, "$test_key orthology data accessibility")
                   || diag $json->pretty->encode({"message" => $message,
                                                  "status" => $response->status_line,
                                                  "url" => $test_url});
            }
        }

        done_testing();
    };

    if ($compara_division eq 'pan') {

        subtest "Check Pan Compara trees", sub {
            my $pan_tree_test_cases = fetch_pan_gene_tree_test_cases($compara_dba, $tree_species_count_threshold, \%web_url_info);

            foreach my $test_case (@{$pan_tree_test_cases}) {
                my ($test_key, $test_url) = @{$test_case};

                usleep($forty_winks) while (tv_interval(\@latest_request_time) < $min_time_between_requests);
                @latest_request_time = gettimeofday();
                my %headers = ("Content-Type" => "image/svg+xml; charset=ISO-8859-1");
                my $response = $ua->get($test_url, %headers);

                ok($response->is_success, "$test_key export accessibility")
                   || diag $json->pretty->encode({"status" => $response->status_line,
                                                  "url" => $test_url});

                if ($response->is_success) {

                    my $dom = XML::LibXML->load_xml( string => $response->decoded_content );
                    my $svg_root = $dom->documentElement();
                    my @anc_seq_genes;
                    foreach my $child ($svg_root->childNodes()) {
                        if ($child->nodeName eq 'text'
                                && $child->textContent =~ /^(.+), Ancestral sequence$/) {
                            push(@anc_seq_genes, $1);
                        }
                    }

                    is(scalar(@anc_seq_genes), 0, "$test_key Ancestral sequence gene check")
                       || diag explain [sort @anc_seq_genes];
                }
            }

            done_testing();
        };

    } else {

        subtest "Check Compara alignments", sub {
            my $alignment_test_cases = fetch_alignment_test_cases($compara_dba, $web_url_info{$compara_division}{'base_url'});

            foreach my $test_case (@{$alignment_test_cases}) {
                my ($test_key, $test_url) = @{$test_case};

                usleep($forty_winks) while (tv_interval(\@latest_request_time) < $min_time_between_requests);
                @latest_request_time = gettimeofday();
                my $response = $ua->get($test_url);

                my $message;
                if ($response->is_success) {
                    my $dom = XML::LibXML->load_html(
                        string => $response->decoded_content,
                        recover => 1,
                        suppress_errors => 1
                    );

                    my @error_nodes = @{$dom->findnodes('//div[contains(@class, "error")]//h3')};
                    if (@error_nodes) {
                        $message = $error_nodes[0]->textContent;
                    }
                }

                ok($response->is_success && !defined($message), "$test_key stats page accessibility")
                   || diag $json->pretty->encode({"message" => $message,
                                                  "status" => $response->status_line,
                                                  "url" => $test_url});
            }

            done_testing();
        };

    }
}

done_testing();
