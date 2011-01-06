package Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $family_id               = $self->param('family_id')   || die "'family_id' is an obligatory parameter, please set it in the input_id hashref";

    my $family = $self->compara_dba()->get_FamilyAdaptor()->fetch_by_dbID($family_id);

    $self->param('family', $family); # and save it for the future

    if(!defined($family)) {
        die "family $family_id could not have been fetched by the adaptor";
    }

    my $aln;
    eval {$aln = $family->get_SimpleAlign};
    unless ($@) {
        if(defined(my $flush = $aln->is_flush)) { # looks like this family is already aligned
            return;
        }
    }

    my @members_attributes = ();

    push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

    if(scalar @members_attributes == 0) {
        die "family $family_id does not seem to contain any members";

    } elsif(scalar @members_attributes == 1) {    # the simple singleton case: just load the fake cigar_line

        my ($member,$attribute) = @{$members_attributes[0]};

        my $cigar_line = length($member->sequence).'M';
        eval { $attribute->cigar_line($cigar_line) };
        if($@) {
            die "could not set the cigar_line for singleton family $family_id, because: $@ ";
        }

            # by setting this parameter we will trigger the update in write_output()
        $self->param('singleton_relation', [$member, $attribute]);

        return;
    }

    # otherwise prepare the files and perform the actual mafft run:

    my $rand = time().rand(1000);
    my $pep_file   = "/tmp/family_${family_id}.pep.$rand";
    my $mafft_file = "/tmp/family_${family_id}.mafft.$rand";
    my $pep_counter = 0;

    open PEP, ">$pep_file";
    foreach my $member_attribute (@members_attributes) {
        my ($member,$attribute) = @{$member_attribute};
        my $member_stable_id = $member->stable_id;
        my $seq = $member->sequence;

        print PEP ">$member_stable_id\n";
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        unless (defined($seq)) {
            die "member $member_stable_id in family $family_id doesn't have a sequence";
        }
        print PEP $seq,"\n";
        $pep_counter++;
    }
    close PEP;

    if($pep_counter>=20000) {
        my $mafft_args = $self->param('mafft_args') || '';
        $self->param('mafft_args', $mafft_args.' --parttree' );
    }

        # if these two parameters are set, run() will need to actually execute mafft
    $self->param('pep_file', $pep_file);
    $self->param('mafft_file', $mafft_file);

    $self->dbc->disconnect_when_inactive(1);
}

sub run {
    my $self = shift @_;

    my $family_id               = $self->param('family_id');
    my $mafft_root_dir          = $self->param('mafft_root_dir') || '/software/ensembl/compara/mafft-6.522';
    my $mafft_executable        = $self->param('mafft_exec')     || ( $mafft_root_dir . '/bin/mafft' );
    my $mafft_args              = $self->param('mafft_args')     || '';

    my $pep_file                = $self->param('pep_file');
    my $mafft_file              = $self->param('mafft_file');

    unless($pep_file) { # if we have no more work to do just exit gracefully
        return;
    }

    $ENV{MAFFT_BINARIES} = $mafft_root_dir; # set it for all exec'd processes

    my $cmd_line = "$mafft_executable $mafft_args $pep_file > $mafft_file";
    if($self->debug) {
        warn "About to execute: $cmd_line\n";
    }

    if(system($cmd_line)) {
        die "running mafft on family $family_id failed, because: $! ";
    } elsif(-z $mafft_file) {
        die "running mafft on family $family_id produced zero-length output";
    }

        # the file(s) will be removed on success and should stay undeleted on failure
    unless($self->debug) {
        unlink $pep_file;
    }
}

sub write_output {
    my $self = shift @_;

    if(my $singleton_relation = $self->param('singleton_relation')) {

        $self->compara_dba()->get_FamilyAdaptor()->update_relation( $singleton_relation );

    } elsif(my $mafft_file = $self->param('mafft_file')) {

        my $family = $self->param('family');
        $family->load_cigars_from_fasta($mafft_file, 1);

        unless($self->debug) {
            unlink $mafft_file;
        }
    } # otherwise we had no work to do and no files to remove
}

1;

