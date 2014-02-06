=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::RunnableDB::BuildHMMprofiles::NotifyUser;
#package Bio::EnsEMBL::Hive::RunnableDB::NotifyUser;

use strict;

use base ('Bio::EnsEMBL::Hive::Process');


sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    my $email            = $self->param('email')   || die "'email' parameter is obligatory";
    my $subject          = $self->param('subject') || "An automatic message from your pipeline";
    my $hmm_directory    = $self->param('hmmLib_dir'); 	
    my $text             = "$subject HMM libraries is available at $hmm_directory.\n";

    open (SENDMAIL, "|sendmail $email");
    print SENDMAIL "Subject: $subject\n";
    print SENDMAIL "\n";
    print SENDMAIL "$text\n";
    close SENDMAIL;
}

sub write_output {
}

1;
