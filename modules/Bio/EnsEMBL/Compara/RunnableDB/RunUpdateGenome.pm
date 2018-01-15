
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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RunUpdateGenome

=head1 SYNOPSIS

This runnable is used to:
    1 - run update_genome.pl


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to run update_genome.pl

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a "_"

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RunUpdateGenome;

use strict;
use warnings;

use File::Find;
use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');
use base ('Bio::EnsEMBL::Hive::Process');
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
             'master_db'            => '#master_db#',
             'work_dir'             => '#work_dir#',
             'registry_source'      => '#registry_source#',
             'update_genome_bin'    => '#update_genome_bin#',
         };
}

sub run {
    my $self = shift @_;

    #run update_genome.pl
    $self->_update_genome;
}

##########################################
#
# internal methods
#
##########################################

sub _update_genome {
    my $self = shift;

    my $cmd = join( ' ', "perl", $self->param('update_genome_bin'), "--reg_conf", $self->param('registry_source')."/".$self->param('reg_conf'), "--compara", $self->param('master_db'), "--species", $self->param('species_name'), "--force" );

    my $cmd_out = $self->run_command( $cmd, { die_on_failure => 1 } );

    my @out_lines = split(/\n/,$cmd_out->out);
    my $genome_db_id;

    foreach my $line_out (@out_lines) {
        if ($line_out =~ /^GenomeDB after update: GenomeDB dbID=/){
            my @tok = split(/\s+/, $line_out);
            $genome_db_id = substr($tok[4],5);
            last;
        }
    }

    $self->dataflow_output_id( $genome_db_id, 3 ); # to genomes_loaded_into_master table
}

1;
