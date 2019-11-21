=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HomologyGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, flows Homology_dNdS jobs.

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'group_size'         => 500,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('homo_mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $genome_dbs = $mlss->species_set->genome_dbs;

    my @homology_ids;
    my $homology_flatfile = $self->param_required('homology_flatfile');
    my $do_gene_qc = $self->param('do_gene_qc');
    my $qc_status;
    if ( $do_gene_qc ) {
        my @genome_db_ids = map {$_->dbID} @$genome_dbs;
        my @placeholders  = map {'?'} @$genome_dbs;
        my $sql = 'SELECT seq_member_id, status FROM gene_member_qc WHERE genome_db_id IN (' . join(', ', @placeholders) . ')';
        $qc_status = $self->compara_dba->dbc->sql_helper->execute_into_hash(
            -SQL => $sql,
            -PARAMS => \@genome_db_ids,
        );
    }
    
    open( my $hffh, '<', $homology_flatfile ) or die "Cannot open $homology_flatfile for reading";
    my $hheader = <$hffh>;
    my @hhead_cols = split(/\s+/, $hheader);
    while( my $line = <$hffh> ) {
        my $row = map_row_to_header( $line, \@hhead_cols );
        my ( $homology_id, $homology_type, $sm_id_1, $sm_id_2 ) = ($row->{homology_id}, $row->{homology_type}, $row->{seq_member_id}, $row->{hom_seq_member_id});
        next if (!$do_gene_qc) && $homology_type eq 'gene_split';
        next if $do_gene_qc && (defined $qc_status->{$sm_id_1} || defined $qc_status->{$sm_id_2});
        push @homology_ids, $homology_id;
    }
    close $hffh;

    $self->param('inputlist', \@homology_ids);

    # check if a homology id mapping exists
    my $hom_map_file = $self->param('homology_mapping_flatfile');
    return unless defined $hom_map_file && -e $hom_map_file;

    #Get homology id mapping
    my $homology_map;
    open( my $hmfh, '<', $hom_map_file ) or die "Cannot open $hom_map_file for reading";
    my $mheader = <$hmfh>;
    my @mhead_cols = split(/\s+/, $mheader);
    while ( my $line = <$hmfh> ) {
        my $row = map_row_to_header( $line, \@mhead_cols );
        $homology_map->{$row->{curr_release_homology_id}} = $row->{prev_release_homology_id};
    }
    close $hmfh;

    $self->param('homology_map', $homology_map);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');
    my $homology_map = $self->param('homology_map') || {};
    my $group_size = $self->param('group_size');

    $self->input_job->autoflow(0) if scalar(@$inputlist) == 0;

    my %job_hash_copy;
    my @job_array_compute = ();

    foreach my $homology_id (@$inputlist) {
        if ( exists( $homology_map->{$homology_id} ) ) {
            $job_hash_copy{$homology_id} = $homology_map->{$homology_id};
        }
        else {
            push( @job_array_compute, $homology_id );
        }
    }

    my @job_array_copy = keys(%job_hash_copy);
    if ( scalar(@job_array_copy) > 0 ) {
        while (@job_array_copy) {
            my @job_array = splice( @job_array_copy, 0, $group_size );

            my %job_hash;
            foreach my $homology_id (@job_array){
                $job_hash{$homology_id} = $job_hash_copy{$homology_id};
            }

            my $output_id;
            $output_id->{'mlss_id'}      = $self->param('homo_mlss_id');
            $output_id->{'homology_ids'} = \%job_hash;
            $self->dataflow_output_id( $output_id, 3 );
        }
    }

    if ( scalar(@job_array_compute) > 0 ){
        while (@job_array_compute){
            my @job_array = splice(@job_array_compute, 0, $group_size);

            my $output_id;
            $output_id->{'mlss_id'}      = $self->param('homo_mlss_id');
            $output_id->{'homology_ids'} = \@job_array;
            $self->dataflow_output_id( $output_id, 2 );
        }
    }
}

1;
