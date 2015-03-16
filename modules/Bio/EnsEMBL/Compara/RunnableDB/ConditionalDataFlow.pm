=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow

=head1 SYNOPSIS

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow \
                    -condition '(#a# + #b#) <= 5' -a 3 -b 4   -debug 1

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow \
                    -compara_db mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_75 \
                    -condition '$self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID(#tree_id#)->get_value_for_tag("gene_count") > #threshold#' \
                    -tree_id 331961 -threshold 200 -debug 1

=head1 DESCRIPTION

    This is a generic RunnableDB module to dataflow into one branch or another depending on the result of a given condition.
    The condition is user-defined and evaluated with the parameter substitution mechanism. This means that it can include
    other parameters with #other_param# and even access $self->compara_dba

    The recognized parameters are:

        - condition: The condition to be evaluated
        - branch_if_success: the branch to dataflow to in case the condition is true (default is 2)
        - branch_if_failure: the branch to dataflow to in case the condition is false (default is 3)

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow;

use strict;

## We inherit from the Compara BaseRunnable to benefit from $self->compara_dba
#use base ('Bio::EnsEMBL::Hive::Process');
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub param_defaults {
    return {
        'branch_if_success' => 2,
        'branch_if_failure' => 3,
    };
}


=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
                  Here we rely on the parameter substitution mechanism to evaluate a user-defined condition

    param('condition'): The condition that has to be evaluated.

=cut

sub fetch_input {
    my $self = shift;

    my $condition = $self->param_required('condition');
    print STDERR "Condition is: ", $condition, "\n" if $self->debug;
    
    if (not ref($condition)) {
        $condition = eval($condition);
        $self->throw("Cannot evaluate 'condition' because of: $@") if $@;
        print STDERR "eval() returned $condition\n" if $self->debug;
    }

    my $result = $condition ? 1 : 0;

    ## I'm not sure this is useful. Let's comment it for now
    ## Special tests: for arrays and hashes, we check their size
    #if (ref($condition)) {
    #
    #    if (ref($condition) eq 'ARRAY') {
    #        $result = scalar(@$condition);
    #        print STDERR "array of $result elements\n";
    #
    #    } elsif (ref($condition) eq 'HASH') {
    #        $result = scalar(keys %$condition);
    #        print STDERR "hash of $result elements\n";
    #
    #    }
    #}

    $self->param('result', $result);
}


=head2 write_output

    Description : Implements write_output() interface method of Bio::EnsEMBL::Hive::Process that is used to deal with job's output after the execution.
                  Here we simply dataflow to the correct branch based on 'result'

    param('result'): set by fetch_input()
    param('branch_if_success'): the branch number if the condition is evaluated to true
    param('branch_if_failure'): the branch number if the condition is evaluated to false

=cut

sub write_output {  # nothing to write out, but some dataflow to perform:
    my $self = shift @_;

    my $result = $self->param('result');

    if ($result) {
        print STDERR "Success: dataflowing to branch #".$self->param_required('branch_if_success')."\n" if $self->debug;
        $self->dataflow_output_id($self->input_id, $self->param_required('branch_if_success'));
    } else {
        print STDERR "Failure: dataflowing to branch #".$self->param_required('branch_if_failure')."\n" if $self->debug;
        $self->dataflow_output_id($self->input_id, $self->param_required('branch_if_failure'));
    }
}

1;
