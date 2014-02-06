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
