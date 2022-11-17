=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments

=head1 DESCRIPTION

This Runnable will search for genes that are significantly longer or shorter than
their orthologues based on the the coverage percentage. Genes that have been flagged as "split-genes" by are
ignored by this analysis.
It works by computing for each gene the average coverage of their
orthologues. Genes with an average that fall below a given threshold (and
when the average has been computed against enough species) are reported.

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::get_gene_fragment_stat -longer <1/0>  -genome_db_id <genome_db_id> -coverage_threshold <> -species_threshold <>

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments;

use strict;
use warnings;
use Data::Dumper;
use List::Util qw( min max );
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);
use Bio::EnsEMBL::Hive::Utils qw(dir_revhash);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
    %{ $self->SUPER::param_defaults() },
  'coverage_threshold'    => 50,  # Genes with a coverage below this are reported
  
    };
}

=head2 fetch_input

    Description: Use the mlss id to fetch the species set 

=cut

sub fetch_input {
  my $self = shift;
  print "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% find gene fragment stat Runnable\n\n" if $self->debug(); 
  # get the seq_member_id of the split_genes
  unless($self->param_required('gene_status') eq 'orphaned') { 
    my %split_genes = map{$_ => 1} @{$self->data_dbc->db_handle->selectcol_arrayref('SELECT seq_member_id from gene_member_qc where status = "split-gene" AND genome_db_id= ?', undef, $self->param_required('genome_db_id') )};
    print Dumper \%split_genes if $self->debug(); 
    $self->param('split_genes_hash', \%split_genes);
    $self->compara_dba->dbc->disconnect_if_idle;
  }
}

sub run {
  my $self = shift;
  my $genome_db_id        = $self->param_required('genome_db_id');

  # Basically, we run this query and we filter on the Perl-side
    # Note: we could filter "avg_cov" and "n_species" in SQL
    my $sql;

    if ($self->param_required('gene_status') eq 'ambiguous_sequence') {
        my $missing_sequence_threshold = $self->param_required('missing_sequence_threshold');

        $sql = 'SELECT gene_member_id, seq_member_id, sequence FROM other_member_sequence JOIN seq_member USING (seq_member_id) WHERE seq_member.genome_db_id = ? AND seq_type = "cds" AND sequence LIKE "%N%";';
        my $sth = $self->compara_dba->dbc->prepare($sql);
        $sth->execute($genome_db_id);

        my $regex = '[^ACGT]'; #https://droog.gs.washington.edu/parc/images/iupac.html
        my $seq_length;
        while (my $row = $sth->fetchrow_hashref()) {
            my $gene_member_id = $row->{gene_member_id};
            my $sequence = $row->{sequence};
            my $seq_member_id = $row->{seq_member_id};
            my @gaps = _match_all_positions( $regex, \$sequence);
            $seq_length = length($sequence);
            if (_is_very_ambiguous( \@gaps, $seq_length, $missing_sequence_threshold)){
                $self->dataflow_output_id( { 'gene_member_id' => $gene_member_id, 'genome_db_id' => $genome_db_id, 'seq_member_id' => $seq_member_id, 'status' => "ambiguous-sequence" }, 2);
            }
        }
    }
    elsif ($self->param_required('gene_status') eq 'orphaned') {
      $sql = 'SELECT mg.gene_member_id, mg.canonical_member_id FROM gene_member mg LEFT JOIN gene_tree_node gtn ON (mg.canonical_member_id = gtn.seq_member_id) WHERE gtn.seq_member_id IS NULL AND mg.genome_db_id = ?';
      my $sth = $self->compara_dba->dbc->prepare($sql);
      $sth->execute($genome_db_id);

      while (my $row = $sth->fetchrow_hashref()) {
        $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'gene_member_id' => $row->{gene_member_id}, 'seq_member_id' => $row->{canonical_member_id}, 'status' => "orphaned-gene" }, 2);
      }

    } else {
        my $coverage_threshold  = $self->param_required('coverage_threshold');
        my $species_threshold   = $self->param_required('species_threshold');
        my $split_genes         = $self->param_required('split_genes_hash');

        my $coverage_stats;
        print "Finding homology dump files\n" if $self->debug;
        my $homology_dump_files = $self->_get_homology_dumps_for_genome_db($genome_db_id);
        print Dumper $homology_dump_files if $self->debug;
        foreach my $hom_dump ( @$homology_dump_files ) {
            open( my $hdh, '<', $hom_dump ) or die "Cannot open $hom_dump for reading\n";
            my $header = <$hdh>;
            my @head_cols = split(/\s+/, $header);

            my $line = <$hdh>;
            while ( $line ) {
                my $row = map_row_to_header( $line, \@head_cols );
                # Check whether the genome_db of interest is genome_db_id or homology_genome_db_id - we don't
                # know which it will be. We'll either use genome_db_id, seq_member_id, etc *OR*
                # homology_genome_db_id, homology_seq_member_id, etc
                my ( $this, $that ) = $row->{genome_db_id} == $genome_db_id ? ('', 'homology_') : ('homology_', '');

                $coverage_stats->{$row->{$this . 'gene_member_id'}}->{genome_db_id}  = $row->{$this . 'genome_db_id'};
                $coverage_stats->{$row->{$this . 'gene_member_id'}}->{seq_member_id} = $row->{$this . 'seq_member_id'};
                $coverage_stats->{$row->{$this . 'gene_member_id'}}->{n_orth}++;
                $coverage_stats->{$row->{$this . 'gene_member_id'}}->{genome_dbs}->{$row->{$that . 'genome_db_id'}} = 1;
                $coverage_stats->{$row->{$this . 'gene_member_id'}}->{total_cov} += $row->{$this . 'perc_cov'};
                $coverage_stats->{$row->{$this . 'gene_member_id'}}->{total_hom_cov} += $row->{$that . 'perc_cov'};
                
                $line = <$hdh>;
            }
            close $hdh;
        }
        
        foreach my $gm_id ( keys %$coverage_stats ) {
            my $these_stats = $coverage_stats->{$gm_id};
            # check species
            my $n_species = scalar(keys %{$these_stats->{genome_dbs}});
            next if $n_species < $species_threshold;
            
            # check coverage for long or short genes
            my ($gene_status, $this_avg_cov);
            my $avg_cov = $these_stats->{total_cov}/$these_stats->{n_orth};
            my $avg_hom_cov = $these_stats->{total_hom_cov}/$these_stats->{n_orth};
            if ( $avg_cov <= $coverage_threshold && $avg_hom_cov <= $coverage_threshold ) {
                # if both coverages are low, it's probably just a distant homology
                next; # do not report these
            } elsif ( $avg_cov <= $coverage_threshold ) {
                $gene_status = 'long-gene';
                $this_avg_cov = $avg_cov;
            } elsif ( $avg_hom_cov <= $coverage_threshold ) {
                $gene_status = 'short-gene';
                $this_avg_cov = $avg_hom_cov;
            }
            next unless defined $gene_status;
            
            my $dataflow = {
                'genome_db_id'          => $these_stats->{genome_db_id},
                'gene_member_id'        => $gm_id,
                'seq_member_id'         => $these_stats->{seq_member_id},
                'n_species'             => $n_species,
                'n_orth'                => $these_stats->{n_orth},
                'avg_cov'               => $this_avg_cov,
                'status'                => $gene_status,
            };
            
            $self->dataflow_output_id($dataflow, 2);
        }
    }
    #disconnect compara database
  $self->compara_dba->dbc->disconnect_if_idle;
}

sub num { $a <=> $b }

sub _match_all_positions {
    my ($regex, $string) = @_;
    my @ret;
    while ($$string =~ /$regex/g) {
        push @ret, [ $-[0], $+[0]-1 ];
    }
    return @ret
}

sub _is_very_ambiguous {
    my $gaps                = $_[0];
    my $seq_length          = $_[1];
    my $ambiguity_threshold = $_[2];

    my $gap_count = 0;
    my %intervals;
    my %control;

    foreach my $gap ( @{ $gaps } ) {
        my ( $from, $to ) = ( $gap->[0], $gap->[1] );
        my ( $new_from, $new_to ) = ( 3*int( $from/3 ), 3*int( $to/3 ) + 2 );
        for ( my $i = $new_from; $i < $new_to; $i++ ) {
            $intervals{$i} = 1;
        }
        $gap_count++;
    }

    my @postitions_to_remove = sort num keys(%intervals);
    my $ratio;

    if (scalar(@postitions_to_remove) > 0){
        my $gap_counter = 0;
        for ( my $i = 0; $i < scalar(@postitions_to_remove); $i++ ) {
            if ( ( $postitions_to_remove[$i] + 1 ) == $postitions_to_remove[ $i + 1 ] ) {
                $control{$gap_counter}{ $postitions_to_remove[$i] } = 1;
            }
            else {
                $control{$gap_counter}{ $postitions_to_remove[$i] } = 1;
                $gap_counter++;
            }
        }

        my $removed_columns_count = 0;
        foreach my $gap (sort keys %control){
            my @positions = sort num keys %{$control{$gap}};
            my $min = min(@positions);
            my $max = max(@positions)+1; #we need to be max + 1 here because of how remove_columns works.
            $removed_columns_count += ($max-$min)+1;
        }

        $ratio = $removed_columns_count/$seq_length;
    }
    else{
        $ratio = 0;
    }

    if ( $ratio > $ambiguity_threshold ) {
        warn("More than 50% of the pairwise alignment is composed of ambiguous sequences (N's)");
        return 1;
    }
    else{
        return 0;
    }

} ## end sub _is_very_ambiguous

sub _get_homology_dumps_for_genome_db {
    my ( $self, $gdb_id ) = @_;
    
    my $gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my @mlss_ids = map {$_->dbID} @{ $mlss_adaptor->fetch_all_by_method_link_type_GenomeDB('ENSEMBL_ORTHOLOGUES', $gdb) };
    
    my $homology_dumps_dir = $self->param_required('homology_dumps_dir');
    my @homology_dump_files = map {"$homology_dumps_dir/" . dir_revhash($_) . "/$_.protein.homologies.tsv"} @mlss_ids;
    return \@homology_dump_files;
}


1;
