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
			   'cagetags' => 'ditag_feature'
			   );

my %sourcesIds = (
		  'reference' => 1,
		  'karyotype' => 2,
		  'transcripts' => 3,
		  'ditags' => 4,
		  'cagetags' => 5, 
		  );

# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs; 

my $species_info;


my $species_defs = EnsEMBL::Web::SpeciesDefs->new();

my $cdb_info = $species_defs->{_storage}->{Multi}->{databases}->{ENSEMBL_COMPARA};
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
    $species_info->{$sp}->{'taxon_id'} = $ta->fetch_node_by_name($vsp)->taxon_id;
    $species_info->{$sp}->{'test_range'} = sprintf("%s:1,100000", $search_info->{'MAPVIEW1_TEXT'} || $search_info->{'DEFAULT1_TEXT'});

    my $db_info = $species_defs->get_config($sp, 'databases')->{'ENSEMBL_DB'};
    my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
			  	 -species => $sp,
				 -dbname => $db_info->{'NAME'},
				 -host => $db_info->{'HOST'},
				 -port => $db_info->{'PORT'},
				 -user=> $db_info->{'USER'},
				 -driver => $db_info->{'DRIVER'},
						 );

    my @toplevel_slices = @{$db->get_SliceAdaptor->fetch_all('toplevel', undef, 1)};

    print STDERR scalar(@toplevel_slices), " toplevel entry points\n";
    my $mapmaster = sprintf("%s.%s.reference", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'));
    $shash->{$mapmaster}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";

    $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), scalar(@toplevel_slices));

    foreach my $feature ( qw(karyotype transcripts ditags cagetags)) {
	my $db = 'ENSEMBL_DB';
	my $table = $featuresMasterTable{$feature};
	my $rv = $species_defs->get_table_size(
					      { 
						  -db => $db, 
						  -table=> $table 
					      },
					      $sp
					      );
	print STDERR "\t $sp : $feature : $table => ", $rv || 'Off',  "\n";

	next unless $rv;


	my $dsn = sprintf("%s.%s.%s", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), $feature);
	$shash->{$dsn}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";
	$shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
    }

    
}

if ($sources_page) {
    sources($shash);
} else {
    dsn($shash);
}

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
	    qq{<CAPABILITY type="das1:entry_points" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/entry_points"/>} :
	    qq{<CAPABILITY type="das1:stylesheet" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/stylesheet"/> };

	print sprintf 
qq{ 
  <SOURCE uri="%s" title="%s" description="%s">
    <MAINTAINER email="helpdesk\@ensembl.org" />
    <VERSION uri="latest" created="%s">
      <COORDINATES uri="ensembl_location_chromosome" taxid="%d" source="Chromosome" authority="%s" version="%s" test_range="%s"/>
      <CAPABILITY type="das1:features" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/features" />
      $capability
      <PROPERTY name="label" value="ENSEMBL" />
    </VERSION>
  </SOURCE>
}, $id, $dsn, $sources->{$dsn}{description}, $today, $ta->fetch_node_by_name($vsp)->taxon_id, $assembly, $assembly, $species_info->{$species}->{'test_range'}, $dsn, $dsn;
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

