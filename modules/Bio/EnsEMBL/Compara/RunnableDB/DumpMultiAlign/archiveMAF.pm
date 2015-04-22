=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::archiveMAF;

=head1 DESCRIPTION

=head1 AUTHOR

ckong

=cut
package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::archiveMAF;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my ($self) 	= @_;

return 0;
}

sub run {
    my ($self)  = @_;

    my $out_file    = $self->param_required('out_file')   || die "'out_file' is an obligatory parameter";
    my $output_dir  = $self->param_required('output_dir') || die "'output_dir' is an obligatory parameter";
   
    chdir $output_dir;

    my $list_cmd     = "ls $out_file*maf";
    my $return_value = system($list_cmd);

    if($return_value==0){
       my $archive_cmd  = "tar -zcvf $out_file.tar.gz $out_file*maf";

       if(my $return_value2 = system($archive_cmd)) {
          $return_value2 >>= 8;
          die "system( $archive_cmd ) failed: $return_value2";
       }
    }

return 0;
}

sub write_output {
    my ($self)  = @_;

return 0;
}


1;


