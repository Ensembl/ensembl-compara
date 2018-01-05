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

Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory

=head1 DESCRIPTION

This is a Compara-specific generic job factory that:
    1) Starting with the $self object executes a list of calls
      (usually, getting the database, then an adaptor, calling a fetch, etc) which returns a list in the end.
    2) Iterates through the list and flows each object into a job using a given getter-to-column mapping.

It also serves as a good simple example of a Compara job factory:
    1) Inherits main factory functionality from Hive::RunnableDB::JobFactory
    2) Inherits Compara-specific functionality (like $self->compara_dba ) from Compara::RunnableDB::BaseRunnable
    3) Only defines fetch_input() method that takes specific parameters, uses API to fetch data and sets the $self->param('inputlist') in the end.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Utils 'stringify';

    # Note: the order is important, this is a true example of Multiple Inheritance:
use base ('Bio::EnsEMBL::Hive::RunnableDB::JobFactory', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $call_list               = $self->param('call_list')
        or die "The old way of configuring this runnable is no longer supported; please set 'call_list' parameter and get more flexibility";

    my $current_result = $self;

    foreach my $call (@$call_list) {
        $call = [ $call ] unless(ref($call));

        my $method = shift @$call or die "Method is missing or didn't properly resolve";

        $current_result = $current_result->$method( @$call ) || die "Calling $current_result -> $method(".stringify(@$call).") returned a False";
    }

    if( ref($current_result) ne 'ARRAY') {
        $current_result = [ $current_result ];
    }

    # now that we have an arrayref of things...

    if(my $column_names2getters = $self->param('column_names2getters') ) {

        my @getters             = values %$column_names2getters;
        my @inputlist           = ();

        foreach my $object (@$current_result) {
            push @inputlist, [ map { $object->$_ } @getters ];
        }
        $self->param('column_names', [ keys %$column_names2getters ] );
        $self->param('inputlist',    \@inputlist);

    } else {   # caller should set 'column_names' for better results

        $self->param('inputlist', $current_result);
    }
}

1;
