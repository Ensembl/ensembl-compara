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
use warnings;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::SeqMember;

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

    my $genome_db_id = $self->param_required('genome_db_id');

        # fetch the Compara::GenomeDB object for the genome_db_id
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with id=$genome_db_id";
    $self->param('genome_db', $genome_db);
  
        # using genome_db_id connect to external core database
    my $core_db = $genome_db->db_adaptor() or die "Can't connect to genome database for id=$genome_db_id";
    $self->param('core_db', $core_db);

    $self->_load_biotype_groups($self->param_required('production_db_url'));

    return;
}


=head2 run

    Iterate through all top-level slices of the corresponding core database and collect ncRNA gene stable_ids

=cut

sub run {
    my $self = shift @_;

    # It may take some time to load the slices, so let's free the connection
    $self->compara_dba->dbc->disconnect_if_idle();

#    my @stable_ids = ();

        # from core database, get all slices, and then all genes in slice
        # and then all transcripts in gene to store as members in compara
    my @slices = @{$self->param('core_db')->get_SliceAdaptor->fetch_all('toplevel')};
    print("fetched ",scalar(@slices), " slices to load from\n");
    die "No toplevel slices, cannot fetch anything" unless(scalar(@slices));

    $self->param('core_db')->dbc->prevent_disconnect( sub { $self->compara_dba->dbc->prevent_disconnect( sub {
      foreach my $slice (@slices) {

        ### ochotona_princeps datafix
        # some scaffolds that belong to genescaffolds are marked as
        # toplevel, but they shouldn't. Skip them !
        if (($self->param('genome_db') eq 'ochotona_princeps') and ($slice->coord_system_name eq 'scaffold')) {
          my $mapped_slice = $slice->project('genescaffold')->[0];
          if (defined($mapped_slice)) {
            print STDERR $slice->seq_region_name, " is redundant with a genescaffold\n";
            next;
          }
        }
        ### ochotona_princeps datafix

        foreach my $gene (sort {$a->start <=> $b->start} @{$slice->get_all_Genes}) {
            if ($gene->biotype =~ /rna/i) {
#                my $gene_stable_id = $gene->stable_id or die "Could not get stable_id from gene with id=".$gene->dbID();
                $self->store_ncrna_gene($gene);
#                push @stable_ids, $gene_stable_id;
            }
        }
      }
    } ) } );

#    $self->param('stable_ids', \@stable_ids);

}


sub store_ncrna_gene {
    my ($self, $gene, $dnafrag) = @_;

    my $gene_member_adaptor = $self->compara_dba->get_GeneMemberAdaptor();
    my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor();

    my $longest_ncrna_member;
    my $max_ncrna_length = 0;
    my $gene_member;
    my $gene_member_stored = 0;

    my $merged_short_and_long_ncRNA = 0;
    my %biotypes = map{$_->biotype => 1}@{$gene->get_all_Transcripts};
    if ((scalar keys %biotypes > 1) and (defined $biotypes{'lincRNA'})) {
        $merged_short_and_long_ncRNA = 1;
    }

    for my $transcript (@{$gene->get_all_Transcripts}) {
        next if ($merged_short_and_long_ncRNA and ($transcript->biotype eq 'lincRNA'));

        if (defined $transcript->translation) {
            warn ("Translation exists for ncRNA transcript ", $transcript->stable_id, "(dbID=", $transcript->dbID. ")\n");
            next;
        }

        print STDERR "   transcript " . $transcript->stable_id  if ($self->debug);
        my $fasta_description = $self->_ncrna_description($gene, $transcript);

        my $ncrna_member = Bio::EnsEMBL::Compara::SeqMember->new_from_Transcript(
                                                                             -transcript => $transcript,
                                                                             -dnafrag => $dnafrag,
                                                                             -genome_db => $self->param('genome_db'),
                                                                            );
        $ncrna_member->description($fasta_description);

        print STDERR "SEQMEMBER: ", $ncrna_member->description, "    ... ", $ncrna_member->display_label, "\n" if ($self->debug);

        print STDERR  " => ncrna_member " . $ncrna_member->stable_id if ($self->debug);
        my $transcript_spliced_seq = $ncrna_member->sequence;
        if ($transcript_spliced_seq =~ /^N+$/i) {
            $self->warning($transcript->stable_id . " cannot be loaded because its sequence is only composed of Ns");
            next;
        }

        # store gene_member here only if at least one ncRNA is to be loaded for the gene
        if ($self->param('store_genes') and (! $gene_member_stored)) {
            print STDERR "    gene    " . $gene->stable_id if ($self->debug);

            my $biotype_group = $self->param('biotype_groups')->{lc $gene->biotype};
            $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_Gene(
                                                                            -gene => $gene,
                                                                            -dnafrag => $dnafrag,
                                                                            -genome_db => $self->param('genome_db'),
                                                                            -biotype_group => $biotype_group,
                                                                           );
            print STDERR " => gene_member " . $gene_member->stable_id if ($self->debug);

            eval {
                $gene_member_adaptor->store($gene_member);
                print STDERR " : stored gene gene_member\n" if ($self->debug);
            };

            print STDERR "\n" if ($self->debug);
            $gene_member_stored = 1;
        }
        $ncrna_member->gene_member_id($gene_member->dbID);
        $seq_member_adaptor->store($ncrna_member);
        print STDERR " : stored seq gene_member\n" if ($self->debug);
        if ($self->param('store_exon_coordinates') and $self->can('store_exon_coordinates')) {
            $self->store_exon_coordinates($transcript, $ncrna_member);
        }

        $self->_store_seq_member_projection($ncrna_member, $transcript);

        ## Probably we will include here the hack to avoid merged lincRNAs and short ncRNAs
        if (length($transcript_spliced_seq) > $max_ncrna_length) {
            $max_ncrna_length = length($transcript_spliced_seq);
            $longest_ncrna_member = $ncrna_member;
        }
    }
    if (defined $longest_ncrna_member) {
        $seq_member_adaptor->_set_member_as_canonical($longest_ncrna_member); ## Watchout merged genes!
    }

    return $gene_member;
}

sub _ncrna_description {
    my ($self, $gene, $transcript) = @_;
    my $acc = 'NULL';
    my $biotype;
    eval { $acc = $transcript->display_xref->primary_id };

    unless ($acc =~ /RF00/) {
        $biotype = $transcript->biotype;
        if ( ($biotype =~ /miRNA/) or ($biotype =~ /lincRNA/) )  {
            my $exons = $transcript->get_all_Exons;
            # lincRNAs can have alternative splicing (so, the next line is commented out)
            # $self->throw("unexpected ncRNA (" . $transcript->stable_id  . ") with more than one exon") if (scalar @$exons > 1);
            my $exon = $exons->[0];
            my $supporting_features = $exon->get_all_supporting_features;
            if (scalar @$supporting_features) {
                eval { $acc = $supporting_features->[0]->hseqname; };
            }
        } elsif ($biotype =~ /snoRNA/) {
            my $exons  = $transcript->get_all_Exons;
            # if (scalar @$exons > 1) {
            #     for my $exon (@$exons) {
            #         print STDERR "EXON: " . $exon->stable_id , "\n";
            #     }
            #     $self->throw("unexpected snoRNA (" . $transcript->stable_id  . ") with more than one exon");
            # }
            my $exon = $exons->[0];
            my $supporting_features = $exon->get_all_supporting_features;
            if (scalar @$supporting_features) {
                my $hseqname = $supporting_features->[0]->hseqname;
                if ($hseqname =~ /(RF\d+)/) {
                    $acc = $1;
                } else {
                    eval { $acc = $transcript->external_name };
                }
            }
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
    print STDERR " Description... $description\n" if ($self->debug);
    return $description;
}

sub _load_biotype_groups {
    my ($self, $production_db_url) = @_;

    my $gene_biotype_sql = q{SELECT name, IF(is_current=1, IF(is_dumped=1, biotype_group, 'current_notdumped'), 'notcurrent') AS biotype_group FROM biotype WHERE object_type = "gene" AND FIND_IN_SET('core', db_type)};

    my $production_dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-url => $production_db_url);
    my %biotype_groups = map {lc($_->[0]) => $_->[1]} @{ $production_dbc->db_handle->selectall_arrayref($gene_biotype_sql) };
    $self->param('biotype_groups', \%biotype_groups);
    $production_dbc->disconnect_if_idle();
}

sub _store_seq_member_projection {
    my ($self, $seq_member, $transcript) = @_;

    my @proj_attrib = @{ $transcript->get_all_Attributes('proj_parent_t') };
    if (@proj_attrib) {
        my $parent_name = $proj_attrib[0]->value;
        $parent_name =~ s/\.\d+$//;   # strip the version out
        $self->compara_dba->dbc->do('INSERT INTO seq_member_projection_stable_id (target_seq_member_id, source_stable_id) VALUES (?,?)', undef, $seq_member->dbID, $parent_name);
    }
}

1;

