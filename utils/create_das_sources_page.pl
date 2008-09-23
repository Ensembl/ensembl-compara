#!/usr/local/bin/perl

use strict;
use warnings;

package create_das_dsn_page;
# This script
use FindBin qw($Bin);
use Cwd;
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use DBI;

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  unshift @INC, "$SERVERROOT";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

my ($sources_page);
&GetOptions(
	    's'  => \$sources_page
	    );

my %featuresMasterTable = (
			   'karyotype' => 'karyotype',
			   'transcripts' => 'gene',
			   'ditags' => 'ditag_feature',
			   'cagetags' => 'ditag_feature',
			   );
my %featuresQuery = (
	'karyotype' => qq{ select s.name, t.seq_region_start, t.seq_region_end from karyotype t, seq_region s where t.seq_region_id = s.seq_region_id limit 1},
	'prediction_transcripts' => qq{ select s.name, t.seq_region_start, t.seq_region_end from prediction_transcript t, seq_region s where t.seq_region_id = s.seq_region_id limit 1},
	'transcripts' => qq{ select s.name, t.seq_region_start, t.seq_region_end from gene t, seq_region s where t.seq_region_id = s.seq_region_id limit 1},
	'ditags' => qq{ select s.name, t.seq_region_start, t.seq_region_end from seq_region s, ditag_feature t, analysis a where a.logic_name in ('GIS_PET_Encode', 'medaka_5pSAGE') and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id limit 1},
	'cagetags' => qq{ select s.name, t.seq_region_start, t.seq_region_end from seq_region s, ditag_feature t, analysis a where a.logic_name = 'FANTOM_CAGE' and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id limit 1},
);

my %sourcesIds = (
		  'reference' => 1,
		  'karyotype' => 2,
		  'transcripts' => 3,
		  'ditags' => 4,
		  'cagetags' => 5, 
		  'prediction_transcripts' => 6,
		  );

# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs; 

my $species_info;


my $species_defs = EnsEMBL::Web::SpeciesDefs->new();

my $cdb_info = $species_defs->{_storage}->{Multi}->{databases}->{DATABASE_COMPARA};
my $cdb = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
						       -dbname => $cdb_info->{'NAME'},
						       -host => $cdb_info->{'HOST'},
						       -port => $cdb_info->{'PORT'},
						       -user=> $cdb_info->{'USER'},
						       -driver => $cdb_info->{'DRIVER'},
						 );

my $ta = $cdb->get_NCBITaxonAdaptor();
my $hash = $species_defs;

my $species =  $SiteDefs::ENSEMBL_SPECIES || [];

my $shash;
$| = 1;
foreach my $sp (@$species) {
    print STDERR "$sp ... ";

    my $search_info = $species_defs->get_config($sp, 'SEARCH_LINKS');
    (my $vsp = $sp) =~ s/\_/ /g;
    $species_info->{$sp}->{'species'} = $vsp;
    my $tanode = $ta->fetch_node_by_name($vsp);
    print STDERR " No Taxon ID ..." and next unless $tanode;
    $species_info->{$sp}->{'taxon_id'} = $tanode->taxon_id;

    my $db_info = $species_defs->get_config($sp, 'databases')->{'DATABASE_CORE'};
    my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
			  	 -species => $sp,
				 -dbname => $db_info->{'NAME'},
				 -host => $db_info->{'HOST'},
				 -port => $db_info->{'PORT'},
				 -user=> $db_info->{'USER'},
				 -driver => $db_info->{'DRIVER'},
						 );

    my @toplevel_slices = @{$db->get_SliceAdaptor->fetch_all('toplevel', undef, 1)};
    print STDERR " No toplevel entries ..." and next unless (@toplevel_slices);
    my %thash;
    map {$thash{$_->seq_region_name } = $_} @toplevel_slices;

    print STDERR scalar(@toplevel_slices), " toplevel entry points\n";
    my $mapmaster = sprintf("%s.%s.reference", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'));
    $shash->{$mapmaster}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";

    $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), scalar(@toplevel_slices));


    my $sl = $thash{$search_info->{'MAPVIEW1_TEXT'} || $search_info->{'DEFAULT1_TEXT'}} || $toplevel_slices[0];
    $shash->{$mapmaster}->{'test_range'} = sprintf("%s:%d,%d", $sl->seq_region_name, $sl->start, $sl->end);

    #warn Data::Dumper::Dumper(\%thash);

    my $cs = $sl->coord_system;
    my $csa = $cs->{adaptor};

    if (my $lcs = $csa->fetch_by_rank($cs->rank + 1)) {
	my @projected_segments = @{$sl->project($lcs->name) || []};
	if (my $pseg = shift @projected_segments) {
      	  my $path;

      	  eval {
	    $path = $sl->project($lcs->name);
	  };

      	  if ($path) {
            warn (join('*', $cs->name, $lcs->name, $path, $path->[0]));
	    $path = $path->[0]->to_Slice;
            $shash->{$mapmaster}->{'test_range'} = sprintf("%s:%d,%d", $path->seq_region_name, $path->start, $path->end);
      	  }
    	}
    }

    print STDERR "\t $sp : reference => On\n";
    print STDERR "\t\t\tTEST REGION : ", $shash->{$mapmaster}->{'test_range'}, "\n";

    foreach my $feature ( qw(karyotype transcripts ditags cagetags)) {
	my $dbn = 'DATABASE_CORE';
	my $table = $featuresMasterTable{$feature};
	my $rv = $species_defs->get_table_size(
					      { 
						  -db => $dbn, 
						  -table=> $table 
					      },
					      $sp
					      );

	print STDERR "\t $sp : $feature => Off\n" and next unless $rv;
        my $sql = $featuresQuery{$feature};
        my $sth = $db->dbc->prepare($sql);
        $sth->execute();
        my @r = $sth->fetchrow();
	print STDERR "\t $sp : $feature => Off\n" and next unless @r;
	print STDERR "\t $sp : $feature : $table => ", $rv || 'Off',  "\n";
        print STDERR "\t\t\tTEST REGION : ", join('*', @r), "\n";
	my $dsn = sprintf("%s.%s.%s", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), $feature);
 	$shash->{$dsn}->{'test_range'} = sprintf("%s:%s,%s",@r); 
	$shash->{$dsn}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";
	$shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
    }
}

    sources($shash);

print STDERR sprintf("%d sources are active\n", scalar(keys %$shash));
#print STDERR Data::Dumper::Dumper($species_info);

sub dsn {
    my $sources = shift;
    print qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASDSN SYSTEM "http://www.biodas.org/dtd/dasdsn.dtd">\n);
    print "<DASDSN>\n";

    for my $dsn (sort keys %$sources) {
	print " <DSN>\n";
	print qq(  <SOURCE id="$dsn">$dsn</SOURCE>\n);
	print qq(  <MAPMASTER>$sources->{$dsn}{mapmaster}</MAPMASTER>\n);
	print qq(  <DESCRIPTION>\n   $sources->{$dsn}{description}\n  </DESCRIPTION>\n);
	print " </DSN>\n";
    }
    print "</DASDSN>\n";
}

sub sources {
    my $sources = shift;

    my ($day, $month, $year) = (localtime)[3,4,5];
    my $today = sprintf("%04d-%02d-%02d", $year + 1900, $month + 1, $day);

    print qq(<?xml version="1.0" encoding="UTF-8" ?>\n);

    print qq{<SOURCES xmlns="http://biodas.org/documents/das2">\n};
    for my $dsn (sort keys %$sources) {
	my @n = split /\./, $dsn;
	my $species = shift @n;
	(my $vsp = $species) =~ s/\_/ /g;
	my $source = pop @n;
	my $assembly = join('.', @n);

	my $id = sprintf("ENSEMBL_%s_%s", $sourcesIds{$source} || $source, $assembly);
	my $capability = $source eq 'reference' ?
	    qq{<CAPABILITY type="das1:entry_points" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/entry_points"/>
      <CAPABILITY type="das1:sequence" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/sequence"/>} :
	    qq{<CAPABILITY type="das1:stylesheet" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/stylesheet"/> };

# TODO: THIS IS NOT CORRECT - WE ARE PUBLISHING SOURCES AS ALWAYS BEING CHROMOSOME COORDINATES
	print sprintf 
qq{ 
  <SOURCE uri="%s" title="%s" description="%s">
    <MAINTAINER email="helpdesk\@ensembl.org" />
    <VERSION uri="latest" created="%s">
      <COORDINATES uri="ensembl_location_chromosome" taxid="%d" source="Chromosome" authority="%s" version="%s" test_range="%s">$assembly,Chromosome,$vsp</COORDINATES>
      <CAPABILITY type="das1:features" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/features" />
      $capability
      <PROPERTY name="label" value="ENSEMBL" />
    </VERSION>
  </SOURCE>
}, $id, $dsn, $sources->{$dsn}{description}, $today, $ta->fetch_node_by_name($vsp)->taxon_id, $assembly, $assembly, $sources->{$dsn}->{'test_range'}, $dsn, $dsn, $dsn;
    }
    print "</SOURCES>\n";

    
}


__END__
           
=head1 NAME
                                                                                
create_das_dsn_page.pl


=head1 DESCRIPTION

A script that generates XML file that effectivly is a response to 
/das/dsn and /das/sources commands to this server. The script just prints the XML to STDOUT.
To create a file use redirection. e.g

./create_das_dsn_page.pl > ../htdocs/das/dsn
./create_das_dsn_page.pl -s > ../htdocs/das/sources


=head1 AUTHOR
                                                                                
[Eugene Kulesha], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html

