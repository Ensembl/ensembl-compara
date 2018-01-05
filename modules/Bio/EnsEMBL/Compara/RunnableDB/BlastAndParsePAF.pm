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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF 

=head1 DESCRIPTION

Run ncbi_blastp and parse the output into PeptideAlignFeature objects.
Store PeptideAlignFeature objects in the compara database
Supported keys:
    'blast_param' => <string>
        ncbi blastp parameters
eg "seg 'yes' -best_hit_overhang 0.2 -best_hit_score_edge 0.1 -use_sw_tback"
    'fasta_dir' => <directory path>
        Path to fasta files
    'mlss_id' => <number>
        Method link species set id for Pecan. Obligatory
    'genome_db_id' => <number>
        Species genome db id.
    'reuse_ss_id' => <number>
        Reuse species set id. Normally stored in the meta table. Obligatory.
    'output_db' => Compara URL (optional)
        By default the blast hits will be stored in the same database as the
        members themselves, but they can be written to 'output_db' instead.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastAndParsePAF;

use strict;
use warnings;

use File::Basename;

use FileHandle;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Compara::MemberSet;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;

use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::Utils::Preloader;

sub param_defaults {
    my $self = shift;
    return {
            %{$self->SUPER::param_defaults},
            'evalue_limit'  => 1e-5,
            'tophits'       => 20,
            'no_cigars'     => 0,
            'allow_same_species_hits'  => 0,
            'blast_db'      => undef,
            'member_id_list'    => undef,
    };
}



sub fetch_input {
    my $self = shift @_;

    my $member_id_list = $self->param('member_id_list');
    my $members;
    if ($member_id_list) {
        $members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($member_id_list);
    } else {
        $members = $self->get_queries;
    }
    $self->param('query_set', Bio::EnsEMBL::Compara::MemberSet->new(-members => $members));

    $self->param('expected_members',scalar(@{$self->param('query_set')->get_all_Members}));

    if($self->debug) {
        print "Loaded ".$self->param('expected_members')." query members\n";
    }

    my $mlss_id         = $self->param_required('mlss_id');
    my $mlss            = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    my $species_set     = $mlss->species_set->genome_dbs;

    $self->param('all_blast_db', {});

    my $genome_db_list = [];

    if ($self->param('blast_db')) {

        # Target species are all mixed
        print STDERR "Using the blast database provided: ", $self->param('blast_db'), "\n" if $self->debug;
        # Loads the files into memory
        system sprintf('cat %s* > /dev/null', $self->param('blast_db'));
        #my $tmp_blast_db = $self->worker_temp_directory.(basename $self->param('blast_db'));
        #system sprintf('cp -a %s* %s', $self->param('blast_db'), $self->worker_temp_directory);
        $self->param('all_blast_db')->{$self->param('blast_db')} = undef;

        #Depending on the amount of sequences and blast version.
        # We may have multiple files, e.g.:
        #                           unannotated.fasta.00.pog
        #                           unannotated.fasta.01.pog
        my $fastafile = $self->param('blast_db');
        my @phr = glob("$fastafile*.phr");
        my @pin = glob("$fastafile*.pin");
        my @pog = glob("$fastafile*.pog");
        my @psd = glob("$fastafile*.psd");
        my @psi = glob("$fastafile*.psi");
        my @psq = glob("$fastafile*.psq");

        my %db_files = ( 'phr' => \@phr, 'pin' => \@pin, 'pog' => \@pog, 'psd' => \@psd, 'psi' => \@psi, 'psq' => \@psq );

        foreach my $ext ( keys %db_files ) {
            #Check if we have at least one file per each extension type
            die "Cound no find blast_db: $ext" if(scalar(@{$db_files{$ext}}) < 1);
            foreach my $file ( @{ $db_files{$ext} } ) {
                #Check if all files exist and have a nonzero size 
                die "Missing blast index: $file\n" unless -e "$file" and -s "$file";
            }
        }

    } elsif ($self->param('target_genome_db_id')) {

        # If we restrict the search to one species at a time
        $genome_db_list = [$self->compara_dba()->get_GenomeDBAdaptor->fetch_by_dbID($self->param('target_genome_db_id'))];

    } else {

        # Otherwise, we get the set of species from mlss_id
        my $mlss_id         = $self->param_required('mlss_id');
        my $mlss            = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
        my $species_set     = $mlss->species_set->genome_dbs;

        $genome_db_list = [ grep {$_->dbID != $self->param('genome_db_id')} @$species_set ];

        # If reusing this genome_db, only need to blast against the 'fresh' genome_dbs
        if ($self->param('reuse_ss_id')) {
            my $reused_species_set = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($self->param('reuse_ss_id')) or die $self->param('reuse_ss_id')." is not a valid species_set_id\n";
            #Check if species_set contains any species
            my $reused_genome_dbs = $reused_species_set->genome_dbs;

#            my $reused_genome_dbs = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($self->param('reuse_ss_id'))->genome_dbs;
            my %reuse_ss_hash = ( map { $_->dbID() => 1 } @$reused_genome_dbs );
            if ($reuse_ss_hash{$self->param('genome_db_id')}) {
                $genome_db_list = [ grep {not $reuse_ss_hash{$_->dbID}} @$genome_db_list ];
            }
        }
    }

    print STDERR "Found ", scalar(@$genome_db_list), " genomes to blast this member against.\n" if ($self->debug);
    my $blastdb_dir = $self->param('fasta_dir');
    foreach my $genome_db (@$genome_db_list) {
        my $fastafile = $blastdb_dir . '/' . $genome_db->name() . '_' . $genome_db->assembly() . ($genome_db->genome_component ? '_comp_'.$genome_db->genome_component : '') . '.fasta';
        $fastafile =~ s/\s+/_/g;    # replace whitespace with '_' characters
        $fastafile =~ s/\/\//\//g;  # converts any // in path to /
        $self->param('all_blast_db')->{$fastafile} = $genome_db->dbID;
        die "Missing blast fasta: $fastafile\n" unless -e $fastafile and -s $fastafile;
        die "Missing blast index: $fastafile.psq\n" unless -e "$fastafile.psq" and -s "$fastafile.psq";
        die "Missing blast index: $fastafile.phr\n" unless -e "$fastafile.phr" and -s "$fastafile.phr";
        die "Missing blast index: $fastafile.pin\n" unless -e "$fastafile.pin" and -s "$fastafile.pin";
    }

    if ($self->param('output_db')) {
        $self->param('output_dba', $self->get_cached_compara_dba('output_db'));
    } else {
        $self->param('output_dba', $self->compara_dba);
    }
}

sub parse_blast_table_into_paf {
    my ($self, $filename, $qgenome_db_id, $hgenome_db_id) = @_;

    my @features = ();
    $self->param('num_query_member', {});

    open(BLASTTABLE, '<', $filename) || die "Could not open the blast table file '$filename'";
    
    print "blast $qgenome_db_id $hgenome_db_id $filename\n" if $self->debug;

    while(my $line = <BLASTTABLE>) {

        #unless ($line =~ /^#/) {
        if ($line !~ /^#/) {
            my ($qmember_id, $hmember_id, $evalue, $score, $nident,$pident, $qstart, $qend, $hstart,$hend, $length, $positive, $ppos, $qseq, $sseq ) = split(/\t/, $line);

            my $cigar_line;
            unless ($self->param('no_cigars')) {
                $qseq =~ s/ /-/g;
                $sseq =~ s/ /-/g;
                $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_two_alignment_strings($qseq, $sseq);
            }

            my $feature = Bio::EnsEMBL::Compara::PeptideAlignFeature->new_fast({
                    _query_member_id        => $qmember_id,
                    _hit_member_id        => $hmember_id,
                    _query_genome_db_id     => $qgenome_db_id,
                    _hit_genome_db_id     => $hgenome_db_id,
                    _score             => $score,
                    _evalue            => $evalue,
                    _qstart            => $qstart,
                    _qend              => $qend,
                    _hstart            => $hstart,
                    _hend              => $hend,
                    _alignment_length            => $length,
                    _perc_ident        => $pident,
                    _identical_matches => $nident,
                    _positive_matches          => $positive,
                    _perc_pos          => $ppos,
                    _cigar_line        => $cigar_line,
            });

            print "feature query $qgenome_db_id $qmember_id hit $hgenome_db_id $hmember_id $hmember_id $qstart $qend $hstart $hend $length $nident $positive\n" if $self->debug;
            push @features, $feature;
        }else{
            if ($line =~ /^# Query:/) {
                #We need to count the queries itself, because sometimes we can have zero hits. 
                my @tok = split(/\s+/,$line);
                my $query = $tok[2];
                $self->param('num_query_member')->{$query} = 1;
            }
        }
    }
    close BLASTTABLE;
    return \@features;
}


sub run {
    my $self = shift @_;
    
    my $blastdb_dir             = $self->param('fasta_dir');
    my $blast_bin_dir           = $self->param_required('blast_bin_dir');
    my $blast_params            = $self->param('blast_params')  || '';  # no parameters to C++ binary means having composition stats on and -seg masking off
    my $evalue_limit            = $self->param('evalue_limit');
    my $tophits                 = $self->param('tophits');

    my $worker_temp_directory   = $self->worker_temp_directory;

    my $blast_infile  = $worker_temp_directory . '/blast.in.'.$$;     # only for debugging
    my $blast_outfile = $worker_temp_directory . '/blast.out.'.$$;    # looks like inevitable evil (tried many hairy alternatives and failed)

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $self->param('query_set'));

    if($self->debug) {
        print "blast_infile $blast_infile\n";
        $self->param('query_set')->print_sequences_to_file($blast_infile, -format => 'fasta');
    }

    $self->compara_dba->dbc->disconnect_if_idle();

    my $cross_pafs = [];
    foreach my $blast_db (keys %{$self->param('all_blast_db')}) {
        my $target_genome_db_id = $self->param('all_blast_db')->{$blast_db};

        my $cig_cmd = $self->param('no_cigars') ? '' : 'qseq sseq';
        my $cmd = "$blast_bin_dir/blastp -db $blast_db $blast_params -evalue $evalue_limit -max_target_seqs $tophits -out $blast_outfile -outfmt '7 qacc sacc evalue score nident pident qstart qend sstart send length positive ppos $cig_cmd'";
        warn "CMD:\t$cmd\n" if $self->debug;

        my $start_time = time();
        open( BLAST, "| $cmd") || die qq{could not execute "$cmd", returned error code: $!};
        $self->param('query_set')->print_sequences_to_file(\*BLAST, -format => 'fasta');
        close BLAST;
        print "Time for blast " . (time() - $start_time) . "\n";

        my $features = $self->parse_blast_table_into_paf($blast_outfile, $self->param('genome_db_id'), $target_genome_db_id);

        unless($self->param('expected_members') == scalar(keys(%{$self->param('num_query_member')}))) {
            # Most likelly, this is happening due to MEMLIMIT, so make the job sleep if it parsed 0 sequences, to wait for MEMLIMIT to happen properly.
            sleep(5);
        }

        push @$cross_pafs, @$features;
        unlink $blast_outfile unless $self->debug;
    }

    $self->param('cross_pafs', $cross_pafs);
}

sub write_output {
    my ($self) = @_;
    my $cross_pafs = $self->param('cross_pafs');

    $self->call_within_transaction(sub {
        $self->param('output_dba')->get_PeptideAlignFeatureAdaptor->rank_and_store_PAFS(@$cross_pafs);
    });
}


1;

