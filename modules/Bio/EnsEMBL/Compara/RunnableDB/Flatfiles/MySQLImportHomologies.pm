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

Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies

=head1 DESCRIPTION

This runnable takes a homology dump file (and optionally, attribute files)
and formats them to import the data directly to the homology and homology_member
tables via LOAD DATA.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies;

use warnings;
use strict;

use List::Util qw(min max);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header get_line_count);
use Bio::EnsEMBL::Compara::Utils::IDGenerator qw(:all);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $homology_count = get_line_count($self->param('homology_flatfile')) - 1; # remove header line
    my $homology_id_start = get_id_range($self->compara_dba->dbc, 'homology', $homology_count, $self->param_required('mlss_id'));
    $self->param('homology_id_start', $homology_id_start);

    # handle any attrib files that may have been passed
    $self->param('attribs', {});
    my $attrib_files = $self->param('attrib_files');
    return unless ( $attrib_files );

    # Check the list of attributes expected for this MLSS
    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my %expected = (
        'goc'       => $mlss->get_tagvalue('goc_expected', 0),
        'wga'       => $mlss->get_tagvalue('wga_expected', 0),
        'high_conf' => $self->param('high_conf_expected') // 0,
    );

    # fetch all attributes from file list
    my %attribs;
    my $primary_key = 'homology_id';
    foreach my $attrib ( keys %$attrib_files ) {
        next unless $expected{$attrib};
        my $f = $attrib_files->{$attrib};
        open( my $fh, '<', $f ) or die "Cannot open $f for reading";
        my $header = <$fh>;
        my @header_cols = split( /\s+/, $header );
        die "No $primary_key found in $f - please check file header line\n" unless grep {$_ eq $primary_key} @header_cols;
        while ( my $line = <$fh> ) {
            my $row = map_row_to_header($line, \@header_cols);
            my $primary_id = $row->{$primary_key};
            delete $row->{$primary_key};
            foreach my $attrib_name ( keys %$row ) {
                $attribs{$primary_id}->{$attrib_name} = $row->{$attrib_name};
            }
        }
        close $fh;
    }

    $self->param('attribs', \%attribs);
}

sub write_output {
    my $self = shift;

    my $filename = $self->param_required('homology_flatfile');
    my $attribs  = $self->param('attribs');

    # open homology file
    open(my $hom_fh, '<', $filename) or die "Cannot open $filename for reading";
    my $header_line = <$hom_fh>;
    my @header_cols = split(/\s+/, $header_line);

    # open output files - one per table in tmp space
    my $homology_csv = $self->worker_temp_directory . '/homology.txt';
    open(my $h_csv, '>', $homology_csv) or die "Cannot open $homology_csv for writing";
    my $homology_member_csv = $self->worker_temp_directory . '/homology_member.txt';
    open(my $hm_csv, '>', $homology_member_csv) or die "Cannot open $homology_member_csv for writing";

    # iterate over homology input and format it for later mysqlimport
    my $h_count = 0;
    my $hc_exp_vals;
    my $homology_id_start = $self->param_required('homology_id_start');
    while ( my $line = <$hom_fh> ) {
        my $row = map_row_to_header($line, \@header_cols);

        # add the attribs
        foreach my $attrib_name ( 'goc_score', 'wga_coverage', 'is_high_confidence' ) {
            my $this_attrib = $attribs->{$row->{homology_id}}->{$attrib_name};
            $row->{$attrib_name} = defined $this_attrib ? $this_attrib : '\N';
        }

        my $this_homology_id = $homology_id_start + $h_count;
        my ( $homology_row, $homology_member_rows ) = $self->split_row_for_homology_tables($row, $this_homology_id);
        print $h_csv $homology_row;
        print $hm_csv $homology_member_rows;

        # gather stats for healthchecks
        $h_count++;
        $hc_exp_vals = $self->gather_hc_stats($hc_exp_vals, $row);
    }
    close $h_csv;
    close $hm_csv;
    print "Files written to: $homology_csv & $homology_member_csv\n" if $self->debug;

    # mysqlimport the data
    my $this_dbc = $self->compara_dba->dbc;
    my $user = $this_dbc->username;
    my $pass = $this_dbc->password;
    my $host = $this_dbc->host;
    my $port = $this_dbc->port;
    my $dbname = $this_dbc->dbname;

    # Disconnect from the database before starting the import
    $this_dbc->disconnect_if_idle();

    my $replace = $self->param('replace');
    # Speed up data loading by disabling certain variables, writing the data, and then enabling them back
    my $import_query = "SET AUTOCOMMIT = 0; SET FOREIGN_KEY_CHECKS = 0; " .
        "LOAD DATA LOCAL INFILE '$homology_csv' " . ($replace ? 'REPLACE' : '' ) . " INTO TABLE homology FIELDS TERMINATED BY ','; " .
        "LOAD DATA LOCAL INFILE '$homology_member_csv' " . ($replace ? 'REPLACE' : '' ) . " INTO TABLE homology_member FIELDS TERMINATED BY ','; " .
        "SET AUTOCOMMIT = 1; SET FOREIGN_KEY_CHECKS = 1;";

    my $import_done = 0;
    my $num_tries = 0;
    until ($import_done) {
        $num_tries++;
        die "Import failed 10 times in a row... Something else must be wrong\n" if $num_tries > 10;
        my $import_cmd = "mysql --host=$host --port=$port --user=$user --password=$pass --local-infile=1 $dbname -e \"$import_query\" --max_allowed_packet=1024M";
        my $command = $self->run_command($import_cmd);

        # Make sure all the homologies have been copied correctly
        $hc_exp_vals->{total_rows} = $h_count;
        my $hc_passed = $self->hc_homology_import($hc_exp_vals);
        print "HC " . ( $hc_passed ? 'PASSED' : 'FAILED' ) . "\n\n" if $self->debug;

        # Check what has happened
        if ($command->err =~ /Lock wait timeout exceeded/ || !$hc_passed) {
            # Try importing the data again but in replace mode, just in case some rows were half-copied
            my $desc = $hc_passed ? "Received 'Lock wait timeout exceeded'." : "The imported data appeared corrupted.";
            print $desc . " Retrying...\n" if $self->debug;
            if (! $replace) {
                $import_query =~ s/  INTO / REPLACE INTO /g;
                $replace = 1;
            }
        } elsif ($command->exit_code) {
            # Something unexpected has gone wrong: die and report the error
            $command->die_with_log;
        } else {
            $import_done = 1;
        }
    }
    $self->warning("'homology' and 'homology_member' data imported successfully after $num_tries attempts\n");
}

sub split_row_for_homology_tables {
    my ( $self, $row, $homology_id ) = @_;

    my $homology_row = join(",",
        $homology_id,
        $row->{mlss_id},
        $row->{homology_type},
        $row->{is_tree_compliant},
        '\N','\N','\N','\N','\N',
        $row->{species_tree_node_id},
        $row->{gene_tree_node_id},
        $row->{gene_tree_root_id},
        $row->{goc_score},
        $row->{wga_coverage},
        $row->{is_high_confidence},
    ) . "\n";

    my $homology_member_rows;
    foreach my $prefix ( '', 'homology_' ) {
        my $this_hm_row = join(",",
            $homology_id,
            $row->{"${prefix}gene_member_id"},
            $row->{"${prefix}seq_member_id"},
            $row->{"${prefix}cigar_line"},
            $row->{"${prefix}perc_cov"},
            $row->{"${prefix}perc_id"},
            $row->{"${prefix}perc_pos"},
        );
        $homology_member_rows .= "$this_hm_row\n";
    }

    return ( $homology_row, $homology_member_rows );
}

sub hc_homology_import {
    my ( $self, $exp_vals ) = @_;

    my $total_rows = $exp_vals->{total_rows};
    my $total_hm_rows = $total_rows*2;
    $exp_vals->{avg_stn} = $exp_vals->{sum_stn}/$total_rows;
    $exp_vals->{avg_gtn} = $exp_vals->{sum_gtn}/$total_rows;
    $exp_vals->{avg_gtr} = $exp_vals->{sum_gtr}/$total_rows;

    $exp_vals->{avg_gm}  = $exp_vals->{sum_gm}/$total_hm_rows;
    $exp_vals->{avg_sm}  = $exp_vals->{sum_sm}/$total_hm_rows;
    $exp_vals->{avg_cov} = $exp_vals->{sum_cov}/$total_hm_rows;
    $exp_vals->{avg_id}  = $exp_vals->{sum_id}/$total_hm_rows;
    $exp_vals->{avg_pos} = $exp_vals->{sum_pos}/$total_hm_rows;

    # HOMOLOGY check : HC number of rows and specific fields in homology table
    my $mlss_id = $self->param_required('mlss_id');
    my $sql = "SELECT COUNT(*) AS total_rows, SUM(species_tree_node_id IS NOT NULL) AS stn_count,
               MIN(species_tree_node_id) as min_stn, MAX(species_tree_node_id) as max_stn, AVG(species_tree_node_id) as avg_stn,
               SUM(gene_tree_node_id IS NOT NULL) AS gtn_count, SUM(gene_tree_root_id IS NOT NULL) AS gtr_count,
               MIN(gene_tree_node_id) as min_gtn, MAX(gene_tree_node_id) as max_gtn, AVG(gene_tree_node_id) as avg_gtn,
               MIN(gene_tree_root_id) as min_gtr, MAX(gene_tree_root_id) as max_gtr, AVG(gene_tree_root_id) as avg_gtr,
               SUM(goc_score IS NOT NULL) AS goc_count, SUM(wga_coverage IS NOT NULL) AS wga_count,
               SUM(is_high_confidence IS NOT NULL) AS hc_count
               FROM homology WHERE method_link_species_set_id = $mlss_id";
    my $db_vals = $self->compara_dba->dbc->db_handle->selectrow_hashref($sql);

    # check homology row counts
    if ( $exp_vals->{total_rows} != $db_vals->{total_rows} ) {
        $self->warning("The number of rows written in the homology table (" . $db_vals->{total_rows} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    }

    # check homology.species_tree_node_id
    if ( $exp_vals->{total_rows} != $db_vals->{stn_count} ) {
        $self->warning("The number of species_tree_node_ids written in the homology table (" . $db_vals->{stn_count} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    } elsif ( $exp_vals->{min_stn} != $db_vals->{min_stn} || $exp_vals->{max_stn} != $db_vals->{max_stn} || ! approx_equal($exp_vals->{avg_stn}, $db_vals->{avg_stn}) ) {
        $self->warning("Some truncated species_tree_node_ids have been detected in the homology table:\n" . hc_report($exp_vals, $db_vals, 'stn'));
        return 0;
    }

    # check homology.gene_tree_node_id
    if ( $exp_vals->{total_rows} != $db_vals->{gtn_count} ) {
        $self->warning("The number of gene_tree_node_ids written in the homology table (" . $db_vals->{gtn_count} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    } elsif ( $exp_vals->{min_gtn} != $db_vals->{min_gtn} || $exp_vals->{max_gtn} != $db_vals->{max_gtn} || ! approx_equal($exp_vals->{avg_gtn}, $db_vals->{avg_gtn}) ) {
        $self->warning("Some truncated gene_tree_node_ids have been detected in the homology table:\n" . hc_report($exp_vals, $db_vals, 'gtn'));
        return 0;
    }

    # check homology.gene_tree_root_id
    if ( $exp_vals->{total_rows} != $db_vals->{gtr_count} ) {
        $self->warning("The number of gene_tree_root_ids written in the homology table (" . $db_vals->{gtr_count} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    } elsif ( $exp_vals->{min_gtr} != $db_vals->{min_gtr} || $exp_vals->{max_gtr} != $db_vals->{max_gtr} || ! approx_equal($exp_vals->{avg_gtr}, $db_vals->{avg_gtr}) ) {
        $self->warning("Some truncated gene_tree_root_ids have been detected in the homology table:\n" . hc_report($exp_vals, $db_vals, 'gtr'));
        return 0;
    }

    # check optional homology attributes: goc, wga, high_conf
    if ( $self->param('goc_expected') && $exp_vals->{total_rows} != $db_vals->{goc_count} ) {
        $self->warning("The number of goc_scores written in the homology table (" . $db_vals->{goc_count} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    }
    if ( $self->param('wga_expected') && $exp_vals->{total_rows} != $db_vals->{wga_count} ) {
        $self->warning("The number of wga_coverage values written in the homology table (" . $db_vals->{wga_count} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    }
    if ( $self->param('high_conf_expected') &&  $exp_vals->{total_rows} != $db_vals->{hc_count} ) {
        $self->warning("The number of high_conf scores written in the homology table (" . $db_vals->{hc_count} . ") doesn't match the number of lines in the homology flat file (" . $exp_vals->{total_rows} . ")");
        return 0;
    }


    # HOMOLOGY_MEMBER check
    my $homology_id_start = $self->param_required('homology_id_start');
    my $homology_id_end   = $homology_id_start + $total_rows - 1;
    my $hm_sql = "SELECT COUNT(*) AS total_hm_rows, SUM(gene_member_id IS NOT NULL) AS gm_count,
               MIN(gene_member_id) as min_gm, MAX(gene_member_id) as max_gm, AVG(gene_member_id) as avg_gm,
               SUM(seq_member_id IS NOT NULL) AS sm_count, MIN(seq_member_id) as min_sm, MAX(seq_member_id) as max_sm,
               AVG(seq_member_id) as avg_sm, SUM(perc_cov IS NOT NULL) AS cov_count,
               MIN(perc_cov) as min_cov, MAX(perc_cov) as max_cov, AVG(perc_cov) as avg_cov,
               SUM(perc_id IS NOT NULL) AS id_count, MIN(perc_id) as min_id, MAX(perc_id) as max_id,
               AVG(perc_id) as avg_id, SUM(perc_pos IS NOT NULL) AS pos_count, MIN(perc_pos) as min_pos,
               MAX(perc_pos) as max_pos, AVG(perc_pos) as avg_pos
               FROM homology_member WHERE homology_id BETWEEN $homology_id_start AND $homology_id_end";
    $db_vals = $self->compara_dba->dbc->db_handle->selectrow_hashref($hm_sql);

    # check homology row counts
    if ( $total_hm_rows != $db_vals->{total_hm_rows} ) {
        $self->warning("The number of rows written in the homology_member table (" . $db_vals->{total_hm_rows} . ") doesn't match the number of lines in the homology flat file (" . $total_hm_rows . ")");
        return 0;
    }

    # check homology_member.gene_member_id
    if ( $total_hm_rows != $db_vals->{gm_count} ) {
        $self->warning("The number of gene_member_ids written in the homology_member table (" . $db_vals->{gm_count} . ") doesn't match the number of lines in the homology flat file (" . $total_hm_rows . ")");
        return 0;
    } elsif ( $exp_vals->{min_gm} != $db_vals->{min_gm} || $exp_vals->{max_gm} != $db_vals->{max_gm} || ! approx_equal($exp_vals->{avg_gm}, $db_vals->{avg_gm}) ) {
        $self->warning("Some truncated gene_member_ids have been detected in the homology_member table:\n" . hc_report($exp_vals, $db_vals, 'gm'));
        return 0;
    }

    # check homology_member.seq_member_id
    if ( $total_hm_rows != $db_vals->{sm_count} ){
        $self->warning("The number of seq_member_ids written in the homology_member table (" . $db_vals->{sm_count} . ") doesn't match the number of lines in the homology flat file (" . $total_hm_rows . ")");
        return 0;
    } elsif ( $exp_vals->{min_sm} != $db_vals->{min_sm} || $exp_vals->{max_sm} != $db_vals->{max_sm} || ! approx_equal($exp_vals->{avg_sm}, $db_vals->{avg_sm}) ) {
        $self->warning("Some truncated seq_member_ids have been detected in the homology_member table:\n" . hc_report($exp_vals, $db_vals, 'sm'));
        return 0;
    }

    # check homology_member.perc_%
    if ( $total_hm_rows != $db_vals->{cov_count} ) {
        $self->warning("The number of perc_cov values written in the homology_member table (" . $db_vals->{cov_count} . ") doesn't match the number of lines in the homology flat file (" . $total_hm_rows . ")");
        return 0;
    } elsif ( ! ( approx_equal($exp_vals->{min_cov}, $db_vals->{min_cov}) && approx_equal($exp_vals->{max_cov}, $db_vals->{max_cov}) && approx_equal($exp_vals->{avg_cov}, $db_vals->{avg_cov}) ) ) {
        $self->warning("Some truncated perc_cov values have been detected in the homology_member table:\n" . hc_report($exp_vals, $db_vals, 'cov'));
        return 0;
    }
    if ( $total_hm_rows != $db_vals->{id_count} ) {
        $self->warning("The number of perc_id values written in the homology_member table (" . $db_vals->{id_count} . ") doesn't match the number of lines in the homology flat file (" . $total_hm_rows . ")");
        return 0;
    } elsif ( ! ( approx_equal($exp_vals->{min_id}, $db_vals->{min_id}) && approx_equal($exp_vals->{max_id}, $db_vals->{max_id}) && approx_equal($exp_vals->{avg_id}, $db_vals->{avg_id}) ) ) {
        $self->warning("Some truncated perc_id values have been detected in the homology_member table:\n" . hc_report($exp_vals, $db_vals, 'id'));
        return 0;
    }
    if ( $total_hm_rows != $db_vals->{pos_count} ) {
        $self->warning("The number of perc_pos values written in the homology_member table (" . $db_vals->{pos_count} . ") doesn't match the number of lines in the homology flat file (" . $total_hm_rows . ")");
        return 0;
    } elsif ( ! ( approx_equal($exp_vals->{min_pos}, $db_vals->{min_pos}) && approx_equal($exp_vals->{max_pos}, $db_vals->{max_pos}) && approx_equal($exp_vals->{avg_pos}, $db_vals->{avg_pos}) ) ) {
        $self->warning("Some truncated perc_pos values have been detected in the homology_member table:\n" . hc_report($exp_vals, $db_vals, 'pos'));
        return 0;
    }

    # other than that, it passes.. ;)
    return 1;
}

sub gather_hc_stats {
    my ( $self, $exp_vals, $row ) = @_;

    # homology table fields
    $exp_vals->{min_stn} =  min $row->{species_tree_node_id}, ($exp_vals->{min_stn}//10**12);
    $exp_vals->{max_stn} =  max $row->{species_tree_node_id}, ($exp_vals->{max_stn}//0);
    $exp_vals->{sum_stn} += $row->{species_tree_node_id};

    $exp_vals->{min_gtn} =  min $row->{gene_tree_node_id}, ($exp_vals->{min_gtn}//10**12);
    $exp_vals->{max_gtn} =  max $row->{gene_tree_node_id}, ($exp_vals->{max_gtn}//0);
    $exp_vals->{sum_gtn} += $row->{gene_tree_node_id};

    $exp_vals->{min_gtr} =  min $row->{gene_tree_root_id}, ($exp_vals->{min_gtr}//10**12);
    $exp_vals->{max_gtr} =  max $row->{gene_tree_root_id}, ($exp_vals->{max_gtr}//0);
    $exp_vals->{sum_gtr} += $row->{gene_tree_root_id};

    # homology_member table fields
    $exp_vals->{min_gm} =  min $row->{gene_member_id}, $row->{homology_gene_member_id}, ($exp_vals->{min_gm}//10**12);
    $exp_vals->{max_gm} =  max $row->{gene_member_id}, $row->{homology_gene_member_id}, ($exp_vals->{max_gm}//0);
    $exp_vals->{sum_gm} += ($row->{gene_member_id} + $row->{homology_gene_member_id});

    $exp_vals->{min_sm} =  min $row->{seq_member_id}, $row->{homology_seq_member_id}, ($exp_vals->{min_sm}//10**12);
    $exp_vals->{max_sm} =  max $row->{seq_member_id}, $row->{homology_seq_member_id}, ($exp_vals->{max_sm}//0);
    $exp_vals->{sum_sm} += ($row->{seq_member_id} + $row->{homology_seq_member_id});

    $exp_vals->{min_cov} =  min $row->{perc_cov}, $row->{homology_perc_cov}, ($exp_vals->{min_cov}//101);
    $exp_vals->{max_cov} =  max $row->{perc_cov}, $row->{homology_perc_cov}, ($exp_vals->{max_cov}//0);
    $exp_vals->{sum_cov} += ($row->{perc_cov} + $row->{homology_perc_cov});

    $exp_vals->{min_id} =  min $row->{perc_id}, $row->{homology_perc_id}, ($exp_vals->{min_id}//101);
    $exp_vals->{max_id} =  max $row->{perc_id}, $row->{homology_perc_id}, ($exp_vals->{max_id}//0);
    $exp_vals->{sum_id} += ($row->{perc_id} + $row->{homology_perc_id});

    $exp_vals->{min_pos} =  min $row->{perc_pos}, $row->{homology_perc_pos}, ($exp_vals->{min_pos}//101);
    $exp_vals->{max_pos} =  max $row->{perc_pos}, $row->{homology_perc_pos}, ($exp_vals->{max_pos}//0);
    $exp_vals->{sum_pos} += ($row->{perc_pos} + $row->{homology_perc_pos});

    return $exp_vals;
}

sub approx_equal {
    my ( $a, $b, $abs_tol ) = @_;
    $abs_tol //= 0.0001;

    if ( defined $a && defined $b && abs($a - $b) <= $abs_tol ) {
        return 1;
    } else {
        return 0;
    }
}

sub hc_report {
    my ( $exp_vals, $db_vals, $type ) = @_;
    my $report = "             expected\tgot\n";
    $report .= "- min values : " . $exp_vals->{"min_$type"} . "\t" . $db_vals->{"min_$type"} . "\n";
    $report .= "- max values : " . $exp_vals->{"max_$type"} . "\t" . $db_vals->{"max_$type"} . "\n";
    $report .= "- avg values : " . $exp_vals->{"avg_$type"} . "\t" . $db_vals->{"avg_$type"} . "\n";
    return $report;
}

1;
