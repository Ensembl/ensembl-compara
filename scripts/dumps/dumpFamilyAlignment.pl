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

dumpFamilyAlignment.pl

=head1 DESCRIPTION

Dumps the aligned sequences of the gene
family with the specified stable ID.

=head1 SYNOPSIS

    $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/dumps/dumpFamilyAlignment.pl \
        --url <compara_db_url> --family_id <family_stable_id> --outfile <fasta_file_path>

=head1 EXAMPLES

    $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/dumps/dumpFamilyAlignment.pl \
        --url mysql://anonymous@mysql-eg-publicsql.ebi.ac.uk:4157/ensembl_compara_plants_63_116 \
        --family_id wheat_cultivars_PTHR11439_SF127 \
        --outfile wheat_cultivars_PTHR11439_SF127.fa

    $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/dumps/dumpFamilyAlignment.pl \
        --url mysql://anonymous@mysql-eg-publicsql.ebi.ac.uk:4157/ensembl_compara_plants_63_116 \
        --family_id oat_cultivars_PTHR11439_SF127 \
        --outfile oat_cultivars_PTHR11439_SF127.fa.gz

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--url STR]>

Compara database URL.

=item B<[--family_id STR]>

Stable ID of the family.

=item B<[--outfile PATH]>

Path of output FASTA file of aligned family sequences.

This can optionally be gzip- or bzip2-compressed.

=back

=cut

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Copy qw(move);
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Utils::Exception qw(info throw verbose);
use Bio::EnsEMBL::Utils::IO qw(bz_work_with_file gz_work_with_file work_with_file);


my %compressed_file_handlers = (
    '.bz2' => \&bz_work_with_file,
    '.gz' => \&gz_work_with_file,
);


my ( $help, $url, $family_id, $outfile );
GetOptions(
    "help|?"      => \$help,
    "url=s"       => \$url,
    "family_id=s" => \$family_id,
    "outfile=s"   => \$outfile,
) or pod2usage(-verbose => 2);

pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$url or !$family_id or !$outfile;

verbose('INFO');


info("Dumping sequences of family '$family_id'");

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($url);

$compara_dba->dbc->db_handle->do('SET SESSION group_concat_max_len = 4294967295');

my $helper = $compara_dba->dbc->sql_helper;

# We group aligned members by sequence/CIGAR to reduce redundancy.
my $sql = q/
    SELECT
        sequence,
        cigar_line,
        COUNT(*) AS num_stable_ids,
        (SUM(LENGTH(sm.stable_id)) + COUNT(*) - 1) AS exp_concat_length,
        GROUP_CONCAT(sm.stable_id SEPARATOR '\t') AS concat_stable_ids
    FROM
        seq_member sm
    JOIN
        sequence USING (sequence_id)
    JOIN
        family_member fm USING (seq_member_id)
    JOIN
        family f USING (family_id)
    WHERE
        f.stable_id = ?
    GROUP BY
        sequence, cigar_line
/;

my $iterator = $helper->execute( -SQL => $sql, -PARAMS => [$family_id], -iterator => 1 );

my ($out_file_name, $out_dir_path, $out_file_suffix) = fileparse($outfile, keys %compressed_file_handlers);
my $work_with_file = $compressed_file_handlers{$out_file_suffix} // \&work_with_file;

my $temp_dir = tempdir( CLEANUP => 1 );
my $temp_out_file_path = catfile($temp_dir, $out_file_name);

my $num_members = 0;
$work_with_file->($temp_out_file_path, 'w', sub {
    my ($fh) = @_;

    while($iterator->has_next()) {
        my ($original_seq, $cigar_line, $num_stable_ids, $exp_concat_length, $concat_stable_ids) = @{$iterator->next()};

        my @stable_ids = split("\t", $concat_stable_ids);

        my $member_group_label = sprintf(
            "sequence member group containing %s and %d other members",
            $stable_ids[0],
            $num_stable_ids - 1,
        );

        if (length($concat_stable_ids) != $exp_concat_length) {
            throw("failed to fetch complete set of stable IDs of $member_group_label");
        }

        if (!defined $original_seq) {
            throw("sequence unavailable for $member_group_label");
        }

        if (!defined $cigar_line) {
            throw("CIGAR line unavailable for $member_group_label");
        }

        my $aligned_seq = Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar($original_seq, $cigar_line);
        $aligned_seq =~ s/(.{60})/$1\n/g;

        foreach my $stable_id (@stable_ids) {
            print $fh sprintf(">%s\n%s\n", $stable_id, $aligned_seq);
        }

        $num_members += $num_stable_ids;
    }
});

info("Dumped aligned sequences of $num_members family members");

info("Writing alignment to '%s'");

make_path($out_dir_path);
move($temp_out_file_path, $outfile);

info("Done.");
