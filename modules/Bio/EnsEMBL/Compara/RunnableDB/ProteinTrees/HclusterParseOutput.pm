=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput

=head1 DESCRIPTION

This is the RunnableDB that parses the output of Hcluster, stores the
clusters as trees without internal structure (each tree will have one
root and several leaves) and dataflows the cluster_ids down branch #2.

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HclusterParseOutput');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput(
                         -input_id   => "{'mlss_id'=>40069}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'member_type'           => 'protein',
            'immediate_dataflow'    => 1,
    };
}


sub run {
    my $self = shift @_;

    $self->parse_hclusteroutput;
}


sub write_output {
    my $self = shift @_;

    $self->store_clusterset('default', $self->param('allclusters'));
}


##########################################
#
# internal methods
#
##########################################

sub parse_hclusteroutput {
    my $self = shift;

    my $filename      = $self->param('cluster_dir') . '/hcluster.out';
    my $division      = $self->param('division'),

    my %allclusters = ();
    $self->param('allclusters', \%allclusters);
    
    open(FILE, $filename) or die "Could not open '$filename' for reading : $!";
    while (<FILE>) {
        # 0       0       0       1.000   2       1       697136_68,
        # 1       0       39      1.000   3       5       1213317_31,1135561_22,288182_42,426893_62,941130_38,
        chomp $_;

        my ($cluster_id, $dummy1, $dummy2, $dummy3, $dummy4, $cluster_size, $cluster_list) = split("\t",$_);

        next if ($cluster_size < 2);
        $cluster_list =~ s/\,$//;
        $cluster_list =~ s/_[0-9]*//g;
        my @cluster_list = split(",", $cluster_list);

        # If it's a singleton, we don't store it as a protein tree
        next if (2 > scalar(@cluster_list));
        $allclusters{$cluster_id} = { 'members' => \@cluster_list };
        $allclusters{$cluster_id}->{'division'} = $division if $division;
    }
    close FILE;
    warn scalar(keys %allclusters), " clusters loaded\n";

}


1;
