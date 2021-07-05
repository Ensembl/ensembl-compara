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

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneMemberHomologyStats

=head1 SYNOPSIS

Generate per-member homology stats to populate the gene_member_hom_stats table for ensembl
compara release

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneMemberHomologyStats;

use warnings;
use strict;

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);
use File::Find;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;
    
    my $basedir = $self->param_required('homology_dumps_dir');
    my $member_type = $self->param_required('member_type');
    
    my $homology_files= [];
    my $wanted = sub { _wanted($homology_files, $member_type) };

    {
        local $File::Find::dont_use_nlink = 1;
        find($wanted, $basedir);
    }

    print "Found " . scalar @$homology_files . " homology dump files to scan..\n\n" if $self->debug;
    $self->param('homology_files', $homology_files);
}

sub _wanted {
   return if ! -e; 
   my ($files, $member_type) = @_;
   push( @$files, $File::Find::name ) if $File::Find::name =~ /\.$member_type\.homologies\.tsv$/;
}

sub run {
    my $self = shift;

    my @hom_files = @{$self->param('homology_files')};

    my $gm_hom_stats;
    my $file_count = 0;
    foreach my $hom_file ( @hom_files ) {
        $file_count++;
        # print "Scanning $hom_file\n" if $self->debug;
        open(my $hom_handle, '<', $hom_file) or die "Cannot open $hom_file";
        my $this_header = <$hom_handle>;
        my @head_cols = split(/\s+/, $this_header);
        while ( my $line = <$hom_handle> ) {
            my $row = map_row_to_header($line, \@head_cols);
            my ( $homology_type, $gm_id_1, $gm_id_2 ) = ($row->{homology_type}, $row->{gene_member_id}, $row->{homology_gene_member_id});
            
            $gm_hom_stats->{$gm_id_1}->{orthologues} += 1 if ( $homology_type =~ /^ortholog/ );
            $gm_hom_stats->{$gm_id_2}->{orthologues} += 1 if ( $homology_type =~ /^ortholog/ );
            
            $gm_hom_stats->{$gm_id_1}->{homoeologues} += 1 if ( $homology_type =~ /^homoeolog/ );
            $gm_hom_stats->{$gm_id_2}->{homoeologues} += 1 if ( $homology_type =~ /^homoeolog/ );
            
            $gm_hom_stats->{$gm_id_1}->{paralogues} += 1 if ( $homology_type =~ /paralog$/ || $homology_type eq 'gene_split' );
            $gm_hom_stats->{$gm_id_2}->{paralogues} += 1 if ( $homology_type =~ /paralog$/ || $homology_type eq 'gene_split' );
        }
        printf("%i files scanned; %i gene members recorded..\n", $file_count, scalar(keys %$gm_hom_stats)) if ($self->debug && $file_count % 1000 == 0);
    }
    $self->param('gm_hom_stats', $gm_hom_stats);
}

sub write_output {
    my $self = shift;
    
    my $update_stats_sql = "UPDATE gene_member_hom_stats SET orthologues = ?, paralogues = ?, homoeologues = ? WHERE gene_member_id = ?";
    my $sth = $self->compara_dba->dbc->prepare($update_stats_sql);
    
    my $gm_hom_stats = $self->param('gm_hom_stats');
    foreach my $gm_id ( keys %$gm_hom_stats ) {
        $sth->execute(
            ($gm_hom_stats->{$gm_id}->{orthologues}  || 0),
            ($gm_hom_stats->{$gm_id}->{paralogues}   || 0),
            ($gm_hom_stats->{$gm_id}->{homoeologues} || 0),
            $gm_id
        );
    }
    $sth->finish;
}

1;
