package Bio::EnsEMBL::Compara::RunnableDB::FamilyMafft;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Hive::Process');

sub compara_dba {
    my $self = shift @_;

    return $self->{'comparaDBA'} ||= Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
}

sub param {
    my $self = shift @_;

    unless($self->{'_param_hash'}) {
        $self->{'_param_hash'} = { %{eval($self->parameters())}, %{eval($self->input_id())} };
    }

    my $param_name = shift @_;
    if(@_) { # If there is a value (even if undef), then set it!
        $self->{'_param_hash'}{$param_name} = shift @_;
    }

    return $self->{'_param_hash'}{$param_name};
}

sub fetch_input {
    my $self = shift @_;

    my $family_id               = $self->param('family_id')   || die "'family_id' is an obligatory parameter, please set it in the input_id hashref";

    my $family = $self->compara_dba()->get_FamilyAdaptor()->fetch_by_dbID($family_id);

    $self->param('family', $family); # and save it for the future

    if(!defined($family)) {
        die "Failed: family $family_id could not have been fetched by the adaptor";
    }

    my $aln;
    eval {$aln = $family->get_SimpleAlign};
    unless ($@) {
        if(defined(my $flush = $aln->is_flush)) { # looks like this family is already aligned
            return 1;
        }
    }

    my @members_attributes = ();

    push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

    if(scalar @members_attributes == 0) {
        die "Failed: family $family_id does not seem to contain any members";

    } elsif(scalar @members_attributes == 1) {    # the simple singleton case: just load the fake cigar_line

        my ($member,$attribute) = @{$members_attributes[0]};

        my $cigar_line = length($member->sequence).'M';
        eval { $attribute->cigar_line($cigar_line) };
        if($@) {
            die "Failed: could not set the cigar_line for singleton family $family_id, because: $@ ";
        }

            # by setting this parameter we will trigger the update in write_output()
        $self->param('singleton_relation', [$member, $attribute]);

        return 1;
    }

    # otherwise prepare the files and perform the actual mafft run:

    my $rand = time().rand(1000);
    my $pep_file   = "/tmp/family_${family_id}.pep.$rand";
    my $mafft_file = "/tmp/family_${family_id}.mafft.$rand";

    open PEP, ">$pep_file";
    foreach my $member_attribute (@members_attributes) {
        my ($member,$attribute) = @{$member_attribute};
        my $member_stable_id = $member->stable_id;
        my $seq = $member->sequence;

        print PEP ">$member_stable_id\n";
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        unless (defined($seq)) {
            die "Failed: member $member_stable_id in family $family_id doesn't have a sequence";
        }
        print PEP $seq,"\n";
    }
    close PEP;

        # if these two parameters are set, run() will need to actually execute mafft
    $self->param('pep_file', $pep_file);
    $self->param('mafft_file', $mafft_file);

    $self->dbc->disconnect_when_inactive(1);

    return 1;
}

sub run {
    my $self = shift @_;

    my $debug                   = $self->param('debug')         || 0;
    my $family_id               = $self->param('family_id');
    my $mafft_root              = $self->param('mafft_root')    || '/software/ensembl/compara';
    my $mafft_bindir            = $self->param('mafft_bindir')  || ( $mafft_root . '/mafft-6.522' );
    my $mafft_executable        = $self->param('mafft_exec')    || ( $mafft_root . '/mafft-6.522/bin/mafft' );
    my $mafft_args              = $self->param('mafft_args')    || '';

    my $pep_file                = $self->param('pep_file');
    my $mafft_file              = $self->param('mafft_file');

    unless($pep_file) { # if we have no more work to do just exit gracefully
        return 1;
    }

    $ENV{MAFFT_BINARIES} = $mafft_bindir; # set it for all exec'd processes

    my $cmd_line = "$mafft_executable $mafft_args $pep_file > $mafft_file";
    if($debug) {
        warn "About to execute: $cmd_line\n";
    }

    if(system($cmd_line)) {
        die "Failed: running mafft on family $family_id failed, because: $! ";
    }

        # the file(s) will be removed on success and should stay undeleted on failure
    unless($debug) {
        unlink $pep_file;
    }
}

sub write_output {
    my $self = shift @_;

    my $debug                   = $self->param('debug')       || 0;

    if(my $singleton_relation = $self->param('singleton_relation')) {

        $self->compara_dba()->get_FamilyAdaptor()->update_relation( $singleton_relation );

    } elsif(my $mafft_file = $self->param('mafft_file')) {

        my $family = $self->param('family');
        $family->load_cigars_from_fasta($mafft_file, 1);

        unless($debug) {
            unlink $mafft_file;
        }
    } # otherwise we had no work to do and no files to remove

    return 1;
}

1;

