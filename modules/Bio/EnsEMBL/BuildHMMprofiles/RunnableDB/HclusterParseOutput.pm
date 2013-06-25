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

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::BuildHMMprofiles::RunnableDB::HclusterParseOutput;
#package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'immediate_dataflow'    => 1,
            'member_type'           => 'protein',
    };
}


sub run {
    my $self = shift @_;

    $self->parse_hclusteroutput;
}


sub write_output {
    my $self = shift @_;

#    $self->store_clusterset('default', $self->param('allclusters'));

#    if (defined $self->param('additional_clustersets')) {
#        foreach my $clusterset_id (@{$self->param('additional_clustersets')}) {
#            $self->create_clusterset($clusterset_id);
#        }
#    }
}


##########################################
#
# internal methods
#
##########################################

sub parse_hclusteroutput {
    my $self = shift;

    my $filename            = $self->param('cluster_dir') . '/hcluster.out';
    my $hcluster_parse_file = $self->param('cluster_dir') . '/hcluster_parse.out'; 

#    my %allclusters = (); # Need to store clusters for MSAChooser
#    $self->param('allclusters', \%allclusters);
    
    open(FILE_2, ">$hcluster_parse_file") or die "Could not open '$hcluster_parse_file' for writing : $!";
       print FILE_2 "cluster_id\tgenes_count\tcluster_list\n";   
 
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
	my $genes_count  = scalar(@cluster_list);

	print FILE_2 "$cluster_id\t$genes_count\t$cluster_list\n";
        # If it's a singleton, we don't store it as a protein tree
#        next if (2 > scalar(@cluster_list));
#        $allclusters{$cluster_id} = { 'members' => \@cluster_list };
    }
    close FILE;
    close FILE_2;
}


1;
