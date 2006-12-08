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
  'transcripts' => qq{ select s.name, t.seq_region_start, t.seq_region_end from gene t, seq_region s where t.seq_region_id = s.seq_region_id limit 1},
  'ditags' => qq{ select s.name, t.seq_region_start, t.seq_region_end from seq_region s, ditag_feature t, analysis a where a.logic_name = 'GIS_PET_Encode' and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id limit 1},
  'cagetags' => qq{ select s.name, t.seq_region_start, t.seq_region_end from seq_region s, ditag_feature t, analysis a where a.logic_name = 'FANTOM_CAGE' and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id limit 1},
);

my %sourcesIds = (
  'reference'   => 1,
  'karyotype'   => 2,
  'transcripts' => 3,
  'ditags'      => 4,
  'cagetags'    => 5, 
);

# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs; 
my $species_info;
my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
my $cdb_info = $species_defs->{_storage}->{Multi}->{databases}->{ENSEMBL_COMPARA};
my $cdb = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
  -dbname => $cdb_info->{'NAME'},
  -host   => $cdb_info->{'HOST'},
  -port   => $cdb_info->{'PORT'},
  -user   => $cdb_info->{'USER'},
  -driver => $cdb_info->{'DRIVER'},
);

my $ta = $cdb->get_NCBITaxonAdaptor();
my $hash = $species_defs;

my $species =  $SiteDefs::ENSEMBL_SPECIES || [];

my $shash;
$| = 1;
foreach my $sp (@$species) {
warn "Parsing species $sp ".gmtime();
  my $search_info = $species_defs->get_config($sp, 'SEARCH_LINKS');
  (my $vsp = $sp) =~ s/\_/ /g;
  $species_info->{$sp}->{'species'} = $vsp;
  $species_info->{$sp}->{'taxon_id'} = $ta->fetch_node_by_name($vsp)->taxon_id;

  my $db_info = $species_defs->get_config($sp, 'databases')->{'ENSEMBL_DB'};
  my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -species => $sp,
    -dbname  => $db_info->{'NAME'},
    -host    => $db_info->{'HOST'},
    -port    => $db_info->{'PORT'},
    -user    => $db_info->{'USER'},
    -driver  => $db_info->{'DRIVER'},
  );
  my $dbh = $db->dbc->db_handle;
  my $toplevel_slices   = $dbh->selectall_arrayref( q(
  select sr.name, sr.length,min(a.asm_start) as a, max(a.asm_end) as b
    from (seq_region as sr, seq_region_attrib as sra, attrib_type as at) left join
         assembly as a on a.asm_seq_region_id = sr.seq_region_id 
   where sr.seq_region_id = sra.seq_region_id and sra.attrib_type_id = at.attrib_type_id and at.code = "toplevel"
   group by sr.seq_region_id
  ));
  my $toplevel_example  = $toplevel_slices->[0];

  my $mapmaster = sprintf("%s.%s.reference", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'));
  $shash->{$mapmaster}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";
  $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), @$toplevel_slices );
# my $sl = $thash{$search_info->{'MAPVIEW1_TEXT'} || $search_info->{'DEFAULT1_TEXT'}} || $toplevel_slices[0];
    #warn Data::Dumper::Dumper(\%thash);

  my $start = $toplevel_example->['2'] || 1;
  $shash->{$mapmaster}->{'test_range'} = sprintf("%s:%d,%d", $toplevel_example->[0], $start, $start);

  entry_points( $toplevel_slices, $mapmaster, "$SERVERROOT/htdocs/das/$mapmaster" );
  foreach my $feature ( qw(karyotype transcripts ditags cagetags)) {
    my $dbn = 'ENSEMBL_DB';
    my $table = $featuresMasterTable{$feature};
    my $rv = $species_defs->get_table_size( { -db => $dbn, -table=> $table }, $sp);
    next unless $rv;
    my $sql = $featuresQuery{$feature};
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @r = $sth->fetchrow();
#   print STDERR "\t $sp : $feature => Off\n" and next unless @r;
#   print STDERR "\t $sp : $feature : $table => ", $rv || 'Off',  "\n";
#   print STDERR "\t\t\tTEST REGION : ", join('*', @r), "\n";
    next unless @r;
    my $dsn = sprintf("%s.%s.%s", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), $feature);
    $shash->{$dsn}->{'test_range'} = sprintf("%s:%s,%s",@r); 
    $shash->{$dsn}->{mapmaster} = "http://$SiteDefs::ENSEMBL_SERVERNAME/das/$mapmaster";
    $shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
  }
}

sources( $shash, "$SERVERROOT/htdocs/das/sources" );
dsn(     $shash, "$SERVERROOT/htdocs/das/dsn"     );

print STDERR sprintf("%d sources are active\n", scalar(keys %$shash));
#print STDERR Data::Dumper::Dumper($species_info);

sub entry_points {
  my( $entry_points, $href, $file ) = @_;

  mkdir $file, 0775 unless -e $file;
  open FH, ">$file/entry_points";
  print FH qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASEP SYSTEM "http://www.biodas.org/dtd/dascep.dtd">\n<DASEP>\n  <ENTRY_POINTS href="$href" version="1.0">);
  foreach my $seg (@$entry_points) {
    printf FH qq(
    <SEGMENT id="%s" start="%d" stop="%d" orientation="+">%s</SEGMENT>), $seg->[0], 1, $seg->[1], $seg->[0];
  }
  print FH qq(\n  </ENTRY_POINTS>\n</DASEP>\n);
  close FH;
}

sub dsn {
  my( $sources, $file ) = @_;
  open FH, ">$file";
  print FH qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASDSN SYSTEM "http://www.biodas.org/dtd/dasdsn.dtd">\n<DASDSN>);
  for my $dsn (sort keys %$sources) {
    print FH qq(
  <DSN>
    <SOURCE id="$dsn">$dsn</SOURCE>
    <MAPMASTER>$sources->{$dsn}{mapmaster}</MAPMASTER>
    <DESCRIPTION>$sources->{$dsn}{description}</DESCRIPTION>
  </DSN>);
  }
  print FH qq(\n</DASDSN>\n);
  close FH;
}

sub sources {
  my( $sources, $file ) = @_;
  open FH, ">$file";
  my ($day, $month, $year) = (localtime)[3,4,5];
  my $today = sprintf("%04d-%02d-%02d", $year + 1900, $month + 1, $day);
  print FH qq(<?xml version="1.0" encoding="UTF-8" ?>\n<SOURCES xmlns="http://biodas.org/documents/das2">);
  for my $dsn (sort keys %$sources) {
    my @n = split /\./, $dsn;
    my $species = shift @n;
    (my $vsp = $species) =~ s/\_/ /g;
    my $source = pop @n;
    my $assembly = join('.', @n);
    my $id = sprintf("ENSEMBL_%s_%s", $sourcesIds{$source} || $source, $assembly);
    my $capability = $source eq 'reference' ?  qq(
    <CAPABILITY type="das1:entry_points" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/entry_points"/>
    <CAPABILITY type="das1:sequence" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/sequence"/>) : qq(
    <CAPABILITY type="das1:stylesheet" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/stylesheet"/> );
    printf FH qq( 
  <SOURCE uri="%s" title="%s" description="%s">
    <MAINTAINER email="helpdesk\@ensembl.org" />
    <VERSION uri="latest" created="%s">
      <COORDINATES uri="ensembl_location_chromosome" taxid="%d" source="Chromosome" authority="%s" version="%s" test_range="%s"/>
      <CAPABILITY type="das1:features" query_uri="http://$SiteDefs::ENSEMBL_SERVERNAME/das/%s/features" />$capability
      <PROPERTY name="label" value="ENSEMBL" />
    </VERSION>
  </SOURCE>),
      $id, $dsn, $sources->{$dsn}{description},
      $today,
      $ta->fetch_node_by_name($vsp)->taxon_id, $assembly, $assembly, $sources->{$dsn}->{'test_range'},
      $dsn, $dsn, $dsn;
  }
  print FH "\n</SOURCES>\n";
  close FH;
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

