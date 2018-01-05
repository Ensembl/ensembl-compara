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



=pod

=head1 NAME

GenerateSSPict

=head1 DESCRIPTION

This script creates secondary structure plots based on the
secondary structures (in bracket notation) created by Infernal.
In addition to secondary structure plots for the whole alignments 
of the family, plots for individual members are also created.

=head1 CONTACT

   Please email comments or questions to the public Ensembl
   developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

   Questions may also be sent to the Ensembl help desk at
   <http://www.ensembl.org/Help/Contact>

=head1 APPENDIX

The rest of the documentation details each of the object methods.

Internal methods are usually preceded with an underscore (_)

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::IO qw/:spurt/;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $reg = "Bio::EnsEMBL::Registry";

my $r2r_exe = $ENV{'LINUXBREW_HOME'}.'/Cellar/r2r/1.0.4/bin/r2r',
my $registry_file;
my $url;
my $compara_url;
my $stable_id;
my $thumbnail;
my $help;

GetOptions(
           "r2r_exe=s"       => \$r2r_exe,
           "url=s"           => \$url,
           "compara_url=s"   => \$compara_url,
           "conf|registry=s" => \$registry_file,
           "id|stable_id:s"  => \$stable_id,
           "thumbnail"       => \$thumbnail,
           "help"            => \$help,
          );

if (! defined $stable_id || $help) {
      print <<'EOH';
GenerateSSPict.pl -- Generate secondary structure of Ensembl ncRNA trees
./GenerateSSPict.pl -compara_url <compara_url> -id <gene_member_stable_id>

Options:
    --url                 [Optional] URL for Ensembl databases
    --compara_url         [Optional] URL for Ensembl Compara database
    --conf | --registry   [Optional] Path to a configuration file
    --id   | --stable_id             Ensembl gene stable id
    --r2r_exe                        Path to the r2r executable
                                     [Defaults to the version 1.0.4 in the linuxbrew cellar]
    --thumbnail           [Optional] If present, only a thumbnail of the family is created
    --help                [Optional] Print this message & exit

EOH
exit
}


if ($registry_file) {
  die if (!-e $registry_file);
  $reg->load_all($registry_file);
} elsif ($url) {
  $reg->load_registry_from_url($url);
} elsif (!$compara_url) {
  $reg->load_all();
}

my $compara_dba;
if ($compara_url) {
    require Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

my $geneMemberAdaptor = $compara_dba->get_GeneMemberAdaptor();
my $seqMemberAdaptor  = $compara_dba->get_SeqMemberAdaptor();
my $geneTreeAdaptor   = $compara_dba->get_GeneTreeAdaptor();

my $gene_member = $geneMemberAdaptor->fetch_by_stable_id($stable_id);
check($gene_member, "gene", $stable_id);
my $transc = $seqMemberAdaptor->fetch_canonical_for_gene_member_id($gene_member->gene_member_id);
check($transc, "transcript", $stable_id);
my $geneTree = $geneTreeAdaptor->fetch_default_for_Member($gene_member);
check($geneTree, "GeneTree", $stable_id);
my $model_name = $geneTree->get_value_for_tag('model_name');
check($model_name, "model_name", $stable_id);
my $ss_cons = $geneTree->get_value_for_tag('ss_cons');
check($ss_cons, "ss_cons", $stable_id);
my $input_aln = $geneTree->get_SimpleAlign( -id => 'MEMBER' );
my $aln_filename = dumpMultipleAlignment($input_aln, $model_name, $ss_cons);

if ($thumbnail) {
    getThumbnail($aln_filename, $geneTree);
} else {
    getPlot($aln_filename, $geneTree, $transc->stable_id);
}

sub dumpMultipleAlignment {
    my ($aln, $model_name, $ss_cons) = @_;
    if ($ss_cons =~ /^\.+$/) {
        die "The tree has no structure\n";
    }

    my $aln_filename = "${model_name}.sto";
    open my $aln_fh, ">", $aln_filename or die "I can't open file $aln_filename: $!\n";
    print $aln_fh "# STOCKHOLM 1.0\n";
    for my $aln_seq ($aln->each_seq) {
        printf $aln_fh ("%-20s %s\n", $aln_seq->display_id, $aln_seq->seq);
    }
    printf $aln_fh ("%-20s\n", "#=GF R2R keep allpairs");
    printf $aln_fh ("%-20s %s\n//\n", "#=GC SS_cons", $ss_cons);

    close($aln_fh);
    return $aln_filename;
}

sub getAlnFile {
    my ($aln_file) = @_;

    my $out_aln_file = $aln_file . ".cons";
    # For information about these options, check http://breaker.research.yale.edu/R2R/R2R-manual-1.0.3.pdf
    run_r2r_and_check("--GSC-weighted-consensus", $aln_file, $out_aln_file, "3 0.97 0.9 0.75 4 0.97 0.9 0.75 0.5 0.1");

    return $out_aln_file;
}

sub getPlot {
    my ($aln_file, $tree, $peptide_id) = @_;

    my $out_aln_file = getAlnFile($aln_file);

    member_pic($peptide_id, $aln_file, $out_aln_file);
}

sub getThumbnail {
    my ($aln_file, $tree) = @_;

    my $out_aln_file = getAlnFile($aln_file);
    thumbnail($aln_file, $out_aln_file);
}

sub thumbnail {
    my ($aln_file, $out_aln_file) = @_;
    my $meta_file_thumbnail = $aln_file . "-thumbnail.meta";
    my $svg_thumbnail_pic = "${out_aln_file}.thumbnail.svg";
    spurt($meta_file_thumbnail, "$out_aln_file\tskeleton-with-pairbonds\n");
    run_r2r_and_check("", $meta_file_thumbnail, $svg_thumbnail_pic, "");
    return;
}


sub member_pic {
    my ($stable_id, $aln_file, $out_aln_file) = @_;

    my $meta_file = $aln_file . ".meta";
    spurt($meta_file, "$out_aln_file\n$aln_file\toneseq\t$stable_id\n");
    my $svg_pic_filename = "${out_aln_file}-${stable_id}.svg";
    run_r2r_and_check("", $meta_file, $svg_pic_filename, "");
    return;
}

sub run_r2r_and_check {
    my ($opts, $infile, $outfile, $extra_params) = @_;
    die "$r2r_exe doesn't exist\n" unless (-e $r2r_exe);

    my $cmd = "$r2r_exe $opts $infile $outfile $extra_params";
#    print STDERR "CMD: $cmd\n";
    system($cmd);
    if (! -e $outfile) {
        die "Problem running r2r: $outfile doesn't exist\nThis is the command I tried to run:\n$cmd\n";
    }
    return;
}


sub check {
    my ($val, $type, $stable_id) = @_;
    unless (defined $val) {
        print STDERR "No $type found for $stable_id in the database\n";
        exit(1);
    }
}
