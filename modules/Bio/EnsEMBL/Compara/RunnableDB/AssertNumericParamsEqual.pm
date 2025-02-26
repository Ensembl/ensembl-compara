=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AssertNumericParamsEqual

=head1 DESCRIPTION

A small runnable to check that the values of two numeric parameters are equal.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AssertNumericParamsEqual;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my ($param1_name, $param2_name) = @{$self->param_required('param_names')};
    my $param1_value = $self->param_required($param1_name);
    my $param2_value = $self->param_required($param2_name);

    unless (looks_like_number($param1_value)) {
        $self->die_no_retry("Value of parameter $param1_name ($param1_value) does not appear to be numeric");
    }

    unless (looks_like_number($param2_value)) {
        $self->die_no_retry("Value of parameter $param2_name ($param2_value) does not appear to be numeric");
    }

    unless ($param1_value == $param2_value) {
        $self->die_no_retry("Parameters $param1_name ($param1_value) and '$param2_name' ($param2_value) are not numerically equal");
    }
}


1;
