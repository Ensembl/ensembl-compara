=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore;

use strict;
use warnings;
use Data::Dumper;
use DBI;

use base ('Bio::EnsEMBL::Hive::Process');

use Bio::EnsEMBL::Registry;

=head2 fetch_input
	Parse ortholog_quality table
=cut

sub fetch_input {
	my $self = shift;

	# !!!!REMOVE!!!!
	return 1;

	my $query = "SELECT exon_coverage, intron_coverage FROM ortholog_quality";
	my $dbh = $self->_select_dbh;	
	my $raw_coverage_list = $dbh->selectall_arrayref($query);

	my @coverage_list;
	foreach my $r ( @{ $raw_coverage_list } ){
		push( @coverage_list, $r->[0] );
	}

	$self->param('coverage_list', \@coverage_list);
}

sub _select_dbh {
	my $self = shift;

	return $self->dbc->db_handle if ( defined $self->dbc );

	$self->warning("Connecting to DBI:mysql:database=cc21_qcwith_alignment;host=compara3;port=3306!!!!!");
	my $dbh = DBI->connect( 
		"DBI:mysql:database=cc21_qcwith_alignment;host=compara3;port=3306", 
		'ensadmin', 
		'ensembl', 
		{ RaiseError => 1 } 
	) or die ( "Couldn't connect to database: " . DBI->errstr );
	return $dbh;
}

=head2 run

	Description: check input from previous step and prepare report structure

=cut

sub run {
	my $self = shift;

	# !!!!REMOVE!!!!
	return 1;

	my $coverage_list = $self->param('coverage_list');

	my $average_cov = _average_coverage( $coverage_list );
	my $std_dev_cov = _std_dev_coverage( $coverage_list, $average_cov );

	my $threshold = ($average_cov-$std_dev_cov);
	$self->warning("average: $average_cov; stdev: $std_dev_cov; threshold: $threshold");
	$self->param( 'threshold', {'quality_threshold' => $threshold} );
}

=head2 write_output

	Description: send data to correct dataflow branch!

=cut

sub write_output {
	my $self = shift;

	# $self->dataflow_output_id( $self->param('threshold'), 1 );
	# !!!!REMOVE!!!!
	$self->dataflow_output_id( {quality_threshold => 50}, 1 );
}

sub _average_coverage {
	my $cov_l = shift;

	my ($total, $c);
	foreach my $cov ( @{ $cov_l } ){
		$total += $cov;
		$c++;
	}
	return ($total/$c);
}

sub _std_dev_coverage {
	my($data, $average) = @_;
        
    if(@$data == 1){
            return 0;
    }
    my $sqtotal = 0;
    foreach(@$data) {
        $sqtotal += ($average-$_) ** 2;
    }
    my $std = ($sqtotal / (@$data-1)) ** 0.5;
    return $std;
}


1;