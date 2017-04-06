=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CopyAlignmentTables

=head1 SYNOPSIS

	Copy genomic_align and genomic_align_block tables from the 'from_url' db to
	the 'to_url' db

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CopyAlignmentTables;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $from_creds = $self->sql_creds_from_url( $self->param_required('from_url') );
	my $to_creds   = $self->sql_creds_from_url( $self->param_required('to_url') );
	my $mlss_str   = join( ',', @{ $self->param_required('mlss_id_list') } );

	my @commands;
	for my $table ( 'genomic_align_block', 'genomic_align' ) {
		push @commands, "mysqldump $from_creds $table --where='method_link_species_set_id IN ($mlss_str)' | mysql $to_creds";
	}

	$self->param( 'commands', \@commands );
}

sub run {
	my $self = shift;

	for my $cmd ( @{ $self->param_required('commands') } ) {
		print "CMD: $cmd\n" if $self->debug;
		system( $cmd ) == 0 or die "Could not run command: $cmd\nError code: $?\n";		
	}
}

sub sql_creds_from_url {
	my ( $self, $url ) = @_;

	$url =~ m!mysql://([\w:]+)@([:a-z0-9\-\.]+)/(\w+)!;
	my ( $user, $pass ) = split(':', $1 );
	my ( $host, $port ) = split(':', $2 );
	my $db_name = $3;

	my $creds = "-h $host -u $user ";
	$creds .= "-P $port " if $port;
	$creds .= "-p$pass " if $pass;
	$creds .= "$db_name";
	chomp $creds;

	return $creds;
}

1;