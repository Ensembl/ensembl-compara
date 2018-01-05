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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ObjectStore

=head1 SYNOPSIS

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ObjectStore \
                    -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2911/lg4_compara_families_66" \
                    -object_type Method \
                    -foo BOO \
                    -arglist "[ -type => '#foo#bar_type', -class => '#foo#bar_class' ]" \
                    -debug 1

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ObjectStore \
                    -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2911/lg4_compara_families_66" \
                    -reference_db "mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2911/lg4_test_master_67" \
                    -object_type GenomeDB \
                    -arglist "[ -name => 'big_fury_animal', -assembly => 'asm1.0', -genebuild => '2012-01-EnsemblTest', -taxon_id => 9598 ]" \
                    -debug 1

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ObjectStore \
                    -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2911/lg4_compara_families_66" \
                    -object_type SpeciesSet \
                    -arglist "[ -genome_dbs => [ {-name => 'homo_sapiens', -taxon_id => 9606, -assembly => 'GRCh37', -genebuild => '2010-07-Ensembl'}, { -name => 'big_fury_animal', -taxon_id => 9598, -assembly => 'asm1.0', -genebuild => '2012-01-EnsemblTest' } ] ]" \
                    -debug 1

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ObjectStore \
                    -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2911/lg4_compara_families_66" \
                    -object_type MethodLinkSpeciesSet \
                    -arglist "[ -name => 'foo_mlss', -method => { -type => 'LASTZ_NET', -class => 'GenomicAlignBlock.pairwise_alignment' }, -species_set => { -genome_dbs => [ {-name => 'homo_sapiens', -taxon_id => 9606, -assembly => 'GRCh37', -genebuild => '2010-07-Ensembl'}, { -name => 'big_fury_animal', -taxon_id => 9598, -assembly => 'asm1.0', -genebuild => '2012-01-EnsemblTest' } ] } ]" \
                    -debug 1

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ObjectStore \
                    -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2914/lg4_compara_families_70" \
                    -object_type SpeciesSet \
                    -arglist "[ -genome_dbs => [] ]" \
                    -flow_into "{ 2 => { 'mysql://ensadmin:${ENSADMIN_PSW}@127.0.0.1:2914/lg4_compara_families_70/meta' => { 'meta_key' => 'reuse_ss_id', 'meta_value' => '#dbID#' } } }" \
                    -debug 1

=head1 DESCRIPTION

This is a Compara-specific generic runnable that creates a storable object and stores it.
    If param('reference_db') is set, it will pre-set it in the adaptor and synchronize ids with it.
    param('arglist') accepts substitutions.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ObjectStore;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $compara_dba     = $self->compara_dba()          or die "Definitely need a Compara database to store a Compara object";
    my $object_type     = $self->param_required('object_type');
    my $arglist         = $self->param('arglist') || [];

    if(my $reference_db = $self->param('reference_db')) {
        my $reference_dba = $self->get_cached_compara_dba('reference_db');

        $compara_dba->reference_dba( $reference_dba );

        warn "Storing with a reference_db ($reference_db)\n" if($self->debug());
    } else {
        warn "Storing without a reference_db\n" if($self->debug());
    }

    my $object_adaptor  = $compara_dba->get_adaptor( $object_type ) or die "Could not create adaptor for '$object_type'";

    my $object_class    = ($object_adaptor->can('object_class') && $object_adaptor->object_class()) or die "No support for '$object_type' yet";

    my $object          = $object_class->new( @$arglist ) or die "Object $object_type(".join(', ',@$arglist).") not created";

    $object_adaptor->store( $object, 1 );

    warn "Object after storing:\n\t".$object->toString()."\n" if($self->debug());

    $self->param('dbID', $object->dbID()) or die "dbID not returned - probably not stored";
}


sub write_output {
    my $self = shift @_;

    $self->dataflow_output_id( {
        'object_type'   => $self->param('object_type'),
        'dbID'          => $self->param('dbID'),
    }, 2);
}

1;
