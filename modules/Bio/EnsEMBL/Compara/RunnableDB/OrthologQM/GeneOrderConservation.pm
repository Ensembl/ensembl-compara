=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation

=head1 SYNOPSIS

Generate orthology quality metric based on gene order/neighbourhood conservation
For more info, see: http://www.ensembl.org/info/genome/compara/Ortholog_qc_manual.html

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::GeneOrderConservation;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use JSON;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'number_neighbours' => 2,
        'allowed_gap'       => 1,
        'homology_header'   => 0,
        'parsed_homologies' => 0,
        'genome_db_ids'     => 0,
        'split_polyploids'  => 1,
        
        
        # for debugging purposes
        # only score the first X homologies
        'limit'                 => 0, # 0 for unlimited
        # print more verbose debugging for this homology id
        'debug_for_homology_id' => 0, # 0 for off
        'dry_run'               => 0,
    }
}

sub fetch_input {
    my $self = shift;
    
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('goc_mlss_id'));
    $self->_split_polyploid_goc($mlss) if $self->param('split_polyploids');
    my $genome_dbs = $mlss->species_set->genome_dbs;
        
    # build gene neighbourhood map
    my (%neighbourhood, %gene_member_strand);
    $| = 1 if $self->debug; # turn on buffer flushing for debug messages
    print "Building gene neighbourhood...\n" if $self->debug;
    
    # identify paralogs in order to discard tandem paralogs later
    print "\tidentifying paralogs... " if $self->debug;
    my $paralogs = $self->_identify_paralogs;
    print "done!\n" if $self->debug;
        
    print "\tfetching and sorting gene_members... " if $self->debug;
    my $all_gene_member_ids = $self->_get_all_gene_member_ids_in_homology_file;
    my $sql = 'SELECT gene_member_id, dnafrag_id, dnafrag_start, dnafrag_strand FROM gene_member WHERE gene_member_id = ?';
    my $sth = $self->compara_dba->dbc->prepare($sql);
    my @gene_members_unordered;
    foreach my $this_gm_id ( @$all_gene_member_ids ) {
        $sth->execute($this_gm_id);
        my $results = $sth->fetchall_arrayref;
        push( @gene_members_unordered, $results->[0] );
    }
    my @gene_members_ordered = sort { $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2] } @gene_members_unordered;
    print "done!\n" if $self->debug;
    
    
    print "\tcreating index of dnafrag positions\n" if $self->debug;
    my %positions;
    my $tandem_paralogs = 0;
    foreach my $gm_info ( @gene_members_ordered ) {
        my ($this_gene_member_id, $this_dnafrag_id, $start, $strand) = @$gm_info;
        my $this_pos = $positions{$this_dnafrag_id} || 0;
        
        # check for tandem paralogs - only include the first one
        my $prev_gene_member_id = $neighbourhood{'pos2member'}->{$this_dnafrag_id}->{$this_pos-1};
        if ( defined $prev_gene_member_id && $paralogs->{$this_gene_member_id}->{$prev_gene_member_id} ) {
            $neighbourhood{'member2pos'}->{$this_gene_member_id} = [$this_dnafrag_id, $this_pos-1];
            
            $tandem_paralogs++;
        } else {
            $neighbourhood{'member2pos'}->{$this_gene_member_id} = [$this_dnafrag_id, $this_pos];
            $neighbourhood{'pos2member'}->{$this_dnafrag_id}->{$this_pos} = $this_gene_member_id;
            
            $positions{$this_dnafrag_id}++;
        }
        
        $gene_member_strand{$this_gene_member_id} = $strand;
    }
    print "\tremoved $tandem_paralogs tandem paralogs\n" if $self->debug;
    print "Neighbourhood complete!\n" if $self->debug;
      
    $self->param('gene_member_strand', \%gene_member_strand);
    $self->param('neighbourhood', \%neighbourhood);
}

sub run {
    my $self = shift;

    my %goc_scores;
    my $gene_member_strand = $self->param('gene_member_strand');

    print "Reading homologies and calculating GOC scores\n" if $self->debug;
    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot open $homology_flatfile";
    my $header = <$hom_handle>;
    my $c = 0;
    while ( my $line = <$hom_handle> ) {
        my $row = map_row_to_header( $line, $self->homology_header );
        my ( $homology_id, $gm_id_1, $gm_id_2 ) = ($row->{homology_id}, $row->{gene_member_id}, $row->{hom_gene_member_id});

        # if param('genome_db_ids') is set, we only want to score genes from those genomes
        # only relevant genomes will be included in the strand map
        next if $self->param('genome_db_ids') && !(defined $gene_member_strand->{$gm_id_1} && defined $gene_member_strand->{$gm_id_2});

        # calculate goc score in each direction (A->B && B->A)
        # the max score becomes the final goc_score for this homology
        my $goc_score_1 = $self->_calculate_goc( $gm_id_1, $gm_id_2, $homology_id );
        my $goc_score_2 = 0;
        $goc_score_2 = $self->_calculate_goc( $gm_id_2, $gm_id_1, $homology_id ) unless $goc_score_1 == 100; # no need to calculate the inverse if we've already got a max score
        my $max_goc_score = ( $goc_score_1 >= ( $goc_score_2 || 0 ) ) ? $goc_score_1 : $goc_score_2;
        
        push @{ $goc_scores{$max_goc_score} }, $homology_id;
        $c++;
        last if $self->param('limit') && $c >= $self->param('limit');
    }
    print "GOC scores complete!\n\n" if $self->debug;
    
    # print Dumper \%goc_scores;
    if ( $self->debug ) {
        my @sorted_scores = sort {$a <=> $b} keys %goc_scores;
        foreach my $score ( @sorted_scores ) {
            printf( "%s : [%s] (count: %s)\n", $score, join(',', sort @{$goc_scores{$score}}), scalar @{$goc_scores{$score}} );
        }
    }
    die if $self->param('dry_run');
    
    $self->param('goc_scores', \%goc_scores);
}

sub write_output {
    my $self = shift;
    
    my $goc_scores = $self->param('goc_scores');
    print "Writing GOC scores to the database\n" if $self->debug;
    $self->compara_dba->dbc->sql_helper->transaction(
        -CALLBACK => sub {
            my $sql = 'UPDATE homology SET goc_score = ? WHERE homology_id = ?';
            my $sth = $self->compara_dba->dbc->prepare($sql);
            foreach my $score ( keys %$goc_scores ) {
                foreach my $homology_id ( @{ $goc_scores->{$score} } ) {
                    $sth->execute($score, $homology_id);
                }
            }
            $sth->finish();
        }
    );
    print "Scores written! Done!\n\n" if $self->debug;
}

sub homology_header {
    my $self = shift;
    
    return $self->param('homology_header') if $self->param('homology_header');
    
    # otherwise, grab header line from the file
    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot open $homology_flatfile";
    my $header = <$hom_handle>;
    my @head_cols = split(/\s+/, $header);
    $self->param('homology_header', \@head_cols);
    close $hom_handle;
    return $header;
}

sub _get_all_gene_member_ids_in_homology_file {
    my $self = shift;
    
    my %gm_ids;
    
    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot read $homology_flatfile";
    my $header = <$hom_handle>;
    while( my $line = <$hom_handle> ) {
        my $row = map_row_to_header( $line, $self->homology_header );
        my ( $gm_id_1, $gm_id_2, $gdb_id_1, $gdb_id_2 ) = ($row->{gene_member_id}, $row->{hom_gene_member_id}, $row->{genome_db_id}, $row->{hom_genome_db_id});
        if ( $self->param('genome_db_ids') ) {
            my ( $gdb_a, $gdb_b ) = @{ $self->param('genome_db_ids') };
            next unless ( 
                ($gdb_id_1 == $gdb_a && $gdb_id_2 == $gdb_b) ||
                ($gdb_id_1 == $gdb_b && $gdb_id_2 == $gdb_a)
            );
        }
        $gm_ids{$gm_id_1} = 1;
        $gm_ids{$gm_id_2} = 1;
    }
    my @uniq_ids = keys %gm_ids;
    return \@uniq_ids;
}

sub _calculate_goc {
    my ( $self, $gm_id_a, $gm_id_b, $hom_id ) = @_;
    
    # get neighbourhood for each gene_member
    my $num_neighbours = $self->param_required('number_neighbours');
    my @neighbours_a   = $self->_get_neighbours( $gm_id_a, $num_neighbours );
    # we want to allow a certain number of gaps, so more neighbours should be fetched for gene B
    my $allowed_gap    = $self->param_required('allowed_gap');
    my $wanted_neighbours = $num_neighbours + ( $allowed_gap * ($num_neighbours - 1) );
    my @neighbours_b   = $self->_get_neighbours( $gm_id_b, $wanted_neighbours );
    
    my $gene_member_strand = $self->param('gene_member_strand');
    if ( $self->param('debug_for_homology_id') && $self->param('debug_for_homology_id') == $hom_id ) {
        # print Dumper \@neighbours_a;
        # print Dumper \@neighbours_b;
        
        print "neighbours_a:\n";
        foreach my $n_id_a ( @neighbours_a ) {
            printf("\t%s, %s\n", $n_id_a, $gene_member_strand->{$n_id_a}) unless $n_id_a eq '*****';
            printf("\t%s, %s\n", $n_id_a, $gene_member_strand->{$gm_id_a}) if $n_id_a eq '*****';
        }
        print "\n";
        
        print "neighbours_b:\n";
        foreach my $n_id_b ( @neighbours_b ) {
            printf("\t%s, %s\n", $n_id_b, $gene_member_strand->{$n_id_b}) unless $n_id_b eq '*****';
            printf("\t%s, %s\n", $n_id_b, $gene_member_strand->{$gm_id_b}) if $n_id_b eq '*****';
        }
        print "\n\n";
    }
    
    my $strand_mismatch;
    unless ($gene_member_strand->{$gm_id_a} eq $gene_member_strand->{$gm_id_b}) {
        @neighbours_b = reverse @neighbours_b;
        $strand_mismatch = 1;
    }
    
    # check for overlaps between left side neighbours' homology ids
    my $shared_homology = 0;
    my $prev_match_pos = -1;
    for ( my $i = 0; $i < @neighbours_a; $i++ ) {
        my $neighbour_id_a = $neighbours_a[$i];
        next if $neighbour_id_a eq '*****';
        for ( my $j = $prev_match_pos+1; $j < @neighbours_b; $j++ ) {
            my $neighbour_id_b = $neighbours_b[$j];
            if ($neighbour_id_b eq '*****') {
                $prev_match_pos = $j;
                next;
            }
            my $share_homology = $self->_find_shared_homology($neighbour_id_a, $neighbour_id_b, $strand_mismatch);
            print "$neighbour_id_a v $neighbour_id_b : " . ($share_homology ? '1' : '0') . "\n" if ( $self->param('debug_for_homology_id') && $self->param('debug_for_homology_id') == $hom_id );
            if ( $share_homology ) {
                if ( $prev_match_pos >= 0 && abs($j - $prev_match_pos) > $allowed_gap + 1) {
                    print "gap too big - ignoring match : $j - $prev_match_pos > $allowed_gap + 1\n" if ( $self->param('debug_for_homology_id') && $self->param('debug_for_homology_id') == $hom_id );
                } else {
                    $shared_homology++;
                }
                $prev_match_pos = $j;
                last; # don't care about multiple matches, so let's move on here
            }
        }
    }
    my $perc_overlap = ($shared_homology / ($num_neighbours*2)) * 100;
    print "perc_overlap : $perc_overlap\n\n" if ( $self->param('debug_for_homology_id') && $self->param('debug_for_homology_id') == $hom_id );

    return $perc_overlap;
}

sub _get_neighbours {
    my ( $self, $gm_id, $num_neighbours) = @_;

    my ($dnafrag_id, $pos) = $self->_get_dnafrag_position($gm_id);
    my @these_neighbours = ('*****');
    foreach my $x ( 1..$num_neighbours ) {
        my $gm_left = $self->_get_gene_member_by_dnafrag_pos($dnafrag_id, ($pos-$x));
        unshift @these_neighbours, $gm_left if defined $gm_left;
        
        my $gm_right = $self->_get_gene_member_by_dnafrag_pos($dnafrag_id, ($pos+$x));
        push @these_neighbours, $gm_right if defined $gm_right;
    }
    return @these_neighbours;
}

sub _get_dnafrag_position {
    my ( $self, $gene_member_id ) = @_;
    
    my $neighbourhood = $self->param('neighbourhood')->{'member2pos'};
    my ( $dnafrag_id, $pos ) = @{ $neighbourhood->{$gene_member_id} };
    
    return ( $dnafrag_id, $pos );
}

sub _get_gene_member_by_dnafrag_pos {
    my ( $self, $dnafrag_id, $pos ) = @_;
    
    my $neighbourhood = $self->param('neighbourhood')->{'pos2member'};
    my $gene_member_id = $neighbourhood->{$dnafrag_id}->{$pos};
    
    return $gene_member_id;
}

sub _find_shared_homology {
    my ( $self, $gm_id_a, $gm_id_b, $strand_mismatch ) = @_;
    
    # first, check that they share directionality
    my $gene_member_strand = $self->param('gene_member_strand');
    return 0 if ( 
        $strand_mismatch && $gene_member_strand->{$gm_id_a} eq $gene_member_strand->{$gm_id_b} ||
       !$strand_mismatch && $gene_member_strand->{$gm_id_a} ne $gene_member_strand->{$gm_id_b}    
    );
    
    # next, check the parsed flatfile
    my $parsed_homologies = $self->parsed_homologies;
    return $parsed_homologies->{$gm_id_a}->{$gm_id_b} if defined $parsed_homologies->{$gm_id_a}->{$gm_id_b};
    return 0;
}

sub parsed_homologies {
    my $self = shift;
    
    return $self->param('parsed_homologies') if $self->param('parsed_homologies');
    
    # open homology flatfile for reading
    print "Parsing homologies from flatfile\n" if $self->debug;
    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot read $homology_flatfile";
    my $header = <$hom_handle>;
    
    my %homologies;
    while( my $line = <$hom_handle> ) {
        my $row = map_row_to_header( $line, $self->homology_header );
        my ( $homology_id, $gm_id_1, $gm_id_2 ) = ( $row->{homology_id}, $row->{gene_member_id}, $row->{hom_gene_member_id} );
        $homologies{$gm_id_1}->{$gm_id_2} = $homology_id;
        $homologies{$gm_id_2}->{$gm_id_1} = $homology_id;      
    }
    
    $self->param('parsed_homologies', \%homologies);
    return \%homologies;
}

sub _identify_paralogs {
    my ( $self ) = @_;
    
    # open homology flatfile for reading
    my $homology_flatfile = $self->param_required('homology_flatfile');
    open( my $hom_handle, '<', $homology_flatfile ) or die "Cannot read $homology_flatfile";
    my $header = <$hom_handle>;
    my @head_cols = split(/\s+/, $header);
    $self->param('homology_header', \@head_cols);
    
    # map gene_tree_node_ids to gene_members and genome_dbs
    my %gtn_ids;
    while( my $line = <$hom_handle> ) {
        my $row = map_row_to_header( $line, $self->homology_header );
        my ( $gene_tree_node_id, $gm_id_1, $gdb_id_1, $gm_id_2, $gdb_id_2 ) = (
            $row->{gene_tree_node_id}, 
            $row->{gene_member_id}, 
            $row->{genome_db_id}, 
            $row->{hom_gene_member_id}, 
            $row->{hom_genome_db_id}
        );
        push( @{$gtn_ids{$gene_tree_node_id}->{$gdb_id_1}}, $gm_id_1 );
        push( @{$gtn_ids{$gene_tree_node_id}->{$gdb_id_2}}, $gm_id_2 );        
    }
    
    # find gene_members from the same genome_db that share a gene_tree_node_id
    # these are our paralogs
    my %paralogs;
    foreach my $gtn_id ( keys %gtn_ids ) {
        foreach my $gdb_id ( keys %{$gtn_ids{$gtn_id}} ) {
            my @gm_id_list = @{$gtn_ids{$gtn_id}->{$gdb_id}};
            next unless scalar @gm_id_list > 1;
            foreach my $gm_id_a ( @gm_id_list ) {
                foreach my $gm_id_b ( @gm_id_list ) {
                    next if $gm_id_a == $gm_id_b;
                    $paralogs{$gm_id_a}->{$gm_id_b} = 1;
                    $paralogs{$gm_id_b}->{$gm_id_a} = 1;
                }
            }
        }
    }
    
    return \%paralogs;
}

sub _split_polyploid_goc {
    my ( $self, $mlss ) = @_;
    
    # First, let's detect ENSEMBL_HOMOEOLOGUES and spawn 1 job per pair of components
    if (($mlss->method->type eq 'ENSEMBL_HOMOEOLOGUES') && !$self->param('genome_db_ids')) {
        my $genome_db = $mlss->species_set->genome_dbs->[0];
        my @components = @{$genome_db->component_genome_dbs};
        while (my $gdb1 = shift @components) {
            foreach my $gdb2 (@components) {
                $self->dataflow_output_id({'genome_db_ids' => [$gdb1->dbID, $gdb2->dbID]}, 3);
            }
        }
        $self->complete_early("Got ENSEMBL_HOMOEOLOGUES, so dataflowed 1 job per pair of component genome_dbs\n");
    }

    # Then, let's find the ENSEMBL_ORTHOLOGUES that link polyploid genomes
    # and spawn 1 job for each of their components
    if (($mlss->method->type eq 'ENSEMBL_ORTHOLOGUES') && !$self->param('genome_db_ids')) {
        my $gdb1 = $mlss->species_set->genome_dbs->[0];
        my $gdb2 = $mlss->species_set->genome_dbs->[1];
        if ($gdb1->is_polyploid || $gdb2->is_polyploid) {
            # Note: both could be polyploid, e.g. T.aes vs T.dic
            my $sub_gdb1s = $gdb1->is_polyploid ? $gdb1->component_genome_dbs : [$gdb1];
            my $sub_gdb2s = $gdb2->is_polyploid ? $gdb2->component_genome_dbs : [$gdb2];
            foreach my $sub_gdb1 (@$sub_gdb1s) {
                foreach my $sub_gdb2 (@$sub_gdb2s) {
                    $self->dataflow_output_id({'genome_db_ids' => [$sub_gdb1->dbID, $sub_gdb2->dbID]}, 3);
                }
            }
            $self->complete_early("Got ENSEMBL_ORTHOLOGUES on polyploids, so dataflowed 1 job per component genome_db\n");
        }
    }
}

1;
