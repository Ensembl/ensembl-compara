#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GeneStoreNCMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GeneStoreNCMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$g_load_members->fetch_input(); #reads from DB
$g_load_members->run();
$g_load_members->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

Create members from a given ncRNA gene (both ncRNA members and gene member).

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GeneStoreNCMembers;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'store_genes'  => 1,    # whether genes are also stored as members
    };
}


=head2 fetch_input

    Read the parameters and set up all necessary objects.

=cut

sub fetch_input {
    my $self = shift @_;

    $self->input_job->transient_error(0);
    my $genome_db_id = $self->param('genome_db_id') || die "'genome_db_id' parameter is an obligatory one, please specify";
    my $stable_id = $self->param('stable_id')       || die "'stable_id' parameter is an obligatory one, please specify";
    $self->input_job->transient_error(1);

        # fetch the Compara::GenomeDB object for the genome_db_id
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with id=$genome_db_id";
    $self->param('genome_db', $genome_db);

        # using genome_db_id connect to external core database
    my $core_db = $genome_db->db_adaptor() or die "Can't connect to genome database for id=$genome_db_id";
    $self->param('core_db', $core_db);

}


=head2 run

    Fetch a particular gene and create members from its' non-coding transcript(s?) and the gene itself

=cut

sub run {
    my $self = shift @_;

    my $core_db     = $self->param('core_db');
    my $stable_id   = $self->param('stable_id');

    $self->compara_dba->dbc->disconnect_when_inactive(0);
    $core_db->dbc->disconnect_when_inactive(0);

    my $gene_adaptor = $core_db->get_GeneAdaptor or die "Could not create the core GeneAdaptor";

    my $gene = $gene_adaptor->fetch_by_stable_id( $stable_id ) or die "Could not fetch gene with stable_id '$stable_id'";

        # Store gene:
    $self->store_ncrna_gene($gene);

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $core_db->dbc->disconnect_when_inactive(1);
}



######################################
#
# subroutines
#
#####################################


sub store_ncrna_gene {
    my ($self, $gene) = @_;

    my $longest_ncrna_member;
    my $max_ncrna_length = 0;
    my $gene_member;
    my $gene_member_not_stored = 1;

    my $gene_member_adaptor = $self->compara_dba->get_GeneMemberAdaptor();
    my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor();

    my $pseudo_stableID_prefix = $self->param('pseudo_stableID_prefix');

    if($pseudo_stableID_prefix) {
        $gene->stable_id($pseudo_stableID_prefix ."G_". $gene->dbID);
    }

    TRANSCRIPT: foreach my $transcript (@{$gene->get_all_Transcripts}) {
        if (defined $transcript->translation) {
            warn("Translation exists for ncRNA transcript ", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
            next;
        }

        if($pseudo_stableID_prefix) {
            $transcript->stable_id($pseudo_stableID_prefix ."T_". $transcript->dbID);
        }

        print("     transcript " . $transcript->stable_id ) if($self->debug);

        my $fasta_description = $self->fasta_description($gene, $transcript) or next TRANSCRIPT;

        my $ncrna_member = Bio::EnsEMBL::Compara::SeqMember->new_from_transcript(
            -transcript  => $transcript,
            -genome_db   => $self->param('genome_db'),
            -translate   => 'ncrna',
            -description => $fasta_description,
        );

        print(" => member " . $ncrna_member->stable_id) if($self->debug);

        my $transcript_spliced_seq = $transcript->spliced_seq;

            # store gene_member here only if at least one ncRNA is to be loaded for the gene.
        if($self->param('store_genes') and $gene_member_not_stored) {
            print("     gene       " . $gene->stable_id ) if($self->debug);

            $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_gene(
                -gene      => $gene,
                -genome_db => $self->param('genome_db'),
            );
            print(" => member " . $gene_member->stable_id) if($self->debug);

            eval {
                $gene_member_adaptor->store($gene_member);
                print(" : stored") if($self->debug);
            };

            print("\n") if($self->debug);
            $gene_member_not_stored = 0;
        }

        $ncrna_member->gene_member_id($gene_member->dbID);
        $seq_member_adaptor->store($ncrna_member);
        print(" : stored\n") if($self->debug);

        if(length($transcript_spliced_seq) > $max_ncrna_length) {
            $max_ncrna_length     = length($transcript_spliced_seq);
            $longest_ncrna_member = $ncrna_member;
        }
    }

    if($longest_ncrna_member) {
        $seq_member_adaptor->_set_member_as_canonical($longest_ncrna_member);
    }
}

sub fasta_description {
    my ($self, $gene, $transcript) = @_;
    my $acc = 'NULL'; my $biotype = undef;
    $DB::single=1;1;
    eval { $acc = $transcript->display_xref->primary_id;};

    unless ($acc =~ /RF00/) {
        $biotype = $transcript->biotype;
        if ($biotype =~ /miRNA/) {
            my @exons = @{$transcript->get_all_Exons};
            $self->throw("unexpected miRNA with more than one exon") if (1 < scalar @exons);
            my $exon = $exons[0];
            my @supporting_features = @{$exon->get_all_supporting_features};
            if (scalar(@supporting_features)!=1) {
                warn "unexpected miRNA supporting features";
                next;
            }
            my $supporting_feature = $supporting_features[0];
            eval { $acc = $supporting_feature->hseqname; };
        } elsif ($biotype =~ /snoRNA/) {
            eval { $acc = $transcript->external_name; };
        } elsif ($biotype =~ /Mt_rRNA/) {
            # $acc = $biotype;
        } else {
            # Let's try with the gene
            eval { $acc = $gene->get_all_xrefs('RFAM')->[0]->primary_id(); };
        }
    }
    my $description = "Transcript:" . $transcript->stable_id .
                      " Gene:" .      $gene->stable_id .
                      " Chr:" .       $gene->seq_region_name .
                      " Start:" .     $gene->seq_region_start .
                      " End:" .       $gene->seq_region_end.
                      " Acc:" .       $acc;
    print STDERR "Description... $description\n" if ($self->debug);
    return $description;
}

1;
