
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMOverlapSystemCmd;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub fetch_input {
    my $self = shift;
    my $cmd = join(' ',
        $self->param_required('python_script'),
        @{$self->param_required('script_args')},
        @{$self->param_required('input_list')},
        '>',
        $self->param_required('output_file'),
    );
    $self->param('cmd', $cmd);
}

1;
