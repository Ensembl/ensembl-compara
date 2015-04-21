=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomeStoreNCMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomeStoreNCMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$g_load_members->fetch_input(); #reads from DB
$g_load_members->run();
$g_load_members->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

A job factory that first iterates through all top-level slices of the corresponding core database and collects ncRNA gene stable_ids,
then loads all individual ncRNA members for the given genome_db.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomeStoreNCMembers;

use strict;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::SeqMember;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Read the parameters and set up all necessary objects.

=cut

sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');

        # fetch the Compara::GenomeDB object for the genome_db_id
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with id=$genome_db_id";
    $self->param('genome_db', $genome_db);
  
        # using genome_db_id connect to external core database
    my $core_db = $genome_db->db_adaptor() or die "Can't connect to genome database for id=$genome_db_id";
    $self->param('core_db', $core_db);

       # GeneMember and SeqMember adaptors
    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
    $self->param('seq_member_adaptor',  $self->compara_dba->get_SeqMemberAdaptor);

    return;
}


=head2 run

    Iterate through all top-level slices of the corresponding core database and collect ncRNA gene stable_ids

=cut

sub run {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_when_inactive(0);
    $self->param('core_db')->dbc->disconnect_when_inactive(0);

#    my @stable_ids = ();

        # from core database, get all slices, and then all genes in slice
        # and then all transcripts in gene to store as members in compara
    my @slices = @{$self->param('core_db')->get_SliceAdaptor->fetch_all('toplevel')};
    print("fetched ",scalar(@slices), " slices to load from\n");
    die "No toplevel slices, cannot fetch anything" unless(scalar(@slices));

    foreach my $slice (@slices) {
        foreach my $gene (sort {$a->start <=> $b->start} @{$slice->get_all_Genes}) {
            if ($gene->biotype =~ /rna/i) {
#                my $gene_stable_id = $gene->stable_id or die "Could not get stable_id from gene with id=".$gene->dbID();
                $self->store_nc_gene($gene);
#                push @stable_ids, $gene_stable_id;
            }
        }
    }

#    $self->param('stable_ids', \@stable_ids);

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $self->param('core_db')->dbc->disconnect_when_inactive(1);
}


=head2 write_output

    Create downstream jobs that will be loading individual ncRNA members

=cut

# sub write_output {
#     my $self = shift @_;

    # my $genome_db_id    = $self->param('genome_db_id');

    # foreach my $stable_id (@{ $self->param('stable_ids') }) {
    #     $self->dataflow_output_id( {
    #         'genome_db_id'    => $genome_db_id,
    #         'stable_id'       => $stable_id,
    #     }, 2);
    # }
#}

sub store_ncrna_gene {
    my ($self, $gene) = @_;

    my $core_db = $self->param('core_db');
    my $gene_member_adaptor = $self->param('gene_member_adaptor');
    my $seq_member_adaptor  = $self->param('seq_member_adaptor');

    my $longest_ncrna_member;
    my $max_ncrna_length = 0;
    my $gene_member;
    my $gene_member_stored = 0;

    for my $transcript (@{$gene->get_all_Transcripts}) {
        if (defined $transcript->translation) {
            warn ("Translation exists for ncRNA transcript ", $transcript->stable_id, "(dbID=", transcript->dbID. ")\n");
            next;
        }

        print STDERR "   transcript " . $transcript->stable_id  if ($self->debug);
        my $fasta_description = $self->fasta_description($gene, $transcript);
        next unless (defined $fasta_description);

        my $ncrna_member = Bio::EnsEMBL::Compara::SeqMember->new_from_Transcript(
                                                                             -transcript => $transcript,
                                                                             -genome_db => $self->param('genome_db'),
                                                                            );
        $ncrna_member->description($fasta_description);
        print STDERR  " => ncrna_member " . $ncrna_member->stable_id if ($self->debug);
        my $transcript_spliced_seq = $transcript->spliced_seq;

        # store gene_member here only if at least one ncRNA is to be loaded for the gene
        if ($self->param('store_genes') and (! $gene_member_stored)) {
            print STDERR "    gene    " . $gene->stable_id if ($self->debug);

            $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_Gene(
                                                                            -gene => $gene,
                                                                            -genome_db => $self->param('genome_db'),
                                                                           );
            print STDERR " => gene_member " . $gene_member->stable_id if ($self->debug);

            eval {
                $gene_member_adaptor->store($gene_member);
                print STDERR " : stored gene_member\n" if ($self->debug);
            };

            print STDERR "\n" if ($self->debug);
            $gene_member_stored = 1;
        }
        $ncrna_member->gene_member_id($gene_member->dbID);
        $seq_member_adaptor->store($ncrna_member);
        print STDERR " : stored ncrna_member\n" if ($self->debug);

        ## Probably here we will to include here the hack to avoid merged lincRNAs and short ncRNAs
        if (length($transcript_spliced_seq) > $max_ncrna_length) {
            $max_ncrna_length = length($transcript_spliced_seq);
            $longest_ncrna_member = $ncrna_member;
        }
    }
    if (defined $longest_ncrna_member) {
        $seq_member_adaptor->_set_member_as_canonical($longest_ncrna_member); ## Watchout merged genes!
    }

}

sub fasta_description {
    my ($self, $gene, $transcript) = @_;
    my $acc = 'NULL';
    my $biotype;
    eval { $acc = $transcript->display_xref->primary_id };

    unless ($acc =~ /RF00/) {
        $biotype = $transcript->biotype;
        if ( ($biotype =~ /miRNA/) || ($biotype =~ /lincRNA/) ) {
            my $exon = $transcript->get_all_Exons->[0];
            my $supporting_feature = $exon->get_all_supporting_features->[0];
            eval { $acc = $supporting_feature->hseqname };
        } elsif ($biotype =~ /snoRNA/) {
            eval { $acc = $transcript->external_name };
        } else {
            eval { $acc = $gene->get_all_xrefs('RFAM')->[0]->primary_id() };
        }
    }

    my $description = "Transcript:" . $transcript->stable_id  .
                      " Gene:"      . $gene->stable_id        .
                      " Chr:"       . $gene->seq_region_name  .
                      " Start:"     . $gene->seq_region_start .
                      " End:"       . $gene->seq_region_end   .
                      " Acc:"       . $acc;
    print STDERR "Description... $description\n" if ($self->debug);
    return $description;
}

1;

