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

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CompleteSummary

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module creates a summary file from the summary table in the pipeline database

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CompleteSummary;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    my $outfile = $self->param('work_dir') . "/" . $self->param('seq_region') . "/" . $self->param('summary_file');
   print "Writing summary to $outfile\n";

    open OUT, ">$outfile" or die "Unable to open $outfile for writing";

    my $sql = "SELECT * FROM statistics";

    if ($self->param('seq_region')) {
	$sql .= " WHERE seq_region = " . $self->param('seq_region');
    }

    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();

    my $totals;

    while (my $row = $sth->fetchrow_hashref) {
        $totals->{num_bases} += $row->{total_bases};
        $totals->{all_N} += $row->{all_N};
	$totals->{low_complexity} += $row->{low_complexity};
	$totals->{multiple_gats} += $row->{multiple_gats};
        $totals->{no_gat} += $row->{no_gat};
        $totals->{insufficient_gat} += $row->{insufficient_gat};
        $totals->{long_alignment} += $row->{long_alignment};
        $totals->{align_all_N} += $row->{align_all_N};
	$totals->{num_bases_analysed} += $row->{num_bases_analysed};

        my $statistics_id = $row->{statistics_id};
        my $event_sql = "SELECT * FROM event WHERE statistics_id=$statistics_id";
        my $event_sth = $self->compara_dba->dbc->prepare($event_sql);
        $event_sth->execute();
        while (my $event = $event_sth->fetchrow_hashref) {
            #foreach my $key (keys %$event) {
            #    print $key . " " . $event->{$key} . "\n";
            #}
            my $indel_type;
            #if ($event->{microinversion}) {
            #    $indel_type = join "_", "microinversion", $event->{indel}, $event->{type}, $event->{detail};
            #} else {
                $indel_type = join "_", $event->{indel}, $event->{type}, $event->{detail};
            #}
            $indel_type .= "_" . $event->{detail1} if ($event->{detail1});
            $indel_type .= "_" . $event->{detail2} if ($event->{detail2});

            #$totals->{microinverion} += $event->{microinversion};
            $totals->{indel}{$event->{indel}}{$indel_type} += $event->{count};

            #Count polymorphic_insertions
            if ($event->{detail2}) {
                $totals->{detail2}->{$event->{indel}}->{$event->{detail2}} += $event->{count};
            }
        }
    }
    
    $sth->finish;

    print OUT "SUMMARY for chr " . $self->param('seq_region') . "\n";
    print OUT "Total number of bases " . $totals->{'num_bases'} . "\n";

    print OUT "Skipped bases\n";
    printf OUT "  Sequence contains only N %d (%.2f%%)\n", $totals->{'all_N'}, ($totals->{'all_N'}/$totals->{'num_bases'}*100);
    printf OUT "  Low complexity regions %d (%.2f%%)\n", $totals->{'low_complexity'}, ($totals->{'low_complexity'}/$totals->{'num_bases'}*100); 

    printf OUT "  Multiple GenomicAlignTrees %d (%.2f%%)\n", $totals->{multiple_gats}, ($totals->{multiple_gats}/$totals->{'num_bases'}*100);
    printf OUT "  No GenomicAlignTrees %d (%.2f%%)\n", $totals->{no_gat}, ($totals->{no_gat}/$totals->{'num_bases'}*100);
    printf OUT "  Insufficient GenomicAlignTree %d (%.2f%%)\n", $totals->{insufficient_gat}, ($totals->{insufficient_gat}/$totals->{'num_bases'}*100);
    printf OUT "  Long alignment %d (%.2f%%)\n", $totals->{'long_alignment'}, ($totals->{'long_alignment'}/$totals->{'num_bases'}*100);
    printf OUT "  Alignments all N %d (%.2f%%)\n", $totals->{'align_all_N'}, ($totals->{'align_all_N'}/$totals->{'num_bases'}*100);

    printf OUT "Number of bases analysed %d (%.2f%%)\n", $totals->{num_bases_analysed}, ($totals->{num_bases_analysed}/$totals->{'num_bases'}*100);
    #print OUT "Number of microinversions " . $totals->{microinversion} . "\n";
    
    print OUT "\n";
    my $this_analysed;



    for my $indel (keys %{$totals->{'indel'}}) {

        for my $event (sort {$totals->{'indel'}{$indel}{$b} <=> $totals->{'indel'}{$indel}{$a}} keys %{$totals->{'indel'}{$indel}}) {
            
        #my ($indel) = $event =~ /(insertion|deletion)_/;
            
            if ($indel =~ /insertion/) {
                printf OUT "$event %d, of total %.2f%%, of analysed %.2f%%\n", $totals->{'indel'}{$indel}{$event}, (($totals->{'indel'}{$indel}{$event}/$totals->{'num_bases'})/3*100), (($totals->{'indel'}{$indel}{$event}/$totals->{num_bases_analysed}/3)*100);
                $this_analysed += (($totals->{'indel'}{$indel}/$totals->{num_bases_analysed}/3)*100);
            } else {
                printf OUT "$event %d, of total %.2f%%, of analysed %.2f%\n", $totals->{'indel'}{$indel}{$event}, ($totals->{'indel'}{$indel}{$event}/$totals->{'num_bases'}*100), ($totals->{'indel'}{$indel}{$event}/$totals->{num_bases_analysed}*100);
            }
        }
    }

    print OUT "\n\nTotals of polymorphic insertions/deletions\n";
    for my $indel (sort {$a cmp $b} keys %{$totals->{'detail2'}}) {
        print OUT "$indel\n";
        for my $detail2 (sort {$totals->{'detail2'}{$indel}{$b} <=> $totals->{'detail2'}{$indel}{$a}} keys %{$totals->{'detail2'}->{$indel}}) {
            if ($indel eq "insertion") {
                printf OUT "  $detail2 %d, of total %.2f%%, of analysed %.2f%%\n", $totals->{'detail2'}{$indel}{$detail2}, (($totals->{'detail2'}{$indel}{$detail2}/$totals->{'num_bases'})/3*100), (($totals->{'detail2'}{$indel}{$detail2}/$totals->{num_bases_analysed}/3)*100);
            } else {
                printf OUT "  $detail2 %d, of total %.2f%%, of analysed %.2f%%\n", $totals->{'detail2'}{$indel}{$detail2}, ($totals->{'detail2'}{$indel}{$detail2}/$totals->{'num_bases'}*100), ($totals->{'detail2'}{$indel}{$detail2}/$totals->{num_bases_analysed}*100);
            }
        }
    }
    
    close OUT;
}

sub write_output {
    my $self = shift;

}

1;
