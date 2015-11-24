=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs

=head1 SYNOPSIS

=head1 DESCRIPTION

	Takes as input an hash of orthologs as values (the query ortholog and 2 orthologs to its left and 2 to its right). The hash also contains the dna frag id of the ref genome, the reference species dbid and the non reference species dbid
	It uses the orthologs to pull out the ref and non ref members.
	it then uses the extreme start and end of the non ref members to define a constraint that is used in a query to pull all the members spanning that region on the non ref genome.
	This new member are screened and ordered before their ordered is compared to the order depicted by the orthologous members.
	It returns an hash showing how much of the orthologous memebers match the order of the members on the genome and a percentage score to reflect this.
	
	Example run

	standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs
=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs;

use strict;
use warnings;
use Data::Dumper;
use List::MoreUtils qw(firstidx);
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;


=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
	my $self = shift;
	return {
            %{ $self->SUPER::param_defaults() },
	    'mlss_ID'=>'100021',
#       'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db',
		'compara_db' => 'mysql://ensro@compara1/mm14_protein_trees_82',
		'ref_species_dbid' =>155,
        'non_ref_species_dbid' => 31,
        'left1' => 14803,
        'right1' => 46043,
        'query' =>14469,
#       'left2' =>  14803,
#        'right2' => 46043,
        'ref_chr_dnafragID' =>14026395
	};
}


=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
    Here I need to retrieve the ordered chromosome ortholog hash that was data flowed here by Prepare_Per_Chr_Jobs.pm 

=cut

sub fetch_input{
	my $self = shift;
	$self->param('gdb_adaptor', $self->compara_dba->get_GenomeDBAdaptor);
	$self->param('homolog_adaptor', $self->compara_dba->get_HomologyAdaptor);
	$self->param('gmember_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
#	print $self->param('gmember_adaptor');
#	print $self->param('homolog_adaptor');
#    $self->param('mlss_ID', $self->param_required('mlss_ID'));
}

sub run {
	my $self = shift;
#	my $orth_hashref = $self->param_required('comparison');
#	print " -------------------------------------------------------------Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Compare_orthologs \n\n";
#    print  $self->param('mlss_ID')," \n\n";
#    print $self->param('left1'), " left1 ", $self->param('left2'), " left2 ", $self->param('query'), " query ", $self->param('right1'), " right1 ", $self->param('right2'), " right2 ", $self->param('ref_chr_dnafragID'), " ref_chr_dnafragID\n\n" ;
#	print Dumper($orth_hashref);
#	my $ref_chr_dnafragID = $orth_hashref->{'ref_chr_dnafragID'};
#	delete $orth_hashref->{'ref_chr_dnafragID'};
#	my $keys_size = keys %$orth_hashref;
    
    my @defined_positions;
    if (defined($self->param('left1'))) {
        push(@defined_positions, 'left1');
        if (defined($self->param('left2'))) {
            push(@defined_positions, 'left2');
        }
    }
    if (defined($self->param('right1'))) {
        push(@defined_positions, 'right1');
        if (defined($self->param('right2'))) {
            push(@defined_positions, 'right2');
        }
    }
#    print "available positions hahahahahahahhaaahhaah \n";
#    print Dumper(\@defined_positions);

    if (@defined_positions) {
        $self->param('defined_positions' , \@defined_positions);
    }
    my %result;
    unless (($self->param('left1')) || ($self->param('right1'))) {
#        print "111111111111111 only the query \n\n";
		$result{'left1'} = undef;
		$result{'left2'} = undef;
		$result{'right1'} = undef;
		$result{'right2'} = undef;
        $result{'percent_conserved_score'} = 0;
		$result{'homology_id'} = $self->param('query');
		my $ref_gene_member = $self->param('homolog_adaptor')->fetch_by_dbID($self->param('query'))->get_all_GeneMembers($self->param('ref_species_dbid'))->[0];
        $result{'dnafrag_id'} = $ref_gene_member->dnafrag_id();
        $result{'gene_member_id'} = $ref_gene_member->dbID();
        $result{'method_link_species_set_id'} = $self->param('mlss_ID');
		$self->param('result', \%result);
	} else {

		
		my $non_ref_gmembers_list={};
		
		
        my $query_ref_gmem_obj = $self->param('homolog_adaptor')->fetch_by_dbID($self->param('query'))->get_all_GeneMembers($self->param('ref_species_dbid'))->[0];
#        print $query_ref_gmem_obj ,"  not just queryyyyyyyyyyyyyyyyyy \n\n ", $self->param('ref_species_dbid') , " yayayay \n" ;
        my $query_non_ref_gmem_obj = $self->param('homolog_adaptor')->fetch_by_dbID($self->param('query'))->get_all_GeneMembers($self->param('non_ref_species_dbid'))->[0];
    #   
        $non_ref_gmembers_list->{'query'} = $query_non_ref_gmem_obj->dbID;
        my $start = $query_non_ref_gmem_obj->dnafrag_start;
        my $end = $query_non_ref_gmem_obj->dnafrag_end;
#        print $query_non_ref_gmem_obj ," nonnnnnn not just queryyyyyyyyyyyyyyyyyy \n\n ", $self->param('non_ref_species_dbid') , " yayayay \n" ;
        my $query_non_ref_dnafragID = $query_non_ref_gmem_obj->dnafrag_id() ;
#        print $query_non_ref_dnafragID, " wooooooooooo\n";
		#create an hash ref with the non ref member dbid has the values for keys(query, left1, left2,right1, right2)
        foreach my $ortholog (@{$self->param('defined_positions')}) {
#            print $ortholog , " orttttttttttttt\n\n";
            my $non_ref_gm = $self->param('homolog_adaptor')->fetch_by_dbID($self->param($ortholog))->get_all_GeneMembers($self->param('non_ref_species_dbid'))->[0];
#            print "line 1388888888888 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n\n";
            $non_ref_gmembers_list->{$ortholog} = $non_ref_gm->dbID;
#            print "line 1388888888888 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n\n";
#            print $non_ref_gm->dbID(), " JJJJJJJJJJ \n";
            if ($query_non_ref_dnafragID eq $non_ref_gm->dnafrag_id()) {
#                print " same dnafragggggggggggggggg \n";
                if ($start > $non_ref_gm->dnafrag_start()) {
                    $start = $non_ref_gm->dnafrag_start();
                }
                if ($end < $non_ref_gm->dnafrag_end()) {
                    $end =  $non_ref_gm->dnafrag_end();
                }
            }
        }

		my $strand = 0;
		#checks if both members of the query ortholog are in the same direction/ strand
		if ($query_ref_gmem_obj->dnafrag_strand() == $query_non_ref_gmem_obj->dnafrag_strand()) {
#			print "################################### \n strand is the same \n\n";
			$strand = 1;
		}

#		print "this is the strand---- ", $strand, "\n\n";

	# get the all gene members with source name ENSEMBLPEP (ordered by their dnafrag start position)  spanning the specified start and end range of the given chromosome. dnafrag_id  == chromosome, that have homologs on the ref genome
		$self->param('non_ref_gmembers_ordered', $self->_get_non_ref_gmembers($query_non_ref_dnafragID, $start, $end));

#ß		print Dumper($self->param('non_ref_gmembers_ordered'));
#        print "############## non_ref_gmembers_ordered^^^^ ##################### non_ref_gmembers_listvvvv \n\n";
#		print Dumper($non_ref_gmembers_list);

        #Create the result hash showing if the order gene conservation indicated by the ortholog matches the order of genes retrieve from the geneme.
        if ($strand == 1) {
            $self->param('result', $self->_compare($non_ref_gmembers_list, $self->param('non_ref_gmembers_ordered')));
        } else {
            my $temp_query = $non_ref_gmembers_list->{'query'};
            my $temp_left1 = $non_ref_gmembers_list->{'right1'};
            my $temp_left2 = $non_ref_gmembers_list->{'right2'};
            my $temp_right1 = $non_ref_gmembers_list->{'left1'};
            my $temp_right2 = $non_ref_gmembers_list->{'left2'};
            $self->param('result_temp', $self->_compare( {'query' => $temp_query, 'left1' => $temp_left1, 'left2' => $temp_left2, 'right1' => $temp_right1, 'right2' => $temp_right2}, , $self->param('non_ref_gmembers_ordered')));
            $result{'left1'} = $self->param('result_temp')->{right1};
            $result{'left2'} = $self->param('result_temp')->{right2};
            $result{'right1'} = $self->param('result_temp')->{left1};
            $result{'right2'} = $self->param('result_temp')->{left2};
            $self->param('result', \%result);
        }   
#        print "RESULTSsssssssssssss hashhhhhhh \n";

		my $percent = $self->param('result')->{'left1'} + $self->param('result')->{'left2'} + $self->param('result')->{'right1'} + $self->param('result')->{'right2'};
		my $percentage = $percent * 25;
        $self->param('result')->{'percent_conserved_score'} =$percentage;
		my $ref_gene_member = $self->param('homolog_adaptor')->fetch_by_dbID($self->param('query'))->get_all_GeneMembers($self->param('ref_species_dbid'))->[0];
        $self->param('result')->{'dnafrag_id'} = $ref_gene_member->dnafrag_id();
        $self->param('result')->{'gene_member_id'} = $ref_gene_member->dbID();
        $self->param('result')->{'homology_id'} = $self->param('query');
        $self->param('result')->{'method_link_species_set_id'} = $self->param('mlss_ID');

	}
#    print Dumper($self->param('result'));
}


sub write_output {
	my $self = shift;

	#$self->dataflow_output_id( $self->param('block_regions') );
	$self->dataflow_output_id( $self->param('result'), 2 );
}

#get all the gene members of in a chromosome coordinate range, filter only the ones that are from a 'ENSEMBLPEP' source and order them based on their dnafrag start positions 
sub _get_non_ref_gmembers {
	my $self = shift;
#	print " This is the _get_non_ref_members subbbbbbbbbbbbb \n\n";
	my ($dnafragID, $st, $ed)= @_;
#	print $dnafragID,"\n", $st ,"\n", $ed ,"\n\n";
	my $non_ref_members = $self->param('gmember_adaptor')->fetch_all_by_dnafrag_id_start_end($dnafragID, $st, $ed); #returns a list of gene member spanning the given coordinates
	my $non_ref_member_cleaned = {};
#	my $non_ref_member_refhash ={};
	my $size = @$non_ref_members;
#	print $size," non_ref genome_members over given range \n\n";
#    print "NON REF MEMBERSSSSSV &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&\n\n";
#	print Dumper($non_ref_members);
	#grab only the gene members that the source is 'ENSEMBLPEP'
	foreach my $GMember (@$non_ref_members) {
#		print $GMember->dbID(),"\n";
#		if ($GMember->dbID() eq '9275331'){
#			print "found the qqqqqqquery ggggggene member\n\n\n";
#		}
		if ($GMember->get_canonical_SeqMember()->source_name() eq 'ENSEMBLPEP') {
			$non_ref_member_cleaned->{$GMember->dbID()} = $GMember->dnafrag_start();
#			$non_ref_member_refhash->{$GMember->dbID()} = $GMember; #to be able to store the actual objects. must be done this way
		}
	}

	my @orth_sorted; # will contain the gene members ordered by the dnafrag start position
    		#sorting the gene members by dnafrag start position
    my @orth_final;
    foreach my $name (sort { int($non_ref_member_cleaned->{$a}) <=> int($non_ref_member_cleaned->{$b}) or $a cmp $b } keys %$non_ref_member_cleaned ) {
    
#            	printf "%-8s %s \n", $name, $orth_hashref->{$name};
        push @orth_sorted, $name;

    }

 #   print "ORTH SORTED £££££££££££££££££££££££££££££££\n\n";
#    print Dumper(\@orth_sorted);
#    my $orth_sorted = @orth_sorted;
#    print $orth_sorted, " orth_sorted size \n\n\n";
#    print "TTTTTTTTTRRRRRRRIIIIIIIIIAAAAAAAAAAAAALlLLLLLLLLLLLLLLLLLLLLLL\n";
#   check to ensure that the non ref member has an ortholog in the ref species 
    foreach my $mem (@orth_sorted) {
#    	print $mem , "\nyayaya", $self->param('gmember_adaptor')->fetch_by_dbID($mem), "\n\n\n";
    	my @homos = @{$self->param('homolog_adaptor')->fetch_all_by_Member($self->param('gmember_adaptor')->fetch_by_dbID($mem), -METHOD_LINK_TYPE => 'ENSEMBL_ORTHOLOGUES', -TARGET_SPECIES => [$self->param('gdb_adaptor')->fetch_by_dbID($self->param('ref_species_dbid'))->name])};
    	if (@homos) {
	    	push @orth_final, $mem;
		}
    }
#	print Dumper(\@orth_final);
#	my $orth_final = @orth_final;
#	print $orth_final , " orth_final sizeeeee\n\n";
	return \@orth_final;
}

#check that the order of the non ref gmembers that we get from the orthologs match the order of the gene member that we get from the the method '_get_non_ref_members' 
sub _compare {
#    print " THis is the _compare subbbbbbbbbbbbb\n\n";
    my $self = shift;
    my ($orth_non_ref_gmembers_hashref, $ordered_non_ref_gmembers_arrayref,$strand1)= @_;
    my $non_ref_query_gmember = $orth_non_ref_gmembers_hashref->{'query'};
    my $query_index = firstidx { $_ eq $non_ref_query_gmember } @$ordered_non_ref_gmembers_arrayref;
#    print $non_ref_query_gmember, "\n\n", $query_index, "\n\n";

        #create an array of available $ordered_non_ref_gmembers_arrayref index so that we dont check uninitialised values in our comparisons
    my @indexes;
    for my $val (0 .. scalar(@{$ordered_non_ref_gmembers_arrayref})-1) {
        push @indexes, $val;
    }

    my $left1_result = undef ;
    my $left2_result = undef;
    my $right1_result = undef ;
    my $right2_result = undef;

    if (defined($orth_non_ref_gmembers_hashref->{'left1'} )) {
        $left1_result =    (grep {$_ == $query_index-1} @indexes)
                                    && (    ($orth_non_ref_gmembers_hashref->{'left1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -1])
                                         || (      (grep {$_ == $query_index-2} @indexes)
                                                && ($orth_non_ref_gmembers_hashref->{'left1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -2])
                                            )
                                       )
                        ? 1 : 0;

        if (defined($orth_non_ref_gmembers_hashref->{'left2'} )) {
            $left2_result = ( $left1_result
                        ? (
                                    (grep {$_ == $query_index-2} @indexes)
                                 && (   ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -2])
                                     || (   (grep {$_ == $query_index-3} @indexes)
                                         && ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -3])
                                        )
                                    )
                        )
                        : (
                                    (grep {$_ == $query_index-1} @indexes)
                                 && (     ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -1])
                                       || (    (grep {$_ == $query_index-2} @indexes)
                                            && ($orth_non_ref_gmembers_hashref->{'left2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index -2])
                                          )
                                    )
                        )
                     ) ? 1 : 0;
        }
    }

    if (defined($orth_non_ref_gmembers_hashref->{'right1'} )) {
        $right1_result =    (grep {$_ == $query_index+1} @indexes)
                                    && (    ($orth_non_ref_gmembers_hashref->{'right1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +1])
                                         || (      (grep {$_ == $query_index+2} @indexes)
                                                && ($orth_non_ref_gmembers_hashref->{'right1'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +2])
                                            )
                                       )
                        ? 1 : 0;

        if (defined($orth_non_ref_gmembers_hashref->{'right2'} )) {
            $right2_result = ( $right1_result
                        ? (
                                    (grep {$_ == $query_index+2} @indexes)
                                 && (   ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +2])
                                     || (   (grep {$_ == $query_index+3} @indexes)
                                         && ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +3])
                                        )
                                    )
                        )
                        : (
                                    (grep {$_ == $query_index+1} @indexes)
                                 && (     ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +1])
                                       || (    (grep {$_ == $query_index+2} @indexes)
                                            && ($orth_non_ref_gmembers_hashref->{'right2'} eq $ordered_non_ref_gmembers_arrayref->[$query_index +2])
                                          )
                                    )
                        )
                     ) ? 1 : 0;
        }
    }
    return {'left1' => $left1_result, 'right1' => $right1_result, 'left2' => $left2_result, 'right2' => $right2_result};
}

1;
